import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
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
    if (widget.topicId == 'topic_notes') {
      ref.read(selectedNoteLevelIdProvider.notifier).state = level.id;
    } else if (widget.topicId == 'topic_staff_reading') {
      ref.read(selectedStaffLevelIdProvider.notifier).state = level.id;
    }
    final notifier = ref.read(practiceSessionProvider.notifier);
    final isTest = ref.read(audioServiceProvider).isTestMode;
    final dur = ref.read(selectedPracticeDurationProvider);

    final canProceed = await checkAndSpendGemsForDurationIfNeeded(
      context,
      ref,
      durationSeconds: dur,
    );
    if (!canProceed || !mounted) return;
    final finalDur = ref.read(selectedPracticeDurationProvider);

    final ok = await notifier.startSession(
      mode: 'topic',
      topicId: widget.topicId,
      levelId: level.id,
      targetCount: 10,
      timeLimitSeconds: isTest ? null : (finalDur == 0 ? null : finalDur),
      isUnlimitedMode: isTest ? false : (finalDur == 0),
    );
    if (ok && mounted) {
      context.push('/quiz');
    } else if (!ok && mounted) {
      final err = ref.read(practiceSessionProvider).errorMessage;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      }
    }
  }

  String _levelDescription(String topicId, int difficulty) {
    if (topicId == 'topic_notes') {
      if (difficulty == 1) {
        return 'Mức 1 (Dễ): Chỉ gồm 7 nốt tự nhiên trong quãng C4 (Đô, Rê, Mi, Fa, Sol, La, Si), không có dấu #/b. Tự động phát âm chuẩn & hỗ trợ đối chiếu Đô (C4).';
      } else if (difficulty == 2) {
        return 'Mức 2 (Trung bình): Gói gọn trong quãng C4 nhưng bổ sung thêm 5 nốt dấu thăng (#) / dấu giáng (b). Tự động phát âm chuẩn & hỗ trợ đối chiếu Đô (C4).';
      } else if (difficulty == 3) {
        return 'Mức 3 (Khá): Mở rộng các nốt tự nhiên (không dấu #/b) trên 3 quãng tám từ trầm đến cao (C3 – C5), có hỗ trợ đối chiếu Đô chuẩn C4.';
      } else {
        return 'Mức 4 (Nâng cao): Đầy đủ cả nốt tự nhiên và dấu thăng/giáng (#/b) trải rộng từ C3 đến C5, tắt nút tham chiếu C4 để rèn cảm âm tuyệt đối.';
      }
    } else if (topicId == 'topic_staff_reading') {
      if (difficulty == 1) {
        return 'Mức 1 (Dễ): Đọc nốt tự nhiên trên khuông nhạc 5 dòng kẻ Khóa Sol cùng các nốt trên 1–2 dòng kẻ phụ dưới & trên (G3, A3, B3, C4 và A5, B5, C6).';
      } else if (difficulty == 2) {
        return 'Mức 2 (Trung bình): Đọc nốt trên khuông nhạc Khóa Sol và dòng kẻ phụ (G3–C6), bổ sung thêm các nốt có dấu hóa (#/b).';
      } else if (difficulty == 3) {
        return 'Mức 3 (Khá): Đọc nốt tự nhiên đa quãng tám (C3 – C6) kết hợp cả Khóa Sol và Khóa Fa cùng đầy đủ dòng kẻ phụ trên & dưới của 2 khóa.';
      } else {
        return 'Mức 4 (Nâng cao): Đọc toàn bộ nốt tự nhiên, dòng kẻ phụ và dấu hóa (#/b) từ C3 đến C6 trên cả Khóa Sol và Khóa Fa.';
      }
    } else if (topicId == 'topic_intervals') {
      if (difficulty == 1) {
        return 'Các quãng giai điệu đi lên cơ bản: Quãng 2 trưởng, 3 trưởng, 4 đúng, 5 đúng, 8 đúng.';
      } else if (difficulty == 2) {
        return 'Phân biệt màu sắc Trưởng/Thứ (quãng 3 thứ, 6 trưởng) và quãng giai điệu đi xuống.';
      } else {
        return 'Nghe hai nốt phát đồng thời (quãng hòa thanh), quãng 7 và quãng 4 tăng / 5 giảm.';
      }
    } else if (topicId == 'topic_chords') {
      if (difficulty == 1) {
        return 'Cơ bản: Nghe hợp âm rải kèm hòa âm để phân biệt rõ Hợp âm 3 Trưởng (tươi sáng) và Hợp âm 3 Thứ (trầm lắng).';
      } else if (difficulty == 2) {
        return 'Trung bình: Phân biệt 4 sắc thái hòa thanh cốt lõi: Hợp âm Trưởng, Hợp âm Thứ, Hợp âm Giảm (dim) và Hợp âm Tăng (aug).';
      } else {
        return 'Nâng cao: Nhận diện các hợp âm màu sắc hiện đại: Hợp âm Bảy Trưởng (Maj7), Bảy Thứ (m7), Bảy Át (Dom7) và Hợp âm Treo (Sus4).';
      }
    } else if (topicId == 'topic_melody') {
      if (difficulty == 1) {
        return 'Cơ bản: Nghe và xác định thứ tự cao độ của các nét giai điệu ngắn 3 nốt đi lên, đi xuống hoặc rải hợp âm.';
      } else if (difficulty == 2) {
        return 'Trung bình: Ghi nhớ và nhận diện chuỗi 4 nốt nhạc liền bậc hoặc ngũ cung trong quãng C4.';
      } else {
        return 'Nâng cao: Nhận diện nét giai điệu 4 nốt có bước nhảy quãng rộng và rải hợp âm trọn quãng tám.';
      }
    } else if (topicId == 'topic_rhythm') {
      if (difficulty == 1) {
        return 'Cơ bản: Nhận biết hình nốt Trắng, nốt Đen đều, chùm Móc đơn đôi và phân biệt nhịp 2/4 Hành khúc với nhịp 3/4 Waltz.';
      } else if (difficulty == 2) {
        return 'Trung bình: Phân biệt chùm ba Liên 3 (Triplet), chùm bốn Móc kép nhanh và tiết tấu Móc đơn chấm dôi.';
      } else {
        return 'Nâng cao: Nhận diện tiết tấu Đảo phách (Syncopation), tiết tấu Phi ngựa (Gallop) và nhịp kép 6/8.';
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
    final selectedDuration = ref.watch(selectedPracticeDurationProvider);
    final staffLedgerOnly = ref.watch(staffLedgerOnlyProvider);

    final topic = topicsAsync.valueOrNull
        ?.where((t) => t.id == widget.topicId)
        .firstOrNull;
    final topicAccent = topic != null
        ? AppColors.topicAccent(topic.code)
        : AppColors.primary;

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
                              color: topicAccent.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              _topicIcon(topic.code),
                              color: topicAccent,
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
                            avatar: const SolfaGemIcon(size: 13),
                            label: const Text('1 tiếng (50 Gem)'),
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
                      if (widget.topicId == 'topic_staff_reading') ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Vùng nốt muốn luyện tập:',
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
                              key: const Key('detail_staff_mode_all'),
                              label: const Text('Tất cả nốt (Khuông + Phụ)'),
                              selected: !staffLedgerOnly,
                              onSelected: (_) => ref
                                  .read(staffLedgerOnlyProvider.notifier)
                                  .state = false,
                            ),
                            ChoiceChip(
                              key: const Key('detail_staff_mode_ledger'),
                              label: const Text('Chuyên luyện Dòng kẻ phụ'),
                              selected: staffLedgerOnly,
                              onSelected: (_) => ref
                                  .read(staffLedgerOnlyProvider.notifier)
                                  .state = true,
                            ),
                          ],
                        ),
                      ],
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
                                          ? topicAccent.withOpacity(0.14)
                                          : Colors.grey.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      unlocked
                                          ? Icons.lock_open_rounded
                                          : Icons.lock_outline_rounded,
                                      color: unlocked
                                          ? topicAccent
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
                                                level.name.startsWith('Mức')
                                                    ? level.name
                                                    : 'Cấp độ: ${level.name}',
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
                                              children: List.generate(
                                                (widget.topicId ==
                                                            'topic_notes' ||
                                                        widget.topicId ==
                                                            'topic_staff_reading')
                                                    ? 4
                                                    : 3,
                                                (s) {
                                                  return Icon(
                                                    s < level.difficulty
                                                        ? Icons.star_rounded
                                                        : Icons
                                                            .star_border_rounded,
                                                    size: 17,
                                                    color: AppColors.accentAmber,
                                                  );
                                                },
                                              ),
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
                                style: unlocked
                                    ? ElevatedButton.styleFrom(
                                        backgroundColor: topicAccent,
                                      )
                                    : null,
                                onPressed: unlocked
                                    ? () => _startLevelPractice(level)
                                    : null,
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 20,
                                ),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    unlocked
                                        ? 'Bắt đầu cấp ${level.name.split(' (').first} (${TopicsScreen.durationLabel(selectedDuration)})'
                                        : 'Chưa mở khóa',
                                  ),
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
