import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/animated_ui.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../core/providers/app_providers.dart';
import '../../practice/application/practice_session_controller.dart';

/// UI-08: Ôn tập câu sai (UC-12)
/// Implements Decision #4: Requires 2 consecutive correct answers in review to mark as mastered.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  String? _selectedTopicId;

  Future<void> _startReviewSession() async {
    final notifier = ref.read(practiceSessionProvider.notifier);
    final ok = await notifier.startSession(
      mode: 'review',
      topicId: _selectedTopicId,
      targetCount: 10,
    );
    if (ok && mounted) {
      context.push('/quiz');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewAsync =
        ref.watch(pendingReviewItemsProvider(_selectedTopicId));
    final topicsAsync = ref.watch(topicsListProvider);
    final audioService = ref.watch(audioServiceProvider);

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Ôn tập câu sai'),
        ),
        body: Column(
          children: [
            // Topic filter bar
            topicsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (topics) {
                final enabled = topics.where((t) => t.isEnabled).toList();
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Tất cả'),
                          selected: _selectedTopicId == null,
                          onSelected: (_) =>
                              setState(() => _selectedTopicId = null),
                        ),
                      ),
                      ...enabled.map((t) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t.name),
                            selected: _selectedTopicId == t.id,
                            onSelected: (_) =>
                                setState(() => _selectedTopicId = t.id),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),

            Expanded(
              child: reviewAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Không thể tải danh sách ôn tập: $e')),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: FadeSlideIn(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: const BoxDecoration(
                                      color: AppColors.correctBgLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.task_alt_rounded,
                                      size: 46,
                                      color: AppColors.correct,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Không có câu sai nào cần ôn',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 17.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Các câu trả lời sai khi luyện tập sẽ được lưu tại đây để bạn ôn lại đến khi đúng 2 lần liên tiếp.',
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(fontSize: 13.5, height: 1.38),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: FadeSlideIn(
                          index: 0,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0D6EFD), Color(0xFF074CB2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.auto_fix_high_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Đang có ${items.length} câu cần ôn tập',
                                        style: const TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Trả lời đúng 2 lần liên tiếp để đánh dấu thuộc bài.',
                                  style: TextStyle(
                                    fontSize: 12.8,
                                    color: Colors.white.withOpacity(0.90),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ScaleTap(
                                  child: ElevatedButton.icon(
                                    key: const Key('btn_start_review_session'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppColors.primaryDark,
                                      minimumSize:
                                          const Size(double.infinity, 46),
                                    ),
                                    onPressed: _startReviewSession,
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 20,
                                    ),
                                    label: Text(
                                      'Bắt đầu ôn tập (${items.length > 10 ? 10 : items.length} câu)',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final q = item.question;
                            if (q == null) return const SizedBox.shrink();

                            return FadeSlideIn(
                              index: index + 1,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryLight,
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
                                              child: Text(
                                                item.topicName ?? 'Chủ đề',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primaryDark,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.wrong
                                                    .withOpacity(0.14),
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
                                              child: Text(
                                                'Sai ${item.wrongCount} lần',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: AppColors.wrong,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.correct
                                                    .withOpacity(0.14),
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
                                              child: Text(
                                                'Tiến độ: ${item.correctReviewCount}/2',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: AppColors.correct,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          q.prompt,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.correct
                                                      .withOpacity(0.10),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  'Đáp án đúng: ${q.correctOption.label}',
                                                  style: const TextStyle(
                                                    color: AppColors.correct,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton.filledTonal(
                                              tooltip: 'Nghe âm thanh câu này',
                                              icon: const Icon(
                                                Icons.volume_up_rounded,
                                                color: AppColors.primary,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                audioService
                                                    .playAsset(q.audioAsset);
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
