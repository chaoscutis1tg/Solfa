import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../practice/application/practice_session_controller.dart';
import 'topics_screen.dart';

final topicDetailLevelsProvider = FutureProvider.family<
    List<({LevelModel level, bool isUnlocked})>, String>((ref, topicId) async {
  // Watch settings so toggling unlockAllLevels refreshes level statuses
  ref.watch(appSettingsProvider);
  ref.watch(overallProgressProvider);
  final db = ref.watch(appDatabaseProvider);
  final levels = await db.getLevelsByTopic(topicId);
  final List<({LevelModel level, bool isUnlocked})> out = [];
  for (final l in levels) {
    final unlocked = await db.isLevelUnlocked(l);
    out.add((level: l, isUnlocked: unlocked));
  }
  return out;
});

/// UI-04: Chi tiết chủ đề / cấp độ trong Phòng luyện tập (UC-03)
class TopicDetailScreen extends ConsumerStatefulWidget {
  final String topicId;

  const TopicDetailScreen({
    super.key,
    required this.topicId,
  });

  @override
  ConsumerState<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends ConsumerState<TopicDetailScreen> {
  Future<void> _startLevelPractice(LevelModel level) async {
    final notifier = ref.read(practiceSessionProvider.notifier);
    final isTest = ref.read(audioServiceProvider).isTestMode;
    final dur = ref.read(selectedPracticeDurationProvider);

    final ok = await notifier.startSession(
      mode: 'topic',
      topicId: widget.topicId,
      levelId: level.id,
      targetCount: 10,
      timeLimitSeconds: isTest ? null : (dur == 0 ? null : dur),
      isUnlimitedMode: isTest ? false : (dur == 0),
    );
    if (ok && mounted) {
      context.push('/quiz');
    }
  }

  String _levelDescription(String topicId, int difficulty) {
    if (topicId == 'topic_notes') {
      if (difficulty == 1) {
        return 'Hỗ trợ nghe nốt Đô chuẩn (C4), bàn phím Piano tương tác và so sánh cao độ 2 nốt.';
      } else if (difficulty == 2) {
        return 'Hỗ trợ nghe nốt Đô chuẩn (C4); bổ sung các nốt hóa (Fa#, Sol#...) và khoảng cách nửa cung.';
      } else {
        return 'Tắt nốt tham chiếu C4 để rèn cảm âm tuyệt đối trên nhiều quãng tám (C3–C5).';
      }
    } else if (topicId == 'topic_intervals') {
      if (difficulty == 1) {
        return 'Các quãng giai điệu đi lên cơ bản: Quãng 2 trưởng, 3 trưởng, 4 đúng, 5 đúng, 8 đúng.';
      } else if (difficulty == 2) {
        return 'Phân biệt màu sắc Trưởng/Thứ (quãng 3 thứ, 6 trưởng) và quãng giai điệu đi xuống.';
      } else {
        return 'Nghe hai nốt phát đồng thời (quãng hòa thanh), quãng 7 và quãng 4 tăng / 5 giảm.';
      }
    } else {
      if (difficulty == 1) {
        return 'Nghe chuỗi hòa âm I–IV–V–I để phân biệt Giọng Trưởng (tươi sáng) và Giọng Thứ (trầm lắng).';
      } else if (difficulty == 2) {
        return 'Nhận biết hóa biểu (số dấu thăng/giáng) và cặp giọng Trưởng – Thứ song song.';
      } else {
        return 'Xác định tên giọng cụ thể qua chuỗi hòa âm và hệ thống nhiều dấu hóa.';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsListProvider);
    final levelsAsync = ref.watch(topicDetailLevelsProvider(widget.topicId));
    final settings = ref.watch(appSettingsProvider);
    final selectedDuration = ref.watch(selectedPracticeDurationProvider);

    final topic = topicsAsync.valueOrNull
        ?.where((t) => t.id == widget.topicId)
        .firstOrNull;

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(topic?.name ?? 'Chi tiết chủ đề'),
        ),
        body: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            if (topic != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              topic.name,
                              style: const TextStyle(
                                fontSize: 18.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        topic.description,
                        style: const TextStyle(fontSize: 13.5, height: 1.38),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Thời gian luyện tập & Tính điểm nốt Đúng / Sai:',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('60 giây'),
                            selected: selectedDuration == 60,
                            onSelected: (_) => ref
                                .read(selectedPracticeDurationProvider.notifier)
                                .state = 60,
                          ),
                          ChoiceChip(
                            label: const Text('15 phút'),
                            selected: selectedDuration == 900,
                            onSelected: (_) => ref
                                .read(selectedPracticeDurationProvider.notifier)
                                .state = 900,
                          ),
                          ChoiceChip(
                            label: const Text('1 tiếng'),
                            selected: selectedDuration == 3600,
                            onSelected: (_) => ref
                                .read(selectedPracticeDurationProvider.notifier)
                                .state = 3600,
                          ),
                          ChoiceChip(
                            label: const Text('Không giới hạn'),
                            selected: selectedDuration == 0,
                            onSelected: (_) => ref
                                .read(selectedPracticeDurationProvider.notifier)
                                .state = 0,
                          ),
                        ],
                      ),
                      const Divider(height: 22),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          'Mở khóa sẵn mọi cấp độ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        subtitle: const Text(
                          'Bật nếu bạn đã có nền tảng nhạc lý cơ bản',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: settings.unlockAllLevels,
                        onChanged: (v) {
                          ref
                              .read(appSettingsProvider.notifier)
                              .setUnlockAllLevels(v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Chọn cấp độ luyện tập',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            levelsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Lỗi tải cấp độ: $e'),
              data: (items) {
                return Column(
                  children: List.generate(items.length, (idx) {
                    final entry = items[idx];
                    final level = entry.level;
                    final unlocked = entry.isUnlocked;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: unlocked
                                          ? AppColors.primaryLight
                                          : Colors.grey.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      unlocked
                                          ? Icons.lock_open_rounded
                                          : Icons.lock_outline_rounded,
                                      color: unlocked
                                          ? AppColors.primary
                                          : Colors.grey,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Cấp độ: ${level.name}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: List.generate(3, (s) {
                                                return Icon(
                                                  s < level.difficulty
                                                      ? Icons.star_rounded
                                                      : Icons
                                                          .star_border_rounded,
                                                  size: 17,
                                                  color: AppColors.accentAmber,
                                                );
                                              }),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          unlocked
                                              ? 'Sẵn sàng luyện tập • Tính điểm Đúng/Sai'
                                              : 'Đạt ≥ 70% ở 2 phiên cấp trước để mở',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: unlocked
                                                ? AppColors.correct
                                                : Colors.grey,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _levelDescription(
                                    widget.topicId, level.difficulty),
                                style: const TextStyle(
                                  fontSize: 13.2,
                                  height: 1.38,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: unlocked
                                    ? () => _startLevelPractice(level)
                                    : null,
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  unlocked
                                      ? 'Bắt đầu cấp ${level.name} (${TopicsScreen.durationLabel(selectedDuration)})'
                                      : 'Chưa mở khóa',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
