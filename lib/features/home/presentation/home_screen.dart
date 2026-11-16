import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_system/solfa_design_system.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../practice/application/practice_session_controller.dart';
import '../../practice/presentation/widgets/free_piano_explorer_sheet.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';
import '../../topics/presentation/topics_screen.dart';

/// UI-02: Trang chủ (Redesigned per Section 3.2 — Simplicity First & Clear Hierarchy)
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
    final notifier = ref.read(practiceSessionProvider.notifier);
    final isTest = ref.read(audioServiceProvider).isTestMode;
    final dur = ref.read(selectedPracticeDurationProvider);
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
                'Chọn mục tiêu luyện tập mỗi ngày',
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
    final topicsAsync = ref.watch(topicsListProvider);
    final selectedDuration = ref.watch(selectedPracticeDurationProvider);
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
          // KHU VỰC 1 – Chào mừng và trạng thái học tập
          _buildGreetingHeader(stats, isDark),
          const SizedBox(height: SolfaSpacing.md),

          // KHU VỰC 2 – Tiếp tục học (Khu vực nổi bật nhất)
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
            data: (s) => _buildContinueLearningHero(context, s, isDark),
          ),
          const SizedBox(height: SolfaSpacing.lg),

          // KHU VỰC 3 – Bắt đầu luyện tập (Chọn thời lượng & Nút chính)
          _buildQuickPracticeSection(context, selectedDuration, isDark),
          const SizedBox(height: SolfaSpacing.lg),

          // KHU VỰC 4 – Truy cập nhanh (1 nhóm tiện ích thống nhất)
          _buildUnifiedQuickAccessGroup(context, stats, isDark),
          const SizedBox(height: SolfaSpacing.lg),

          // KHU VỰC 5 – Mục tiêu hôm nay (Tối giản: Số câu đã hoàn thành / Mục tiêu + Thanh tiến trình)
          if (stats != null) ...[
            _buildTodayGoalSection(context, stats, isDark),
            const SizedBox(height: SolfaSpacing.lg),
          ],

          // KHU VỰC 6 – Nhiệm vụ hàng ngày (Danh sách Checklist có thể thu gọn)
          _buildDailyQuestsChecklist(context, stats, adState, isDark),
          const SizedBox(height: SolfaSpacing.lg),

          // KHU VỰC 7 – Chủ đề học tập (Danh sách 7 chủ đề tối giản)
          SolfaSectionHeader(
            title: 'Chủ đề học tập',
            actionLabel: 'Xem tất cả',
            onActionTap: () => context.go('/topics'),
          ),
          topicsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (topics) => _buildMinimalistTopicsList(
              context,
              topics.where((t) => t.isEnabled).toList(),
              stats,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  /// Khu vực 1: Lời chào ngắn, trạng thái học tập và Streak tinh gọn.
  Widget _buildGreetingHeader(OverallProgressStats? stats, bool isDark) {
    final streak = stats?.currentStreakDays ?? 0;
    final goalMet = stats?.isDailyGoalReached ?? false;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Học cảm âm mỗi ngày',
                style: SolfaTypography.heading,
              ),
              const SizedBox(height: 2),
              Text(
                goalMet
                    ? 'Bạn đã hoàn thành mục tiêu hôm nay'
                    : 'Dành 5 phút rèn luyện đôi tai âm nhạc của bạn',
                style: TextStyle(
                  fontSize: 12.8,
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
                '$streak ngày',
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

  /// Khu vực 2: Tiếp tục học (Khu vực nổi bật nhất trên Trang chủ).
  Widget _buildContinueLearningHero(
    BuildContext context,
    OverallProgressStats stats,
    bool isDark,
  ) {
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
              child: const Text(
                'KHỞI ĐỘNG ĐẦU TIÊN',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Bắt đầu hành trình đầu tiên',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Làm quen 7 nốt tự nhiên (Đô – Si) với âm thanh chuẩn phòng thu 44.1kHz.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.90),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              key: const Key('btn_first_time_notes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
                minimumSize: const Size(double.infinity, 46),
              ),
              onPressed: () => _startQuickPractice(
                context,
                topicId: 'topic_notes',
                levelId: 'lvl_notes_basic',
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text(
                'Tiếp tục học: Nhận biết nốt (Cơ bản)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
                child: const Text(
                  'TIẾP TỤC HỌC',
                  style: TextStyle(
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
                  'Đúng ${recent.correctCount}/${recent.totalQuestions} câu',
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
            recent.topicName ?? 'Nhận biết nốt',
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
            'Cấp độ hiện tại: ${recent.levelName ?? 'Cơ bản'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDark,
              minimumSize: const Size(double.infinity, 46),
            ),
            onPressed: () => _startQuickPractice(
              context,
              topicId: recent.topicId,
              levelId: recent.levelId,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Tiếp tục học'),
          ),
        ],
      ),
    );
  }

  /// Khu vực 3: Bắt đầu luyện tập (Chọn thời lượng 60s / 15p / 1h / Tự do & Nút bắt đầu).
  Widget _buildQuickPracticeSection(
    BuildContext context,
    int selectedDuration,
    bool isDark,
  ) {
    const durations = [
      (60, '60 giây'),
      (900, '15 phút'),
      (3600, '1 tiếng'),
      (0, 'Tự do'),
    ];

    return SolfaSurfaceCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Luyện tập nhanh theo thời gian',
            style: SolfaTypography.cardTitle,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 0; i < durations.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _DurationSegmentPill(
                    label: durations[i].$2,
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
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('btn_quick_practice'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              side: const BorderSide(color: AppColors.primary, width: 1.3),
              foregroundColor:
                  isDark ? AppColors.textPrimaryDark : AppColors.primary,
            ),
            onPressed: () => _startQuickPractice(context),
            icon: const Icon(Icons.headphones_rounded, size: 19),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Bắt đầu luyện tập • Luyện tập ngay (${TopicsScreen.durationLabel(selectedDuration)})',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Khu vực 4: Truy cập nhanh (Đàn Piano, Đọc khuông nhạc, Ôn câu sai trong 1 nhóm thống nhất).
  Widget _buildUnifiedQuickAccessGroup(
    BuildContext context,
    OverallProgressStats? stats,
    bool isDark,
  ) {
    final pendingCount = stats?.pendingReviewCount ?? 0;
    final dividerColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return SolfaSurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _QuickAccessItem(
                key: const Key('btn_open_free_piano_explorer'),
                icon: Icons.piano_rounded,
                title: 'Đàn Piano',
                subtitle: 'Khuông C3–C5',
                onTap: () => showFreePianoExplorerSheet(context),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: dividerColor),
            Expanded(
              child: _QuickAccessItem(
                key: const Key('btn_quick_staff_reading'),
                icon: Icons.menu_book_rounded,
                title: 'Đọc khuông',
                subtitle: 'Khóa Sol & Fa',
                onTap: () => _startQuickPractice(
                  context,
                  topicId: 'topic_staff_reading',
                ),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: dividerColor),
            Expanded(
              child: _QuickAccessItem(
                icon: Icons.replay_rounded,
                title: 'Ôn câu sai',
                subtitle:
                    pendingCount > 0 ? '$pendingCount câu cần ôn' : 'Đã thuộc hết',
                accentColor: pendingCount > 0 ? AppColors.wrong : null,
                onTap: () => context.push('/review'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Khu vực 5: Mục tiêu hôm nay (Chỉ hiển thị số câu đã hoàn thành / mục tiêu + thanh tiến trình).
  Widget _buildTodayGoalSection(
    BuildContext context,
    OverallProgressStats stats,
    bool isDark,
  ) {
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
                child: Text(
                  'Mục tiêu hôm nay: ${stats.todayAnsweredCount} / ${stats.dailyGoalTarget} câu',
                  style: SolfaTypography.cardTitle,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () =>
                    _showDailyGoalPicker(context, stats.dailyGoalTarget),
                child: const Text(
                  'Đổi mục tiêu',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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

  /// Khu vực 6: Nhiệm vụ hàng ngày (Checklist có thể thu gọn trong 1 Card duy nhất).
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
                const Expanded(
                  child: Text(
                    'Nhiệm vụ hàng ngày',
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
                    '${adState.claimedQuestsCountToday}/3 hoàn thành',
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
              title: 'Luyện cảm âm 10 câu',
              progressText: '${todayAnswered.clamp(0, 10)}/10',
              rewardPoints: 30,
              isReadyToClaim: practiceReady,
              isClaimed: adState.questPracticeClaimedToday,
              questCode: 'practice',
              onGoAction: () => _startQuickPractice(context),
            ),
            const Divider(height: 14),
            _buildQuestChecklistItem(
              context: context,
              buttonKey: const Key('btn_claim_quest_battle'),
              title: 'Thi đấu 1 trận Đấu Trường',
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
              title: 'Chép nhạc 1 câu giai điệu',
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
          child: Text(
            '$title ($progressText)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: isClaimed ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          key: buttonKey,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: isClaimed
                ? Colors.transparent
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
                    final pts = await ref
                        .read(rewardedAdProvider.notifier)
                        .claimDailyQuest(questCode);
                    if (pts > 0 && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.correct,
                          content: Text(
                            'Đã nhận +$pts Điểm Uy Tín!',
                          ),
                        ),
                      );
                    }
                  } else {
                    onGoAction();
                  }
                },
          child: Text(
            isClaimed
                ? 'Đã nhận +$rewardPointsđ'
                : (isReadyToClaim ? 'Nhận +$rewardPointsđ' : '+$rewardPointsđ'),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  /// Khu vực 7: Danh sách 7 chủ đề tối giản (Icon, Tên, Số cấp độ, Trạng thái).
  Widget _buildMinimalistTopicsList(
    BuildContext context,
    List<TopicModel> topics,
    OverallProgressStats? stats,
    bool isDark,
  ) {
    final dividerColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return SolfaSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < topics.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: dividerColor),
            Builder(
              builder: (context) {
                final topic = topics[i];
                final topicStat = stats?.topicStats
                    .where((s) => s.topicId == topic.id)
                    .firstOrNull;
                final totalAnswered = topicStat?.totalAnswered ?? 0;
                final completedSessions = topicStat?.completedSessions ?? 0;
                final levelCount = (topic.id == 'topic_notes' ||
                        topic.id == 'topic_staff_reading')
                    ? 4
                    : 3;
                final statusLabel = completedSessions >= levelCount
                    ? 'Hoàn thành'
                    : (totalAnswered > 0 ? 'Đang học' : 'Sẵn sàng');
                final statusColor = completedSessions >= levelCount
                    ? AppColors.correct
                    : (totalAnswered > 0
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight));

                return InkWell(
                  borderRadius: BorderRadius.vertical(
                    top: i == 0 ? const Radius.circular(SolfaRadius.lg) : Radius.zero,
                    bottom: i == topics.length - 1
                        ? const Radius.circular(SolfaRadius.lg)
                        : Radius.zero,
                  ),
                  onTap: () => context.push('/topics/${topic.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _iconForTopic(topic.code),
                            color: AppColors.primary,
                            size: 20,
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
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$levelCount cấp độ',
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
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForTopic(String code) {
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
        return Icons.music_note_rounded;
    }
  }
}

class _DurationSegmentPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _DurationSegmentPill({
    required this.label,
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
      borderRadius: BorderRadius.circular(SolfaRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(SolfaRadius.sm),
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
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

class _QuickAccessItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accentColor;
  final VoidCallback onTap;

  const _QuickAccessItem({
    super.key,
    required this.icon,
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
            Icon(icon, size: 22, color: effectiveColor),
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
