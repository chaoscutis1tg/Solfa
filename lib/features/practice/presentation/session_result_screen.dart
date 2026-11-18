import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/pulsing_red_heart.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../app/widgets/solfa_logo.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/note_formatter.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';
import '../../support_developer/presentation/support_developer_screen.dart';
import '../application/practice_session_controller.dart';

/// UI-07: Kết quả & Bảng điểm phiên luyện tập (UC-11)
/// Thiết kế gọn trong 1 màn hình, lưới thông số 2x2 rõ ràng, không bị cắt mép trên.
class SessionResultScreen extends ConsumerStatefulWidget {
  const SessionResultScreen({super.key});

  @override
  ConsumerState<SessionResultScreen> createState() =>
      _SessionResultScreenState();
}

class _SessionResultScreenState extends ConsumerState<SessionResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(audioServiceProvider).playSessionCompleteFanfare();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(practiceSessionProvider);
    final progressAsync = ref.watch(overallProgressProvider);
    final adState = ref.watch(rewardedAdProvider);
    final completedSessions =
        progressAsync.valueOrNull?.completedSessionsCount ?? 0;
    final isMilestoneNudge =
        (completedSessions > 0 && completedSessions % 3 == 0) ||
            adState.supportedCount == 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accuracy = state.accuracyPercent;
    final isHighAccuracy = accuracy >= 70.0;
    final starCount = accuracy >= 90
        ? 3
        : accuracy >= 70
            ? 2
            : accuracy >= 40
                ? 1
                : 0;

    final accentColor = isHighAccuracy ? AppColors.correct : AppColors.primary;
    final cardSurfaceColor = isDark
        ? AppColors.surfaceDark.withOpacity(0.92)
        : Colors.white.withOpacity(0.95);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
      child: SolfaBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: const Text('Bảng điểm phiên luyện tập'),
            actions: [
              IconButton(
                key: const Key('btn_share_achievement_card'),
                tooltip: 'Thẻ Vinh Danh Thành Tích',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () => _showAchievementShareDialog(
                  context,
                  scorePoints: state.scorePoints,
                  accuracy: accuracy,
                  maxCombo: state.maxComboInSession,
                  starCount: starCount,
                  streakDays:
                      progressAsync.valueOrNull?.currentStreakDays ?? 1,
                ),
              ),
            ],
          ),
        body: SafeArea(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            children: [
              // 1. Main Scoreboard Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Bar: Mode Pill + Star Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Chế độ: ${state.timeModeLabel}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(3, (index) {
                              final earned = index < starCount;
                              return Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Icon(
                                  earned
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 24,
                                  color: earned
                                      ? AppColors.warning
                                      : Colors.grey.withOpacity(0.35),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Hero Row: Circular Accuracy Gauge (Left) + Total Score & Feedback (Right)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 106,
                            height: 106,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: CircularProgressIndicator(
                                    value: (accuracy / 100.0).clamp(0.0, 1.0),
                                    strokeWidth: 9,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor:
                                        accentColor.withOpacity(0.14),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      accentColor,
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${accuracy.toStringAsFixed(0)}%',
                                      key: const Key('result_accuracy_text'),
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: accentColor,
                                        height: 1.05,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Chính xác',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.accentAmber.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.accentAmber
                                          .withOpacity(0.45),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.emoji_events_rounded,
                                        color: AppColors.accentAmber,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          state.isNewHighScore
                                              ? '${state.scorePoints} ĐIỂM (KỶ LỤC MỚI!)'
                                              : '${state.scorePoints} ĐIỂM',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.accentAmber,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (state.maxComboInSession > 0 ||
                                    (progressAsync.valueOrNull?.bestScore ??
                                            0) >
                                        0) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          'Combo phiên: x${state.maxComboInSession} • Kỷ lục: ${progressAsync.valueOrNull?.bestScore ?? state.scorePoints} điểm',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11.8,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  state.encouragingFeedback,
                                  style: const TextStyle(
                                    fontSize: 13.2,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // 2x2 Wide Metric Grid (Spacious, never clips text like '48 giây')
                      Row(
                        children: [
                          Expanded(
                            child: _ResultMetricTile(
                              label: 'Nốt đúng',
                              value: '${state.correctCount} nốt',
                              icon: Icons.check_circle_rounded,
                              color: AppColors.correct,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ResultMetricTile(
                              label: 'Nốt sai',
                              value: '${state.wrongCount} nốt',
                              icon: Icons.cancel_rounded,
                              color: AppColors.wrong,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _ResultMetricTile(
                              label: 'Điểm đạt',
                              value: '+${state.scorePoints} điểm',
                              icon: Icons.stars_rounded,
                              color: AppColors.accentAmber,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ResultMetricTile(
                              label: 'Thời gian',
                              value: NoteFormatter.formatDurationSeconds(
                                state.activeDurationSeconds,
                              ),
                              icon: Icons.timer_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 1b. Instant Daily Quest Reward Card (+30 Prestige Points if >= 10 questions answered today)
              if ((progressAsync.valueOrNull?.todayAnsweredCount ?? 0) >= 10 &&
                  !adState.questPracticeClaimedToday) ...[
                Container(
                  key: const Key('card_result_claim_quest_practice'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.correct.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.correct.withOpacity(0.5),
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.task_alt_rounded,
                        color: AppColors.correct,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hoàn thành Nhiệm vụ Khởi động Cảm Âm!',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.correct,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Nhận ngay +30 Gem để tích lũy đổi Lượt Đấu Trường & gói 1 tiếng',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        key: const Key('btn_result_claim_quest_practice'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.correct,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () async {
                          final pts = await ref
                              .read(rewardedAdProvider.notifier)
                              .claimDailyQuest('practice');
                          if (pts > 0 && context.mounted) {
                            showGemRewardAnimation(
                              context,
                              gemsAdded: pts,
                              subtitle: 'Nhiệm vụ Khởi động Cảm Âm',
                              isTestMode:
                                  ref.read(audioServiceProvider).isTestMode,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.correct,
                                content: Text(
                                  'Đã nhận +$pts Gem từ nhiệm vụ Khởi động Cảm Âm!',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const SolfaGemIcon(size: 13),
                        label: const Text(
                          'Nhận +30 Gem',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 2. Primary Action: Retry Session
              ElevatedButton.icon(
                key: const Key('btn_retry_session'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () async {
                  final ok = await ref
                      .read(practiceSessionProvider.notifier)
                      .startSession(
                        mode: state.mode,
                        topicId: state.topicId,
                        levelId: state.levelId,
                        targetCount: state.totalQuestions > 0
                            ? state.totalQuestions
                            : 10,
                        timeLimitSeconds: state.timeLimitSeconds,
                        isUnlimitedMode: state.isUnlimitedMode,
                      );
                  if (ok && context.mounted) {
                    context.pushReplacement('/quiz');
                  }
                },
                icon: const Icon(Icons.replay_rounded, size: 20),
                label: const Text('Luyện lại phiên này'),
              ),

              // 3. Review Wrong Notes Button (High-contrast solid surface)
              if (state.wrongCount > 0) ...[
                const SizedBox(height: 8),
                Material(
                  color: cardSurfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    key: const Key('btn_review_wrong_from_result'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.pushReplacement('/review'),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.wrong.withOpacity(0.45),
                          width: 1.4,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.auto_fix_high_rounded,
                            color: AppColors.wrong,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Ôn nốt sai (${state.wrongCount} nốt vừa sai)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: AppColors.wrong,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // 4. Side-by-Side Secondary Navigation Row (Phòng luyện tập & Về trang chủ)
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: cardSurfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.go('/topics'),
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.32),
                              width: 1.2,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.library_music_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Phòng luyện tập',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
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
                    child: Material(
                      color: cardSurfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: const Key('btn_back_home'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.go('/home'),
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.32),
                              width: 1.2,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.home_outlined,
                                size: 19,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Về trang chủ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 5. Rewarded Video Ad Card (+100 Gem for Unlimited / 1-Hour / VIP Guitar / Battle Arena)
              Container(
                key: const Key('card_result_rewarded_ad'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF280D20).withOpacity(0.92),
                            const Color(0xFF130B29).withOpacity(0.92),
                          ]
                        : [
                            const Color(0xFFFFF0F3),
                            const Color(0xFFFFF8FA),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: kHeartRedColor.withOpacity(isDark ? 0.55 : 0.42),
                    width: 1.4,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('btn_result_watch_ad_100_gems'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => showRewardedVideoAdSimulationDialog(context, ref),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const PulsingRedHeart(
                            size: 20,
                            showGlowBadge: true,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMilestoneNudge && completedSessions > 0
                                      ? 'Cột mốc $completedSessions phiên học! Xem video nhận +100 Gem'
                                      : 'Thưởng thêm +100 Gem (Xem video ngắn 15s)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Mở khóa Tự do Không giới hạn, VIP Guitar Điện/Thùng & Đấu Trường',
                                  style: TextStyle(fontSize: 11.2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: kHeartRedColor,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SolfaGemIcon(size: 13),
                                SizedBox(width: 4),
                                Text(
                                  '+100',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
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
          ),
        ),
      ),
    ),
    );
  }

  Future<void> _showAchievementShareDialog(
    BuildContext context, {
    required int scorePoints,
    required double accuracy,
    required int maxCombo,
    required int starCount,
    required int streakDays,
  }) async {
    final starsStr = '★' * starCount + '☆' * (3 - starCount);
    final shareText =
        '🎵 ChaoNote (Cháo Nhạc) – Thành Tích Luyện Tập!\n'
        '🏆 Điểm đạt: $scorePoints điểm ($starsStr)\n'
        '🎯 Độ chính xác: ${accuracy.toStringAsFixed(0)}% • Combo x$maxCombo\n'
        '🔥 Chuỗi ngày học: $streakDays ngày liên tiếp\n'
        '👉 Cùng luyện Piano, Guitar Thùng/Điện & Cảm âm Offline trên ChaoNote!';

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        key: const Key('dialog_achievement_share_card'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SolfaLogo(size: 36),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'CHAONOTE • THẺ VINH DANH',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFDE047),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Chuỗi học tập: 🔥 $streakDays ngày',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  starsStr,
                  style: const TextStyle(
                    fontSize: 28,
                    color: Color(0xFFFACC15),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$scorePoints ĐIỂM',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Chính xác ${accuracy.toStringAsFixed(0)}% • Combo x$maxCombo',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Đóng'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('btn_copy_achievement_text'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: shareText),
                        );
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.correct,
                              content: Text(
                                'Đã sao chép Thẻ Vinh Danh! Bạn có thể dán chia sẻ ngay.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Sao chép'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ResultMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
