import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/animated_ui.dart';
import '../../../app/widgets/pulsing_red_heart.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../app/widgets/solfa_logo.dart';
import '../../../core/ads/admob_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../battle/application/battle_controller.dart';
import '../application/rewarded_ad_controller.dart';

bool _isOpeningGlobalAdModal = false;

Future<bool> _showRealAdMobOrFallbackVideo(
  BuildContext context,
  WidgetRef ref,
) async {
  final audioService = ref.read(audioServiceProvider);
  await audioService.stop();

  final adMobOutcome = await AdMobService.instance.showRewardedAd(
    isTestMode: audioService.isTestMode,
  );
  if (adMobOutcome == AdMobShowResult.earnedReward) {
    return true;
  }
  if (adMobOutcome == AdMobShowResult.dismissedWithoutReward) {
    return false;
  }

  if (!context.mounted) return false;
  final completed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RewardedVideoAdPlayerDialog(
      isTestMode: audioService.isTestMode,
      onPlayPreviewSound: (asset) {
        audioService.playAsset(asset);
      },
      onStopSound: () {
        audioService.stop();
      },
    ),
  );
  await audioService.stop();
  return completed == true;
}

/// Opens the 15-second Rewarded Video Ad modal and, upon completion,
/// grants +1 Battle Arena turn AND +100 Developer Supporter Prestige Points.
Future<bool> showSolfaRewardedVideoAdModal(
  BuildContext context,
  WidgetRef ref,
) async {
  if (_isOpeningGlobalAdModal) return false;
  _isOpeningGlobalAdModal = true;
  try {
    final notifier = ref.read(rewardedAdProvider.notifier);
    final currentStatus = ref.read(rewardedAdProvider).status;

    if (currentStatus != RewardedAdStatus.ready) {
      final ok = await notifier.loadRewardedAd();
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              content: const Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chưa có kết nối Internet để tải quảng cáo hồi lượt. Bạn vẫn có thể luyện tập tại Phòng luyện tập!',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return false;
      }
    }

    if (!context.mounted) return false;
    final audioService = ref.read(audioServiceProvider);
    final completed = await _showRealAdMobOrFallbackVideo(context, ref);

    await notifier.completeWatchingAd(watchedToEnd: completed);

    if (completed) {
      await ref
          .read(battleProvider.notifier)
          .restoreTurnFromRewardedAd(turns: 1);
      await audioService.playSessionCompleteFanfare();
      if (context.mounted) {
        showGemRewardAnimation(
          context,
          gemsAdded: 100,
          subtitle: '+1 Lượt Đấu Trường',
          isTestMode: audioService.isTestMode,
        );
      }
      return true;
    }
    return false;
  } finally {
    _isOpeningGlobalAdModal = false;
  }
}

/// Alias tiện ích để mở trình phát Quảng cáo Video Nhận Thưởng (+100 Gem & +1 Lượt Đấu Trường) từ mọi màn hình.
Future<bool> showRewardedVideoAdSimulationDialog(
  BuildContext context,
  WidgetRef ref,
) =>
    showSolfaRewardedVideoAdModal(context, ref);

/// Exchanges accumulated Developer Supporter Prestige Points (`prestigePoints`)
/// into Battle Arena Turns (`remainingBattlesToday`). Works 100% offline!
Future<bool> redeemPrestigePointsForBattleTurns(
  BuildContext context,
  WidgetRef ref, {
  required int pointsCost,
  required int turnsToGrant,
}) async {
  final adNotifier = ref.read(rewardedAdProvider.notifier);
  final currentPoints = ref.read(rewardedAdProvider).prestigePoints;

  if (currentPoints < pointsCost) {
    final missing = pointsCost - currentPoints;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bạn cần thêm $missing Gem nữa để đổi gói +$turnsToGrant Lượt Đấu. Hãy xem 1 video ủng hộ (15s) để nhận ngay +100 Gem nhé!',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return false;
  }

  final battleNotifier = ref.read(battleProvider.notifier);
  final audioService = ref.read(audioServiceProvider);

  final results = await Future.wait([
    adNotifier.spendPrestigePointsForTurns(
      pointsCost: pointsCost,
      turnsGranted: turnsToGrant,
    ),
    battleNotifier.restoreTurnFromRewardedAd(turns: turnsToGrant),
  ]);
  final ok = results.first as bool;
  if (!ok) return false;

  await audioService.playSessionCompleteFanfare();

  if (context.mounted) {
    final remainingPoints = ref.read(rewardedAdProvider).prestigePoints;
    final remainingTurns = ref.read(battleProvider).remainingBattlesToday;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.correct,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đổi thành công $pointsCost Gem → +$turnsToGrant Lượt Đấu Trường! (Hiện có: $remainingTurns lượt • Còn $remainingPoints Gem)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
  return true;
}

/// Màn hình Trạm Gem & Hỗ trợ nhà phát triển
class SupportDeveloperScreen extends ConsumerStatefulWidget {
  const SupportDeveloperScreen({super.key});

  @override
  ConsumerState<SupportDeveloperScreen> createState() =>
      _SupportDeveloperScreenState();
}

class _SupportDeveloperScreenState
    extends ConsumerState<SupportDeveloperScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isTest = ref.read(audioServiceProvider).isTestMode;
      if (!isTest) {
        ref.read(rewardedAdProvider.notifier).loadRewardedAd();
      }
    });
  }

  bool _isOpeningAdModal = false;

  Future<void> _loadAndWatchVideoAd() async {
    if (_isOpeningAdModal) return;
    final notifier = ref.read(rewardedAdProvider.notifier);
    final currentStatus = ref.read(rewardedAdProvider).status;

    if (currentStatus != RewardedAdStatus.ready) {
      final ok = await notifier.loadRewardedAd();
      if (!ok || !mounted) return;
    }

    if (!mounted) return;
    await _openRewardedVideoPlayerModal();
  }

  Future<void> _openRewardedVideoPlayerModal() async {
    if (_isOpeningAdModal) return;
    _isOpeningAdModal = true;
    try {
      final audioService = ref.read(audioServiceProvider);
      final completed = await _showRealAdMobOrFallbackVideo(context, ref);

      await ref
          .read(rewardedAdProvider.notifier)
          .completeWatchingAd(watchedToEnd: completed);

      if (completed && mounted) {
        await ref
            .read(battleProvider.notifier)
            .restoreTurnFromRewardedAd(turns: 1);
        await audioService.playSessionCompleteFanfare();
        if (!mounted) return;
        showGemRewardAnimation(
          context,
          gemsAdded: 100,
          subtitle: 'Cảm ơn bạn đã ủng hộ ChaoNote!',
          isTestMode: audioService.isTestMode,
        );
      final updatedState = ref.read(rewardedAdProvider);
      final count = updatedState.supportedCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const SolfaGemIcon(size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cảm ơn bạn! +1 Lượt Đấu Trường & +100 Gem (Lượt ủng hộ #$count • ${updatedState.supporterBadgeTitle}).',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
      if (!audioService.isTestMode && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: AppColors.accentAmber, size: 26),
                    SizedBox(width: 10),
                    SolfaGemIcon(size: 42),
                    SizedBox(width: 10),
                    Icon(Icons.celebration_rounded,
                        color: AppColors.accentAmber, size: 26),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Nhận thành công +100 Gem!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '+100 Gem • Tổng khả dụng: ${updatedState.prestigePoints} Gem',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Huy hiệu hiện tại: ${updatedState.supporterBadgeTitle}\n(Dùng Gem để mở khóa phiên học 1 tiếng hoặc đổi Lượt Đấu Trường)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.8, height: 1.38),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const SolfaGemIcon(size: 18),
                  label: const Text('Tuyệt vời!'),
                ),
                ],
              ),
            ),
          );
        }
      }
    } finally {
      _isOpeningAdModal = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final adState = ref.watch(rewardedAdProvider);
    final battleState = ref.watch(battleProvider);
    final notifier = ref.read(rewardedAdProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate milestone progress (next goal: 1, 5, 10, 25)
    final count = adState.supportedCount;
    final int nextMilestone = count < 1
        ? 1
        : count < 5
            ? 5
            : count < 10
                ? 10
                : ((count ~/ 10) + 1) * 10;
    final milestoneProgress = (count / nextMilestone).clamp(0.0, 1.0);

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Ủng hộ nhà phát triển'),
        ),
        body: ListView(
          cacheExtent: 1200,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            // Phần 1: Đổi Điểm Uy Tín lấy Lượt Đấu Trường
            _buildPrestigePointsRedeemCard(
              context,
              adState,
              battleState,
              isDark,
            ),

            const SizedBox(height: 16),

            // Phần 2: Ủng Hộ Nhà Phát Triển & Nhận Thưởng (Unified Card)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const SolfaLogo(size: 52, showShadow: false),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: kHeartRedColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.accentAmber.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 14,
                                      color: AppColors.accentAmber,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        adState.supporterBadgeTitle,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.accentAmber,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Ủng Hộ Nhà Phát Triển & Nhận Gem',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Xem video ngắn (15s) nhận +100 Gem & +1 Lượt Đấu',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Supporter Counter & Milestone Bar
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.04)
                            : AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Đã ủng hộ: ${adState.supportedCount} lần (${adState.prestigePoints} Gem khả dụng)',
                                  key: const Key('text_supported_count'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Text(
                                '$count / $nextMilestone mốc tiếp',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: milestoneProgress,
                              minHeight: 6,
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.14),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.accentAmber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    Text(
                      adState.statusMessage,
                      key: const Key('text_ad_status_message'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.2, height: 1.32),
                    ),
                    const SizedBox(height: 12),

                    // Primary Watch Video Ad Button
                    if (adState.status == RewardedAdStatus.ready)
                      ElevatedButton.icon(
                        key: const Key('btn_watch_rewarded_ad'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.correct,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: _openRewardedVideoPlayerModal,
                        icon: const Icon(
                          Icons.play_circle_fill_rounded,
                          size: 22,
                        ),
                        label: const Text(
                          'Xem video 15s (+100 Gem & +1 Lượt)',
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        key: const Key('btn_load_rewarded_ad'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: adState.status == RewardedAdStatus.loading
                            ? null
                            : _loadAndWatchVideoAd,
                        icon: adState.status == RewardedAdStatus.loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.ondemand_video_rounded),
                        label: Text(
                          adState.status == RewardedAdStatus.loading
                              ? 'Đang tải video...'
                              : 'Xem video 15s (+100 Gem)',
                        ),
                      ),

                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed:
                                adState.status == RewardedAdStatus.loading
                                    ? null
                                    : () => notifier.loadRewardedAd(),
                            icon: const Icon(Icons.refresh_rounded, size: 17),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Làm mới kết nối'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('btn_simulate_offline_ad'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () =>
                                notifier.loadRewardedAd(simulateOffline: true),
                            icon: const Icon(Icons.wifi_off_rounded, size: 17),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Thử khi Offline'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrestigePointsRedeemCard(
    BuildContext context,
    RewardedAdState adState,
    BattleState battleState,
    bool isDark,
  ) {
    final availablePoints = adState.prestigePoints;
    final remainingTurns = battleState.remainingBattlesToday;
    const maxFree = BattleState.maxDailyFreeBattles;

    return Card(
      key: const Key('card_redeem_prestige_points'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const SolfaGemIcon(size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trạm Đổi Gem → Lượt Đấu Trường & Phiên 1h',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${RewardedAdState.kOneHourPracticeGemCost} Gem mở phiên 1h • ${RewardedAdState.kUnlimitedPracticeGemCost} Gem mở Tự do • ${RewardedAdState.kSingleBattleTurnGemCost} Gem đổi +1 Lượt Đấu',
                        style: TextStyle(
                          fontSize: 11.3,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Wallet & Energy Bar Summary Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const SolfaGemIcon(size: 16),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Khả dụng: $availablePoints Gem',
                                key: const Key('text_available_prestige_points'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.8,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Thanh lượt: $remainingTurns/$maxFree',
                              key: const Key('text_redeem_current_turns'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 5-Segment Visual Energy Bar
                  Row(
                    children: List.generate(maxFree, (i) {
                      final active = i < remainingTurns;
                      return Expanded(
                        child: Container(
                          height: 7,
                          margin: EdgeInsets.only(
                            right: i < maxFree - 1 ? 5 : 0,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            gradient: active
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF00D287),
                                      Color(0xFF0D6EFD),
                                    ],
                                  )
                                : null,
                            color: active
                                ? null
                                : (isDark
                                    ? Colors.white.withOpacity(0.12)
                                    : Colors.black.withOpacity(0.10)),
                          ),
                        ),
                      );
                    }),
                  ),
                  if (adState.spentPrestigePoints > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Tổng tích lũy trọn đời: ${adState.totalPrestigePoints} Gem • Đã dùng: ${adState.spentPrestigePoints} Gem',
                      style: TextStyle(
                        fontSize: 10.8,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Package 1: 200 Gems -> +1 Turn
            _buildRedeemPackageTile(
              buttonKey: const Key('btn_redeem_100_points'),
              title: '+1 Lượt Đấu Trường',
              subtitle: '${RewardedAdState.kSingleBattleTurnGemCost} Gem',
              pointsCost: RewardedAdState.kSingleBattleTurnGemCost,
              turnsToGrant: 1,
              availablePoints: availablePoints,
              badgeText: null,
              accentColor: AppColors.primary,
              isDark: isDark,
            ),
            const SizedBox(height: 8),

            // Package 2: 500 Gems -> +3 Turns (Save 100 Gems)
            _buildRedeemPackageTile(
              buttonKey: const Key('btn_redeem_250_points'),
              title: '+3 Lượt Đấu Trường',
              subtitle: 'Tiết kiệm 100 Gem',
              pointsCost: RewardedAdState.kThreeBattleTurnsGemCost,
              turnsToGrant: 3,
              availablePoints: availablePoints,
              badgeText: 'ƯU ĐÃI',
              accentColor: AppColors.correct,
              isDark: isDark,
            ),
            const SizedBox(height: 8),

            // Package 3: 800 Gems -> +5 Turns (Save 200 Gems)
            _buildRedeemPackageTile(
              buttonKey: const Key('btn_redeem_400_points'),
              title: '+5 Lượt Đấu Trường',
              subtitle: 'Tiết kiệm 200 Gem',
              pointsCost: RewardedAdState.kFiveBattleTurnsGemCost,
              turnsToGrant: 5,
              availablePoints: availablePoints,
              badgeText: 'TỐT NHẤT',
              accentColor: AppColors.primary,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedeemPackageTile({
    required Key buttonKey,
    required String title,
    required String subtitle,
    required int pointsCost,
    required int turnsToGrant,
    required int availablePoints,
    required String? badgeText,
    required Color accentColor,
    required bool isDark,
  }) {
    final canAfford = availablePoints >= pointsCost;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: canAfford
              ? accentColor.withOpacity(0.45)
              : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.bolt_rounded,
              color: accentColor,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badgeText != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            key: buttonKey,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  canAfford ? accentColor : Colors.grey.withOpacity(0.35),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => redeemPrestigePointsForBattleTurns(
              context,
              ref,
              pointsCost: pointsCost,
              turnsToGrant: turnsToGrant,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SolfaGemIcon(size: 13),
                const SizedBox(width: 4),
                Text(
                  'Đổi $pointsCost Gem',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive Rewarded Video Ad Player Modal (15-second video showcase with countdown & audio).
class _RewardedVideoAdPlayerDialog extends StatefulWidget {
  final bool isTestMode;
  final ValueChanged<String> onPlayPreviewSound;
  final VoidCallback onStopSound;

  const _RewardedVideoAdPlayerDialog({
    required this.isTestMode,
    required this.onPlayPreviewSound,
    required this.onStopSound,
  });

  @override
  State<_RewardedVideoAdPlayerDialog> createState() =>
      _RewardedVideoAdPlayerDialogState();
}

class _RewardedVideoAdPlayerDialogState
    extends State<_RewardedVideoAdPlayerDialog> with WidgetsBindingObserver {
  static const int _totalVideoSeconds = 15;
  int _elapsedSeconds = 0;
  bool _isMuted = false;
  bool _isPausedInBackground = false;
  Timer? _videoTimer;

  static const List<({
    String title,
    String subtitle,
    IconData icon,
    List<Color> gradient,
  })> _scenes = [
    (
      title: 'ChaoNote Studio • Học Piano, Guitar & Cảm Âm',
      subtitle:
          'Nhận diện cao độ, khuông nhạc, hợp âm Guitar và thi đấu 1v1 trực quan mỗi ngày.',
      icon: Icons.headphones_rounded,
      gradient: [Color(0xFF0A265C), Color(0xFF0D6EFD)],
    ),
    (
      title: 'Máy đếm nhịp cơ học chuẩn xác (< 10ms)',
      subtitle:
          'Giữ vững tốc độ luyện đàn với âm thanh búa gõ cơ học tự nhiên, hoạt động 100% Offline.',
      icon: Icons.av_timer_rounded,
      gradient: [Color(0xFF1A1446), Color(0xFF5A31F4)],
    ),
    (
      title: 'Cảm ơn bạn đã ủng hộ đội ngũ phát triển!',
      subtitle:
          'Sự đồng hành của bạn giúp ChaoNote luôn miễn phí và không ngừng hoàn thiện.',
      icon: Icons.favorite_rounded,
      gradient: [Color(0xFF0B3B2E), Color(0xFF12946F)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.isTestMode) {
      widget.onPlayPreviewSound('assets/audio/keys/c_major.wav');
      _videoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _isPausedInBackground) return;
        setState(() {
          _elapsedSeconds++;
        });

        // Play pleasant musical cues on scene transitions
        if (!_isMuted) {
          if (_elapsedSeconds == 5) {
            widget.onPlayPreviewSound('assets/audio/intervals/c4_p5_asc.wav');
          } else if (_elapsedSeconds == 10) {
            widget.onPlayPreviewSound('assets/audio/keys/g_major.wav');
          }
        }

        if (_elapsedSeconds >= _totalVideoSeconds) {
          timer.cancel();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isPausedInBackground = true;
      widget.onStopSound();
    } else if (state == AppLifecycleState.resumed) {
      _isPausedInBackground = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        (_totalVideoSeconds - _elapsedSeconds).clamp(0, _totalVideoSeconds);
    final isRewardUnlocked = remaining == 0;
    final progress = (_elapsedSeconds / _totalVideoSeconds).clamp(0.0, 1.0);
    final sceneIdx = (_elapsedSeconds ~/ 5).clamp(0, _scenes.length - 1);
    final scene = _scenes[sceneIdx];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: const Color(0xFF0D1322),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Video Ad Header Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.smart_display_rounded,
                        size: 15,
                        color: AppColors.accentAmber,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'VIDEO QUẢNG CÁO',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accentAmber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isRewardUnlocked
                        ? 'Đã hoàn tất video!'
                        : 'Nhận thưởng sau ${remaining}s',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isRewardUnlocked
                          ? AppColors.correct
                          : Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: _isMuted ? 'Bật tiếng' : 'Tắt tiếng',
                  icon: Icon(
                    _isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _isMuted = !_isMuted);
                    if (_isMuted) {
                      widget.onStopSound();
                    }
                  },
                ),
                IconButton(
                  key: const Key('btn_ad_dismiss_early'),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Đóng quảng cáo',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 22,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(isRewardUnlocked);
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 2. 16:9 Cinema Video Canvas
            Container(
              height: 220,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: scene.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.16),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SolfaLogo(size: 46, showShadow: false),
                      const SizedBox(width: 12),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          scene.icon,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedSoundWave(
                    isPlaying: !isRewardUnlocked && !_isMuted,
                    color: const Color(0xFFFFD166),
                    maxHeight: 20,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    scene.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    scene.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 3. Video Progress Bar & Timecode
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.14),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isRewardUnlocked ? AppColors.correct : AppColors.accentAmber,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '00:${_elapsedSeconds.toString().padLeft(2, '0')} / 00:15',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Cảnh ${sceneIdx + 1}/3',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 4. Bottom Action Buttons (Explicit dark-surface styling so Light Mode never causes white-on-white or dark-on-dark)
            Row(
              children: [
                if (!isRewardUnlocked) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.08),
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                          color: Colors.white38,
                          width: 1.2,
                        ),
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Đóng giữa chừng',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    key: const Key('btn_ad_complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (isRewardUnlocked || widget.isTestMode)
                          ? AppColors.correct
                          : const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF1E293B),
                      disabledForegroundColor: Colors.white70,
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: (isRewardUnlocked || widget.isTestMode)
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    icon: Icon(
                      isRewardUnlocked
                          ? Icons.redeem_rounded
                          : Icons.hourglass_bottom_rounded,
                      size: 19,
                      color: isRewardUnlocked ? Colors.white : Colors.white70,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isRewardUnlocked
                            ? 'Nhận thưởng (+100 Gem & +1 Lượt)'
                            : 'Đang phát... Còn ${remaining}s',
                        style: TextStyle(
                          color:
                              isRewardUnlocked ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
