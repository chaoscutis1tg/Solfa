import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/note_formatter.dart';
import '../application/practice_session_controller.dart';

/// UI-07: Kết quả & Bảng điểm phiên luyện tập (UC-11)
/// Thiết kế gọn trong 1 màn hình, lưới thông số 2x2 rõ ràng, không bị cắt mép trên.
class SessionResultScreen extends ConsumerStatefulWidget {
  const SessionResultScreen({super.key});

  @override
  ConsumerState<SessionResultScreen> createState() =>
      _SessionResultScreenState();
}

class _SessionResultScreenState extends ConsumerState<SessionResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(audioServiceProvider).playSessionCompleteFanfare();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(practiceSessionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accuracy = state.accuracyPercent;
    final isHighAccuracy = accuracy >= 70.0;
    final starCount = accuracy >= 90
        ? 3
        : accuracy >= 70
            ? 2
            : accuracy >= 40
                ? 1
                : 0;

    final accentColor = isHighAccuracy ? AppColors.correct : AppColors.primary;
    final cardSurfaceColor = isDark
        ? AppColors.surfaceDark.withOpacity(0.92)
        : Colors.white.withOpacity(0.95);

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: const Text('Bảng điểm phiên luyện tập'),
        ),
        body: SafeArea(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            children: [
              // 1. Main Scoreboard Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Bar: Mode Pill + Star Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Chế độ: ${state.timeModeLabel}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(3, (index) {
                              final earned = index < starCount;
                              return Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Icon(
                                  earned
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 24,
                                  color: earned
                                      ? AppColors.warning
                                      : Colors.grey.withOpacity(0.35),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Hero Row: Circular Accuracy Gauge (Left) + Total Score & Feedback (Right)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 106,
                            height: 106,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: CircularProgressIndicator(
                                    value: (accuracy / 100.0).clamp(0.0, 1.0),
                                    strokeWidth: 9,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor:
                                        accentColor.withOpacity(0.14),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      accentColor,
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${accuracy.toStringAsFixed(0)}%',
                                      key: const Key('result_accuracy_text'),
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: accentColor,
                                        height: 1.05,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Chính xác',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.accentAmber.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.accentAmber
                                          .withOpacity(0.45),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.emoji_events_rounded,
                                        color: AppColors.accentAmber,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          '${state.scorePoints} ĐIỂM',
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.accentAmber,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  state.encouragingFeedback,
                                  style: const TextStyle(
                                    fontSize: 13.2,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // 2x2 Wide Metric Grid (Spacious, never clips text like '48 giây')
                      Row(
                        children: [
                          Expanded(
                            child: _ResultMetricTile(
                              label: 'Nốt đúng',
                              value: '${state.correctCount} nốt',
                              icon: Icons.check_circle_rounded,
                              color: AppColors.correct,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ResultMetricTile(
                              label: 'Nốt sai',
                              value: '${state.wrongCount} nốt',
                              icon: Icons.cancel_rounded,
                              color: AppColors.wrong,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _ResultMetricTile(
                              label: 'Điểm đạt',
                              value: '+${state.scorePoints} điểm',
                              icon: Icons.stars_rounded,
                              color: AppColors.accentAmber,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ResultMetricTile(
                              label: 'Thời gian',
                              value: NoteFormatter.formatDurationSeconds(
                                state.activeDurationSeconds,
                              ),
                              icon: Icons.timer_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. Primary Action: Retry Session
              ElevatedButton.icon(
                key: const Key('btn_retry_session'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () async {
                  final ok = await ref
                      .read(practiceSessionProvider.notifier)
                      .startSession(
                        mode: state.mode,
                        topicId: state.topicId,
                        levelId: state.levelId,
                        targetCount: state.totalQuestions > 0
                            ? state.totalQuestions
                            : 10,
                        timeLimitSeconds: state.timeLimitSeconds,
                        isUnlimitedMode: state.isUnlimitedMode,
                      );
                  if (ok && context.mounted) {
                    context.pushReplacement('/quiz');
                  }
                },
                icon: const Icon(Icons.replay_rounded, size: 20),
                label: const Text('Luyện lại phiên này'),
              ),

              // 3. Review Wrong Notes Button (High-contrast solid surface)
              if (state.wrongCount > 0) ...[
                const SizedBox(height: 8),
                Material(
                  color: cardSurfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    key: const Key('btn_review_wrong_from_result'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.pushReplacement('/review'),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.wrong.withOpacity(0.45),
                          width: 1.4,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.auto_fix_high_rounded,
                            color: AppColors.wrong,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ôn nốt sai (${state.wrongCount} nốt vừa sai)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: AppColors.wrong,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // 4. Side-by-Side Secondary Navigation Row (Phòng luyện tập & Về trang chủ)
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: cardSurfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.go('/topics'),
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.32),
                              width: 1.2,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.library_music_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Phòng luyện tập',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Material(
                      color: cardSurfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: const Key('btn_back_home'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.go('/home'),
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.32),
                              width: 1.2,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.home_outlined,
                                size: 19,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Về trang chủ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 5. Voluntary Support Developer Shortcut
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: const Size(0, 34),
                  ),
                  onPressed: () => context.push('/support-developer'),
                  icon: const Icon(
                    Icons.favorite_rounded,
                    size: 16,
                    color: AppColors.accentCoral,
                  ),
                  label: const Text(
                    'Xem video ngắn ủng hộ nhà phát triển',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ResultMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
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
