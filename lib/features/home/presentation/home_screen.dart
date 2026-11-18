import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_system/solfa_design_system.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/crossed_swords_icon.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../app/widgets/solfa_guitar_icon.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../guitar/presentation/guitar_studio_sheet.dart';
import '../../practice/application/practice_session_controller.dart';
import '../../practice/presentation/widgets/free_piano_explorer_sheet.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';
import '../../topics/presentation/topics_screen.dart';

/// Màn hình Trang chủ tinh gọn 4 khối:
/// 1. Lời chào & Streak ngày
/// 2. Thẻ lớn Tiếp tục bài đang học (hoặc bắt đầu hành trình)
/// 3. Tiện ích nhanh (Đàn Piano C3–C5, Ôn câu sai, Đấu trường)
/// 4. Mục tiêu hôm nay (+20 Gem) & Nhiệm vụ hàng ngày
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _questsExpanded = true;

  Future<void> _startQuickPractice(
    BuildContext context, {
    String? topicId,
    String? levelId,
  }) async {
    final dur = ref.read(selectedPracticeDurationProvider);
    final canProceed = await checkAndSpendGemsForDurationIfNeeded(
      context,
      ref,
      durationSeconds: dur,
    );
    if (!canProceed || !context.mounted) return;

    final notifier = ref.read(practiceSessionProvider.notifier);
    final isTest = ref.read(audioServiceProvider).isTestMode;
    final selectedNoteLevel = ref.read(selectedNoteLevelIdProvider);
    final selectedStaffLevel = ref.read(selectedStaffLevelIdProvider);

    final ok = await notifier.startSession(
      mode: topicId != null ? 'topic' : 'quick',
      topicId: topicId,
      levelId: levelId ??
          ((topicId == null || topicId == 'topic_notes')
              ? selectedNoteLevel
              : (topicId == 'topic_staff_reading' ? selectedStaffLevel : null)),
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

  Future<void> _showDailyGoalPicker(
    BuildContext context,
    int currentTarget,
  ) async {
    const options = [10, 20, 30, 50];
    final picked = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn mục tiêu mỗi ngày',
                style: SolfaTypography.sectionTitle,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final target in options)
                    ChoiceChip(
                      label: Text('$target câu / ngày'),
                      selected: currentTarget == target,
                      onSelected: (_) => Navigator.of(ctx).pop(target),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      await ref.read(appSettingsProvider.notifier).setDailyGoalTarget(picked);
      ref.invalidate(overallProgressProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(overallProgressProvider);
    final adState = ref.watch(rewardedAdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = progressAsync.valueOrNull;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(overallProgressProvider);
        ref.invalidate(topicsListProvider);
        ref.invalidate(pendingReviewItemsProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: SolfaSpacing.screenPadding,
        children: [
          // KHỐI 1 – Lời chào ngắn & Streak ngày
          _buildGreetingHeader(stats, isDark),
          const SizedBox(height: SolfaSpacing.md),

          // KHỐI 2 – Thẻ lớn Tiếp tục bài đang học (Hành động chính duy nhất)
          progressAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => SolfaSurfaceCard(
              child: Text('Không thể tải tiến trình: $e'),
            ),
            data: (s) => _buildContinueLearningHero(context, s),
          ),
          const SizedBox(height: SolfaSpacing.md),

          // KHỐI 3 – Tiện ích nhanh (Đàn Piano C3–C5, Đàn Guitar, Ôn câu sai, Đấu trường)
          _buildUnifiedQuickAccessGroup(context, stats, isDark),
          const SizedBox(height: SolfaSpacing.md),

          // KHỐI 4 – Mục tiêu hôm nay (+20 Gem) & Nhiệm vụ ngày
          if (stats != null) ...[
            _buildTodayGoalSection(context, stats, adState, isDark),
            const SizedBox(height: SolfaSpacing.md),
          ],
          _buildDailyQuestsChecklist(context, stats, adState, isDark),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader(OverallProgressStats? stats, bool isDark) {
    final streak = stats?.currentStreakDays ?? 0;
    final goalMet = stats?.isDailyGoalReached ?? false;
    final isEn = ref.watch(appSettingsProvider).isEnglish;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn ? 'Daily Ear & Music Training' : 'Học cảm âm mỗi ngày',
                style: SolfaTypography.heading,
              ),
              const SizedBox(height: 2),
              Text(
                goalMet
                    ? (isEn
                        ? 'Daily goal completed!'
                        : 'Đã hoàn thành mục tiêu hôm nay')
                    : (isEn
                        ? 'Choose a lesson in Practice or continue below'
                        : 'Chọn bài học tại tab Luyện tập hoặc tiếp tục bên dưới'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withOpacity(isDark ? 0.06 : 1.0),
            borderRadius: BorderRadius.circular(SolfaRadius.pill),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: AppColors.accentAmber,
              ),
              const SizedBox(width: 4),
              Text(
                isEn ? '$streak days' : '$streak ngày',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContinueLearningHero(
    BuildContext context,
    OverallProgressStats stats,
  ) {
    final isEn = ref.watch(appSettingsProvider).isEnglish;
    if (!stats.hasAnyHistory || stats.recentSessions.isEmpty) {
      return SolfaSurfaceCard(
        isPrimaryHighlight: true,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(SolfaRadius.pill),
              ),
              child: Text(
                isEn ? 'GET STARTED' : 'KHỞI ĐỘNG',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isEn ? 'Start Your Musical Journey' : 'Bắt đầu hành trình đầu tiên',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isEn
                  ? 'Master the 7 basic notes (C–D–E–F–G–A–B) or pick any Piano & Guitar topic.'
                  : 'Làm quen 7 nốt nhạc cơ bản hoặc chọn chủ đề bất kỳ tại tab Luyện tập.',
              style: TextStyle(
                fontSize: 12.8,
                color: Colors.white.withOpacity(0.90),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('btn_first_time_notes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryDark,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => _startQuickPractice(
                      context,
                      topicId: 'topic_notes',
                      levelId: 'lvl_notes_basic',
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 19),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(isEn ? 'Pitch Practice' : 'Luyện nghe nốt'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('btn_quick_practice'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.16),
                      foregroundColor: Colors.white,
                      iconColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.85),
                        width: 1.3,
                      ),
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => context.go('/topics'),
                    icon: const Icon(
                      Icons.grid_view_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isEn ? 'Practice Now' : 'Luyện tập ngay',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final recent = stats.recentSessions.first;
    final progressRatio = recent.totalQuestions > 0
        ? (recent.correctCount / recent.totalQuestions).clamp(0.0, 1.0)
        : 0.0;

    return SolfaSurfaceCard(
      isPrimaryHighlight: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(SolfaRadius.pill),
                ),
                child: Text(
                  isEn ? 'CONTINUE LESSON' : 'TIẾP TỤC BÀI HỌC',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isEn
                      ? 'Correct ${recent.correctCount}/${recent.totalQuestions}'
                      : 'Đúng ${recent.correctCount}/${recent.totalQuestions} câu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.92),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppLocale.localizeTopicName(
              recent.topicId,
              recent.topicName ?? 'Luyện nghe nốt',
              isEn,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            AppLocale.localizeLevelName(
              recent.levelId ?? 'level_notes_basic',
              recent.levelName ?? 'Cơ bản',
              isEn,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.8,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(SolfaRadius.pill),
            child: LinearProgressIndicator(
              value: progressRatio,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.20),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('btn_quick_practice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: () => _startQuickPractice(
                    context,
                    topicId: recent.topicId,
                    levelId: recent.levelId,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 19),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(isEn ? 'Practice Now' : 'Luyện tập ngay'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.16),
                  foregroundColor: Colors.white,
                  iconColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.85),
                    width: 1.3,
                  ),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () => context.go('/topics'),
                icon: const Icon(
                  Icons.grid_view_rounded,
                  size: 17,
                  color: Colors.white,
                ),
                label: Text(
                  isEn ? 'Topics' : 'Đổi bài',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedQuickAccessGroup(
    BuildContext context,
    OverallProgressStats? stats,
    bool isDark,
  ) {
    final pendingCount = stats?.pendingReviewCount ?? 0;
    final dividerColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final isEn = ref.watch(appSettingsProvider).isEnglish;

    return SolfaSurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _QuickAccessItem(
                key: const Key('btn_open_free_piano_explorer'),
                icon: Icons.piano_rounded,
                title: isEn ? 'Piano' : 'Đàn Piano',
                subtitle: isEn ? 'Staff C3–C5' : 'Khuông C3–C5',
                onTap: () => showFreePianoExplorerSheet(context),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: dividerColor),
            Expanded(
              child: _QuickAccessItem(
                key: const Key('btn_open_guitar_studio'),
                customIcon: const SolfaGuitarIcon(
                  size: 22,
                  color: Color(0xFFD97706),
                ),
                icon: Icons.grid_on_rounded,
                title: isEn ? 'Guitar' : 'Đàn Guitar',
                subtitle: 'Map & Tab',
                accentColor: const Color(0xFFD97706),
                onTap: () => showGuitarStudioSheet(context),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: dividerColor),
            Expanded(
              child: _QuickAccessItem(
                icon: Icons.replay_rounded,
                title: isEn ? 'Review' : 'Ôn câu sai',
                subtitle: pendingCount > 0
                    ? (isEn ? '$pendingCount left' : '$pendingCount câu')
                    : (isEn ? 'All clear' : 'Thuộc hết'),
                accentColor: pendingCount > 0 ? AppColors.wrong : null,
                onTap: () => context.push('/review'),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: dividerColor),
            Expanded(
              child: _QuickAccessItem(
                key: const Key('btn_home_open_battle'),
                customIcon: const CrossedSwordsIcon(
                  size: 21,
                  color: AppColors.primary,
                  guardColor: AppColors.primary,
                ),
                icon: Icons.sports_mma_rounded,
                title: isEn ? 'Arena' : 'Đấu trường',
                subtitle: isEn ? '1v1 Match' : 'So tài 1v1',
                onTap: () => context.push('/battle'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayGoalSection(
    BuildContext context,
    OverallProgressStats stats,
    RewardedAdState adState,
    bool isDark,
  ) {
    final canClaimGoalGem =
        stats.isDailyGoalReached && !adState.dailyGoalGemClaimedToday;
    final isEn = ref.watch(appSettingsProvider).isEnglish;

    return SolfaSurfaceCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                stats.isDailyGoalReached
                    ? Icons.check_circle_rounded
                    : Icons.flag_outlined,
                size: 18,
                color: stats.isDailyGoalReached
                    ? AppColors.correct
                    : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isEn
                        ? 'Today\'s Goal: ${stats.todayAnsweredCount}/${stats.dailyGoalTarget}'
                        : 'Mục tiêu hôm nay: ${stats.todayAnsweredCount}/${stats.dailyGoalTarget} câu',
                    maxLines: 1,
                    style: SolfaTypography.cardTitle,
                  ),
                ),
              ),
              if (canClaimGoalGem)
                TextButton.icon(
                  key: const Key('btn_claim_daily_goal_gem'),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.correct,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () async {
                    final isTest = ref.read(audioServiceProvider).isTestMode;
                    final bonus = await ref
                        .read(rewardedAdProvider.notifier)
                        .awardDailyGoalBonusIfEligible();
                    if (bonus > 0 && context.mounted) {
                      showGemRewardAnimation(
                        context,
                        gemsAdded: bonus,
                        subtitle: isEn
                            ? 'Daily goal completed!'
                            : 'Hoàn thành mục tiêu hôm nay!',
                        isTestMode: isTest,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.correct,
                          content: Text(
                            isEn
                                ? 'Congratulations! You earned +$bonus Gems for reaching today\'s goal.'
                                : 'Chúc mừng! Bạn vừa nhận +$bonus Gem hoàn thành mục tiêu hôm nay.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const SolfaGemIcon(size: 13),
                  label: Text(
                    isEn ? 'Claim +20 Gems' : 'Nhận +20 Gem',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                TextButton(
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () =>
                      _showDailyGoalPicker(context, stats.dailyGoalTarget),
                  child: Text(
                    isEn ? 'Change' : 'Đổi mục tiêu',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(SolfaRadius.pill),
            child: LinearProgressIndicator(
              value: stats.dailyGoalProgress,
              minHeight: 7,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                stats.isDailyGoalReached
                    ? AppColors.correct
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyQuestsChecklist(
    BuildContext context,
    OverallProgressStats? stats,
    RewardedAdState adState,
    bool isDark,
  ) {
    final todayAnswered = stats?.todayAnsweredCount ?? 0;
    final practiceReady = todayAnswered >= 10;
    final battleReady = adState.dailyBattlesPlayed >= 1;
    final dictationReady = adState.dailyDictationCompletedCount >= 1;
    final isEn = ref.watch(appSettingsProvider).isEnglish;

    return SolfaSurfaceCard(
      key: const Key('card_daily_quests'),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(SolfaRadius.sm),
            onTap: () => setState(() => _questsExpanded = !_questsExpanded),
            child: Row(
              children: [
                const Icon(
                  Icons.checklist_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEn ? 'Daily Quests' : 'Nhiệm vụ hàng ngày',
                    style: SolfaTypography.cardTitle,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(SolfaRadius.pill),
                  ),
                  child: Text(
                    isEn
                        ? '${adState.claimedQuestsCountToday}/3 done'
                        : '${adState.claimedQuestsCountToday}/3 hoàn thành',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _questsExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                ),
              ],
            ),
          ),
          if (_questsExpanded) ...[
            const SizedBox(height: 10),
            _buildQuestChecklistItem(
              context: context,
              buttonKey: const Key('btn_claim_quest_practice'),
              title: isEn
                  ? 'Practice 10 questions'
                  : 'Luyện cảm âm 10 câu',
              progressText: '${todayAnswered.clamp(0, 10)}/10',
              rewardPoints: 30,
              isReadyToClaim: practiceReady,
              isClaimed: adState.questPracticeClaimedToday,
              questCode: 'practice',
              onGoAction: () => context.go('/topics'),
            ),
            const Divider(height: 14),
            _buildQuestChecklistItem(
              context: context,
              buttonKey: const Key('btn_claim_quest_battle'),
              title: isEn
                  ? 'Play 1 Arena match'
                  : 'Đấu 1 trận Đấu Trường',
              progressText: '${adState.dailyBattlesPlayed.clamp(0, 1)}/1',
              rewardPoints: 40,
              isReadyToClaim: battleReady,
              isClaimed: adState.questBattleClaimedToday,
              questCode: 'battle',
              onGoAction: () => context.push('/battle'),
            ),
            const Divider(height: 14),
            _buildQuestChecklistItem(
              context: context,
              buttonKey: const Key('btn_claim_quest_dictation'),
              title: isEn
                  ? 'Complete 1 dictation'
                  : 'Chép nhạc 1 giai điệu',
              progressText:
                  '${adState.dailyDictationCompletedCount.clamp(0, 1)}/1',
              rewardPoints: 30,
              isReadyToClaim: dictationReady,
              isClaimed: adState.questDictationClaimedToday,
              questCode: 'dictation',
              onGoAction: () => showFreePianoExplorerSheet(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestChecklistItem({
    required BuildContext context,
    required Key buttonKey,
    required String title,
    required String progressText,
    required int rewardPoints,
    required bool isReadyToClaim,
    required bool isClaimed,
    required String questCode,
    required VoidCallback onGoAction,
  }) {
    return Row(
      children: [
        Icon(
          isClaimed
              ? Icons.check_circle_rounded
              : (isReadyToClaim
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded),
          size: 18,
          color: isClaimed
              ? AppColors.correct
              : (isReadyToClaim ? AppColors.primary : Colors.grey),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$title ($progressText)',
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: isClaimed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          key: buttonKey,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: isClaimed
                ? AppColors.correct.withOpacity(0.10)
                : (isReadyToClaim
                    ? AppColors.correct
                    : AppColors.primary.withOpacity(0.10)),
            foregroundColor: isClaimed
                ? AppColors.correct
                : (isReadyToClaim ? Colors.white : AppColors.primary),
          ),
          onPressed: isClaimed
              ? null
              : () async {
                  if (isReadyToClaim) {
                    final isTest = ref.read(audioServiceProvider).isTestMode;
                    final pts = await ref
                        .read(rewardedAdProvider.notifier)
                        .claimDailyQuest(questCode);
                    if (pts > 0 && context.mounted) {
                      showGemRewardAnimation(
                        context,
                        gemsAdded: pts,
                        subtitle: 'Hoàn thành nhiệm vụ hàng ngày',
                        isTestMode: isTest,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.correct,
                          content: Text('Đã nhận +$pts Gem!'),
                        ),
                      );
                    }
                  } else {
                    onGoAction();
                  }
                },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SolfaGemIcon(size: 12.5),
              const SizedBox(width: 4),
              Text(
                isClaimed
                    ? 'Đã nhận +$rewardPoints'
                    : (isReadyToClaim
                        ? 'Nhận +$rewardPoints'
                        : '+$rewardPoints'),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAccessItem extends StatelessWidget {
  final IconData icon;
  final Widget? customIcon;
  final String title;
  final String subtitle;
  final Color? accentColor;
  final VoidCallback onTap;

  const _QuickAccessItem({
    super.key,
    required this.icon,
    this.customIcon,
    required this.title,
    required this.subtitle,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = accentColor ?? AppColors.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(SolfaRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            customIcon ?? Icon(icon, size: 22, color: effectiveColor),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      accentColor != null ? FontWeight.w700 : FontWeight.w500,
                  color: accentColor ??
                      Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
