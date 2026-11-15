import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/pulsing_red_heart.dart';
import '../../../app/widgets/solfa_logo.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/note_formatter.dart';
import '../../practice/application/practice_session_controller.dart';
import '../../practice/presentation/widgets/free_piano_explorer_sheet.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';
import '../../topics/presentation/topics_screen.dart';

/// UI-02: Trang chủ (UC-01 & UC-02)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _startQuickPractice(
    BuildContext context,
    WidgetRef ref, {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(overallProgressProvider);
    final topicsAsync = ref.watch(topicsListProvider);
    final selectedDuration = ref.watch(selectedPracticeDurationProvider);
    final adState = ref.watch(rewardedAdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          // 1. Hero Quick Practice Banner (UC-02)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0D6EFD),
                  Color(0xFF084EB2),
                  Color(0xFF063782),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.26),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phòng luyện cảm âm nhanh',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Tính điểm Đúng / Sai trực tiếp • 100% Offline',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFFFD166),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    SolfaLogo(size: 40, showShadow: false),
                  ],
                ),
                const SizedBox(height: 12),
                // Quick Duration Mode Pills
                Row(
                  children: [
                    _HeroDurationChip(
                      label: '60 giây',
                      isSelected: selectedDuration == 60,
                      onTap: () => ref
                          .read(selectedPracticeDurationProvider.notifier)
                          .state = 60,
                    ),
                    const SizedBox(width: 6),
                    _HeroDurationChip(
                      label: '15 phút',
                      isSelected: selectedDuration == 900,
                      onTap: () => ref
                          .read(selectedPracticeDurationProvider.notifier)
                          .state = 900,
                    ),
                    const SizedBox(width: 6),
                    _HeroDurationChip(
                      label: '1 tiếng',
                      isSelected: selectedDuration == 3600,
                      onTap: () => ref
                          .read(selectedPracticeDurationProvider.notifier)
                          .state = 3600,
                    ),
                    const SizedBox(width: 6),
                    _HeroDurationChip(
                      label: 'Tự do',
                      isSelected: selectedDuration == 0,
                      onTap: () => ref
                          .read(selectedPracticeDurationProvider.notifier)
                          .state = 0,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        key: const Key('btn_quick_practice'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryDark,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        onPressed: () => _startQuickPractice(context, ref),
                        icon: const Icon(
                          Icons.play_circle_fill_rounded,
                          size: 20,
                          color: AppColors.accentAmber,
                        ),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Luyện tập ngay (${TopicsScreen.durationLabel(selectedDuration)})',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: OutlinedButton.icon(
                        key: const Key('btn_quick_staff_reading'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.14),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.45),
                          ),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        onPressed: () => _startQuickPractice(
                          context,
                          ref,
                          topicId: 'topic_staff_reading',
                        ),
                        icon: const Icon(
                          Icons.menu_book_rounded,
                          size: 18,
                          color: Color(0xFFFFD166),
                        ),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Đọc khuông 𝄞/𝄢'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Quick Utility Bento Row (Đàn Piano C3–C5 + Ôn câu sai)
          progressAsync.maybeWhen(
            data: (stats) => _buildUtilityRow(context, stats),
            orElse: () => _buildUtilityRow(context, null),
          ),
          const SizedBox(height: 14),

          // 3. Progress / First-Time Guidance Section (UC-01)
          progressAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Không thể tải thống kê: $e'),
              ),
            ),
            data: (stats) => _buildProgressSection(context, ref, stats),
          ),

          const SizedBox(height: 14),

          // 3b. Daily Quests Card (Nhận tối đa +100 Điểm Uy Tín / Ngày)
          _buildDailyQuestsCard(
            context,
            ref,
            progressAsync.valueOrNull,
            adState,
            isDark,
          ),

          const SizedBox(height: 14),

          // 4. Core Topics Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.headphones_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Chủ đề cốt lõi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 36),
                ),
                onPressed: () => context.go('/topics'),
                child: const Text(
                  'Vào phòng luyện',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          topicsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (topics) {
              final stats = progressAsync.valueOrNull;
              final enabledTopics = topics.where((t) => t.isEnabled).toList();
              return Column(
                children: List.generate(enabledTopics.length, (i) {
                  final topic = enabledTopics[i];
                  final topicAcc = stats?.topicStats
                      .where((s) => s.topicId == topic.id)
                      .firstOrNull;
                  final accent = AppColors.topicAccent(topic.code);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push('/topics/${topic.id}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _iconForTopic(topic.code),
                                      color: accent,
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
                                                topic.name,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            if (topicAcc != null &&
                                                topicAcc.totalAnswered > 0)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      accent.withOpacity(0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(99),
                                                ),
                                                child: Text(
                                                  '${topicAcc.accuracyPercent.toStringAsFixed(0)}%',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: accent,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          topic.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12.2,
                                            height: 1.28,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: accent,
                                  ),
                                ],
                              ),
                              if (topicAcc != null &&
                                  topicAcc.totalAnswered > 0) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    value: (topicAcc.accuracyPercent / 100.0)
                                        .clamp(0.0, 1.0),
                                    minHeight: 4,
                                    backgroundColor: accent.withOpacity(0.14),
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(accent),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF280D20).withOpacity(0.92),
                        const Color(0xFF120B28).withOpacity(0.92),
                      ]
                    : [
                        const Color(0xFFFFF0F3),
                        const Color(0xFFFFF8FA),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: kHeartRedColor.withOpacity(isDark ? 0.55 : 0.42),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push('/support-developer'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      const PulsingRedHeart(
                        size: 22,
                        showGlowBadge: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Ủng hộ nhà phát triển',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kHeartRedColor.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        adState.supportedCount > 0
                                            ? Icons.military_tech_rounded
                                            : Icons.favorite_rounded,
                                        size: 12,
                                        color: kHeartRedColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        adState.supportedCount > 0
                                            ? '${adState.prestigePoints} Uy tín'
                                            : '15s miễn phí',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: kHeartRedColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              adState.supportedCount > 0
                                  ? 'Huy hiệu: ${adState.supporterBadgeTitle} (${adState.supportedCount} tim đã trao)'
                                  : 'Tặng 1 trái tim đỏ qua video 15s để nhận Huy hiệu Tri Ân',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: kHeartRedColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyQuestsCard(
    BuildContext context,
    WidgetRef ref,
    OverallProgressStats? stats,
    RewardedAdState adState,
    bool isDark,
  ) {
    final todayAnswered = stats?.todayAnsweredCount ?? 0;
    final practiceReady = todayAnswered >= 10;
    final battleReady = adState.dailyBattlesPlayed >= 1;
    final dictationReady = adState.dailyDictationCompletedCount >= 1;

    return Card(
      key: const Key('card_daily_quests'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: AppColors.accentAmber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhiệm vụ Hàng ngày (+100 Điểm Uy Tín)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hoàn thành 3 nhiệm vụ ngày để đổi miễn phí +1 Lượt Đấu Trường',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${adState.claimedQuestsCountToday}/3',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildQuestRow(
              context: context,
              ref: ref,
              buttonKey: const Key('btn_claim_quest_practice'),
              icon: Icons.headphones_rounded,
              title: 'Khởi động Cảm Âm (${todayAnswered.clamp(0, 10)}/10 câu)',
              rewardPoints: 30,
              isReadyToClaim: practiceReady,
              isClaimed: adState.questPracticeClaimedToday,
              questCode: 'practice',
              onGoAction: () => _startQuickPractice(context, ref),
            ),
            const Divider(height: 12),
            _buildQuestRow(
              context: context,
              ref: ref,
              buttonKey: const Key('btn_claim_quest_battle'),
              icon: Icons.bolt_rounded,
              title:
                  'Chiến binh Đấu Trường (${adState.dailyBattlesPlayed.clamp(0, 1)}/1 trận)',
              rewardPoints: 40,
              isReadyToClaim: battleReady,
              isClaimed: adState.questBattleClaimedToday,
              questCode: 'battle',
              onGoAction: () => context.go('/battle'),
            ),
            const Divider(height: 12),
            _buildQuestRow(
              context: context,
              ref: ref,
              buttonKey: const Key('btn_claim_quest_dictation'),
              icon: Icons.piano_rounded,
              title:
                  'Chép Nhạc Giai Điệu (${adState.dailyDictationCompletedCount.clamp(0, 1)}/1 câu)',
              rewardPoints: 30,
              isReadyToClaim: dictationReady,
              isClaimed: adState.questDictationClaimedToday,
              questCode: 'dictation',
              onGoAction: () => showFreePianoExplorerSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestRow({
    required BuildContext context,
    required WidgetRef ref,
    required Key buttonKey,
    required IconData icon,
    required String title,
    required int rewardPoints,
    required bool isReadyToClaim,
    required bool isClaimed,
    required String questCode,
    required VoidCallback onGoAction,
  }) {
    return Row(
      children: [
        Icon(
          isClaimed ? Icons.check_circle_rounded : icon,
          size: 18,
          color: isClaimed
              ? AppColors.correct
              : (isReadyToClaim ? AppColors.accentAmber : AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
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
                ? AppColors.correct.withOpacity(0.12)
                : (isReadyToClaim
                    ? AppColors.correct
                    : AppColors.primary.withOpacity(0.12)),
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
                            'Đã nhận +$pts Điểm Uy Tín! Có thể dùng đổi Lượt Đấu Trường.',
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
                : (isReadyToClaim ? 'Nhận +$rewardPointsđ' : '+$rewardPointsđ • Làm ngay'),
            style: const TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUtilityRow(BuildContext context, OverallProgressStats? stats) {
    final pendingCount = stats?.pendingReviewCount ?? 0;

    return Row(
      children: [
        Expanded(
          child: Card(
            child: InkWell(
              key: const Key('btn_open_free_piano_explorer'),
              borderRadius: BorderRadius.circular(20),
              onTap: () => showFreePianoExplorerSheet(context),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF635BFF).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.piano_rounded,
                        color: Color(0xFF635BFF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đàn & Khuông',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tra cứu C3–C5 & Hợp âm',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/review'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: (pendingCount > 0
                                ? AppColors.wrong
                                : AppColors.correct)
                            .withOpacity(0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        pendingCount > 0
                            ? Icons.auto_fix_high_rounded
                            : Icons.verified_rounded,
                        color: pendingCount > 0
                            ? AppColors.wrong
                            : AppColors.correct,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ôn câu sai',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pendingCount > 0
                                ? '$pendingCount câu cần ôn'
                                : '0 câu tồn đọng',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: pendingCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: pendingCount > 0 ? AppColors.wrong : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection(
    BuildContext context,
    WidgetRef ref,
    OverallProgressStats stats,
  ) {
    if (!stats.hasAnyHistory) {
      // First-time user flow (UC-01 Alternative Flow)
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bắt đầu hành trình đầu tiên',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Gợi ý khởi động nhanh cho người mới:',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Bài "Nhận biết nốt (Cơ bản)" có nút nghe nốt Đô chuẩn (C4) và bàn phím đàn trực quan giúp bạn làm quen dễ dàng.',
                style: TextStyle(fontSize: 13, height: 1.38),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('btn_first_time_notes'),
                onPressed: () => _startQuickPractice(
                  context,
                  ref,
                  topicId: 'topic_notes',
                  levelId: 'lvl_notes_basic',
                ),
                icon: const Icon(Icons.music_note_rounded, size: 20),
                label: const Text(
                  'Học ngay: Nhận biết nốt (Cơ bản)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final latestSession =
        stats.recentSessions.isNotEmpty ? stats.recentSessions.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.query_stats_rounded, size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Tiến trình của bạn',
              style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatMiniCard(
                label: 'Chính xác',
                value: '${stats.overallAccuracyPercent.toStringAsFixed(0)}%',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.correct,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatMiniCard(
                label: 'Nốt đã nghe',
                value: '${stats.totalAnswered}',
                icon: Icons.quiz_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatMiniCard(
                label: 'Chuỗi ngày',
                value: '${stats.currentStreakDays} ngày',
                icon: Icons.local_fire_department_rounded,
                color: AppColors.accentAmber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          key: const Key('daily_goal_progress_card'),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showDailyGoalPicker(
              context,
              ref,
              stats.dailyGoalTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        stats.isDailyGoalReached
                            ? Icons.verified_rounded
                            : Icons.flag_circle_rounded,
                        color: stats.isDailyGoalReached
                            ? AppColors.correct
                            : AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          stats.isDailyGoalReached
                              ? 'Hoàn thành mục tiêu hôm nay (${stats.todayAnsweredCount}/${stats.dailyGoalTarget} nốt)!'
                              : 'Mục tiêu hôm nay: ${stats.todayAnsweredCount}/${stats.dailyGoalTarget} nốt',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (stats.bestScore > 0 || stats.bestComboStreak > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentAmber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.emoji_events_rounded,
                                size: 12,
                                color: AppColors.accentAmber,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${stats.bestScore}đ',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentAmber,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.local_fire_department_rounded,
                                size: 12,
                                color: AppColors.accentAmber,
                              ),
                              Text(
                                'x${stats.bestComboStreak}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentAmber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: stats.dailyGoalProgress,
                      minHeight: 6,
                      backgroundColor: AppColors.primary.withOpacity(0.14),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        stats.isDailyGoalReached
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
        if (latestSession != null) ...[
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.replay_rounded,
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
                              'Phiên gần nhất: ${latestSession.topicName ?? 'Luyện tập'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Đúng ${latestSession.correctCount}/${latestSession.totalQuestions} nốt • Điểm: ${latestSession.correctCount * 10} • ${NoteFormatter.formatDurationSeconds(latestSession.durationSeconds)}',
                              style: const TextStyle(fontSize: 12.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: () => _startQuickPractice(
                      context,
                      ref,
                      topicId: latestSession.topicId,
                      levelId: latestSession.levelId,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Tiếp tục chủ đề này'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showDailyGoalPicker(
    BuildContext context,
    WidgetRef ref,
    int currentGoal,
  ) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.flag_circle_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Đặt mục tiêu luyện tập hàng ngày',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chọn số câu/nốt nhạc bạn muốn hoàn thành mỗi ngày:',
                  style: TextStyle(fontSize: 12.8),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in const [
                      (10, '10 nốt/ngày (Khởi động)'),
                      (20, '20 nốt/ngày (Tiêu chuẩn)'),
                      (30, '30 nốt/ngày (Chăm chỉ)'),
                      (50, '50 nốt/ngày (Chuyên sâu)'),
                    ])
                      ChoiceChip(
                        key: Key('chip_daily_goal_${g.$1}'),
                        label: Text(g.$2),
                        selected: currentGoal == g.$1,
                        onSelected: (_) => Navigator.of(ctx).pop(g.$1),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null) {
      await ref.read(appSettingsProvider.notifier).setDailyGoalTarget(chosen);
      ref.invalidate(overallProgressProvider);
    }
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
        return Icons.queue_music_rounded;
    }
  }
}

class _HeroDurationChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _HeroDurationChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected
            ? const Color(0xFFFFD166)
            : Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 32,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? const Color(0xFF0A214A) : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
