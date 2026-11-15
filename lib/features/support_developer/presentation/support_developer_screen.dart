import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/animated_ui.dart';
import '../../../app/widgets/pulsing_red_heart.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../app/widgets/solfa_logo.dart';
import '../../../core/providers/app_providers.dart';
import '../../battle/application/battle_controller.dart';
import '../application/rewarded_ad_controller.dart';

/// Opens the 15-second Rewarded Video Ad modal and, upon completion,
/// grants +1 Battle Arena turn AND +100 Developer Supporter Prestige Points.
Future<bool> showSolfaRewardedVideoAdModal(
  BuildContext context,
  WidgetRef ref,
) async {
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
                    'Chưa có kết nối Internet để tải quảng cáo hồi lượt. Bạn vẫn có thể luyện tập không giới hạn tại Phòng luyện tập!',
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
  await notifier.completeWatchingAd(watchedToEnd: completed == true);

  if (completed == true) {
    await ref.read(battleProvider.notifier).restoreTurnFromRewardedAd(turns: 1);
    await audioService.playSessionCompleteFanfare();
    return true;
  }
  return false;
}

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
                  'Bạn cần thêm $missing Điểm Uy Tín nữa để đổi gói +$turnsToGrant Lượt Đấu. Hãy xem 1 video ủng hộ (15s) để nhận ngay +100 điểm nhé!',
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
                'Đổi thành công $pointsCost Điểm Uy Tín → +$turnsToGrant Lượt Đấu Trường! (Hiện có: $remainingTurns lượt • Còn $remainingPoints điểm)',
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

/// UI-12: Hỗ trợ nhà phát triển – Xem Video Quảng Cáo Có Thưởng (UC-16 & Section 13)
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

  Future<void> _loadAndWatchVideoAd() async {
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
    final audioService = ref.read(audioServiceProvider);
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
    await ref
        .read(rewardedAdProvider.notifier)
        .completeWatchingAd(watchedToEnd: completed == true);

    if (completed == true && mounted) {
      await ref.read(battleProvider.notifier).restoreTurnFromRewardedAd(turns: 1);
      await audioService.playSessionCompleteFanfare();
      if (!mounted) return;
      final updatedState = ref.read(rewardedAdProvider);
      final count = updatedState.supportedCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kHeartRedColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(Icons.celebration_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cảm ơn bạn! +1 Lượt Đấu Trường & +100 Điểm Uy Tín (Lượt ủng hộ #$count • ${updatedState.supporterBadgeTitle}).',
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
                    PulsingRedHeart(size: 42, showGlowBadge: true),
                    SizedBox(width: 10),
                    Icon(Icons.celebration_rounded,
                        color: AppColors.accentAmber, size: 26),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Cảm ơn trái tim đỏ của bạn!',
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
                    color: kHeartRedColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '+100 Điểm Uy Tín • Tổng: ${updatedState.prestigePoints} điểm',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: kHeartRedColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Huy hiệu hiện tại: ${updatedState.supporterBadgeTitle}\n(Đã hiển thị vinh danh trên Trang chủ của bạn)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.8, height: 1.38),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kHeartRedColor,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.favorite_rounded, size: 18),
                  label: const Text('Tuyệt vời!'),
                ),
              ],
            ),
          ),
        );
      }
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
            // 1. Hero Supporter Badge & Gratitude Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const SolfaLogo(size: 60, showShadow: false),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: kHeartRedColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.accentAmber.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 15,
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
                              const SizedBox(height: 5),
                              const Text(
                                'Ủng hộ Solfa tự nguyện',
                                style: TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '100% bài học & Metronome luôn miễn phí',
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Mỗi lượt xem trọn vẹn video quảng cáo ngắn (15 giây) khi có mạng Internet sẽ giúp nhóm phát triển duy trì và bổ sung thêm nhiều bài luyện cảm âm mới cho cộng đồng.',
                      style: TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                    const SizedBox(height: 14),

                    // Supporter Counter & Milestone Bar
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : AppColors.primary.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.18),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Số lượt bạn đã ủng hộ trên thiết bị này: ${adState.supportedCount} (${adState.prestigePoints} điểm Uy tín)',
                                  key: const Key('text_supported_count'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: kHeartRedColor,
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
                                  AppColors.primary.withOpacity(0.15),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.accentAmber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 2. Prestige Points -> Battle Arena Turns Exchange Station Card
            _buildPrestigePointsRedeemCard(
              context,
              adState,
              battleState,
              isDark,
            ),

            const SizedBox(height: 14),

            // 3. Video Ad Control & Status Card (Section 13.3)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _statusColor(adState.status)
                                .withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _statusIcon(adState.status),
                            color: _statusColor(adState.status),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trạng thái: ${_statusLabel(adState.status)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 1),
                              const Text(
                                'Thời lượng video: 15 giây • Có âm thanh minh họa',
                                style: TextStyle(fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      adState.statusMessage,
                      key: const Key('text_ad_status_message'),
                      style: const TextStyle(fontSize: 13.5, height: 1.38),
                    ),
                    const SizedBox(height: 14),

                    // Primary Watch Video Ad Button
                    if (adState.status == RewardedAdStatus.ready)
                      ElevatedButton.icon(
                        key: const Key('btn_watch_rewarded_ad'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.correct,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: _openRewardedVideoPlayerModal,
                        icon: const Icon(
                          Icons.play_circle_fill_rounded,
                          size: 24,
                        ),
                        label: const Text(
                          'Xem video quảng cáo ủng hộ ngay (15s)',
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        key: const Key('btn_load_rewarded_ad'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
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
                              ? 'Đang tải video quảng cáo...'
                              : 'Tải & Xem video quảng cáo ủng hộ',
                        ),
                      ),

                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 42),
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
                              minimumSize: const Size(0, 42),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9500), Color(0xFFFF5E3A)],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đổi Điểm Uy Tín → Lượt Đấu Trường',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Đổi bất cứ lúc nào (kể cả khi Offline) • Giữ nguyên danh hiệu vinh danh',
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
                    : AppColors.accentAmber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accentAmber.withOpacity(0.3),
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
                            const Icon(
                              Icons.generating_tokens_rounded,
                              size: 16,
                              color: AppColors.accentAmber,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Khả dụng: $availablePoints điểm',
                                key: const Key('text_available_prestige_points'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.8,
                                  color: AppColors.accentAmber,
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
                      'Tổng tích lũy trọn đời: ${adState.totalPrestigePoints}đ • Đã quy đổi: ${adState.spentPrestigePoints}đ',
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

            // Package 1: 100 Points -> +1 Turn
            _buildRedeemPackageTile(
              buttonKey: const Key('btn_redeem_100_points'),
              title: 'Gói Nạp Nhanh: +1 Lượt Đấu Trường',
              subtitle: 'Tỷ lệ chuẩn 1:1 • Đổi ngay cả khi không có mạng',
              pointsCost: 100,
              turnsToGrant: 1,
              availablePoints: availablePoints,
              badgeText: null,
              accentColor: AppColors.primary,
              isDark: isDark,
            ),
            const SizedBox(height: 8),

            // Package 2: 250 Points -> +3 Turns (Save 50 pts)
            _buildRedeemPackageTile(
              buttonKey: const Key('btn_redeem_250_points'),
              title: 'Gói Tăng Tốc: +3 Lượt Đấu Trường',
              subtitle: 'Tiết kiệm 50 Điểm Uy Tín (+20% giá trị lượt chơi)',
              pointsCost: 250,
              turnsToGrant: 3,
              availablePoints: availablePoints,
              badgeText: 'TIẾT KIỆM 50Đ',
              accentColor: AppColors.correct,
              isDark: isDark,
            ),
            const SizedBox(height: 8),

            // Package 3: 400 Points -> +5 Turns (Save 100 pts)
            _buildRedeemPackageTile(
              buttonKey: const Key('btn_redeem_400_points'),
              title: 'Gói Cao Thủ: +5 Lượt Đấu Trường',
              subtitle: 'Tiết kiệm 100 Điểm (Tặng 1 lượt miễn phí • Đầy 5/5 thanh)',
              pointsCost: 400,
              turnsToGrant: 5,
              availablePoints: availablePoints,
              badgeText: 'HOT • TẶNG +1 LƯỢT',
              accentColor: kHeartRedColor,
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
            child: Text(
              'Đổi $pointsCostđ',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(RewardedAdStatus status) {
    switch (status) {
      case RewardedAdStatus.notLoaded:
        return 'Sẵn sàng kết nối';
      case RewardedAdStatus.loading:
        return 'Đang tải video...';
      case RewardedAdStatus.ready:
        return 'Video đã sẵn sàng';
      case RewardedAdStatus.completed:
        return 'Đã xem hoàn tất';
      case RewardedAdStatus.dismissedEarly:
        return 'Đã đóng sớm';
      case RewardedAdStatus.offline:
        return 'Không có mạng';
      case RewardedAdStatus.sdkError:
        return 'Tạm thời chưa khả dụng';
    }
  }

  IconData _statusIcon(RewardedAdStatus status) {
    switch (status) {
      case RewardedAdStatus.completed:
        return Icons.check_circle_rounded;
      case RewardedAdStatus.offline:
        return Icons.wifi_off_rounded;
      case RewardedAdStatus.ready:
        return Icons.play_circle_fill_rounded;
      default:
        return Icons.smart_display_rounded;
    }
  }

  Color _statusColor(RewardedAdStatus status) {
    switch (status) {
      case RewardedAdStatus.completed:
      case RewardedAdStatus.ready:
        return AppColors.correct;
      case RewardedAdStatus.offline:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
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
    extends State<_RewardedVideoAdPlayerDialog> {
  static const int _totalVideoSeconds = 15;
  int _elapsedSeconds = 0;
  bool _isMuted = false;
  Timer? _videoTimer;

  static const List<({
    String title,
    String subtitle,
    IconData icon,
    List<Color> gradient,
  })> _scenes = [
    (
      title: 'Solfa Studio Pro • Luyện cảm âm mỗi ngày',
      subtitle:
          'Nhận diện cao độ, quãng nhạc và giọng Trưởng/Thứ trực quan cùng bàn phím Piano.',
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
          'Sự đồng hành của bạn giúp Solfa luôn miễn phí và không ngừng hoàn thiện.',
      icon: Icons.favorite_rounded,
      gradient: [Color(0xFF0B3B2E), Color(0xFF12946F)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (!widget.isTestMode) {
      widget.onPlayPreviewSound('assets/audio/keys/c_major.wav');
      _videoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
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
  void dispose() {
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

            // 4. Bottom Action Buttons
            Row(
              children: [
                if (!isRewardUnlocked) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Đóng giữa chừng'),
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
                      backgroundColor: isRewardUnlocked
                          ? AppColors.correct
                          : AppColors.primary,
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: Icon(
                      isRewardUnlocked
                          ? Icons.redeem_rounded
                          : Icons.fast_forward_rounded,
                      size: 19,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isRewardUnlocked
                            ? 'Nhận thưởng & Hoàn tất ủng hộ'
                            : 'Hoàn tất xem ngay',
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
