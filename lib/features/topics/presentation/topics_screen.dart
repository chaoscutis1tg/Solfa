import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_system/solfa_design_system.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../app/widgets/solfa_guitar_icon.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../guitar/presentation/guitar_studio_sheet.dart';
import '../../guitar/presentation/interactive_songbook_and_theory_sheet.dart';
import '../../practice/application/practice_session_controller.dart';
import '../../practice/presentation/chord_progression_ear_screen.dart';
import '../../practice/presentation/widgets/free_piano_explorer_sheet.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';
import '../../support_developer/presentation/support_developer_screen.dart';

/// Chế độ phân khu trên trang Luyện tập: 'piano' (Piano & Nhạc lý) hoặc 'guitar' (Học Guitar & Cần đàn).
final selectedPracticeAreaProvider = StateProvider<String>((ref) => 'piano');

/// Kiểm tra và trừ Gem khi người dùng bắt đầu phiên luyện tập chuyên sâu 1 tiếng (3600 giây = 50 Gem)
/// hoặc chế độ Tự do không giới hạn thời gian (0 giây = 100 Gem).
/// Các phiên 60 giây và 15 phút hoàn toàn miễn phí (0 Gem).
Future<bool> checkAndSpendGemsForDurationIfNeeded(
  BuildContext context,
  WidgetRef ref, {
  required int durationSeconds,
}) async {
  final isTest = ref.read(audioServiceProvider).isTestMode;
  if (isTest || (durationSeconds != 3600 && durationSeconds != 0)) {
    return true;
  }
  final isUnlimited = durationSeconds == 0;
  final isEn = ref.read(appSettingsProvider).isEnglish;
  final cost = isUnlimited
      ? RewardedAdState.kUnlimitedPracticeGemCost
      : RewardedAdState.kOneHourPracticeGemCost;
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
            label: isEn ? 'Get Gems' : 'Nhận Gem',
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
                  isUnlimited
                      ? (isEn
                          ? 'Unlimited mode requires $cost Gems (you need $missing more). Use Free 60s/15m or earn +100 Gems at Gem Station!'
                          : 'Chế độ Tự do (Không giới hạn thời gian) cần $cost Gem (bạn còn thiếu $missing Gem). Hãy dùng 60s/15p Miễn phí hoặc nhận +100 Gem tại Trạm Gem!')
                      : (isEn
                          ? '1-hour practice requires $cost Gems (you need $missing more). Use Free 60s/15m or earn +100 Gems at Gem Station!'
                          : 'Gói luyện 1 tiếng cần $cost Gem (bạn còn thiếu $missing Gem). Hãy dùng 60s/15p Miễn phí hoặc nhận +100 Gem tại Trạm Gem!'),
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
      .spendGemsForOneHourSession(
        gemCost: cost,
        isUnlimited: isUnlimited,
      );
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
                isUnlimited
                    ? (isEn
                        ? 'Spent $cost Gems to unlock Unlimited mode (Remaining: $remaining Gems).'
                        : 'Đã dùng $cost Gem mở khóa chế độ Tự do không giới hạn (Còn lại: $remaining Gem).')
                    : (isEn
                        ? 'Spent $cost Gems to unlock 1-hour session (Remaining: $remaining Gems).'
                        : 'Đã dùng $cost Gem mở khóa phiên 1 tiếng (Còn lại: $remaining Gem).'),
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

/// Mở Modal Bottom Sheet gọn gàng để người dùng chọn Độ khó (Cấp độ) & Thời gian luyện tập.
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

/// Màn hình Phòng luyện tập:
/// - Lưới 2 cột (1 hàng 2 thẻ to).
/// - Ngoài thẻ CHỈ hiển thị Logo/Icon lớn của bài luyện tập + Tên bài luyện tập (ví dụ: Luyện nghe nốt, Luyện đọc nốt...).
/// - Chạm vào thẻ sẽ mở Modal chọn Chế độ khó/dễ và Thời gian (bao nhiêu phút).
class TopicsScreen extends ConsumerWidget {
  const TopicsScreen({super.key});

  static String durationLabel(int seconds, {bool isEn = false}) {
    switch (seconds) {
      case 60:
        return isEn ? '60s' : '60 giây';
      case 900:
        return isEn ? '15 min' : '15 phút';
      case 3600:
        return isEn ? '1 hour' : '1 tiếng';
      case 0:
        return isEn ? 'Free Play' : 'Không giới hạn';
      default:
        return '${seconds}s';
    }
  }

  static String shortTopicTitle(TopicModel topic, {bool isEn = false}) {
    if (isEn) {
      return AppLocale.localizeTopicName(topic.id, topic.name, true);
    }
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
      case 'topic_guitar_notes':
        return 'Nhớ nốt Cần đàn';
      case 'topic_guitar_chords':
        return 'Hợp âm Guitar';
      case 'topic_guitar_scales':
        return 'Bản đồ Scale';
      case 'topic_guitar_tabs':
        return 'Đọc Tab & Ngón';
      default:
        return topic.name;
    }
  }

  static String shortTopicSubtitle(TopicModel topic, {bool isEn = false}) {
    if (isEn) {
      return AppLocale.localizeTopicSubtitle(topic.id, topic.description, true);
    }
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
      case 'topic_guitar_notes':
        return '6 Dây buông E–A–D–G–B–e & Ngăn 1–12';
      case 'topic_guitar_chords':
        return 'Thế bấm C, G, Am, Em, Dm, F, D, E';
      case 'topic_guitar_scales':
        return 'Pentatonic, Trưởng/Thứ & Quãng 8 chéo';
      case 'topic_guitar_tabs':
        return 'Khuông Tab 6 dây & Bò nhện 1-2-3-4';
      default:
        return topic.description;
    }
  }

  static IconData topicIconForCode(String code) {
    switch (code) {
      case 'note_recognition':
      case 'notes':
        return Icons.headphones_rounded;
      case 'staff_reading':
        return Icons.menu_book_rounded;
      case 'interval_recognition':
      case 'intervals':
        return Icons.compare_arrows_rounded;
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
      case 'guitar_notes':
        return Icons.grid_on_rounded;
      case 'guitar_chords':
        return Icons.pan_tool_alt_rounded;
      case 'guitar_scales':
        return Icons.timeline_rounded;
      case 'guitar_tabs':
        return Icons.format_list_numbered_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }

  static const List<TopicModel> guitarTopics = [
    TopicModel(
      id: 'topic_guitar_notes',
      code: 'guitar_notes',
      name: 'Nhớ nốt Cần đàn',
      description: '6 Dây buông E–A–D–G–B–e & Ngăn 1–12',
      sortOrder: 1,
      isEnabled: true,
    ),
    TopicModel(
      id: 'topic_guitar_chords',
      code: 'guitar_chords',
      name: 'Hợp âm Guitar',
      description: 'Thế bấm C, G, Am, Em, Dm, F, D, E',
      sortOrder: 2,
      isEnabled: true,
    ),
    TopicModel(
      id: 'topic_guitar_scales',
      code: 'guitar_scales',
      name: 'Bản đồ Scale',
      description: 'Pentatonic, Trưởng/Thứ & Quãng 8 chéo',
      sortOrder: 3,
      isEnabled: true,
    ),
    TopicModel(
      id: 'topic_guitar_tabs',
      code: 'guitar_tabs',
      name: 'Đọc Tab & Ngón',
      description: 'Khuông Tab 6 dây & Bò nhện 1-2-3-4',
      sortOrder: 4,
      isEnabled: true,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsListProvider);
    final selectedArea = ref.watch(selectedPracticeAreaProvider);
    final isGuitarArea = selectedArea == 'guitar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = ref.watch(appSettingsProvider).isEnglish;

    return topicsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          isEn ? 'Failed to load topics: $e' : 'Lỗi tải danh sách chủ đề: $e',
        ),
      ),
      data: (topics) {
        final activeTopics =
            isGuitarArea ? guitarTopics : topics.where((t) => t.isEnabled).toList();
        final quizRowCount = (activeTopics.length / 2).ceil();
        final practiceTools = _buildStandaloneTools(
          context,
          isGuitarArea: isGuitarArea,
          isDark: isDark,
          isEn: isEn,
        );
        final toolRowCount = (practiceTools.length / 2).ceil();

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            // 1. Hero Banner: Kho Bản Nhạc & Chơi Đàn Tương Tác (Trang riêng 2 bước: Chọn bài -> Phòng chơi đàn)
            _SongbookHeroCard(
              key: const Key('btn_open_songbook_catalog'),
              isDark: isDark,
              isEn: isEn,
              onTap: () => openSongbookCatalogScreen(context),
            ),
            const SizedBox(height: 14),

            // 2. Thanh chuyển đổi Khu vực Piano & Nhạc lý <-> Khu vực Guitar & Cần đàn
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _AreaSwitchButton(
                      key: const Key('tab_practice_area_piano'),
                      icon: Icons.piano_rounded,
                      label: isEn ? 'Piano & Theory' : 'Piano & Nhạc lý',
                      isSelected: !isGuitarArea,
                      accentColor: AppColors.primary,
                      onTap: () => ref
                          .read(selectedPracticeAreaProvider.notifier)
                          .state = 'piano',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _AreaSwitchButton(
                      key: const Key('tab_practice_area_guitar'),
                      icon: Icons.grid_on_rounded,
                      customIcon: SolfaGuitarIcon(
                        size: 17,
                        color: isGuitarArea
                            ? Colors.white
                            : const Color(0xFFD97706),
                      ),
                      label: isEn
                          ? 'Guitar & Fretboard'
                          : 'Học Guitar & Cần đàn',
                      isSelected: isGuitarArea,
                      accentColor: const Color(0xFFD97706),
                      onTap: () => ref
                          .read(selectedPracticeAreaProvider.notifier)
                          .state = 'guitar',
                    ),
                  ),
                ],
              ),
            ),
            if (isGuitarArea) ...[
              const SizedBox(height: 10),
              const GuitarTypeSwitchBar(),
            ],
            const SizedBox(height: 16),

            // 3. Phân khu Công cụ Thực hành Trực tiếp (Đưa toàn bộ tab con ra ngoài — Mở thẳng không lồng tab)
            Row(
              children: [
                Expanded(
                  child: Text(
                    isGuitarArea
                        ? (isEn ? 'Guitar Studio Tools' : 'Công cụ Thực hành Guitar')
                        : (isEn ? 'Interactive Instruments & Theory' : 'Công cụ Đàn & Hòa âm'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SolfaTypography.heading.copyWith(fontSize: 16.5),
                  ),
                ),
                TextButton.icon(
                  key: const Key('btn_topics_open_free_piano'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: (isGuitarArea
                            ? const Color(0xFFD97706)
                            : AppColors.primary)
                        .withOpacity(0.12),
                    foregroundColor: isGuitarArea
                        ? const Color(0xFFD97706)
                        : AppColors.primary,
                  ),
                  onPressed: () => isGuitarArea
                      ? showGuitarStudioSheet(
                          context,
                          initialTab: 0,
                          singleTabMode: true,
                        )
                      : showFreePianoExplorerSheet(context),
                  icon: Icon(
                    isGuitarArea
                        ? Icons.grid_on_rounded
                        : Icons.piano_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isGuitarArea
                        ? (isEn ? 'Fretboard' : 'Map Cần đàn')
                        : (isEn ? 'Piano C3–C5' : 'Đàn Piano'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (int r = 0; r < toolRowCount; r++) ...[
              if (r > 0) const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: practiceTools[r * 2]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: (r * 2 + 1) < practiceTools.length
                        ? practiceTools[r * 2 + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // 4. Phân khu Bài tập Cảm âm & Trắc nghiệm (Quiz)
            Row(
              children: [
                Expanded(
                  child: Text(
                    isGuitarArea
                        ? (isEn
                            ? 'Guitar Quizzes & Ear Training'
                            : 'Bài Luyện Trắc Nghiệm Guitar')
                        : (isEn
                            ? 'Ear Training & Sight-Reading'
                            : 'Bài Luyện Cảm Âm & Thị Xướng'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SolfaTypography.heading.copyWith(fontSize: 16.5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (isGuitarArea
                            ? const Color(0xFFD97706)
                            : AppColors.primary)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    isEn
                        ? '${activeTopics.length} topics'
                        : '${activeTopics.length} chủ đề',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isGuitarArea
                          ? const Color(0xFFD97706)
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            for (int r = 0; r < quizRowCount; r++) ...[
              if (r > 0) const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildQuizTopicCard(
                      context,
                      ref,
                      activeTopics[r * 2],
                      isGuitarArea,
                      isDark,
                      isEn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: (r * 2 + 1) < activeTopics.length
                        ? _buildQuizTopicCard(
                            context,
                            ref,
                            activeTopics[r * 2 + 1],
                            isGuitarArea,
                            isDark,
                            isEn,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildQuizTopicCard(
    BuildContext context,
    WidgetRef ref,
    TopicModel topic,
    bool isGuitarArea,
    bool isDark,
    bool isEn,
  ) {
    return _BigTopicGridCard(
      key: Key('topic_grid_card_${topic.id}'),
      icon: topicIconForCode(topic.code),
      title: shortTopicTitle(topic, isEn: isEn),
      subtitle: shortTopicSubtitle(topic, isEn: isEn),
      accentColor: isGuitarArea ? const Color(0xFFD97706) : AppColors.primary,
      isDark: isDark,
      onTap: () => showTopicPracticeSetupModal(context, ref, topic),
    );
  }

  List<Widget> _buildStandaloneTools(
    BuildContext context, {
    required bool isGuitarArea,
    required bool isDark,
    required bool isEn,
  }) {
    if (!isGuitarArea) {
      return [
        _CompactToolCard(
          key: const Key('topic_grid_card_free_piano'),
          icon: Icons.piano_rounded,
          title: isEn ? 'Piano C3–C5' : 'Đàn Piano C3–C5',
          subtitle: isEn ? 'Staff & Dictation' : 'Khuông & Chép nhạc',
          accentColor: AppColors.primary,
          isDark: isDark,
          onTap: () => showFreePianoExplorerSheet(context),
        ),
        _CompactToolCard(
          key: const Key('topic_grid_card_chord_prog_ear'),
          icon: Icons.queue_music_rounded,
          title: isEn ? 'Chord Loops' : 'Dò Vòng Hợp Âm',
          subtitle: isEn ? 'I–V–vi–IV Ear' : 'Đệm hát I–V–vi–IV',
          accentColor: const Color(0xFF7C3AED),
          isDark: isDark,
          onTap: () => openChordProgressionEarScreen(context),
        ),
        _CompactToolCard(
          key: const Key('topic_grid_card_circle_capo'),
          icon: Icons.donut_large_rounded,
          title: isEn ? 'Circle & Capo' : 'Vòng Bậc 5 & Capo',
          subtitle: isEn ? '12 Keys • Transpose' : '12 Giọng • Dịch tông',
          accentColor: const Color(0xFF0D9488),
          isDark: isDark,
          onTap: () => openCircleOfFifthsAndCapoScreen(context),
        ),
      ];
    }

    return [
      _CompactToolCard(
        key: const Key('topic_grid_card_guitar_studio'),
        icon: Icons.grid_on_rounded,
        customIcon: const SolfaGuitarIcon(
          size: 20,
          color: Color(0xFFD97706),
        ),
        title: isEn ? 'Fretboard & Hz' : 'Map Cần đàn',
        subtitle: isEn ? '6 Strings • Tuner' : '6 Dây • So dây Hz',
        accentColor: const Color(0xFFD97706),
        isDark: isDark,
        onTap: () => showGuitarStudioSheet(
          context,
          initialTab: 0,
          singleTabMode: true,
        ),
      ),
      _CompactToolCard(
        key: const Key('topic_grid_card_guitar_chords_tool'),
        icon: Icons.pan_tool_alt_rounded,
        title: isEn ? '44 Chords' : '44 Hợp âm',
        subtitle: isEn ? 'Open • Barre • 7th' : 'Mở • Chặn • Power 5',
        accentColor: const Color(0xFFEA580C),
        isDark: isDark,
        onTap: () => showGuitarStudioSheet(
          context,
          initialTab: 1,
          singleTabMode: true,
        ),
      ),
      _CompactToolCard(
        key: const Key('topic_grid_card_guitar_scales_tool'),
        icon: Icons.timeline_rounded,
        title: isEn ? '7 Scales & Jam' : 'Scale & Jam',
        subtitle: isEn ? '12 Frets • Solo' : '12 Ngăn • Đệm Solo',
        accentColor: const Color(0xFF6366F1),
        isDark: isDark,
        onTap: () => showGuitarStudioSheet(
          context,
          initialTab: 2,
          singleTabMode: true,
        ),
      ),
      _CompactToolCard(
        key: const Key('topic_grid_card_guitar_spider'),
        icon: Icons.touch_app_rounded,
        title: isEn ? '12 Workouts' : 'Luyện ngón',
        subtitle: isEn ? 'Lv.1–5 • Tab (★)' : '12 Bài • Đọc Tab',
        accentColor: const Color(0xFF10B981),
        isDark: isDark,
        onTap: () => showGuitarFingerWorkoutPage(context),
      ),
      _CompactToolCard(
        key: const Key('topic_grid_card_chord_prog_ear'),
        icon: Icons.queue_music_rounded,
        title: isEn ? 'Chord Loops' : 'Dò Vòng Hợp Âm',
        subtitle: isEn ? 'I–V–vi–IV Ear' : 'Đệm hát I–V–vi–IV',
        accentColor: const Color(0xFF7C3AED),
        isDark: isDark,
        onTap: () => openChordProgressionEarScreen(context),
      ),
      _CompactToolCard(
        key: const Key('topic_grid_card_circle_capo'),
        icon: Icons.donut_large_rounded,
        title: isEn ? 'Circle & Capo' : 'Bậc 5 & Capo',
        subtitle: isEn ? 'Key & Transpose' : 'Dịch tông • Kẹp Capo',
        accentColor: const Color(0xFF0D9488),
        isDark: isDark,
        onTap: () => openCircleOfFifthsAndCapoScreen(context),
      ),
    ];
  }
}

class _CompactToolCard extends StatelessWidget {
  final IconData icon;
  final Widget? customIcon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  const _CompactToolCard({
    super.key,
    required this.icon,
    this.customIcon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: accentColor.withOpacity(isDark ? 0.30 : 0.22),
              width: 1.1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: customIcon ??
                    Icon(
                      icon,
                      color: accentColor,
                      size: 20,
                    ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
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

class _SongbookHeroCard extends StatelessWidget {
  final bool isDark;
  final bool isEn;
  final VoidCallback onTap;

  const _SongbookHeroCard({
    super.key,
    required this.isDark,
    required this.isEn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF312E81), Color(0xFF1E3A8A)]
                  : const [Color(0xFF4F46E5), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(isDark ? 0.30 : 0.22),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.28)),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.queue_music_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isEn ? '20 SONGS' : '20 BÀI MỚI',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E1B4B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isEn ? 'Classical & Modern' : 'Cổ điển • Hiện đại',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.86),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEn
                          ? 'Interactive Songbook Room'
                          : 'Kho Bản Nhạc & Phòng Chơi Đàn',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn
                          ? 'Pick a track, then play live on Guitar or Piano'
                          : 'Chọn bài trước • Vào phòng bấm đàn Guitar & Piano thật',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.86),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaSwitchButton extends StatelessWidget {
  final IconData icon;
  final Widget? customIcon;
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _AreaSwitchButton({
    super.key,
    required this.icon,
    this.customIcon,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? accentColor : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              customIcon ??
                  Icon(
                    icon,
                    size: 17,
                    color: isSelected ? Colors.white : accentColor,
                  ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : null,
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

/// Thẻ chủ đề lớn trên lưới 2 cột:
/// Hiển thị Logo/Icon lớn + Tên bài luyện tập + Phụ đề ngắn gọn 1 dòng để giao diện thoáng và trực quan.
class _BigTopicGridCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  const _BigTopicGridCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accentColor = AppColors.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 136,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 26,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet cho phép chọn Độ khó (Cấp độ) & Thời gian luyện tập (60s/15p Miễn phí, 1h dùng 50 Gem).
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
    final isEn = ref.watch(appSettingsProvider).isEnglish;

    final topicId = widget.topic.id;
    final isNotes = topicId == 'topic_notes';
    final isStaff = topicId == 'topic_staff_reading';

    final prefix = topicId.replaceFirst('topic_', 'lvl_');
    final otherLevels = [
      (
        '${prefix}_basic',
        isEn ? 'Level 1' : 'Mức 1',
        isEn ? 'Basic' : 'Cơ bản',
      ),
      (
        '${prefix}_inter',
        isEn ? 'Level 2' : 'Mức 2',
        isEn ? 'Inter' : 'Trung bình',
      ),
      (
        '${prefix}_adv',
        isEn ? 'Level 3' : 'Mức 3',
        isEn ? 'Advanced' : 'Nâng cao',
      ),
    ];
    final currentOtherLvl = _selectedOtherLevelId ?? otherLevels.first.$1;

    final durations = [
      (
        60,
        isEn ? '60s' : '60 giây',
        isEn ? 'Free' : 'Miễn phí',
        false,
      ),
      (
        900,
        isEn ? '15 min' : '15 phút',
        isEn ? 'Free' : 'Miễn phí',
        false,
      ),
      (
        3600,
        isEn ? '1 hour' : '1 tiếng',
        '${RewardedAdState.kOneHourPracticeGemCost} Gem',
        true,
      ),
      (
        0,
        isEn ? 'Unlimited' : 'Tự do',
        '${RewardedAdState.kUnlimitedPracticeGemCost} Gem',
        true,
      ),
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
                          TopicsScreen.shortTopicTitle(
                            widget.topic,
                            isEn: isEn,
                          ),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          TopicsScreen.shortTopicSubtitle(
                            widget.topic,
                            isEn: isEn,
                          ),
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

              // 1. Chọn chế độ khó / dễ (Cấp độ)
              Text(
                isEn
                    ? '1. Select Difficulty Level'
                    : '1. Chọn độ khó luyện tập',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
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
                            final keyPrefix =
                                isStaff ? 'topic_staff_lvl_' : 'topic_note_lvl_';
                            return _ModalOptionCard(
                              key: Key('$keyPrefix${item.$1}'),
                              title: isEn ? 'Level ${i + 1}' : item.$2,
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
                        key: const Key('chip_staff_mode_all'),
                        title: isEn
                            ? 'All Notes (Staff + Ledger)'
                            : 'Tất cả nốt (Khuông + Phụ)',
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
                        key: const Key('chip_staff_mode_ledger'),
                        title: isEn
                            ? 'Ledger Lines Focus'
                            : 'Chuyên luyện Dòng kẻ phụ',
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
              Text(
                isEn
                    ? '2. Select Practice Duration'
                    : '2. Chọn thời gian luyện tập',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
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
                        onTap: () {
                          ref
                              .read(selectedPracticeDurationProvider.notifier)
                              .state = durations[i].$1;
                          ref
                              .read(appSettingsProvider.notifier)
                              .setDefaultPracticeDuration(durations[i].$1);
                        },
                      ),
                    ),
                  ],
                ],
              ),

              if (selectedDuration == 3600 || selectedDuration == 0) ...[
                const SizedBox(height: 8),
                InkWell(
                  key: const Key('btn_setup_modal_watch_ad_gems'),
                  borderRadius: BorderRadius.circular(11),
                  onTap: () {
                    showRewardedVideoAdSimulationDialog(context, ref);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.play_circle_fill_rounded,
                          size: 16,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isEn
                                ? 'Need Gems for Unlimited / 1-Hour? Watch a short video for +100 Gems!'
                                : 'Cần thêm Gem mở gói Tự do / 1 tiếng? Xem video ngắn nhận ngay +100 Gem!',
                            style: const TextStyle(
                              fontSize: 11.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SolfaGemIcon(size: 14),
                        const SizedBox(width: 3),
                        const Text(
                          '+100',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

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
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  if (ok && context.mounted) {
                    context.push('/quiz');
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: Text(
                  selectedDuration == 3600
                      ? (isEn
                          ? 'Start Now (1 hour • ${RewardedAdState.kOneHourPracticeGemCost} Gems)'
                          : 'Bắt đầu ngay (1 tiếng • ${RewardedAdState.kOneHourPracticeGemCost} Gem)')
                      : selectedDuration == 0
                          ? (isEn
                              ? 'Start Now (Unlimited • ${RewardedAdState.kUnlimitedPracticeGemCost} Gems)'
                              : 'Bắt đầu ngay (Tự do • ${RewardedAdState.kUnlimitedPracticeGemCost} Gem)')
                          : (isEn
                              ? 'Start Now (${TopicsScreen.durationLabel(selectedDuration, isEn: true)} • Free)'
                              : 'Bắt đầu ngay (${TopicsScreen.durationLabel(selectedDuration)} • Miễn phí)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showGemBadge;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ModalOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.showGemBadge = false,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? AppColors.primary
        : (isDark
            ? Colors.white.withOpacity(0.05)
            : AppColors.backgroundLight);
    final fgColor = isSelected
        ? Colors.white
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final subColor = isSelected
        ? Colors.white.withOpacity(0.88)
        : (showGemBadge
            ? AppColors.primary
            : (isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight));

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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
                    color: fgColor,
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
                        fontWeight: FontWeight.w700,
                        color: subColor,
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
