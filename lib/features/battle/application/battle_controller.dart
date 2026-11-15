import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../practice/application/practice_session_controller.dart';
import '../../practice/domain/hybrid_question_generator.dart';

enum BattleMode {
  smartMatchmaking,
  botAi,
  localSplitScreen,
}

enum BotDifficulty {
  rookie, // Tập Sự (Dễ)
  academy, // Học Viện (Trung bình)
  maestro, // Nhạc Trưởng (Khó)
  legend, // Huyền Thoại (Siêu Cấp)
}

enum BattlePhase {
  lobby,
  matchmaking,
  vsIntro,
  fighting,
  finished,
}

class BattleRankInfo {
  final String tierName;
  final String badgeEmoji;
  final int currentStars;
  final int nextTierStars;
  final int colorHex;

  const BattleRankInfo({
    required this.tierName,
    required this.badgeEmoji,
    required this.currentStars,
    required this.nextTierStars,
    required this.colorHex,
  });

  double get progressToNextTier {
    if (currentStars >= 35) return 1.0;
    if (currentStars >= 22) return (currentStars - 22) / 13.0;
    if (currentStars >= 12) return (currentStars - 12) / 10.0;
    if (currentStars >= 5) return (currentStars - 5) / 7.0;
    return (currentStars / 5.0).clamp(0.0, 1.0);
  }

  static BattleRankInfo fromStars(int stars) {
    final s = stars < 0 ? 0 : stars;
    if (s >= 35) {
      return BattleRankInfo(
        tierName: 'Đại Cao Thủ Solfa',
        badgeEmoji: '👑',
        currentStars: s,
        nextTierStars: s + 10,
        colorHex: 0xFFEC4899,
      );
    } else if (s >= 22) {
      return BattleRankInfo(
        tierName: 'Kim Cương',
        badgeEmoji: '💎',
        currentStars: s,
        nextTierStars: 35,
        colorHex: 0xFF06B6D4,
      );
    } else if (s >= 12) {
      return BattleRankInfo(
        tierName: 'Vàng',
        badgeEmoji: '🏆',
        currentStars: s,
        nextTierStars: 22,
        colorHex: 0xFFF59E0B,
      );
    } else if (s >= 5) {
      return BattleRankInfo(
        tierName: 'Bạc',
        badgeEmoji: '🛡️',
        currentStars: s,
        nextTierStars: 12,
        colorHex: 0xFF94A3B8,
      );
    } else {
      return BattleRankInfo(
        tierName: 'Đồng',
        badgeEmoji: '⚔️',
        currentStars: s,
        nextTierStars: 5,
        colorHex: 0xFFCD7F32,
      );
    }
  }
}

class BattleState {
  static const int maxHp = 100;

  final BattlePhase phase;
  final BattleMode mode;
  final BotDifficulty botDifficulty;
  final String selectedTopicId; // 'all' or specific topic_id

  // Persistent Rank Stats
  final int totalStars;
  final int totalWins;
  final int totalMatches;

  // Match Fighters
  final String player1Name;
  final String player1Title;
  final String player2Name;
  final String player2Title;
  final String player2AvatarEmoji;

  // Active Match Combat State
  final List<QuestionModel> questions;
  final int currentRoundIndex;
  final int player1Hp;
  final int player2Hp;
  final int player1Combo;
  final int player2Combo;
  final int player1MaxCombo;
  final int player2MaxCombo;
  final int player1CorrectCount;
  final int player2CorrectCount;

  // Round Resolution & Game FX
  final bool isRoundResolved;
  final String? roundWinner; // 'p1', 'p2', 'both_wrong'
  final String? p1SelectedOptionId;
  final String? p2SelectedOptionId;
  final bool p1LockedOut;
  final bool p2LockedOut;
  final int lastDamageDealt;
  final bool lastHitWasCrit;
  final String? combatBannerText;
  final int roundRemainingDeciseconds; // 80 = 8.0s
  final int starsDeltaLastMatch;
  final bool isLoading;

  const BattleState({
    this.phase = BattlePhase.lobby,
    this.mode = BattleMode.smartMatchmaking,
    this.botDifficulty = BotDifficulty.academy,
    this.selectedTopicId = 'all',
    this.totalStars = 0,
    this.totalWins = 0,
    this.totalMatches = 0,
    this.player1Name = 'Bạn',
    this.player1Title = 'Chiến binh Solfa',
    this.player2Name = 'Đối thủ',
    this.player2Title = 'Cao thủ Cảm âm',
    this.player2AvatarEmoji = '🎹',
    this.questions = const [],
    this.currentRoundIndex = 0,
    this.player1Hp = maxHp,
    this.player2Hp = maxHp,
    this.player1Combo = 0,
    this.player2Combo = 0,
    this.player1MaxCombo = 0,
    this.player2MaxCombo = 0,
    this.player1CorrectCount = 0,
    this.player2CorrectCount = 0,
    this.isRoundResolved = false,
    this.roundWinner,
    this.p1SelectedOptionId,
    this.p2SelectedOptionId,
    this.p1LockedOut = false,
    this.p2LockedOut = false,
    this.lastDamageDealt = 0,
    this.lastHitWasCrit = false,
    this.combatBannerText,
    this.roundRemainingDeciseconds = 80,
    this.starsDeltaLastMatch = 0,
    this.isLoading = false,
  });

  BattleRankInfo get rankInfo => BattleRankInfo.fromStars(totalStars);

  QuestionModel? get currentQuestion =>
      (currentRoundIndex >= 0 && currentRoundIndex < questions.length)
          ? questions[currentRoundIndex]
          : null;

  int get totalRounds => questions.length;

  bool get isKnockOut => player1Hp <= 0 || player2Hp <= 0;

  bool get didPlayer1Win {
    if (player1Hp != player2Hp) return player1Hp > player2Hp;
    if (player1CorrectCount != player2CorrectCount) {
      return player1CorrectCount > player2CorrectCount;
    }
    return player1MaxCombo >= player2MaxCombo;
  }

  bool get isDraw =>
      player1Hp == player2Hp &&
      player1CorrectCount == player2CorrectCount &&
      player1MaxCombo == player2MaxCombo;

  BattleState copyWith({
    BattlePhase? phase,
    BattleMode? mode,
    BotDifficulty? botDifficulty,
    String? selectedTopicId,
    int? totalStars,
    int? totalWins,
    int? totalMatches,
    String? player1Name,
    String? player1Title,
    String? player2Name,
    String? player2Title,
    String? player2AvatarEmoji,
    List<QuestionModel>? questions,
    int? currentRoundIndex,
    int? player1Hp,
    int? player2Hp,
    int? player1Combo,
    int? player2Combo,
    int? player1MaxCombo,
    int? player2MaxCombo,
    int? player1CorrectCount,
    int? player2CorrectCount,
    bool? isRoundResolved,
    String? roundWinner,
    bool clearRoundWinner = false,
    String? p1SelectedOptionId,
    bool clearP1Selection = false,
    String? p2SelectedOptionId,
    bool clearP2Selection = false,
    bool? p1LockedOut,
    bool? p2LockedOut,
    int? lastDamageDealt,
    bool? lastHitWasCrit,
    String? combatBannerText,
    bool clearCombatBanner = false,
    int? roundRemainingDeciseconds,
    int? starsDeltaLastMatch,
    bool? isLoading,
  }) {
    return BattleState(
      phase: phase ?? this.phase,
      mode: mode ?? this.mode,
      botDifficulty: botDifficulty ?? this.botDifficulty,
      selectedTopicId: selectedTopicId ?? this.selectedTopicId,
      totalStars: totalStars ?? this.totalStars,
      totalWins: totalWins ?? this.totalWins,
      totalMatches: totalMatches ?? this.totalMatches,
      player1Name: player1Name ?? this.player1Name,
      player1Title: player1Title ?? this.player1Title,
      player2Name: player2Name ?? this.player2Name,
      player2Title: player2Title ?? this.player2Title,
      player2AvatarEmoji: player2AvatarEmoji ?? this.player2AvatarEmoji,
      questions: questions ?? this.questions,
      currentRoundIndex: currentRoundIndex ?? this.currentRoundIndex,
      player1Hp: player1Hp ?? this.player1Hp,
      player2Hp: player2Hp ?? this.player2Hp,
      player1Combo: player1Combo ?? this.player1Combo,
      player2Combo: player2Combo ?? this.player2Combo,
      player1MaxCombo: player1MaxCombo ?? this.player1MaxCombo,
      player2MaxCombo: player2MaxCombo ?? this.player2MaxCombo,
      player1CorrectCount: player1CorrectCount ?? this.player1CorrectCount,
      player2CorrectCount: player2CorrectCount ?? this.player2CorrectCount,
      isRoundResolved: isRoundResolved ?? this.isRoundResolved,
      roundWinner:
          clearRoundWinner ? null : (roundWinner ?? this.roundWinner),
      p1SelectedOptionId: clearP1Selection
          ? null
          : (p1SelectedOptionId ?? this.p1SelectedOptionId),
      p2SelectedOptionId: clearP2Selection
          ? null
          : (p2SelectedOptionId ?? this.p2SelectedOptionId),
      p1LockedOut: p1LockedOut ?? this.p1LockedOut,
      p2LockedOut: p2LockedOut ?? this.p2LockedOut,
      lastDamageDealt: lastDamageDealt ?? this.lastDamageDealt,
      lastHitWasCrit: lastHitWasCrit ?? this.lastHitWasCrit,
      combatBannerText:
          clearCombatBanner ? null : (combatBannerText ?? this.combatBannerText),
      roundRemainingDeciseconds:
          roundRemainingDeciseconds ?? this.roundRemainingDeciseconds,
      starsDeltaLastMatch: starsDeltaLastMatch ?? this.starsDeltaLastMatch,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class BattleNotifier extends StateNotifier<BattleState> {
  static final Random _rng = Random();

  static const List<(String name, String title, String emoji)>
      _onlineChallengers = [
    ('Minh Khôi', 'Nhạc viện TP.HCM • Piano', '🎹'),
    ('Bảo Ngọc', 'Học viện Âm nhạc • Violin', '🎻'),
    ('Hoàng Nam', 'Guitarist Acoustic', '🎸'),
    ('Thanh Trúc', 'Soprano Vocalist', '🎤'),
    ('Đức Anh', 'Jazz Saxophone', '🎷'),
    ('Linh Đan', 'Cao thủ Đọc Khuông', '🎼'),
    ('Tuấn Kiệt', 'Trống & Tiết tấu', '🥁'),
    ('Hà My', 'Thính giác Tuyệt đối', '🎧'),
  ];

  final AppDatabase _db;
  final HybridQuestionGenerator _generator;
  final AudioService _audioService;
  final Ref _ref;

  Timer? _phaseTimer;
  Timer? _roundTimer;
  Timer? _botActionTimer;
  Timer? _autoNextRoundTimer;
  DateTime? _roundStartedAt;

  BattleNotifier(
    this._db,
    this._generator,
    this._audioService,
    this._ref,
  ) : super(const BattleState()) {
    loadRankStats();
  }

  void _cancelAllTimers() {
    _phaseTimer?.cancel();
    _roundTimer?.cancel();
    _botActionTimer?.cancel();
    _autoNextRoundTimer?.cancel();
    _phaseTimer = null;
    _roundTimer = null;
    _botActionTimer = null;
    _autoNextRoundTimer = null;
  }

  Future<void> loadRankStats() async {
    try {
      final stars =
          int.tryParse(await _db.getSetting('battle_stars') ?? '0') ?? 0;
      final wins =
          int.tryParse(await _db.getSetting('battle_wins') ?? '0') ?? 0;
      final matches =
          int.tryParse(await _db.getSetting('battle_matches') ?? '0') ?? 0;
      state = state.copyWith(
        totalStars: stars,
        totalWins: wins,
        totalMatches: matches,
      );
    } catch (_) {}
  }

  void setBattleMode(BattleMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setBotDifficulty(BotDifficulty difficulty) {
    state = state.copyWith(botDifficulty: difficulty);
  }

  void setSelectedTopicId(String topicId) {
    state = state.copyWith(selectedTopicId: topicId);
  }

  /// Starts a 1v1 Battle Match (Matchmaking, Bot AI, or Local Split-Screen).
  Future<void> startBattle({int? seed, int roundCount = 10}) async {
    _cancelAllTimers();
    await _audioService.stop();
    state = state.copyWith(isLoading: true);

    final rng = seed != null ? Random(seed) : _rng;
    final questions = await _buildBattleQuestionSet(
      topicId: state.selectedTopicId,
      targetCount: roundCount,
      seed: seed,
    );

    if (questions.isEmpty) {
      state = state.copyWith(isLoading: false);
      return;
    }

    // Resolve fighter names & avatars based on mode
    String p1Name = 'Bạn';
    String p1Title = 'Hạng ${state.rankInfo.tierName}';
    String p2Name = 'Đối thủ';
    String p2Title = 'Cao thủ Cảm âm';
    String p2Emoji = '🎹';

    if (state.mode == BattleMode.localSplitScreen) {
      p1Name = 'Người chơi 1';
      p1Title = 'Góc Xanh Indigo';
      p2Name = 'Người chơi 2';
      p2Title = 'Góc Đỏ Crimson';
      p2Emoji = '🔥';
    } else if (state.mode == BattleMode.botAi) {
      switch (state.botDifficulty) {
        case BotDifficulty.rookie:
          p2Name = 'Bot Tập Sự';
          p2Title = 'AI Cấp 1 • Tốc độ Chậm';
          p2Emoji = '🤖';
          break;
        case BotDifficulty.academy:
          p2Name = 'Bot Học Viện';
          p2Title = 'AI Cấp 2 • Cân bằng';
          p2Emoji = '🎹';
          break;
        case BotDifficulty.maestro:
          p2Name = 'Bot Nhạc Trưởng';
          p2Title = 'AI Cấp 3 • Phản xạ Nhanh';
          p2Emoji = '🎼';
          break;
        case BotDifficulty.legend:
          p2Name = 'Bot Huyền Thoại';
          p2Title = 'AI Cấp 4 • Tuyệt Đỉnh';
          p2Emoji = '👑';
          break;
      }
    } else {
      final pick = _onlineChallengers[rng.nextInt(_onlineChallengers.length)];
      p2Name = pick.$1;
      p2Title = '${pick.$2} • ${state.rankInfo.tierName}';
      p2Emoji = pick.$3;
    }

    state = state.copyWith(
      isLoading: false,
      phase: state.mode == BattleMode.smartMatchmaking
          ? BattlePhase.matchmaking
          : BattlePhase.vsIntro,
      player1Name: p1Name,
      player1Title: p1Title,
      player2Name: p2Name,
      player2Title: p2Title,
      player2AvatarEmoji: p2Emoji,
      questions: questions,
      currentRoundIndex: 0,
      player1Hp: BattleState.maxHp,
      player2Hp: BattleState.maxHp,
      player1Combo: 0,
      player2Combo: 0,
      player1MaxCombo: 0,
      player2MaxCombo: 0,
      player1CorrectCount: 0,
      player2CorrectCount: 0,
      isRoundResolved: false,
      clearRoundWinner: true,
      clearP1Selection: true,
      clearP2Selection: true,
      p1LockedOut: false,
      p2LockedOut: false,
      lastDamageDealt: 0,
      lastHitWasCrit: false,
      clearCombatBanner: true,
      roundRemainingDeciseconds: 80,
      starsDeltaLastMatch: 0,
    );

    if (_audioService.isTestMode) {
      // In automated test mode, allow immediate progression or explicit enterArenaNow()
      return;
    }

    if (state.phase == BattlePhase.matchmaking) {
      _phaseTimer = Timer(const Duration(milliseconds: 1100), () {
        if (!mounted || state.phase != BattlePhase.matchmaking) return;
        state = state.copyWith(phase: BattlePhase.vsIntro);
        _phaseTimer = Timer(const Duration(milliseconds: 1200), () {
          if (!mounted || state.phase != BattlePhase.vsIntro) return;
          enterArenaNow();
        });
      });
    } else if (state.phase == BattlePhase.vsIntro) {
      _phaseTimer = Timer(const Duration(milliseconds: 1100), () {
        if (!mounted || state.phase != BattlePhase.vsIntro) return;
        enterArenaNow();
      });
    }
  }

  /// Transitions immediately from matchmaking/vsIntro into active Round 1 fighting.
  Future<void> enterArenaNow() async {
    _phaseTimer?.cancel();
    if (state.questions.isEmpty) return;
    state = state.copyWith(
      phase: BattlePhase.fighting,
      currentRoundIndex: 0,
      isRoundResolved: false,
      clearRoundWinner: true,
      clearP1Selection: true,
      clearP2Selection: true,
      p1LockedOut: false,
      p2LockedOut: false,
      clearCombatBanner: true,
      roundRemainingDeciseconds: 80,
    );
    await _beginCurrentRound();
  }

  Future<List<QuestionModel>> _buildBattleQuestionSet({
    required String topicId,
    required int targetCount,
    int? seed,
  }) async {
    if (topicId != 'all') {
      final res = await _generator.generateSessionQuestions(
        mode: 'topic',
        topicId: topicId,
        targetCount: targetCount,
        seed: seed,
      );
      return res.questions;
    }

    // All-in-One mixed arena: sample across all 7 topics and shuffle!
    const allTopics = [
      ('topic_notes', 'lvl_notes_basic'),
      ('topic_staff_reading', 'lvl_staff_basic'),
      ('topic_intervals', 'lvl_intervals_basic'),
      ('topic_chords', 'lvl_chords_basic'),
      ('topic_melody', 'lvl_melody_basic'),
      ('topic_rhythm', 'lvl_rhythm_basic'),
      ('topic_keys', 'lvl_keys_basic'),
    ];
    final List<QuestionModel> mixed = [];
    for (int i = 0; i < allTopics.length; i++) {
      final (tId, lId) = allTopics[i];
      final res = await _generator.generateSessionQuestions(
        mode: 'topic',
        topicId: tId,
        levelId: lId,
        targetCount: 2,
        seed: seed != null ? seed + i * 31 : null,
      );
      mixed.addAll(res.questions);
    }
    final rng = seed != null ? Random(seed) : _rng;
    mixed.shuffle(rng);
    return mixed.take(targetCount).toList();
  }

  Future<void> _beginCurrentRound() async {
    _roundTimer?.cancel();
    _botActionTimer?.cancel();
    _autoNextRoundTimer?.cancel();
    _roundStartedAt = DateTime.now();

    final curQ = state.currentQuestion;
    if (curQ == null) return;

    final settings = _ref.read(appSettingsProvider);
    if (settings.autoPlayQuestionAudio && !curQ.isSightReading) {
      await _audioService.playAsset(curQ.audioAsset);
    }

    if (_audioService.isTestMode) return;

    // 100ms decisecond countdown (8.0s per round)
    _roundTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted ||
          state.phase != BattlePhase.fighting ||
          state.isRoundResolved) {
        timer.cancel();
        return;
      }
      final nextDeci = state.roundRemainingDeciseconds - 1;
      if (nextDeci <= 0) {
        timer.cancel();
        _onRoundTimeExpired();
      } else {
        state = state.copyWith(roundRemainingDeciseconds: nextDeci);
      }
    });

    // Schedule Bot / Online Challenger simulated response if not Local Split-Screen
    if (state.mode != BattleMode.localSplitScreen) {
      final (minMs, maxMs, _) = _opponentProfileParams();
      final delayMs = minMs + _rng.nextInt(max(100, maxMs - minMs));
      _botActionTimer = Timer(Duration(milliseconds: delayMs), () {
        if (!mounted ||
            state.phase != BattlePhase.fighting ||
            state.isRoundResolved) {
          return;
        }
        _triggerOpponentAiStrike();
      });
    }
  }

  (int minMs, int maxMs, double accuracy) _opponentProfileParams() {
    if (state.mode == BattleMode.botAi) {
      switch (state.botDifficulty) {
        case BotDifficulty.rookie:
          return (4000, 6200, 0.62);
        case BotDifficulty.academy:
          return (2800, 4600, 0.76);
        case BotDifficulty.maestro:
          return (1900, 3200, 0.88);
        case BotDifficulty.legend:
          return (1300, 2300, 0.95);
      }
    }
    // Smart Matchmaking scales smoothly with user's current stars
    final stars = state.totalStars;
    if (stars >= 25) return (1700, 3000, 0.88);
    if (stars >= 12) return (2300, 3800, 0.80);
    if (stars >= 5) return (2800, 4500, 0.74);
    return (3300, 5200, 0.68);
  }

  int _computeStrikeDamage({
    required int responseMs,
    required int newCombo,
  }) {
    int dmg = 16;
    if (responseMs <= 1600) {
      dmg += 8; // Tốc kích siêu thanh
    } else if (responseMs <= 3000) {
      dmg += 4; // Tốc kích
    }
    if (newCombo >= 3) {
      dmg = (dmg * 1.35).round(); // Bạo kích Combo!
    }
    return dmg.clamp(12, 36);
  }

  /// Submits an answer for Player 1 (User in 1v1 Bot/Matchmaking, or Player 1 in Split-Screen).
  Future<void> submitPlayer1Answer(QuestionOptionModel option) async {
    if (state.phase != BattlePhase.fighting ||
        state.isRoundResolved ||
        state.p1LockedOut) {
      return;
    }
    final curQ = state.currentQuestion;
    if (curQ == null) return;

    final elapsedMs = _roundStartedAt != null
        ? DateTime.now().difference(_roundStartedAt!).inMilliseconds
        : 1200;

    if (option.isCorrect) {
      _roundTimer?.cancel();
      _botActionTimer?.cancel();

      final nextCombo = state.player1Combo + 1;
      final nextMaxCombo =
          nextCombo > state.player1MaxCombo ? nextCombo : state.player1MaxCombo;
      final isCrit = nextCombo >= 3;
      final dmg = _computeStrikeDamage(
        responseMs: elapsedMs,
        newCombo: nextCombo,
      );
      final nextP2Hp = (state.player2Hp - dmg).clamp(0, BattleState.maxHp);

      final banner = isCrit
          ? '💥 BẠO KÍCH COMBO x$nextCombo! -$dmg HP'
          : (elapsedMs <= 1800
              ? '⚡ TỐC KÍCH! -$dmg HP'
              : '⚔️ ĐÒN CHUẨN XÁC! -$dmg HP');

      state = state.copyWith(
        isRoundResolved: true,
        roundWinner: 'p1',
        p1SelectedOptionId: option.id,
        player2Hp: nextP2Hp,
        player1Combo: nextCombo,
        player1MaxCombo: nextMaxCombo,
        player2Combo: 0,
        player1CorrectCount: state.player1CorrectCount + 1,
        lastDamageDealt: dmg,
        lastHitWasCrit: isCrit,
        combatBannerText: banner,
      );

      _triggerImpactFeedback(isCorrect: true, isCrit: isCrit, curQ: curQ);
      _scheduleAutoAdvanceRound();
    } else {
      // Wrong answer!
      if (state.mode == BattleMode.localSplitScreen) {
        // In Local 1v1 Split-Screen: P1 takes -12 HP self-recoil and locks out; if P2 already locked out, resolve round
        final nextP1Hp = (state.player1Hp - 12).clamp(0, BattleState.maxHp);
        final bothLocked = state.p2LockedOut || nextP1Hp <= 0;
        state = state.copyWith(
          p1SelectedOptionId: option.id,
          p1LockedOut: true,
          player1Hp: nextP1Hp,
          player1Combo: 0,
          isRoundResolved: bothLocked,
          roundWinner: bothLocked ? 'both_wrong' : null,
          lastDamageDealt: 12,
          lastHitWasCrit: false,
          combatBannerText:
              '⚠️ ${state.player1Name} bấm sai! Tự mất -12 HP',
        );
        _triggerImpactFeedback(isCorrect: false, isCrit: false, curQ: curQ);
        if (bothLocked) {
          _roundTimer?.cancel();
          _scheduleAutoAdvanceRound();
        }
      } else {
        // In Bot / Matchmaking mode: P1 wrong -> Opponent immediately counter-attacks!
        _roundTimer?.cancel();
        _botActionTimer?.cancel();
        final nextP2Combo = state.player2Combo + 1;
        final nextP2Max = nextP2Combo > state.player2MaxCombo
            ? nextP2Combo
            : state.player2MaxCombo;
        final isCrit = nextP2Combo >= 3;
        final counterDmg = isCrit ? 24 : 18;
        final nextP1Hp =
            (state.player1Hp - counterDmg).clamp(0, BattleState.maxHp);

        state = state.copyWith(
          isRoundResolved: true,
          roundWinner: 'p2',
          p1SelectedOptionId: option.id,
          p2SelectedOptionId: curQ.correctOption.id,
          player1Hp: nextP1Hp,
          player1Combo: 0,
          player2Combo: nextP2Combo,
          player2MaxCombo: nextP2Max,
          player2CorrectCount: state.player2CorrectCount + 1,
          lastDamageDealt: counterDmg,
          lastHitWasCrit: isCrit,
          combatBannerText:
              '🛡️ ${state.player2Name} PHẢN ĐÒN! -$counterDmg HP',
        );
        _triggerImpactFeedback(isCorrect: false, isCrit: isCrit, curQ: curQ);
        _scheduleAutoAdvanceRound();
      }
    }
  }

  /// Submits an answer for Player 2 (in Local 1v1 Split-Screen mode).
  Future<void> submitPlayer2Answer(QuestionOptionModel option) async {
    if (state.mode != BattleMode.localSplitScreen ||
        state.phase != BattlePhase.fighting ||
        state.isRoundResolved ||
        state.p2LockedOut) {
      return;
    }
    final curQ = state.currentQuestion;
    if (curQ == null) return;

    final elapsedMs = _roundStartedAt != null
        ? DateTime.now().difference(_roundStartedAt!).inMilliseconds
        : 1200;

    if (option.isCorrect) {
      _roundTimer?.cancel();
      final nextCombo = state.player2Combo + 1;
      final nextMaxCombo =
          nextCombo > state.player2MaxCombo ? nextCombo : state.player2MaxCombo;
      final isCrit = nextCombo >= 3;
      final dmg = _computeStrikeDamage(
        responseMs: elapsedMs,
        newCombo: nextCombo,
      );
      final nextP1Hp = (state.player1Hp - dmg).clamp(0, BattleState.maxHp);

      final banner = isCrit
          ? '💥 ${state.player2Name} BẠO KÍCH x$nextCombo! -$dmg HP'
          : '⚔️ ${state.player2Name} TẤN CÔNG! -$dmg HP';

      state = state.copyWith(
        isRoundResolved: true,
        roundWinner: 'p2',
        p2SelectedOptionId: option.id,
        player1Hp: nextP1Hp,
        player2Combo: nextCombo,
        player2MaxCombo: nextMaxCombo,
        player1Combo: 0,
        player2CorrectCount: state.player2CorrectCount + 1,
        lastDamageDealt: dmg,
        lastHitWasCrit: isCrit,
        combatBannerText: banner,
      );

      _triggerImpactFeedback(isCorrect: true, isCrit: isCrit, curQ: curQ);
      _scheduleAutoAdvanceRound();
    } else {
      final nextP2Hp = (state.player2Hp - 12).clamp(0, BattleState.maxHp);
      final bothLocked = state.p1LockedOut || nextP2Hp <= 0;
      state = state.copyWith(
        p2SelectedOptionId: option.id,
        p2LockedOut: true,
        player2Hp: nextP2Hp,
        player2Combo: 0,
        isRoundResolved: bothLocked,
        roundWinner: bothLocked ? 'both_wrong' : null,
        lastDamageDealt: 12,
        lastHitWasCrit: false,
        combatBannerText:
            '⚠️ ${state.player2Name} bấm sai! Tự mất -12 HP',
      );
      _triggerImpactFeedback(isCorrect: false, isCrit: false, curQ: curQ);
      if (bothLocked) {
        _roundTimer?.cancel();
        _scheduleAutoAdvanceRound();
      }
    }
  }

  void _triggerOpponentAiStrike() {
    if (state.isRoundResolved || state.phase != BattlePhase.fighting) return;
    final curQ = state.currentQuestion;
    if (curQ == null) return;

    final (_, _, acc) = _opponentProfileParams();
    final isOpponentCorrect = _rng.nextDouble() <= acc;

    if (isOpponentCorrect) {
      _roundTimer?.cancel();
      final nextP2Combo = state.player2Combo + 1;
      final nextP2Max = nextP2Combo > state.player2MaxCombo
          ? nextP2Combo
          : state.player2MaxCombo;
      final isCrit = nextP2Combo >= 3;
      final dmg = isCrit ? 22 : 16;
      final nextP1Hp = (state.player1Hp - dmg).clamp(0, BattleState.maxHp);

      state = state.copyWith(
        isRoundResolved: true,
        roundWinner: 'p2',
        p2SelectedOptionId: curQ.correctOption.id,
        player1Hp: nextP1Hp,
        player2Combo: nextP2Combo,
        player2MaxCombo: nextP2Max,
        player1Combo: 0,
        player2CorrectCount: state.player2CorrectCount + 1,
        lastDamageDealt: dmg,
        lastHitWasCrit: isCrit,
        combatBannerText:
            '⚡ ${state.player2Name} ra đòn trước! -$dmg HP',
      );
      _triggerImpactFeedback(isCorrect: false, isCrit: isCrit, curQ: curQ);
      _scheduleAutoAdvanceRound();
    } else {
      // Opponent missed! Give player a free opening banner
      final wrongOpt = curQ.options.firstWhere((o) => !o.isCorrect);
      state = state.copyWith(
        p2SelectedOptionId: wrongOpt.id,
        player2Combo: 0,
        combatBannerText:
            '🎯 ${state.player2Name} trả lời trượt! Cơ hội tấn công của bạn!',
      );
    }
  }

  void _onRoundTimeExpired() {
    if (state.isRoundResolved || state.phase != BattlePhase.fighting) return;
    final curQ = state.currentQuestion;
    if (curQ == null) return;

    final nextP1Hp = (state.player1Hp - 15).clamp(0, BattleState.maxHp);
    final nextP2Hp = state.mode == BattleMode.localSplitScreen
        ? (state.player2Hp - 15).clamp(0, BattleState.maxHp)
        : state.player2Hp;

    state = state.copyWith(
      isRoundResolved: true,
      roundWinner: state.mode == BattleMode.localSplitScreen ? 'both_wrong' : 'p2',
      player1Hp: nextP1Hp,
      player2Hp: nextP2Hp,
      player1Combo: 0,
      lastDamageDealt: 15,
      lastHitWasCrit: false,
      combatBannerText: '⌛ Hết giờ! Mất -15 HP',
    );
    _triggerImpactFeedback(isCorrect: false, isCrit: false, curQ: curQ);
    _scheduleAutoAdvanceRound();
  }

  void _triggerImpactFeedback({
    required bool isCorrect,
    required bool isCrit,
    required QuestionModel curQ,
  }) {
    final settings = _ref.read(appSettingsProvider);
    if (settings.hapticFeedbackEnabled) {
      try {
        if (isCrit) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.mediumImpact();
        }
      } catch (_) {}
    }
    if (curQ.isSightReading) {
      unawaited(_audioService.playAsset(curQ.audioAsset));
    }
    unawaited(_audioService.playFeedbackSfx(isCorrect: isCorrect));
  }

  void _scheduleAutoAdvanceRound() {
    _autoNextRoundTimer?.cancel();
    if (_audioService.isTestMode) return;
    _autoNextRoundTimer = Timer(const Duration(milliseconds: 1350), () {
      if (!mounted ||
          state.phase != BattlePhase.fighting ||
          !state.isRoundResolved) {
        return;
      }
      nextRound();
    });
  }

  /// Advances to the next round or finishes the match if K.O. or all rounds completed.
  Future<void> nextRound() async {
    _autoNextRoundTimer?.cancel();
    if (state.phase != BattlePhase.fighting) return;

    final nextIdx = state.currentRoundIndex + 1;
    if (state.isKnockOut || nextIdx >= state.questions.length) {
      await _finishMatch();
      return;
    }

    state = state.copyWith(
      currentRoundIndex: nextIdx,
      isRoundResolved: false,
      clearRoundWinner: true,
      clearP1Selection: true,
      clearP2Selection: true,
      p1LockedOut: false,
      p2LockedOut: false,
      lastDamageDealt: 0,
      lastHitWasCrit: false,
      clearCombatBanner: true,
      roundRemainingDeciseconds: 80,
    );
    await _beginCurrentRound();
  }

  Future<void> _finishMatch() async {
    _cancelAllTimers();
    await _audioService.stop();

    final won = state.didPlayer1Win && !state.isDraw;
    int starsDelta = 0;
    if (state.isDraw) {
      starsDelta = 0;
    } else if (won) {
      starsDelta = (state.player2Hp <= 0 || state.player1MaxCombo >= 4) ? 2 : 1;
    } else {
      // Only deduct 1 star if player is above Bronze (>= 5 stars)
      starsDelta = state.totalStars >= 5 ? -1 : 0;
    }

    final nextStars = max(0, state.totalStars + starsDelta);
    final nextWins = won ? state.totalWins + 1 : state.totalWins;
    final nextMatches = state.totalMatches + 1;

    try {
      await _db.setSetting('battle_stars', nextStars.toString());
      await _db.setSetting('battle_wins', nextWins.toString());
      await _db.setSetting('battle_matches', nextMatches.toString());
    } catch (_) {}

    if (won) {
      unawaited(_audioService.playSessionCompleteFanfare());
    }

    state = state.copyWith(
      phase: BattlePhase.finished,
      totalStars: nextStars,
      totalWins: nextWins,
      totalMatches: nextMatches,
      starsDeltaLastMatch: starsDelta,
    );
  }

  /// Returns to the Battle Arena Lobby.
  Future<void> backToLobby() async {
    _cancelAllTimers();
    await _audioService.stop();
    state = state.copyWith(
      phase: BattlePhase.lobby,
      isRoundResolved: false,
      clearCombatBanner: true,
    );
  }

  @override
  void dispose() {
    _cancelAllTimers();
    super.dispose();
  }
}

final battleProvider =
    StateNotifierProvider<BattleNotifier, BattleState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final generator = ref.watch(hybridQuestionGeneratorProvider);
  final audio = ref.watch(audioServiceProvider);
  return BattleNotifier(db, generator, audio, ref);
});
