import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../practice/application/practice_session_controller.dart';
import '../../practice/domain/hybrid_question_generator.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';

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
  final IconData badgeIcon;
  final int currentStars;
  final int nextTierStars;
  final int colorHex;

  const BattleRankInfo({
    required this.tierName,
    required this.badgeIcon,
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
        badgeIcon: Icons.workspace_premium_rounded,
        currentStars: s,
        nextTierStars: s + 10,
        colorHex: 0xFFEC4899,
      );
    } else if (s >= 22) {
      return BattleRankInfo(
        tierName: 'Kim Cương',
        badgeIcon: Icons.diamond_rounded,
        currentStars: s,
        nextTierStars: 35,
        colorHex: 0xFF06B6D4,
      );
    } else if (s >= 12) {
      return BattleRankInfo(
        tierName: 'Vàng',
        badgeIcon: Icons.emoji_events_rounded,
        currentStars: s,
        nextTierStars: 22,
        colorHex: 0xFFF59E0B,
      );
    } else if (s >= 5) {
      return BattleRankInfo(
        tierName: 'Bạc',
        badgeIcon: Icons.shield_rounded,
        currentStars: s,
        nextTierStars: 12,
        colorHex: 0xFF94A3B8,
      );
    } else {
      return BattleRankInfo(
        tierName: 'Đồng',
        badgeIcon: Icons.military_tech_rounded,
        currentStars: s,
        nextTierStars: 5,
        colorHex: 0xFFCD7F32,
      );
    }
  }
}

class BattleMatchRecord {
  final String opponentName;
  final String modeLabel;
  final bool didWin;
  final bool isDraw;
  final int player1Hp;
  final int player2Hp;
  final int maxCombo;
  final int starsDelta;

  const BattleMatchRecord({
    required this.opponentName,
    required this.modeLabel,
    required this.didWin,
    required this.isDraw,
    required this.player1Hp,
    required this.player2Hp,
    required this.maxCombo,
    required this.starsDelta,
  });

  Map<String, dynamic> toJson() => {
        'opponentName': opponentName,
        'modeLabel': modeLabel,
        'didWin': didWin,
        'isDraw': isDraw,
        'player1Hp': player1Hp,
        'player2Hp': player2Hp,
        'maxCombo': maxCombo,
        'starsDelta': starsDelta,
      };

  factory BattleMatchRecord.fromJson(Map<String, dynamic> map) {
    return BattleMatchRecord(
      opponentName: (map['opponentName'] as String?) ?? 'Đối thủ',
      modeLabel: (map['modeLabel'] as String?) ?? 'Đấu Trường',
      didWin: (map['didWin'] as bool?) ?? false,
      isDraw: (map['isDraw'] as bool?) ?? false,
      player1Hp: (map['player1Hp'] as int?) ?? 0,
      player2Hp: (map['player2Hp'] as int?) ?? 0,
      maxCombo: (map['maxCombo'] as int?) ?? 0,
      starsDelta: (map['starsDelta'] as int?) ?? 0,
    );
  }
}

class BattleState {
  static const int maxHp = 100;
  static const int maxDailyFreeBattles = 5;

  final BattlePhase phase;
  final BattleMode mode;
  final BotDifficulty botDifficulty;
  final String selectedTopicId; // 'all' or specific topic_id

  // Persistent Rank & Daily Turn Stats
  final int totalStars;
  final int totalWins;
  final int totalMatches;
  final int remainingBattlesToday;
  final int adRestoredTurnsToday;
  final int dailyBattlesPlayed;
  final List<BattleMatchRecord> matchHistory;
  final int lastRankUpBonusPoints;

  // Match Fighters
  final String player1Name;
  final String player1Title;
  final String player2Name;
  final String player2Title;
  final IconData player2AvatarIcon;

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
    this.remainingBattlesToday = maxDailyFreeBattles,
    this.adRestoredTurnsToday = 0,
    this.dailyBattlesPlayed = 0,
    this.matchHistory = const [],
    this.lastRankUpBonusPoints = 0,
    this.player1Name = 'Bạn',
    this.player1Title = 'Chiến binh Solfa',
    this.player2Name = 'Đối thủ',
    this.player2Title = 'Cao thủ Cảm âm',
    this.player2AvatarIcon = Icons.piano_rounded,
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

  bool get canStartBattle => remainingBattlesToday > 0;

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
    int? remainingBattlesToday,
    int? adRestoredTurnsToday,
    int? dailyBattlesPlayed,
    List<BattleMatchRecord>? matchHistory,
    int? lastRankUpBonusPoints,
    String? player1Name,
    String? player1Title,
    String? player2Name,
    String? player2Title,
    IconData? player2AvatarIcon,
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
      remainingBattlesToday:
          remainingBattlesToday ?? this.remainingBattlesToday,
      adRestoredTurnsToday:
          adRestoredTurnsToday ?? this.adRestoredTurnsToday,
      dailyBattlesPlayed: dailyBattlesPlayed ?? this.dailyBattlesPlayed,
      matchHistory: matchHistory ?? this.matchHistory,
      lastRankUpBonusPoints:
          lastRankUpBonusPoints ?? this.lastRankUpBonusPoints,
      player1Name: player1Name ?? this.player1Name,
      player1Title: player1Title ?? this.player1Title,
      player2Name: player2Name ?? this.player2Name,
      player2Title: player2Title ?? this.player2Title,
      player2AvatarIcon: player2AvatarIcon ?? this.player2AvatarIcon,
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

  static const List<(String name, String title, IconData icon)>
      _onlineChallengers = [
    ('Minh Khôi', 'Nhạc viện TP.HCM • Piano', Icons.piano_rounded),
    ('Bảo Ngọc', 'Học viện Âm nhạc • Violin', Icons.music_note_rounded),
    ('Hoàng Nam', 'Guitarist Acoustic', Icons.audiotrack_rounded),
    ('Thanh Trúc', 'Soprano Vocalist', Icons.mic_rounded),
    ('Đức Anh', 'Jazz Saxophone', Icons.queue_music_rounded),
    ('Linh Đan', 'Cao thủ Đọc Khuông', Icons.library_music_rounded),
    ('Tuấn Kiệt', 'Trống & Tiết tấu', Icons.timer_rounded),
    ('Hà My', 'Thính giác Tuyệt đối', Icons.hearing_rounded),
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
  bool _isBusy = false;
  bool _isAppPaused = false;

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

  String _todayDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> loadRankStats() async {
    try {
      final map = await _db.getAllSettings();
      if (!mounted) return;
      final stars = int.tryParse(map['battle_stars'] ?? '0') ?? 0;
      final wins = int.tryParse(map['battle_wins'] ?? '0') ?? 0;
      final matches = int.tryParse(map['battle_matches'] ?? '0') ?? 0;

      final today = _todayDateKey();
      final savedDate = map['battle_energy_date'];
      int remainingTurns = BattleState.maxDailyFreeBattles;
      int adRestoredToday = 0;
      int dailyPlayed = 0;

      if (savedDate == today) {
        remainingTurns = int.tryParse(
              map['battle_remaining_turns'] ??
                  '${BattleState.maxDailyFreeBattles}',
            ) ??
            BattleState.maxDailyFreeBattles;
        adRestoredToday =
            int.tryParse(map['battle_ad_restored_today'] ?? '0') ?? 0;
        dailyPlayed = int.tryParse(map['battle_daily_played'] ?? '0') ?? 0;
      }

      List<BattleMatchRecord> history = [];
      final rawHistory = map['battle_match_history_json'];
      if (rawHistory != null && rawHistory.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawHistory) as List<dynamic>;
          history = decoded
              .whereType<Map>()
              .map(
                (m) =>
                    BattleMatchRecord.fromJson(Map<String, dynamic>.from(m)),
              )
              .toList();
        } catch (_) {}
      }

      // Avoid overwriting in-memory state if a battle has already started or turns were already modified
      if (state.dailyBattlesPlayed > 0 || state.phase != BattlePhase.lobby) {
        return;
      }
      state = state.copyWith(
        totalStars: stars,
        totalWins: wins,
        totalMatches: matches,
        remainingBattlesToday: remainingTurns.clamp(0, 99),
        adRestoredTurnsToday: adRestoredToday.clamp(0, 999),
        dailyBattlesPlayed: dailyPlayed.clamp(0, 999),
        matchHistory: history,
      );
    } catch (_) {}
  }

  /// Restores +1 battle turn after the user completes watching a Rewarded Video Ad.
  Future<void> restoreTurnFromRewardedAd({int turns = 1}) async {
    final added = turns.clamp(1, 10);
    final nextTurns = (state.remainingBattlesToday + added).clamp(0, 99);
    final nextRestored = (state.adRestoredTurnsToday + added).clamp(0, 999);
    state = state.copyWith(
      remainingBattlesToday: nextTurns,
      adRestoredTurnsToday: nextRestored,
    );
    try {
      await _db.setSetting('battle_energy_date', _todayDateKey());
      await _db.setSetting('battle_remaining_turns', nextTurns.toString());
      await _db.setSetting(
        'battle_ad_restored_today',
        nextRestored.toString(),
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
  /// Consumes 1 daily battle turn. Returns false if no turns remain today.
  Future<bool> startBattle({int? seed, int roundCount = 10}) async {
    if (_isBusy) return false;
    if (state.remainingBattlesToday <= 0) {
      return false;
    }
    _isBusy = true;
    try {
      _cancelAllTimers();
      try {
        await _audioService.stop();
      } catch (_) {}
      state = state.copyWith(isLoading: true);

      final rng = seed != null ? Random(seed) : _rng;
      final questions = await _buildBattleQuestionSet(
        topicId: state.selectedTopicId,
        targetCount: roundCount.clamp(1, 20),
        seed: seed,
      );

      if (questions.isEmpty || !mounted) {
        if (mounted) state = state.copyWith(isLoading: false);
        return false;
      }

      // Deduct 1 daily battle turn and persist to SQLite
      final nextTurns = (state.remainingBattlesToday - 1).clamp(0, 99);
      final nextDailyPlayed = (state.dailyBattlesPlayed + 1).clamp(0, 999);
      try {
        _ref.read(rewardedAdProvider.notifier).recordDailyBattlePlayed();
      } catch (_) {}
      try {
        await _db.setSetting('battle_energy_date', _todayDateKey());
        await _db.setSetting('battle_remaining_turns', nextTurns.toString());
        await _db.setSetting(
          'battle_daily_played',
          nextDailyPlayed.toString(),
        );
      } catch (_) {}

      // Resolve fighter names & avatars based on mode
      String p1Name = 'Bạn';
      String p1Title = 'Hạng ${state.rankInfo.tierName}';
      String p2Name = 'Đối thủ';
      String p2Title = 'Cao thủ Cảm âm';
      IconData p2Icon = Icons.piano_rounded;

      if (state.mode == BattleMode.localSplitScreen) {
        p1Name = 'Người chơi 1';
        p1Title = 'Góc Xanh Indigo';
        p2Name = 'Người chơi 2';
        p2Title = 'Góc Đỏ Crimson';
        p2Icon = Icons.local_fire_department_rounded;
      } else if (state.mode == BattleMode.botAi) {
        switch (state.botDifficulty) {
          case BotDifficulty.rookie:
            p2Name = 'Bot Tập Sự';
            p2Title = 'AI Cấp 1 • Tốc độ Chậm';
            p2Icon = Icons.smart_toy_rounded;
            break;
          case BotDifficulty.academy:
            p2Name = 'Bot Học Viện';
            p2Title = 'AI Cấp 2 • Cân bằng';
            p2Icon = Icons.school_rounded;
            break;
          case BotDifficulty.maestro:
            p2Name = 'Bot Nhạc Trưởng';
            p2Title = 'AI Cấp 3 • Phản xạ Nhanh';
            p2Icon = Icons.auto_awesome_rounded;
            break;
          case BotDifficulty.legend:
            p2Name = 'Bot Huyền Thoại';
            p2Title = 'AI Cấp 4 • Tuyệt Đỉnh';
            p2Icon = Icons.workspace_premium_rounded;
            break;
        }
      } else {
        final pick = _onlineChallengers[rng.nextInt(_onlineChallengers.length)];
        p2Name = pick.$1;
        p2Title = '${pick.$2} • ${state.rankInfo.tierName}';
        p2Icon = pick.$3;
      }

      state = state.copyWith(
        isLoading: false,
        remainingBattlesToday: nextTurns,
        dailyBattlesPlayed: nextDailyPlayed,
        lastRankUpBonusPoints: 0,
        phase: state.mode == BattleMode.smartMatchmaking
            ? BattlePhase.matchmaking
            : BattlePhase.vsIntro,
        player1Name: p1Name,
        player1Title: p1Title,
        player2Name: p2Name,
        player2Title: p2Title,
        player2AvatarIcon: p2Icon,
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
        return true;
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
      return true;
    } finally {
      _isBusy = false;
    }
  }

  /// Transitions immediately from matchmaking/vsIntro into active Round 1 fighting.
  Future<void> enterArenaNow() async {
    _phaseTimer?.cancel();
    if (state.questions.isEmpty || state.phase == BattlePhase.fighting) return;
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

  int _resolveBattleDifficultyTier() {
    if (state.mode == BattleMode.botAi) {
      return switch (state.botDifficulty) {
        BotDifficulty.rookie => 1,
        BotDifficulty.academy => 2,
        BotDifficulty.maestro || BotDifficulty.legend => 3,
      };
    }
    if (state.mode == BattleMode.smartMatchmaking) {
      if (state.totalStars >= 12) return 3;
      if (state.totalStars >= 5) return 2;
    }
    return 1;
  }

  String _levelIdForTopic(String topicId, String tierSuffix) {
    final short = topicId == 'topic_staff_reading'
        ? 'staff'
        : topicId.replaceFirst('topic_', '');
    return 'lvl_${short}_$tierSuffix';
  }

  Future<List<QuestionModel>> _buildBattleQuestionSet({
    required String topicId,
    required int targetCount,
    int? seed,
  }) async {
    final rng = seed != null ? Random(seed) : _rng;
    final tier = _resolveBattleDifficultyTier();
    final suffixes = switch (tier) {
      3 => const ['basic', 'inter', 'adv'],
      2 => const ['basic', 'inter'],
      _ => const ['basic'],
    };

    if (topicId != 'all') {
      if (suffixes.length == 1) {
        final res = await _generator.generateSessionQuestions(
          mode: 'topic',
          topicId: topicId,
          levelId: _levelIdForTopic(topicId, suffixes.first),
          targetCount: targetCount,
          seed: seed,
        );
        return res.questions;
      }
      final List<QuestionModel> topicPool = [];
      final perLevelCount = (targetCount / suffixes.length).ceil() + 1;
      for (int i = 0; i < suffixes.length; i++) {
        final res = await _generator.generateSessionQuestions(
          mode: 'topic',
          topicId: topicId,
          levelId: _levelIdForTopic(topicId, suffixes[i]),
          targetCount: perLevelCount,
          seed: seed != null ? seed + i * 29 : null,
        );
        topicPool.addAll(res.questions);
      }
      topicPool.shuffle(rng);
      return topicPool.take(targetCount).toList();
    }

    // All-in-One mixed arena: sample across all 7 topics and shuffle!
    const allTopicIds = [
      'topic_notes',
      'topic_staff_reading',
      'topic_intervals',
      'topic_chords',
      'topic_melody',
      'topic_rhythm',
      'topic_keys',
    ];
    final List<QuestionModel> mixed = [];
    for (int i = 0; i < allTopicIds.length; i++) {
      final tId = allTopicIds[i];
      final chosenSuffix = suffixes[i % suffixes.length];
      final res = await _generator.generateSessionQuestions(
        mode: 'topic',
        topicId: tId,
        levelId: _levelIdForTopic(tId, chosenSuffix),
        targetCount: 2,
        seed: seed != null ? seed + i * 31 : null,
      );
      mixed.addAll(res.questions);
    }
    mixed.shuffle(rng);
    return mixed.take(targetCount).toList();
  }

  void _startRoundCountdownAndBotTimers() {
    _roundTimer?.cancel();
    _botActionTimer?.cancel();
    if (_audioService.isTestMode || _isAppPaused) return;

    // 100ms decisecond countdown (8.0s per round)
    _roundTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted ||
          _isAppPaused ||
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
            _isAppPaused ||
            state.phase != BattlePhase.fighting ||
            state.isRoundResolved) {
          return;
        }
        _triggerOpponentAiStrike();
      });
    }
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
      try {
        await _audioService.playAsset(curQ.audioAsset);
      } catch (_) {}
    }

    _startRoundCountdownAndBotTimers();
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
          ? 'BẠO KÍCH COMBO x$nextCombo! -$dmg HP'
          : (elapsedMs <= 1800
              ? 'TỐC KÍCH! -$dmg HP'
              : 'ĐÒN CHUẨN XÁC! -$dmg HP');

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
              '${state.player1Name} bấm sai! Tự mất -12 HP',
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
              '${state.player2Name} PHẢN ĐÒN! -$counterDmg HP',
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
          ? '${state.player2Name} BẠO KÍCH x$nextCombo! -$dmg HP'
          : '${state.player2Name} TẤN CÔNG! -$dmg HP';

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
            '${state.player2Name} bấm sai! Tự mất -12 HP',
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
            '${state.player2Name} ra đòn trước! -$dmg HP',
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
            '${state.player2Name} trả lời trượt! Cơ hội tấn công của bạn!',
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
      combatBannerText: 'Hết giờ! Mất -15 HP',
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
    if (_isBusy) return;
    _isBusy = true;
    try {
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
    } finally {
      _isBusy = false;
    }
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

    // Check first-time Rank-Up Milestone Bonus Prestige Points
    final prevTierName = BattleRankInfo.fromStars(state.totalStars).tierName;
    final nextTierName = BattleRankInfo.fromStars(nextStars).tierName;
    int rankUpBonus = 0;
    if (nextStars > state.totalStars && prevTierName != nextTierName) {
      final highestRewarded = int.tryParse(
            await _db.getSetting('battle_highest_rewarded_stars') ?? '0',
          ) ??
          0;
      if (nextStars >= 35 && highestRewarded < 35) {
        rankUpBonus = 250;
      } else if (nextStars >= 22 && highestRewarded < 22) {
        rankUpBonus = 150;
      } else if (nextStars >= 12 && highestRewarded < 12) {
        rankUpBonus = 100;
      } else if (nextStars >= 5 && highestRewarded < 5) {
        rankUpBonus = 50;
      }
      if (rankUpBonus > 0) {
        try {
          await _db.setSetting(
            'battle_highest_rewarded_stars',
            nextStars.toString(),
          );
          await _ref
              .read(rewardedAdProvider.notifier)
              .grantBonusPrestigePoints(
                rankUpBonus,
                customMessage:
                    'Thăng hạng $nextTierName! Tặng thưởng +$rankUpBonus Điểm Uy Tín!',
              );
        } catch (_) {}
      }
    }

    final modeLabel = switch (state.mode) {
      BattleMode.smartMatchmaking => 'Ghép Trận',
      BattleMode.botAi => 'Đấu Bot AI',
      BattleMode.localSplitScreen => '2 Người 1 Máy',
    };
    final newRecord = BattleMatchRecord(
      opponentName: state.player2Name,
      modeLabel: modeLabel,
      didWin: won,
      isDraw: state.isDraw,
      player1Hp: state.player1Hp,
      player2Hp: state.player2Hp,
      maxCombo: state.player1MaxCombo,
      starsDelta: starsDelta,
    );
    final updatedHistory = [newRecord, ...state.matchHistory].take(10).toList();

    try {
      await _db.setSetting('battle_stars', nextStars.toString());
      await _db.setSetting('battle_wins', nextWins.toString());
      await _db.setSetting('battle_matches', nextMatches.toString());
      await _db.setSetting(
        'battle_match_history_json',
        jsonEncode(updatedHistory.map((r) => r.toJson()).toList()),
      );
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
      lastRankUpBonusPoints: rankUpBonus,
      matchHistory: updatedHistory,
    );
  }

  /// Pauses all active timers and audio when the app goes to background or screen locks.
  void onAppPaused() {
    _isAppPaused = true;
    _cancelAllTimers();
    unawaited(_audioService.stop());
  }

  /// Resumes timers cleanly when the app returns to foreground.
  void onAppResumed() {
    if (!_isAppPaused) return;
    _isAppPaused = false;
    if (_audioService.isTestMode || !mounted) return;

    if (state.phase == BattlePhase.matchmaking ||
        state.phase == BattlePhase.vsIntro) {
      _phaseTimer = Timer(const Duration(milliseconds: 800), () {
        if (!mounted || _isAppPaused) return;
        enterArenaNow();
      });
    } else if (state.phase == BattlePhase.fighting) {
      if (state.isRoundResolved) {
        _scheduleAutoAdvanceRound();
      } else {
        _startRoundCountdownAndBotTimers();
      }
    }
  }

  /// Stops all active battle timers and audio if the BattleScreen is disposed.
  void onScreenDisposed() {
    _cancelAllTimers();
    unawaited(_audioService.stop());
  }

  /// Returns to the Battle Arena Lobby.
  Future<void> backToLobby() async {
    _cancelAllTimers();
    try {
      await _audioService.stop();
    } catch (_) {}
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
