import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../practice/application/practice_session_controller.dart';
import '../../practice/presentation/widgets/free_piano_explorer_sheet.dart';

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
    final noteLevelId = ref.read(selectedNoteLevelIdProvider);
    final staffLevelId = ref.read(selectedStaffLevelIdProvider);

    final ok = await notifier.startSession(
      mode: 'topic',
      topicId: topic.id,
      levelId: topic.id == 'topic_notes'
          ? noteLevelId
          : (topic.id == 'topic_staff_reading' ? staffLevelId : null),
      targetCount: 10,
      timeLimitSeconds: isTest ? null : (dur == 0 ? null : dur),
      isUnlimitedMode: isTest ? false : (dur == 0),
    );
    if (ok && context.mounted) {
      context.push('/quiz');
    } else if (!ok && context.mounted) {
      final err = ref.read(practiceSessionProvider).errorMessage;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      }
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
    final selectedNoteLevelId = ref.watch(selectedNoteLevelIdProvider);
    final selectedStaffLevelId = ref.watch(selectedStaffLevelIdProvider);
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
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: AppColors.primary,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Thời gian luyện tập',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('btn_topics_open_free_piano'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor:
                                const Color(0xFF635BFF).withOpacity(0.12),
                            foregroundColor: const Color(0xFF635BFF),
                          ),
                          onPressed: () => showFreePianoExplorerSheet(context),
                          icon: const Icon(Icons.piano_rounded, size: 16),
                          label: const Text(
                            'Đàn C3–C5',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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

            // 2. Active Topics List (Minimalist, unified primary accent, clear progress)
            ...List.generate(activeTopics.length, (i) {
              final topic = activeTopics[i];
              final stat = statsMap[topic.id];
              final sessionsDone = stat?.completedSessions ?? 0;
              final answered = stat?.totalAnswered ?? 0;
              final levelCount = (topic.id == 'topic_notes' ||
                      topic.id == 'topic_staff_reading')
                  ? 4
                  : 3;
              final progressRatio =
                  (sessionsDone / levelCount).clamp(0.0, 1.0);
              final statusLabel = sessionsDone >= levelCount
                  ? 'Hoàn thành'
                  : (answered > 0 ? 'Đang học' : 'Đã mở khóa');
              final statusColor = sessionsDone >= levelCount
                  ? AppColors.correct
                  : (answered > 0
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight));

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => context.push('/topics/${topic.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _topicIcon(topic.code),
                                  color: AppColors.primary,
                                  size: 22,
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
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$levelCount cấp độ • $statusLabel',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: statusColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () =>
                                    _startBasicForTopic(context, ref, topic),
                                child: const Text(
                                  'Luyện',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            topic.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          if (topic.id == 'topic_notes' ||
                              topic.id == 'topic_staff_reading') ...[
                            const SizedBox(height: 10),
                            Builder(
                              builder: (context) {
                                final isStaff =
                                    topic.id == 'topic_staff_reading';
                                final levelsList = isStaff
                                    ? kStaffReadingLevels
                                    : kNoteRecognitionLevels;
                                final currentSelectedId = isStaff
                                    ? selectedStaffLevelId
                                    : selectedNoteLevelId;
                                final keyPrefix = isStaff
                                    ? 'topic_staff_lvl_'
                                    : 'topic_note_lvl_';
                                return Row(
                                  children: [
                                    for (int lvlIdx = 0;
                                        lvlIdx < levelsList.length;
                                        lvlIdx++) ...[
                                      if (lvlIdx > 0)
                                        const SizedBox(width: 6),
                                      Expanded(
                                        child: _NoteLevelQuickButton(
                                          key: Key(
                                            '$keyPrefix${levelsList[lvlIdx].$1}',
                                          ),
                                          title: levelsList[lvlIdx].$2,
                                          subtitle: levelsList[lvlIdx].$3,
                                          isSelected: currentSelectedId ==
                                              levelsList[lvlIdx].$1,
                                          isDark: isDark,
                                          onTap: () {
                                            if (isStaff) {
                                              ref
                                                  .read(
                                                      selectedStaffLevelIdProvider
                                                          .notifier)
                                                  .state =
                                                  levelsList[lvlIdx].$1;
                                            } else {
                                              ref
                                                  .read(
                                                      selectedNoteLevelIdProvider
                                                          .notifier)
                                                  .state =
                                                  levelsList[lvlIdx].$1;
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: progressRatio,
                              minHeight: 4,
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.10),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                sessionsDone >= levelCount
                                    ? AppColors.correct
                                    : AppColors.primary,
                              ),
                            ),
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
                  Expanded(
                    child: Text(
                      'Chủ đề mở rộng (Sắp ra mắt)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
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
      case 'staff_reading':
        return Icons.menu_book_rounded;
      case 'interval_recognition':
      case 'intervals':
        return Icons.swap_vert_circle_outlined;
      case 'key_recognition':
      case 'keys':
        return Icons.library_music_rounded;
      case 'chord_recognition':
      case 'chords':
        return Icons.piano_rounded;
      case 'melody_recognition':
      case 'melody':
        return Icons.queue_music_rounded;
      case 'rhythm_recognition':
      case 'rhythm':
        return Icons.graphic_eq_rounded;
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

class _NoteLevelQuickButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NoteLevelQuickButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primary
          : (isDark ? Colors.white.withOpacity(0.06) : Colors.white),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isSelected
                  ? AppColors.secondary
                  : AppColors.primary.withOpacity(0.22),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.8,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white.withOpacity(0.92)
                        : Theme.of(context).textTheme.bodySmall?.color,
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
