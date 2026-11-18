import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/security/solfa_integrity_guard.dart';

enum RewardedAdStatus {
  notLoaded,
  loading,
  ready,
  completed,
  dismissedEarly,
  offline,
  sdkError,
}

class RewardedAdState {
  /// Chi phí mở khóa 1 phiên luyện tập chuyên sâu 1 tiếng (3600 giây) = 200 Gem (tương đương 2 video quảng cáo).
  static const int kOneHourPracticeGemCost = 200;

  /// Chi phí mở khóa 1 phiên luyện tập Tự do không giới hạn thời gian (0 giây) = 350 Gem (tương đương 3–4 video quảng cáo).
  static const int kUnlimitedPracticeGemCost = 350;

  /// Chi phí mở khóa vĩnh viễn Bản đồ Scale VIP Guitar 12 ngăn = 300 Gem (tương đương 3 video quảng cáo).
  static const int kGuitarProScaleGemCost = 300;

  /// Chi phí đổi Gem tích lũy lấy +1 Lượt Đấu Trường = 200 Gem.
  static const int kSingleBattleTurnGemCost = 200;

  /// Chi phí đổi Gem tích lũy lấy gói +3 Lượt Đấu Trường (Ưu đãi tiết kiệm 100 Gem) = 500 Gem.
  static const int kThreeBattleTurnsGemCost = 500;

  /// Chi phí đổi Gem tích lũy lấy gói +5 Lượt Đấu Trường (Tốt nhất tiết kiệm 200 Gem) = 800 Gem.
  static const int kFiveBattleTurnsGemCost = 800;

  /// Phần thưởng Gem khi hoàn thành mục tiêu hàng ngày.
  static const int kDailyGoalBonusGems = 20;

  /// Phần thưởng Gem mỗi khi thăng bậc Rank mới trong Đấu Trường.
  static const int kRankUpBonusGems = 50;

  final RewardedAdStatus status;
  final int supportedCount;
  final int bonusPrestigePoints;
  final int spentPrestigePoints;
  final bool questPracticeClaimedToday;
  final bool questBattleClaimedToday;
  final bool questDictationClaimedToday;
  final bool dailyGoalGemClaimedToday;
  final int dailyBattlesPlayed;
  final int dailyDictationCompletedCount;
  final bool isIntegrityVerified;
  final String statusMessage;

  const RewardedAdState({
    this.status = RewardedAdStatus.notLoaded,
    this.supportedCount = 0,
    this.bonusPrestigePoints = 0,
    this.spentPrestigePoints = 0,
    this.questPracticeClaimedToday = false,
    this.questBattleClaimedToday = false,
    this.questDictationClaimedToday = false,
    this.dailyGoalGemClaimedToday = false,
    this.dailyBattlesPlayed = 0,
    this.dailyDictationCompletedCount = 0,
    this.isIntegrityVerified = true,
    this.statusMessage =
        'Quảng cáo video có thưởng hoàn toàn tự nguyện (+100 Gem & +1 Lượt Đấu), cần kết nối Internet và không khóa các bài học 60s/15p.',
  });

  /// Tổng Gem tích lũy trọn đời (từ video ủng hộ + nhiệm vụ, mục tiêu ngày & thăng hạng).
  int get totalPrestigePoints => supportedCount * 100 + bonusPrestigePoints;

  /// Số dư Gem khả dụng hiện tại (dùng để mở phiên 1 tiếng hoặc quy đổi sang Lượt Đấu Trường).
  int get prestigePoints =>
      (totalPrestigePoints - spentPrestigePoints).clamp(0, 999999);

  /// Alias cho `prestigePoints` theo tên đơn vị mới `Gem`.
  int get gems => prestigePoints;

  bool get canRedeemSingleTurn => prestigePoints >= kSingleBattleTurnGemCost;

  bool get canAffordOneHourPractice =>
      prestigePoints >= kOneHourPracticeGemCost;

  bool get canAffordUnlimitedPractice =>
      prestigePoints >= kUnlimitedPracticeGemCost;

  int get claimedQuestsCountToday =>
      (questPracticeClaimedToday ? 1 : 0) +
      (questBattleClaimedToday ? 1 : 0) +
      (questDictationClaimedToday ? 1 : 0);

  String get supporterBadgeTitle {
    if (supportedCount >= 10) return 'Đại sứ Kim Cương ChaoNote';
    if (supportedCount >= 5) return 'Nhà tài trợ Cảm âm';
    if (supportedCount >= 1) return 'Người đồng hành Âm nhạc';
    return 'Người bạn của ChaoNote';
  }

  RewardedAdState copyWith({
    RewardedAdStatus? status,
    int? supportedCount,
    int? bonusPrestigePoints,
    int? spentPrestigePoints,
    bool? questPracticeClaimedToday,
    bool? questBattleClaimedToday,
    bool? questDictationClaimedToday,
    bool? dailyGoalGemClaimedToday,
    int? dailyBattlesPlayed,
    int? dailyDictationCompletedCount,
    bool? isIntegrityVerified,
    String? statusMessage,
  }) {
    return RewardedAdState(
      status: status ?? this.status,
      supportedCount: supportedCount ?? this.supportedCount,
      bonusPrestigePoints: bonusPrestigePoints ?? this.bonusPrestigePoints,
      spentPrestigePoints: spentPrestigePoints ?? this.spentPrestigePoints,
      questPracticeClaimedToday:
          questPracticeClaimedToday ?? this.questPracticeClaimedToday,
      questBattleClaimedToday:
          questBattleClaimedToday ?? this.questBattleClaimedToday,
      questDictationClaimedToday:
          questDictationClaimedToday ?? this.questDictationClaimedToday,
      dailyGoalGemClaimedToday:
          dailyGoalGemClaimedToday ?? this.dailyGoalGemClaimedToday,
      dailyBattlesPlayed: dailyBattlesPlayed ?? this.dailyBattlesPlayed,
      dailyDictationCompletedCount:
          dailyDictationCompletedCount ?? this.dailyDictationCompletedCount,
      isIntegrityVerified: isIntegrityVerified ?? this.isIntegrityVerified,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class RewardedAdNotifier extends StateNotifier<RewardedAdState> {
  final AppDatabase _db;
  final bool Function()? _customConnectivityCheck;

  RewardedAdNotifier(this._db, {bool Function()? customConnectivityCheck})
      : _customConnectivityCheck = customConnectivityCheck,
        super(const RewardedAdState()) {
    _loadSupportCount();
  }

  String _todayDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _persistWalletSignature({
    required int supportedCount,
    required int bonusGems,
    required int spentGems,
  }) async {
    try {
      final sig = SolfaIntegrityGuard.computeWalletSignature(
        supportedCount: supportedCount,
        bonusGems: bonusGems,
        spentGems: spentGems,
      );
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await _db.setSetting('wallet_integrity_sig', '$sig|$nowMs');
    } catch (_) {}
  }

  Future<void> _loadSupportCount() async {
    try {
      final map = await _db.getAllSettings();
      if (!mounted) return;
      int count = int.tryParse(map['developer_support_count'] ?? '0') ?? 0;
      int bonus =
          int.tryParse(map['developer_support_bonus_points'] ?? '0') ?? 0;
      int spent =
          int.tryParse(map['developer_support_points_spent'] ?? '0') ?? 0;
      final rawSig = map['wallet_integrity_sig'];
      String? savedSig;
      int? lastEpochMs;
      if (rawSig != null && rawSig.contains('|')) {
        final parts = rawSig.split('|');
        savedSig = parts.first;
        lastEpochMs = int.tryParse(parts.last);
      } else {
        savedSig = rawSig;
        lastEpochMs = int.tryParse(map['wallet_last_epoch_ms'] ?? '');
      }
      final nowEpochMs = DateTime.now().millisecondsSinceEpoch;

      final sigOk = SolfaIntegrityGuard.verifyWalletSignature(
        supportedCount: count,
        bonusGems: bonus,
        spentGems: spent,
        savedSignature: savedSig,
      );
      final clockOk = SolfaIntegrityGuard.isSystemClockValid(
        lastVerifiedEpochMs: lastEpochMs,
        currentEpochMs: nowEpochMs,
      );

      if (!sigOk) {
        // Nếu phát hiện chỉnh sửa dữ liệu trái phép từ bên ngoài -> khôi phục về 0 an toàn
        count = 0;
        bonus = 0;
        spent = 0;
        await _db.setSetting('developer_support_count', '0');
        await _db.setSetting('developer_support_bonus_points', '0');
        await _db.setSetting('developer_support_points_spent', '0');
        await _persistWalletSignature(
          supportedCount: 0,
          bonusGems: 0,
          spentGems: 0,
        );
      }

      final today = _todayDateKey();
      final questDate = map['daily_quests_date'];
      final isTodayQuest = questDate == today;
      // Nếu phát hiện tua ngược đồng hồ -> khóa nhận lại nhiệm vụ
      final qPractice = !clockOk ||
          (isTodayQuest && map['daily_quest_practice_claimed'] == '1');
      final qBattle =
          !clockOk || (isTodayQuest && map['daily_quest_battle_claimed'] == '1');
      final qDictation = !clockOk ||
          (isTodayQuest && map['daily_quest_dictation_claimed'] == '1');
      final dailyGoalClaimed = !clockOk ||
          (map['daily_goal_gem_date'] == today &&
              map['daily_goal_gem_claimed'] == '1');
      final dictationCount = isTodayQuest
          ? (int.tryParse(map['daily_dictation_completed_count'] ?? '0') ?? 0)
          : 0;
      final battleDate = map['battle_energy_date'];
      final battlesToday = battleDate == today
          ? (int.tryParse(map['battle_daily_played'] ?? '0') ?? 0)
          : 0;

      // Preserve in-memory state if already modified synchronously during tests
      if (state.supportedCount > count || state.bonusPrestigePoints > bonus) {
        return;
      }
      final totalPts = count * 100 + bonus;
      state = state.copyWith(
        supportedCount: count,
        bonusPrestigePoints: bonus.clamp(0, 999999),
        spentPrestigePoints: spent.clamp(0, totalPts),
        questPracticeClaimedToday: qPractice,
        questBattleClaimedToday: qBattle,
        questDictationClaimedToday: qDictation,
        dailyGoalGemClaimedToday: dailyGoalClaimed,
        dailyBattlesPlayed: battlesToday.clamp(0, 999),
        dailyDictationCompletedCount: dictationCount.clamp(0, 999),
        isIntegrityVerified: sigOk && clockOk,
      );
    } catch (_) {}
  }

  Future<bool> _hasInternetConnection() async {
    if (_customConnectivityCheck != null) {
      return _customConnectivityCheck();
    }
    try {
      final results = await Connectivity().checkConnectivity();
      return results.isNotEmpty &&
          !results.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Triggered when the user requests to load a voluntary rewarded video ad (BR-12).
  Future<bool> loadRewardedAd({bool simulateOffline = false}) async {
    if (state.status == RewardedAdStatus.loading) return false;

    state = state.copyWith(
      status: RewardedAdStatus.loading,
      statusMessage: 'Đang kiểm tra kết nối mạng và chuẩn bị video quảng cáo...',
    );

    final online = !simulateOffline && await _hasInternetConnection();
    if (!mounted) return false;
    if (!online) {
      state = state.copyWith(
        status: RewardedAdStatus.offline,
        statusMessage:
            'Không có kết nối Internet. Quảng cáo cần mạng để tải, nhưng toàn bộ bài học và Máy đếm nhịp vẫn hoạt động bình thường!',
      );
      return false;
    }

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return false;
    state = state.copyWith(
      status: RewardedAdStatus.ready,
      statusMessage:
          'Video quảng cáo ngắn (15 giây) đã sẵn sàng. Nhấn "Xem video quảng cáo" để nhận +100 Gem & ủng hộ nhà phát triển.',
    );
    return true;
  }

  /// Records completing or dismissing the voluntary rewarded video ad (UC-16).
  Future<void> completeWatchingAd({required bool watchedToEnd}) async {
    if (!mounted) return;
    if (!watchedToEnd) {
      state = state.copyWith(
        status: RewardedAdStatus.dismissedEarly,
        statusMessage:
            'Bạn đã đóng video sớm (chưa ghi nhận lượt hoàn tất). Cảm ơn bạn đã quan tâm, chúc bạn luyện tập vui vẻ!',
      );
      return;
    }

    final nextCount = state.supportedCount + 1;
    state = state.copyWith(
      status: RewardedAdStatus.completed,
      supportedCount: nextCount,
      statusMessage:
          'Cảm ơn bạn rất nhiều! Lượt xem video ủng hộ thứ #$nextCount của bạn đã được ghi nhận (+100 Gem).',
    );
    try {
      await _db.setSetting('developer_support_count', nextCount.toString());
      await _persistWalletSignature(
        supportedCount: nextCount,
        bonusGems: state.bonusPrestigePoints,
        spentGems: state.spentPrestigePoints,
      );
    } catch (_) {}
  }

  /// Quy đổi Gem khả dụng (`prestigePoints`) sang Lượt Đấu Trường.
  /// Danh hiệu ủng hộ (`supportedCount`) vẫn được bảo toàn vĩnh viễn!
  Future<bool> spendPrestigePointsForTurns({
    required int pointsCost,
    required int turnsGranted,
  }) async {
    if (!mounted) return false;
    if (pointsCost <= 0 || turnsGranted <= 0) return false;
    if (state.prestigePoints < pointsCost) return false;

    final nextSpent = state.spentPrestigePoints + pointsCost;
    state = state.copyWith(
      spentPrestigePoints: nextSpent,
      statusMessage:
          'Đã quy đổi $pointsCost Gem sang +$turnsGranted Lượt Đấu Trường thành công!',
    );
    try {
      await _db.setSetting(
        'developer_support_points_spent',
        nextSpent.toString(),
      );
      await _persistWalletSignature(
        supportedCount: state.supportedCount,
        bonusGems: state.bonusPrestigePoints,
        spentGems: nextSpent,
      );
    } catch (_) {}
    return true;
  }

  /// Mở khóa phiên luyện tập chuyên sâu 1 tiếng (`3600s` = `50 Gem`) hoặc Tự do không giới hạn (`0s` = `100 Gem`).
  /// Các phiên `60 giây` và `15 phút` hoàn toàn miễn phí (`0 Gem`).
  Future<bool> spendGemsForOneHourSession({
    int gemCost = RewardedAdState.kOneHourPracticeGemCost,
    bool isUnlimited = false,
  }) async {
    if (!mounted) return false;
    if (gemCost <= 0) return true;
    if (state.prestigePoints < gemCost) return false;

    final nextSpent = state.spentPrestigePoints + gemCost;
    state = state.copyWith(
      spentPrestigePoints: nextSpent,
      statusMessage: isUnlimited
          ? 'Đã mở khóa chế độ Luyện tập Tự do không giới hạn thời gian (-$gemCost Gem). Chúc bạn luyện tập hiệu quả!'
          : 'Đã mở khóa phiên luyện tập chuyên sâu 1 tiếng (-$gemCost Gem). Chúc bạn luyện tập hiệu quả!',
    );
    try {
      await _db.setSetting(
        'developer_support_points_spent',
        nextSpent.toString(),
      );
      await _persistWalletSignature(
        supportedCount: state.supportedCount,
        bonusGems: state.bonusPrestigePoints,
        spentGems: nextSpent,
      );
    } catch (_) {}
    return true;
  }

  /// Mở khóa phiên luyện tập Tự do không giới hạn thời gian (`100 Gem`).
  Future<bool> spendGemsForUnlimitedSession() {
    return spendGemsForOneHourSession(
      gemCost: RewardedAdState.kUnlimitedPracticeGemCost,
      isUnlimited: true,
    );
  }

  /// Cộng Gem thưởng từ Nhiệm Vụ Hàng Ngày, Đạt Mục Tiêu Ngày hoặc Thăng Hạng Đấu Trường.
  Future<void> grantBonusPrestigePoints(
    int points, {
    String? customMessage,
  }) async {
    if (!mounted || points <= 0) return;
    final nextBonus = state.bonusPrestigePoints + points;
    state = state.copyWith(
      bonusPrestigePoints: nextBonus,
      statusMessage: customMessage ?? 'Bạn vừa nhận thêm +$points Gem thưởng!',
    );
    try {
      await _db.setSetting(
        'developer_support_bonus_points',
        nextBonus.toString(),
      );
      await _persistWalletSignature(
        supportedCount: state.supportedCount,
        bonusGems: nextBonus,
        spentGems: state.spentPrestigePoints,
      );
    } catch (_) {}
  }

  /// Thưởng nóng +20 Gem khi hoàn thành Mục tiêu hàng ngày (nhận 1 lần/ngày).
  Future<int> awardDailyGoalBonusIfEligible() async {
    if (!mounted || state.dailyGoalGemClaimedToday) return 0;
    const bonus = RewardedAdState.kDailyGoalBonusGems;
    final nextBonus = state.bonusPrestigePoints + bonus;
    state = state.copyWith(
      dailyGoalGemClaimedToday: true,
      bonusPrestigePoints: nextBonus,
      statusMessage:
          'Chúc mừng bạn đã hoàn thành Mục tiêu hôm nay! Nhận thưởng +$bonus Gem.',
    );
    try {
      await _db.setSetting('daily_goal_gem_date', _todayDateKey());
      await _db.setSetting('daily_goal_gem_claimed', '1');
      await _db.setSetting(
        'developer_support_bonus_points',
        nextBonus.toString(),
      );
      await _persistWalletSignature(
        supportedCount: state.supportedCount,
        bonusGems: nextBonus,
        spentGems: state.spentPrestigePoints,
      );
    } catch (_) {}
    return bonus;
  }

  /// Ghi nhận người dùng vừa tham gia 1 trận Đấu Trường 1v1 hôm nay.
  void recordDailyBattlePlayed() {
    if (!mounted) return;
    state = state.copyWith(dailyBattlesPlayed: state.dailyBattlesPlayed + 1);
  }

  /// Ghi nhận người dùng vừa giải xong 1 câu Chép Nhạc Giai Điệu trên Đàn Piano C3–C5.
  Future<void> recordMelodicDictationCompleted() async {
    if (!mounted) return;
    final nextCount = state.dailyDictationCompletedCount + 1;
    state = state.copyWith(dailyDictationCompletedCount: nextCount);
    try {
      await _db.setSetting('daily_quests_date', _todayDateKey());
      await _db.setSetting(
        'daily_dictation_completed_count',
        nextCount.toString(),
      );
    } catch (_) {}
  }

  /// Nhận thưởng Nhiệm Vụ Hàng Ngày ('practice' -> +30 Gem, 'battle' -> +40 Gem, 'dictation' -> +30 Gem).
  Future<int> claimDailyQuest(String questCode) async {
    if (!mounted) return 0;
    int rewardPoints = 0;
    String settingKey = '';

    if (questCode == 'practice') {
      if (state.questPracticeClaimedToday) return 0;
      rewardPoints = 30;
      settingKey = 'daily_quest_practice_claimed';
      state = state.copyWith(
        questPracticeClaimedToday: true,
        bonusPrestigePoints: state.bonusPrestigePoints + rewardPoints,
        statusMessage:
            'Đã nhận +$rewardPoints Gem từ nhiệm vụ Luyện Tập Cảm Âm!',
      );
    } else if (questCode == 'battle') {
      if (state.questBattleClaimedToday) return 0;
      rewardPoints = 40;
      settingKey = 'daily_quest_battle_claimed';
      state = state.copyWith(
        questBattleClaimedToday: true,
        bonusPrestigePoints: state.bonusPrestigePoints + rewardPoints,
        statusMessage:
            'Đã nhận +$rewardPoints Gem từ nhiệm vụ Chiến Binh Đấu Trường!',
      );
    } else if (questCode == 'dictation') {
      if (state.questDictationClaimedToday) return 0;
      rewardPoints = 30;
      settingKey = 'daily_quest_dictation_claimed';
      state = state.copyWith(
        questDictationClaimedToday: true,
        bonusPrestigePoints: state.bonusPrestigePoints + rewardPoints,
        statusMessage:
            'Đã nhận +$rewardPoints Gem từ nhiệm vụ Chép Nhạc Giai Điệu!',
      );
    } else {
      return 0;
    }

    try {
      await _db.setSetting('daily_quests_date', _todayDateKey());
      await _db.setSetting(settingKey, '1');
      await _db.setSetting(
        'developer_support_bonus_points',
        state.bonusPrestigePoints.toString(),
      );
      await _persistWalletSignature(
        supportedCount: state.supportedCount,
        bonusGems: state.bonusPrestigePoints,
        spentGems: state.spentPrestigePoints,
      );
    } catch (_) {}
    return rewardPoints;
  }
}

final rewardedAdProvider =
    StateNotifierProvider<RewardedAdNotifier, RewardedAdState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return RewardedAdNotifier(db);
});
