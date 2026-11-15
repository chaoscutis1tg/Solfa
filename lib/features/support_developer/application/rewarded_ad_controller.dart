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
  final int spentPrestigePoints;
  final String statusMessage;

  const RewardedAdState({
    this.status = RewardedAdStatus.notLoaded,
    this.supportedCount = 0,
    this.spentPrestigePoints = 0,
    this.statusMessage =
        'Quảng cáo video có thưởng hoàn toàn tự nguyện, cần kết nối Internet và không khóa bất kỳ bài học nào.',
  });

  /// Tổng Điểm Uy Tín tích lũy trọn đời (dùng để giữ nguyên danh hiệu vinh danh).
  int get totalPrestigePoints => supportedCount * 100;

  /// Số dư Điểm Uy Tín khả dụng hiện tại (có thể dùng để quy đổi sang Lượt Đấu Trường).
  int get prestigePoints =>
      (totalPrestigePoints - spentPrestigePoints).clamp(0, 999999);

  bool get canRedeemSingleTurn => prestigePoints >= 100;

  String get supporterBadgeTitle {
    if (supportedCount >= 10) return 'Đại sứ Vàng Solfa';
    if (supportedCount >= 5) return 'Nhà tài trợ Cảm âm';
    if (supportedCount >= 1) return 'Người đồng hành Âm nhạc';
    return 'Người bạn của Solfa';
  }

  RewardedAdState copyWith({
    RewardedAdStatus? status,
    int? supportedCount,
    int? spentPrestigePoints,
    String? statusMessage,
  }) {
    return RewardedAdState(
      status: status ?? this.status,
      supportedCount: supportedCount ?? this.supportedCount,
      spentPrestigePoints: spentPrestigePoints ?? this.spentPrestigePoints,
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

  Future<void> _loadSupportCount() async {
    final val = await _db.getSetting('developer_support_count');
    final spentVal = await _db.getSetting('developer_support_points_spent');
    if (!mounted) return;
    final count = int.tryParse(val ?? '0') ?? 0;
    final spent = int.tryParse(spentVal ?? '0') ?? 0;
    state = state.copyWith(
      supportedCount: count,
      spentPrestigePoints: spent.clamp(0, count * 100),
    );
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
    if (!online) {
      state = state.copyWith(
        status: RewardedAdStatus.offline,
        statusMessage:
            'Không có kết nối Internet. Quảng cáo cần mạng để tải, nhưng toàn bộ bài học và Máy đếm nhịp vẫn hoạt động bình thường!',
      );
      return false;
    }

    await Future.delayed(const Duration(milliseconds: 350));
    state = state.copyWith(
      status: RewardedAdStatus.ready,
      statusMessage:
          'Video quảng cáo ngắn (15 giây) đã sẵn sàng. Nhấn "Xem video quảng cáo" để ủng hộ nhà phát triển.',
    );
    return true;
  }

  /// Records completing or dismissing the voluntary rewarded video ad (UC-16).
  Future<void> completeWatchingAd({required bool watchedToEnd}) async {
    if (!watchedToEnd) {
      state = state.copyWith(
        status: RewardedAdStatus.dismissedEarly,
        statusMessage:
            'Bạn đã đóng video sớm (chưa ghi nhận lượt hoàn tất). Cảm ơn bạn đã quan tâm, chúc bạn luyện tập vui vẻ!',
      );
      return;
    }

    final nextCount = state.supportedCount + 1;
    await _db.setSetting('developer_support_count', nextCount.toString());
    state = state.copyWith(
      status: RewardedAdStatus.completed,
      supportedCount: nextCount,
      statusMessage:
          'Cảm ơn bạn rất nhiều! Lượt xem video ủng hộ thứ #$nextCount của bạn đã được ghi nhận (+100 Điểm Uy Tín).',
    );
  }

  /// Quy đổi Điểm Uy Tín khả dụng (`prestigePoints`) sang Lượt Đấu Trường.
  /// Danh hiệu ủng hộ (`supportedCount`) vẫn được bảo toàn vĩnh viễn!
  Future<bool> spendPrestigePointsForTurns({
    required int pointsCost,
    required int turnsGranted,
  }) async {
    if (pointsCost <= 0 || turnsGranted <= 0) return false;
    if (state.prestigePoints < pointsCost) return false;

    final nextSpent = state.spentPrestigePoints + pointsCost;
    await _db.setSetting(
      'developer_support_points_spent',
      nextSpent.toString(),
    );
    state = state.copyWith(
      spentPrestigePoints: nextSpent,
      statusMessage:
          'Đã quy đổi $pointsCost Điểm Uy Tín sang +$turnsGranted Lượt Đấu Trường thành công!',
    );
    return true;
  }
}

final rewardedAdProvider =
    StateNotifierProvider<RewardedAdNotifier, RewardedAdState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return RewardedAdNotifier(db);
});
