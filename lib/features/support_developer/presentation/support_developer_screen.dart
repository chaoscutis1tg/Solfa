import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/animated_ui.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../app/widgets/solfa_logo.dart';
import '../../../core/providers/app_providers.dart';
import '../application/rewarded_ad_controller.dart';

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
      await audioService.playSessionCompleteFanfare();
      if (!mounted) return;
      final count = ref.read(rewardedAdProvider).supportedCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.correct,
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
                  'Cảm ơn bạn! Đã ghi nhận lượt xem video ủng hộ thứ #$count.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final adState = ref.watch(rewardedAdProvider);
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
                                  color: AppColors.accentCoral,
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
                                  'Số lượt bạn đã ủng hộ trên thiết bị này: ${adState.supportedCount}',
                                  key: const Key('text_supported_count'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
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

            // 2. Video Ad Control & Status Card (Section 13.3)
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
                        ? '✓ Đã hoàn tất video!'
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
