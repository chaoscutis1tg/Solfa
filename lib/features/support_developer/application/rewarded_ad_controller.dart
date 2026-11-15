import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/app_providers.dart';

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
  final RewardedAdStatus status;
  final int supportedCount;
  final int bonusPrestigePoints;
  final int spentPrestigePoints;
  final bool questPracticeClaimedToday;
  final bool questBattleClaimedToday;
  final bool questDictationClaimedToday;
  final int dailyBattlesPlayed;
  final int dailyDictationCompletedCount;
  final String statusMessage;

  const RewardedAdState({
    this.status = RewardedAdStatus.notLoaded,
    this.supportedCount = 0,
    this.bonusPrestigePoints = 0,
    this.spentPrestigePoints = 0,
    this.questPracticeClaimedToday = false,
    this.questBattleClaimedToday = false,
    this.questDictationClaimedToday = false,
    this.dailyBattlesPlayed = 0,
    this.dailyDictationCompletedCount = 0,
    this.statusMessage =
        'Quảng cáo video có thưởng hoàn toàn tự nguyện, cần kết nối Internet và không khóa bất kỳ bài học nào.',
  });

  /// Tổng Điểm Uy Tín tích lũy trọn đời (từ video ủng hộ + nhiệm vụ & thăng hạng).
  int get totalPrestigePoints => supportedCount * 100 + bonusPrestigePoints;

  /// Số dư Điểm Uy Tín khả dụng hiện tại (có thể dùng để quy đổi sang Lượt Đấu Trường).
  int get prestigePoints =>
      (totalPrestigePoints - spentPrestigePoints).clamp(0, 999999);

  bool get canRedeemSingleTurn => prestigePoints >= 100;

  int get claimedQuestsCountToday =>
      (questPracticeClaimedToday ? 1 : 0) +
      (questBattleClaimedToday ? 1 : 0) +
      (questDictationClaimedToday ? 1 : 0);

  String get supporterBadgeTitle {
    if (supportedCount >= 10) return 'Đại sứ Vàng Solfa';
    if (supportedCount >= 5) return 'Nhà tài trợ Cảm âm';
    if (supportedCount >= 1) return 'Người đồng hành Âm nhạc';
    return 'Người bạn của Solfa';
  }

  RewardedAdState copyWith({
    RewardedAdStatus? status,
    int? supportedCount,
    int? bonusPrestigePoints,
    int? spentPrestigePoints,
    bool? questPracticeClaimedToday,
    bool? questBattleClaimedToday,
    bool? questDictationClaimedToday,
    int? dailyBattlesPlayed,
    int? dailyDictationCompletedCount,
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
      dailyBattlesPlayed: dailyBattlesPlayed ?? this.dailyBattlesPlayed,
      dailyDictationCompletedCount:
          dailyDictationCompletedCount ?? this.dailyDictationCompletedCount,
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

  Future<void> _loadSupportCount() async {
    try {
      final map = await _db.getAllSettings();
      if (!mounted) return;
      final count = int.tryParse(map['developer_support_count'] ?? '0') ?? 0;
      final bonus =
          int.tryParse(map['developer_support_bonus_points'] ?? '0') ?? 0;
      final spent =
          int.tryParse(map['developer_support_points_spent'] ?? '0') ?? 0;

      final today = _todayDateKey();
      final questDate = map['daily_quests_date'];
      final isTodayQuest = questDate == today;
      final qPractice =
          isTodayQuest && map['daily_quest_practice_claimed'] == '1';
      final qBattle = isTodayQuest && map['daily_quest_battle_claimed'] == '1';
      final qDictation =
          isTodayQuest && map['daily_quest_dictation_claimed'] == '1';
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
        dailyBattlesPlayed: battlesToday.clamp(0, 999),
        dailyDictationCompletedCount: dictationCount.clamp(0, 999),
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
          'Video quảng cáo ngắn (15 giây) đã sẵn sàng. Nhấn "Xem video quảng cáo" để ủng hộ nhà phát triển.',
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
          'Cảm ơn bạn rất nhiều! Lượt xem video ủng hộ thứ #$nextCount của bạn đã được ghi nhận (+100 Điểm Uy Tín).',
    );
    try {
      await _db.setSetting('developer_support_count', nextCount.toString());
    } catch (_) {}
  }

  /// Quy đổi Điểm Uy Tín khả dụng (`prestigePoints`) sang Lượt Đấu Trường.
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
          'Đã quy đổi $pointsCost Điểm Uy Tín sang +$turnsGranted Lượt Đấu Trường thành công!',
    );
    try {
      await _db.setSetting(
        'developer_support_points_spent',
        nextSpent.toString(),
      );
    } catch (_) {}
    return true;
  }

  /// Cộng Điểm Uy Tín thưởng từ Nhiệm Vụ Hàng Ngày hoặc Thăng Hạng Đấu Trường.
  Future<void> grantBonusPrestigePoints(
    int points, {
    String? customMessage,
  }) async {
    if (!mounted || points <= 0) return;
    final nextBonus = state.bonusPrestigePoints + points;
    state = state.copyWith(
      bonusPrestigePoints: nextBonus,
      statusMessage:
          customMessage ?? 'Bạn vừa nhận thêm +$points Điểm Uy Tín thưởng!',
    );
    try {
      await _db.setSetting(
        'developer_support_bonus_points',
        nextBonus.toString(),
      );
    } catch (_) {}
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

  /// Nhận thưởng Nhiệm Vụ Hàng Ngày ('practice' -> +30đ, 'battle' -> +40đ, 'dictation' -> +30đ).
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
            'Đã nhận +$rewardPoints Điểm Uy Tín từ nhiệm vụ Luyện Tập Cảm Âm!',
      );
    } else if (questCode == 'battle') {
      if (state.questBattleClaimedToday) return 0;
      rewardPoints = 40;
      settingKey = 'daily_quest_battle_claimed';
      state = state.copyWith(
        questBattleClaimedToday: true,
        bonusPrestigePoints: state.bonusPrestigePoints + rewardPoints,
        statusMessage:
            'Đã nhận +$rewardPoints Điểm Uy Tín từ nhiệm vụ Chiến Binh Đấu Trường!',
      );
    } else if (questCode == 'dictation') {
      if (state.questDictationClaimedToday) return 0;
      rewardPoints = 30;
      settingKey = 'daily_quest_dictation_claimed';
      state = state.copyWith(
        questDictationClaimedToday: true,
        bonusPrestigePoints: state.bonusPrestigePoints + rewardPoints,
        statusMessage:
            'Đã nhận +$rewardPoints Điểm Uy Tín từ nhiệm vụ Chép Nhạc Giai Điệu!',
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
    } catch (_) {}
    return rewardPoints;
  }
}

final rewardedAdProvider =
    StateNotifierProvider<RewardedAdNotifier, RewardedAdState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return RewardedAdNotifier(db);
});
