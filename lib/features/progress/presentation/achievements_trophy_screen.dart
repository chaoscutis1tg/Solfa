import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../battle/application/battle_controller.dart';
import '../../guitar/presentation/custom_melody_composer_screen.dart';
import '../../guitar/presentation/interactive_songbook_and_theory_sheet.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';
import '../../support_developer/presentation/support_developer_screen.dart';

const String _kClaimedAchievementsKey = 'solfa_claimed_achievements_v1';

final claimedAchievementsProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

Future<void> loadClaimedAchievements(WidgetRef ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kClaimedAchievementsKey) ?? const [];
    ref.read(claimedAchievementsProvider.notifier).state = list.toSet();
  } catch (_) {}
}

Future<void> persistClaimedAchievements(Set<String> claimed) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kClaimedAchievementsKey, claimed.toList());
  } catch (_) {}
}

class SolfaAchievementBadge {
  final String id;
  final String titleVi;
  final String titleEn;
  final String descVi;
  final String descEn;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final String progressLabel;
  final int gemReward;

  const SolfaAchievementBadge({
    required this.id,
    required this.titleVi,
    required this.titleEn,
    required this.descVi,
    required this.descEn,
    required this.icon,
    required this.color,
    required this.isUnlocked,
    required this.progressLabel,
    this.gemReward = 25,
  });
}

List<SolfaAchievementBadge> evaluateAllAchievements({
  required OverallProgressStats? stats,
  required BattleState battle,
  required Map<String, int> songStars,
  required int customSongsCount,
  required RewardedAdState adState,
}) {
  final totalAnswered = stats?.totalAnswered ?? 0;
  final streak = stats?.currentStreakDays ?? 0;
  final acc = stats?.overallAccuracyPercent ?? 0.0;
  final maxCombo = stats?.bestComboStreak ?? 0;
  final completedSongs = songStars.values.where((s) => s >= 1).length;
  final threeStarSongs = songStars.values.where((s) => s >= 3).length;

  return [
    SolfaAchievementBadge(
      id: 'ach_first_step',
      titleVi: 'Khởi Đầu Thanh Âm',
      titleEn: 'First Musical Step',
      descVi: 'Hoàn thành ít nhất 10 câu luyện tập cảm âm',
      descEn: 'Answer at least 10 practice questions',
      icon: Icons.music_note_rounded,
      color: const Color(0xFF3B82F6),
      isUnlocked: totalAnswered >= 10,
      progressLabel: '${totalAnswered.clamp(0, 10)}/10',
    ),
    SolfaAchievementBadge(
      id: 'ach_streak_3',
      titleVi: 'Ngọn Lửa Bền Bỉ',
      titleEn: '3-Day Flame',
      descVi: 'Duy trì chuỗi học liên tiếp 3 ngày',
      descEn: 'Maintain a 3-day practice streak',
      icon: Icons.local_fire_department_rounded,
      color: const Color(0xFFF59E0B),
      isUnlocked: streak >= 3,
      progressLabel: '${streak.clamp(0, 3)}/3',
    ),
    SolfaAchievementBadge(
      id: 'ach_streak_7',
      titleVi: 'Chiến Thần Tuần Lễ',
      titleEn: '7-Day Maestro',
      descVi: 'Duy trì chuỗi học liên tiếp 7 ngày',
      descEn: 'Maintain a 7-day practice streak',
      icon: Icons.whatshot_rounded,
      color: const Color(0xFFEA580C),
      isUnlocked: streak >= 7,
      progressLabel: '${streak.clamp(0, 7)}/7',
    ),
    SolfaAchievementBadge(
      id: 'ach_sharp_ear',
      titleVi: 'Đôi Tai Vàng 90%',
      titleEn: 'Golden Ear 90%',
      descVi: 'Đạt độ chính xác ≥ 90% (tối thiểu 30 câu)',
      descEn: 'Reach ≥ 90% accuracy over 30+ questions',
      icon: Icons.hearing_rounded,
      color: const Color(0xFF10B981),
      isUnlocked: totalAnswered >= 30 && acc >= 90.0,
      progressLabel: totalAnswered < 30
          ? '$totalAnswered/30'
          : '${acc.toStringAsFixed(0)}%',
    ),
    SolfaAchievementBadge(
      id: 'ach_combo_10',
      titleVi: 'Bậc Thầy Liên Kích',
      titleEn: 'Combo Master x10',
      descVi: 'Đạt chuỗi đúng liên tiếp từ x10 trở lên',
      descEn: 'Reach a x10 or higher combo streak',
      icon: Icons.bolt_rounded,
      color: const Color(0xFF8B5CF6),
      isUnlocked: maxCombo >= 10,
      progressLabel: 'x${maxCombo.clamp(0, 10)}/x10',
    ),
    SolfaAchievementBadge(
      id: 'ach_first_blood',
      titleVi: 'Tân Binh Đấu Trường',
      titleEn: 'Arena Victor',
      descVi: 'Giành chiến thắng đầu tiên tại Đấu Trường 1v1',
      descEn: 'Win your first 1v1 Battle Arena match',
      icon: Icons.shield_rounded,
      color: const Color(0xFF6366F1),
      isUnlocked: battle.totalWins >= 1,
      progressLabel: '${battle.totalWins.clamp(0, 1)}/1',
    ),
    SolfaAchievementBadge(
      id: 'ach_win_streak_3',
      titleVi: 'Chuỗi Bất Bại x3',
      titleEn: 'Unstoppable 3-Win Streak',
      descVi: 'Thắng 3 trận liên tiếp trong Đấu Trường',
      descEn: 'Win 3 consecutive Battle Arena matches',
      icon: Icons.flash_on_rounded,
      color: const Color(0xFFEC4899),
      isUnlocked: battle.currentWinStreak >= 3,
      progressLabel: '${battle.currentWinStreak.clamp(0, 3)}/3',
    ),
    SolfaAchievementBadge(
      id: 'ach_gold_rank',
      titleVi: 'Kỳ Tài Đấu Hạng Vàng',
      titleEn: 'Gold Rank Contender',
      descVi: 'Đạt từ 12 Sao Đấu Trường (Hạng Vàng trở lên)',
      descEn: 'Reach 12+ Stars in Battle Arena (Gold Rank)',
      icon: Icons.emoji_events_rounded,
      color: const Color(0xFFD97706),
      isUnlocked: battle.totalStars >= 12,
      progressLabel: '${battle.totalStars.clamp(0, 12)}/12★',
    ),
    SolfaAchievementBadge(
      id: 'ach_solo_3star',
      titleVi: 'Nghệ Sĩ Độc Tấu 3★',
      titleEn: '3-Star Virtuoso',
      descVi: 'Đạt 3 Sao tuyệt đối ở ít nhất 1 bản nhạc',
      descEn: 'Earn 3 Stars on any Interactive Songbook track',
      icon: Icons.star_rounded,
      color: const Color(0xFFFBBF24),
      isUnlocked: threeStarSongs >= 1,
      progressLabel: '${threeStarSongs.clamp(0, 1)}/1',
    ),
    SolfaAchievementBadge(
      id: 'ach_song_collector',
      titleVi: 'Chinh Phục 5 Bản Nhạc',
      titleEn: 'Songbook Explorer',
      descVi: 'Chơi hoàn thành từ 5 bản nhạc khác nhau',
      descEn: 'Complete 5 different Songbook tracks',
      icon: Icons.queue_music_rounded,
      color: const Color(0xFF0D9488),
      isUnlocked: completedSongs >= 5,
      progressLabel: '${completedSongs.clamp(0, 5)}/5',
    ),
    SolfaAchievementBadge(
      id: 'ach_composer',
      titleVi: 'Nhạc Sĩ Sáng Tạo',
      titleEn: 'Melody Composer',
      descVi: 'Tự soạn và lưu ít nhất 1 giai điệu cá nhân',
      descEn: 'Compose and save at least 1 custom melody',
      icon: Icons.edit_note_rounded,
      color: const Color(0xFF2563EB),
      isUnlocked: customSongsCount >= 1,
      progressLabel: '${customSongsCount.clamp(0, 1)}/1',
    ),
    SolfaAchievementBadge(
      id: 'ach_supporter',
      titleVi: 'Người Đồng Hành ChaoNote',
      titleEn: 'ChaoNote Companion',
      descVi: 'Tích lũy từ 100 Gem trở lên cùng ChaoNote',
      descEn: 'Earn 100+ total Prestige Gems',
      icon: Icons.diamond_rounded,
      color: const Color(0xFF06B6D4),
      isUnlocked: adState.totalPrestigePoints >= 100,
      progressLabel: '${adState.totalPrestigePoints.clamp(0, 100)}/100',
    ),
  ];
}

Future<void> openAchievementsTrophyScreen(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  final isRouterPage = ModalRoute.of(context)?.settings is Page;
  if (router != null && isRouterPage) {
    return router.push('/achievements');
  }
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => const AchievementsTrophyScreen(),
    ),
  );
}

class AchievementsTrophyScreen extends ConsumerStatefulWidget {
  const AchievementsTrophyScreen({super.key});

  @override
  ConsumerState<AchievementsTrophyScreen> createState() =>
      _AchievementsTrophyScreenState();
}

class _AchievementsTrophyScreenState
    extends ConsumerState<AchievementsTrophyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      loadClaimedAchievements(ref);
      loadSongbookPreferences(ref);
      loadCustomUserSongs(ref);
    });
  }

  Future<void> _claimBadgeGem(
    SolfaAchievementBadge badge,
    bool isEn,
  ) async {
    final claimed = ref.read(claimedAchievementsProvider);
    if (claimed.contains(badge.id) || !badge.isUnlocked) return;

    final updated = {...claimed, badge.id};
    ref.read(claimedAchievementsProvider.notifier).state = updated;
    await persistClaimedAchievements(updated);
    await ref.read(rewardedAdProvider.notifier).grantBonusPrestigePoints(
          badge.gemReward,
          customMessage: isEn
              ? '+${badge.gemReward} Gems from badge "${badge.titleEn}"!'
              : 'Đã nhận +${badge.gemReward} Gem từ huy hiệu "${badge.titleVi}"!',
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.correct,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const SolfaGemIcon(size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEn
                    ? 'Claimed +${badge.gemReward} Gems for "${badge.titleEn}"!'
                    : 'Đã nhận thưởng +${badge.gemReward} Gem huy hiệu "${badge.titleVi}"!',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyShareSummary({
    required OverallProgressStats? stats,
    required BattleState battle,
    required int unlockedCount,
    required int totalBadges,
    required int totalSongStars,
    required bool isEn,
  }) async {
    final acc = (stats?.overallAccuracyPercent ?? 0).toStringAsFixed(1);
    final streak = stats?.currentStreakDays ?? 0;
    final rankName = battle.rankInfo.tierName;
    final summary = isEn
        ? '🎵 ChaoNote Studio Profile\n'
            '🏆 Rank: $rankName (${battle.totalStars}★) • Badges: $unlockedCount/$totalBadges\n'
            '🔥 Daily Streak: $streak days • Ear Accuracy: $acc%\n'
            '🎸 Songbook Stars: $totalSongStars★\n'
            'Train Piano, Guitar & Ear Training 100% Offline on ChaoNote!'
        : '🎵 Hồ Sơ Thành Tích ChaoNote Studio\n'
            '🏆 Hạng Đấu Trường: $rankName (${battle.totalStars}★) • Huy hiệu: $unlockedCount/$totalBadges\n'
            '🔥 Chuỗi học: $streak ngày • Độ chính xác Cảm âm: $acc%\n'
            '🎸 Sao Kho Bản Nhạc: $totalSongStars★\n'
            'Cùng luyện Cảm âm, Piano & Guitar trên ChaoNote nhé!';
    try {
      await Clipboard.setData(ClipboardData(text: summary));
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        content: Text(
          isEn
              ? 'Copied achievement profile card! Ready to paste & share.'
              : 'Đã sao chép Thẻ Thành Tích! Bạn có thể dán chia sẻ lên Zalo / Facebook ngay.',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = ref.watch(appSettingsProvider).isEnglish;
    final stats = ref.watch(overallProgressProvider).valueOrNull;
    final battle = ref.watch(battleProvider);
    final songStars = ref.watch(songbookStarsProvider);
    final customSongs = ref.watch(customUserSongsProvider);
    final adState = ref.watch(rewardedAdProvider);
    final claimedSet = ref.watch(claimedAchievementsProvider);

    final badges = evaluateAllAchievements(
      stats: stats,
      battle: battle,
      songStars: songStars,
      customSongsCount: customSongs.length,
      adState: adState,
    );
    final unlockedCount = badges.where((b) => b.isUnlocked).length;
    final totalSongStars =
        songStars.values.fold<int>(0, (prev, elem) => prev + elem);

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          titleSpacing: 0,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isEn ? 'Trophy Room & Share Card' : 'Huy Hiệu & Thẻ Thành Tích',
              maxLines: 1,
            ),
          ),
          actions: const [
            SolfaHeaderGemPill(),
          ],
        ),
        body: SafeArea(
          child: ListView(
            key: const Key('screen_achievements_trophy'),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              // 1. Thẻ Vinh Danh Cá Nhân (Player Share Card)
              Container(
                key: const Key('card_player_share_profile'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withOpacity(0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFDE047),
                              width: 1.8,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            battle.rankInfo.badgeIcon,
                            color: const Color(0xFFFDE047),
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEn
                                    ? 'ChaoNote Mastery Card'
                                    : 'Thẻ Vinh Danh ChaoNote',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEn
                                    ? 'Rank ${battle.rankInfo.tierName} • $unlockedCount/${badges.length} Badges'
                                    : 'Hạng ${battle.rankInfo.tierName} • $unlockedCount/${badges.length} Huy hiệu',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.88),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _ShareStatBox(
                          label: isEn ? 'Streak' : 'Chuỗi ngày',
                          value: '${stats?.currentStreakDays ?? 0}🔥',
                        ),
                        const SizedBox(width: 8),
                        _ShareStatBox(
                          label: isEn ? 'Accuracy' : 'Chính xác',
                          value:
                              '${(stats?.overallAccuracyPercent ?? 0).toStringAsFixed(0)}%',
                        ),
                        const SizedBox(width: 8),
                        _ShareStatBox(
                          label: isEn ? 'Song Stars' : 'Sao Nhạc',
                          value: '$totalSongStars★',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      key: const Key('btn_copy_share_achievement_card'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E1B4B),
                        minimumSize: const Size(double.infinity, 42),
                      ),
                      onPressed: () => _copyShareSummary(
                        stats: stats,
                        battle: battle,
                        unlockedCount: unlockedCount,
                        totalBadges: badges.length,
                        totalSongStars: totalSongStars,
                        isEn: isEn,
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn
                              ? 'Copy Profile Card to Share'
                              : 'Sao chép Thẻ Thành Tích để Chia sẻ',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 2. Danh sách 12 Huy Hiệu Thành Tựu (+25 Gem mỗi huy hiệu)
              Text(
                isEn
                    ? 'All Achievements ($unlockedCount/${badges.length})'
                    : 'Bộ Sưu Tập Huy Hiệu ($unlockedCount/${badges.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),

              for (int i = 0; i < badges.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Builder(
                  builder: (_) {
                    final b = badges[i];
                    final isClaimed = claimedSet.contains(b.id);
                    return Container(
                      key: Key('badge_item_${b.id}'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: b.isUnlocked
                              ? b.color.withOpacity(0.55)
                              : (isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight),
                          width: b.isUnlocked ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: b.isUnlocked
                                  ? b.color.withOpacity(0.16)
                                  : Colors.grey.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              b.icon,
                              color: b.isUnlocked ? b.color : Colors.grey,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEn ? b.titleEn : b.titleVi,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: b.isUnlocked ? null : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isEn ? b.descEn : b.descVi,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (b.isUnlocked && !isClaimed)
                            ElevatedButton.icon(
                              key: Key('btn_claim_badge_${b.id}'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.correct,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 34),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _claimBadgeGem(b, isEn),
                              icon: const SolfaGemIcon(size: 13),
                              label: Text(
                                '+${b.gemReward}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            )
                          else if (b.isUnlocked && isClaimed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.correct.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: AppColors.correct,
                              ),
                            )
                          else
                            Text(
                              b.progressLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareStatBox extends StatelessWidget {
  final String label;
  final String value;

  const _ShareStatBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

