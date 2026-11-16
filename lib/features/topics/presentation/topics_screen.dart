import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_system/solfa_design_system.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../practice/application/practice_session_controller.dart';
import '../../practice/presentation/widgets/free_piano_explorer_sheet.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';

/// Kiểm tra và trừ 50 Gem khi người dùng bắt đầu phiên luyện tập chuyên sâu 1 tiếng (3600 giây).
/// Các phiên 60 giây, 15 phút và Tự do hoàn toàn miễn phí (0 Gem).
Future<bool> checkAndSpendGemsForDurationIfNeeded(
  BuildContext context,
  WidgetRef ref, {
  required int durationSeconds,
}) async {
  final isTest = ref.read(audioServiceProvider).isTestMode;
  if (isTest || durationSeconds != 3600) {
    return true;
  }
  const cost = RewardedAdState.kOneHourPracticeGemCost;
  final currentGems = ref.read(rewardedAdProvider).prestigePoints;
  if (currentGems < cost) {
    final missing = cost - currentGems;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          action: SnackBarAction(
            label: 'Nhận Gem',
            textColor: Colors.white,
            onPressed: () {
              context.push('/support-developer');
            },
          ),
          content: Row(
            children: [
              const SolfaGemIcon(size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gói luyện 1 tiếng cần $cost Gem (bạn còn thiếu $missing Gem). Hãy dùng 60s/15p Miễn phí hoặc nhận +100 Gem tại Trạm Gem!',
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

  final ok = await ref
      .read(rewardedAdProvider.notifier)
      .spendGemsForOneHourSession(gemCost: cost);
  if (ok && context.mounted) {
    final remaining = ref.read(rewardedAdProvider).prestigePoints;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Row(
          children: [
            const SolfaGemIcon(size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Đã dùng $cost Gem mở khóa phiên 1 tiếng (Còn lại: $remaining Gem).',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
  return ok;
}

/// Mở Modal Bottom Sheet gọn gàng để người dùng chọn Cấp độ luyện tập & Thời gian luyện tập cho chủ đề.
Future<void> showTopicPracticeSetupModal(
  BuildContext context,
  WidgetRef ref,
  TopicModel topic,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TopicPracticeSetupSheet(topic: topic),
  );
}

/// UI-03: Phòng luyện tập – Thẻ chủ đề tối giản & Modal chọn Cấp độ / Thời gian (Redesigned)
class TopicsScreen extends ConsumerWidget {
  const TopicsScreen({super.key});

  Future<void> _startForTopic(
    BuildContext context,
    WidgetRef ref,
    TopicModel topic,
  ) async {
    final dur = ref.read(selectedPracticeDurationProvider);
    final canProceed = await checkAndSpendGemsForDurationIfNeeded(
      context,
      ref,
      durationSeconds: dur,
    );
    if (!canProceed || !context.mounted) return;

    final notifier = ref.read(practiceSessionProvider.notifier);
    final isTest = ref.read(audioServiceProvider).isTestMode;
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

  static String shortTopicTitle(TopicModel topic) {
    switch (topic.id) {
      case 'topic_notes':
        return 'Luyện nghe nốt';
      case 'topic_staff_reading':
        return 'Luyện đọc nốt';
      case 'topic_intervals':
        return 'Luyện nghe quãng';
      case 'topic_keys':
        return 'Nhận biết giọng';
      case 'topic_chords':
        return 'Nhận biết hợp âm';
      case 'topic_melody':
        return 'Nghe giai điệu';
      case 'topic_rhythm':
        return 'Nhận biết nhịp điệu';
      default:
        return topic.name;
    }
  }

  static String shortTopicSubtitle(TopicModel topic) {
    switch (topic.id) {
      case 'topic_notes':
        return 'Cảm âm cao độ C3–C5';
      case 'topic_staff_reading':
        return 'Khuông nhạc & Dòng kẻ phụ';
      case 'topic_intervals':
        return 'Quãng 2 đến Quãng 8';
      case 'topic_keys':
        return 'Trưởng, Thứ & Hóa biểu';
      case 'topic_chords':
        return 'Ba nốt & Hợp âm 7';
      case 'topic_melody':
        return 'Chuỗi 3 – 4 nốt nhạc';
      case 'topic_rhythm':
        return 'Tiết tấu & Nhịp 2/4..6/8';
      default:
        return topic.description;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsListProvider);
    final progressAsync = ref.watch(overallProgressProvider);
    final selectedNoteLevelId = ref.watch(selectedNoteLevelIdProvider);
    final selectedStaffLevelId = ref.watch(selectedStaffLevelIdProvider);
    final staffLedgerOnly = ref.watch(staffLedgerOnlyProvider);
    final adState = ref.watch(rewardedAdProvider);
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

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            // Thanh công cụ gọn nhẹ: Chọn chủ đề để mở Modal cấu hình + Mở Đàn C3–C5
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Chọn thẻ chủ đề để bắt đầu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SolfaTypography.sectionTitle,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const Key('btn_topics_open_free_piano'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppColors.primary.withOpacity(0.10),
                    foregroundColor: AppColors.primary,
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
            const SizedBox(height: 4),
            Text(
              'Chạm vào thẻ chủ đề để chọn Cấp độ & Thời gian • 60s & 15p Miễn phí • 1 tiếng (${RewardedAdState.kOneHourPracticeGemCost} Gem • Hiện có: ${adState.prestigePoints} Gem)',
              style: TextStyle(
                fontSize: 11.8,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),

            // Danh sách Thẻ Chủ Đề Tối Giản (Minimalist Topic Cards)
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
                  : (answered > 0 ? 'Đang học' : 'Sẵn sàng');

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () =>
                        showTopicPracticeSetupModal(context, ref, topic),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
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
                                  topicIconForCode(topic.code),
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
                                      shortTopicTitle(topic),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${shortTopicSubtitle(topic)} • $levelCount mức ($statusLabel)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
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
                                    _startForTopic(context, ref, topic),
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
                                        child: _CompactLevelChip(
                                          key: Key(
                                            '$keyPrefix${levelsList[lvlIdx].$1}',
                                          ),
                                          title: levelsList[lvlIdx].$2,
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
                            if (topic.id == 'topic_staff_reading') ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: _CompactLevelChip(
                                      key: const Key('chip_staff_mode_all'),
                                      title: 'Tất cả nốt',
                                      isSelected: !staffLedgerOnly,
                                      isDark: isDark,
                                      onTap: () => ref
                                          .read(
                                              staffLedgerOnlyProvider.notifier)
                                          .state = false,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _CompactLevelChip(
                                      key: const Key('chip_staff_mode_ledger'),
                                      title: 'Chuyên dòng kẻ phụ',
                                      isSelected: staffLedgerOnly,
                                      isDark: isDark,
                                      onTap: () => ref
                                          .read(
                                              staffLedgerOnlyProvider.notifier)
                                          .state = true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                          const SizedBox(height: 8),
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
          ],
        );
      },
    );
  }

  static IconData topicIconForCode(String code) {
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

/// Modal Bottom Sheet cho phép chọn Cấp độ luyện tập & Thời gian luyện tập (60s/15p Miễn phí, 1h dùng 50 Gem).
class _TopicPracticeSetupSheet extends ConsumerStatefulWidget {
  final TopicModel topic;

  const _TopicPracticeSetupSheet({required this.topic});

  @override
  ConsumerState<_TopicPracticeSetupSheet> createState() =>
      _TopicPracticeSetupSheetState();
}

class _TopicPracticeSetupSheetState
    extends ConsumerState<_TopicPracticeSetupSheet> {
  String? _selectedOtherLevelId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDuration = ref.watch(selectedPracticeDurationProvider);
    final selectedNoteLvl = ref.watch(selectedNoteLevelIdProvider);
    final selectedStaffLvl = ref.watch(selectedStaffLevelIdProvider);
    final staffLedgerOnly = ref.watch(staffLedgerOnlyProvider);
    final adState = ref.watch(rewardedAdProvider);

    final topicId = widget.topic.id;
    final isNotes = topicId == 'topic_notes';
    final isStaff = topicId == 'topic_staff_reading';

    final prefix = topicId.replaceFirst('topic_', 'lvl_');
    final otherLevels = [
      ('${prefix}_basic', 'Mức 1', 'Cơ bản'),
      ('${prefix}_inter', 'Mức 2', 'Trung bình'),
      ('${prefix}_adv', 'Mức 3', 'Nâng cao'),
    ];
    final currentOtherLvl = _selectedOtherLevelId ?? otherLevels.first.$1;

    const durations = [
      (60, '60 giây', 'Miễn phí', false),
      (900, '15 phút', 'Miễn phí', false),
      (3600, '1 tiếng', '50 Gem', true),
      (0, 'Tự do', 'Miễn phí', false),
    ];

    return Container(
      key: const Key('modal_topic_practice_setup'),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      TopicsScreen.topicIconForCode(widget.topic.code),
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
                          TopicsScreen.shortTopicTitle(widget.topic),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          TopicsScreen.shortTopicSubtitle(widget.topic),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SolfaGemIcon(size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${adState.prestigePoints} Gem',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 1. Chọn cấp độ luyện tập
              const Text(
                '1. Chọn cấp độ luyện tập',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (isNotes || isStaff)
                Row(
                  children: [
                    for (int i = 0;
                        i <
                            (isStaff
                                    ? kStaffReadingLevels
                                    : kNoteRecognitionLevels)
                                .length;
                        i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Builder(
                          builder: (_) {
                            final item = (isStaff
                                ? kStaffReadingLevels
                                : kNoteRecognitionLevels)[i];
                            final selected =
                                (isStaff ? selectedStaffLvl : selectedNoteLvl) ==
                                    item.$1;
                            return _ModalOptionCard(
                              title: item.$2,
                              subtitle: item.$3,
                              isSelected: selected,
                              isDark: isDark,
                              onTap: () {
                                if (isStaff) {
                                  ref
                                      .read(selectedStaffLevelIdProvider.notifier)
                                      .state = item.$1;
                                } else {
                                  ref
                                      .read(selectedNoteLevelIdProvider.notifier)
                                      .state = item.$1;
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    for (int i = 0; i < otherLevels.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _ModalOptionCard(
                          title: otherLevels[i].$2,
                          subtitle: otherLevels[i].$3,
                          isSelected: currentOtherLvl == otherLevels[i].$1,
                          isDark: isDark,
                          onTap: () => setState(
                            () => _selectedOtherLevelId = otherLevels[i].$1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

              if (isStaff) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _CompactLevelChip(
                        title: 'Tất cả nốt (Khuông + Phụ)',
                        isSelected: !staffLedgerOnly,
                        isDark: isDark,
                        onTap: () => ref
                            .read(staffLedgerOnlyProvider.notifier)
                            .state = false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactLevelChip(
                        title: 'Chuyên luyện Dòng kẻ phụ',
                        isSelected: staffLedgerOnly,
                        isDark: isDark,
                        onTap: () => ref
                            .read(staffLedgerOnlyProvider.notifier)
                            .state = true,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // 2. Chọn thời gian luyện tập
              const Text(
                '2. Chọn thời gian luyện tập',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (int i = 0; i < durations.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _ModalOptionCard(
                        title: durations[i].$2,
                        subtitle: durations[i].$3,
                        showGemBadge: durations[i].$4,
                        isSelected: selectedDuration == durations[i].$1,
                        isDark: isDark,
                        onTap: () => ref
                            .read(selectedPracticeDurationProvider.notifier)
                            .state = durations[i].$1,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 18),

              // 3. Nút hành động chính duy nhất
              ElevatedButton.icon(
                key: const Key('btn_modal_start_practice'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () async {
                  final dur = ref.read(selectedPracticeDurationProvider);
                  final canProceed =
                      await checkAndSpendGemsForDurationIfNeeded(
                    context,
                    ref,
                    durationSeconds: dur,
                  );
                  if (!canProceed || !context.mounted) return;

                  final resolvedLvl = isNotes
                      ? ref.read(selectedNoteLevelIdProvider)
                      : (isStaff
                          ? ref.read(selectedStaffLevelIdProvider)
                          : currentOtherLvl);
                  final isTest = ref.read(audioServiceProvider).isTestMode;
                  final ok = await ref
                      .read(practiceSessionProvider.notifier)
                      .startSession(
                        mode: 'topic',
                        topicId: topicId,
                        levelId: resolvedLvl,
                        targetCount: 10,
                        timeLimitSeconds:
                            isTest ? null : (dur == 0 ? null : dur),
                        isUnlimitedMode: isTest ? false : (dur == 0),
                      );
                  if (ok && context.mounted) {
                    Navigator.of(context).pop();
                    context.push('/quiz');
                  }
                },
                icon: selectedDuration == 3600
                    ? const SolfaGemIcon(size: 18)
                    : const Icon(Icons.play_arrow_rounded, size: 22),
                label: Text(
                  selectedDuration == 3600
                      ? 'Mở khóa & Bắt đầu 1 tiếng (${RewardedAdState.kOneHourPracticeGemCost} Gem)'
                      : 'Bắt đầu học ngay (${TopicsScreen.durationLabel(selectedDuration)})',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactLevelChip extends StatelessWidget {
  final String title;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _CompactLevelChip({
    super.key,
    required this.title,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primary
          : (isDark
              ? Colors.white.withOpacity(0.05)
              : AppColors.backgroundLight),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModalOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isDark;
  final bool showGemBadge;
  final VoidCallback onTap;

  const _ModalOptionCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isDark,
    this.showGemBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primary
          : (isDark
              ? Colors.white.withOpacity(0.05)
              : AppColors.backgroundLight),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : null,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showGemBadge) ...[
                      const SolfaGemIcon(size: 11),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white.withOpacity(0.92)
                            : (showGemBadge
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
