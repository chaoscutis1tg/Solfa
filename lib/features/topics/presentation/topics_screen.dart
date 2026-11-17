import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_system/solfa_design_system.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../guitar/presentation/guitar_studio_sheet.dart';
import '../../practice/application/practice_session_controller.dart';
import '../../practice/presentation/widgets/free_piano_explorer_sheet.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';

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
        final totalItems = activeTopics.length + (isGuitarArea ? 2 : 1);
        final rowCount = (totalItems / 2).ceil();

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEn ? 'Practice Topics' : 'Chủ đề luyện tập',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SolfaTypography.heading,
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
                      ? showGuitarStudioSheet(context)
                      : showFreePianoExplorerSheet(context),
                  icon: Icon(
                    isGuitarArea
                        ? Icons.grid_on_rounded
                        : Icons.piano_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isGuitarArea
                        ? (isEn ? 'Fretboard Map' : 'Map Cần đàn')
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

            // Thanh chuyển đổi tách biệt rõ Khu vực Piano & Nhạc lý <-> Khu vực Guitar & Cần đàn
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
            const SizedBox(height: 14),

            for (int r = 0; r < rowCount; r++) ...[
              if (r > 0) const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildGridItem(
                      context,
                      ref,
                      activeTopics,
                      r * 2,
                      isGuitarArea,
                      isDark,
                      isEn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: (r * 2 + 1) < totalItems
                        ? _buildGridItem(
                            context,
                            ref,
                            activeTopics,
                            r * 2 + 1,
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

  Widget _buildGridItem(
    BuildContext context,
    WidgetRef ref,
    List<TopicModel> activeTopics,
    int index,
    bool isGuitarArea,
    bool isDark,
    bool isEn,
  ) {
    if (index < activeTopics.length) {
      final topic = activeTopics[index];
      return _BigTopicGridCard(
        key: Key('topic_grid_card_${topic.id}'),
        icon: topicIconForCode(topic.code),
        title: shortTopicTitle(topic, isEn: isEn),
        accentColor: isGuitarArea ? const Color(0xFFD97706) : AppColors.primary,
        isDark: isDark,
        onTap: () => showTopicPracticeSetupModal(context, ref, topic),
      );
    }

    if (isGuitarArea) {
      if (index == activeTopics.length) {
        return _BigTopicGridCard(
          key: const Key('topic_grid_card_guitar_studio'),
          icon: Icons.explore_rounded,
          title: isEn ? '6-String Fretboard' : 'Map Cần đàn 6 dây',
          accentColor: const Color(0xFFD97706),
          isDark: isDark,
          onTap: () => showGuitarStudioSheet(context, initialTab: 0),
        );
      }
      return _BigTopicGridCard(
        key: const Key('topic_grid_card_guitar_spider'),
        icon: Icons.touch_app_rounded,
        title: isEn ? 'Finger Workouts' : 'Luyện ngón 1-2-3-4',
        accentColor: const Color(0xFFD97706),
        isDark: isDark,
        onTap: () => showGuitarFingerWorkoutPage(context),
      );
    }

    // Thẻ thứ 8 trên lưới Piano & Nhạc lý: Tra cứu Đàn Piano & Khuông C3–C5
    return _BigTopicGridCard(
      key: const Key('topic_grid_card_free_piano'),
      icon: Icons.piano_rounded,
      title: isEn ? 'Piano C3–C5 Studio' : 'Đàn Piano C3–C5',
      accentColor: AppColors.primary,
      isDark: isDark,
      onTap: () => showFreePianoExplorerSheet(context),
    );
  }
}

class _AreaSwitchButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _AreaSwitchButton({
    super.key,
    required this.icon,
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
/// Chỉ hiển thị Logo/Icon lớn + Tên bài luyện tập để giao diện cực kỳ thoáng và trực quan.
class _BigTopicGridCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  const _BigTopicGridCard({
    super.key,
    required this.icon,
    required this.title,
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
          height: 132,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
