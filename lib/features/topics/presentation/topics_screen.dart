import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../practice/application/practice_session_controller.dart';

/// UI-03: Phòng luyện tập – Danh sách chủ đề & Chọn thời gian luyện tập (UC-03)
class TopicsScreen extends ConsumerWidget {
  const TopicsScreen({super.key});

  Future<void> _startBasicForTopic(
    BuildContext context,
    WidgetRef ref,
    TopicModel topic,
  ) async {
    final notifier = ref.read(practiceSessionProvider.notifier);
    final isTest = ref.read(audioServiceProvider).isTestMode;
    final dur = ref.read(selectedPracticeDurationProvider);

    final ok = await notifier.startSession(
      mode: 'topic',
      topicId: topic.id,
      levelId: null, // Defaults to Basic level
      targetCount: 10,
      timeLimitSeconds: isTest ? null : (dur == 0 ? null : dur),
      isUnlimitedMode: isTest ? false : (dur == 0),
    );
    if (ok && context.mounted) {
      context.push('/quiz');
    }
  }

  static String durationLabel(int seconds) {
    switch (seconds) {
      case 60:
        return '60 giây';
      case 900:
        return '15 phút';
      case 3600:
        return '1 tiếng';
      case 0:
        return 'Không giới hạn';
      default:
        return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsListProvider);
    final progressAsync = ref.watch(overallProgressProvider);
    final selectedDuration = ref.watch(selectedPracticeDurationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return topicsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải danh sách chủ đề: $e')),
      data: (topics) {
        final statsMap = <String, TopicAccuracyStat>{};
        if (progressAsync.hasValue) {
          for (final s in progressAsync.value!.topicStats) {
            statsMap[s.topicId] = s;
          }
        }

        final activeTopics = topics.where((t) => t.isEnabled).toList();
        final upcomingTopics = topics.where((t) => !t.isEnabled).toList();

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            // 1. Practice Duration & Scoring Selector Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.timer_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thời gian luyện tập & Tính điểm',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Đếm trực tiếp số nốt Đúng / Sai (+10 điểm / nốt đúng)',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _DurationOptionButton(
                          label: '60 giây',
                          subLabel: 'Tốc độ',
                          icon: Icons.bolt_rounded,
                          isSelected: selectedDuration == 60,
                          isDark: isDark,
                          onTap: () => ref
                              .read(selectedPracticeDurationProvider.notifier)
                              .state = 60,
                        ),
                        const SizedBox(width: 8),
                        _DurationOptionButton(
                          label: '15 phút',
                          subLabel: 'Tiêu chuẩn',
                          icon: Icons.schedule_rounded,
                          isSelected: selectedDuration == 900,
                          isDark: isDark,
                          onTap: () => ref
                              .read(selectedPracticeDurationProvider.notifier)
                              .state = 900,
                        ),
                        const SizedBox(width: 8),
                        _DurationOptionButton(
                          label: '1 tiếng',
                          subLabel: 'Chuyên sâu',
                          icon: Icons.hourglass_bottom_rounded,
                          isSelected: selectedDuration == 3600,
                          isDark: isDark,
                          onTap: () => ref
                              .read(selectedPracticeDurationProvider.notifier)
                              .state = 3600,
                        ),
                        const SizedBox(width: 8),
                        _DurationOptionButton(
                          label: 'Tự do',
                          subLabel: 'Không giới hạn',
                          icon: Icons.all_inclusive_rounded,
                          isSelected: selectedDuration == 0,
                          isDark: isDark,
                          onTap: () => ref
                              .read(selectedPracticeDurationProvider.notifier)
                              .state = 0,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Active Topics List
            ...List.generate(activeTopics.length, (i) {
              final topic = activeTopics[i];
              final stat = statsMap[topic.id];
              final sessionsDone = stat?.completedSessions ?? 0;
              final answered = stat?.totalAnswered ?? 0;
              final accuracy = stat?.accuracyPercent ?? 0.0;
              final accent = AppColors.topicAccent(topic.code);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => context.push('/topics/${topic.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _topicIcon(topic.code),
                                  color: accent,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      topic.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: accent.withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            sessionsDone > 0
                                                ? '$sessionsDone phiên • $answered nốt'
                                                : '3 cấp độ • Cơ bản',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: accent,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (answered > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.correct
                                                  .withOpacity(0.14),
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                            child: Text(
                                              'Đúng ${accuracy.toStringAsFixed(0)}%',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors.correct,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: accent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            topic.description,
                            style:
                                const TextStyle(fontSize: 13.5, height: 1.38),
                          ),
                          if (answered > 0) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: (accuracy / 100.0).clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: accent.withOpacity(0.14),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(accent),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    minimumSize:
                                        const Size(double.infinity, 44),
                                  ),
                                  onPressed: () =>
                                      context.push('/topics/${topic.id}'),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Chọn cấp độ'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    minimumSize:
                                        const Size(double.infinity, 44),
                                  ),
                                  onPressed: () =>
                                      _startBasicForTopic(context, ref, topic),
                                  icon: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 19,
                                  ),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Luyện (${durationLabel(selectedDuration)})',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (upcomingTopics.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Chủ đề mở rộng (Sắp ra mắt)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(upcomingTopics.length, (i) {
                final topic = upcomingTopics[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.lock_clock_outlined,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  topic.name.replaceAll(' (Mở rộng)', ''),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  topic.description
                                      .replaceAll(' (Giai đoạn mở rộng)', ''),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  IconData _topicIcon(String code) {
    switch (code) {
      case 'note_recognition':
      case 'notes':
        return Icons.music_note_rounded;
      case 'interval_recognition':
      case 'intervals':
        return Icons.swap_vert_circle_outlined;
      case 'key_recognition':
      case 'chords':
        return Icons.library_music_rounded;
      default:
        return Icons.queue_music_rounded;
    }
  }
}

class _DurationOptionButton extends StatelessWidget {
  final String label;
  final String subLabel;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _DurationOptionButton({
    required this.label,
    required this.subLabel,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark ? AppColors.primary : AppColors.primary;
    final inactiveBg = isDark
        ? Colors.white.withOpacity(0.06)
        : AppColors.primary.withOpacity(0.06);

    return Expanded(
      child: Material(
        color: isSelected ? activeBg : inactiveBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.secondary
                    : AppColors.primary.withOpacity(0.18),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : AppColors.primary,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white.withOpacity(0.88)
                          : Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
