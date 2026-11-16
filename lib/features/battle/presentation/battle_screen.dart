import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/crossed_swords_icon.dart';
import '../../../app/widgets/pulsing_red_heart.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../practice/presentation/widgets/musical_staff_widget.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';
import '../../support_developer/presentation/support_developer_screen.dart';
import '../application/battle_controller.dart';

class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key});

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen>
    with WidgetsBindingObserver {
  BattleNotifier? _battleNotifier;

  static const List<(String id, String label, IconData icon)> _battleTopics = [
    ('all', 'Tổng hợp (7 Chủ đề)', Icons.auto_awesome_rounded),
    ('topic_notes', 'Nghe nốt', Icons.graphic_eq_rounded),
    ('topic_staff_reading', 'Đọc khuông', Icons.music_note_rounded),
    ('topic_intervals', 'Quãng', Icons.compare_arrows_rounded),
    ('topic_chords', 'Hợp âm', Icons.library_music_rounded),
    ('topic_melody', 'Giai điệu', Icons.queue_music_rounded),
    ('topic_rhythm', 'Nhịp điệu', Icons.timer_rounded),
    ('topic_keys', 'Giọng', Icons.piano_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _battleNotifier = ref.read(battleProvider.notifier);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _battleNotifier?.onScreenDisposed();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      ref.read(battleProvider.notifier).onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(battleProvider.notifier).onAppResumed();
    }
  }

  Future<void> _handleWatchAdForTurn(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final restored = await showSolfaRewardedVideoAdModal(context, ref);
    if (!context.mounted) return;
    if (restored) {
      final turns = ref.read(battleProvider).remainingBattlesToday;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.correct,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã hồi +1 Lượt Đấu Trường (Hiện có: $turns lượt) & +100 Điểm Uy Tín ủng hộ nhà phát triển!',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _showOutOfTurnsDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final adState = ref.read(rewardedAdProvider);
    final availablePoints = adState.prestigePoints;
    final canRedeem = availablePoints >= 100;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('dialog_out_of_battle_turns'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.16),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.bolt_rounded,
                color: Color(0xFFF59E0B),
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Đã Hết 5 Lượt Đấu Hôm Nay!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mỗi ngày Đấu Trường tặng 5 lượt miễn phí. Bạn có thể xem 1 video (15 giây) để hồi ngay +1 lượt & nhận +100 Điểm Uy Tín, hoặc dùng Điểm Uy Tín tích lũy (hiện có: $availablePointsđ) để đổi sang lượt chơi!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.38),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                key: const Key('btn_confirm_watch_ad_turn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop('watch_ad'),
                icon: const Icon(Icons.smart_display_rounded, size: 20),
                label: const Text(
                  'Xem Video 15s (+1 Lượt & +100đ)',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                key: const Key('btn_dialog_redeem_points_turn'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  side: BorderSide(
                    color: canRedeem ? AppColors.correct : AppColors.accentAmber,
                    width: 1.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop('redeem_points'),
                icon: Icon(
                  Icons.swap_horiz_rounded,
                  size: 19,
                  color: canRedeem ? AppColors.correct : AppColors.accentAmber,
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Đổi 100 Điểm Uy Tín → +1 Lượt ($availablePointsđ)',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color:
                          canRedeem ? AppColors.correct : AppColors.accentAmber,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  key: const Key('btn_dialog_open_exchange_station'),
                  onPressed: () => Navigator.of(ctx).pop('open_station'),
                  icon: const Icon(Icons.storefront_rounded, size: 16),
                  label: const Text(
                    'Gói 3–5 lượt (Ưu đãi)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('cancel'),
                  child: const Text('Để sau'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    if (action == 'watch_ad') {
      await _handleWatchAdForTurn(context, ref);
    } else if (action == 'redeem_points') {
      await redeemPrestigePointsForBattleTurns(
        context,
        ref,
        pointsCost: 100,
        turnsToGrant: 1,
      );
    } else if (action == 'open_station') {
      context.push('/support-developer');
    }
  }

  Future<void> _onTapStartOrRematch(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final state = ref.read(battleProvider);
    if (!state.canStartBattle) {
      await _showOutOfTurnsDialog(context, ref);
      return;
    }
    await ref.read(battleProvider.notifier).startBattle();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(battleProvider);
    final notifier = ref.read(battleProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: state.phase == BattlePhase.lobby,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.phase != BattlePhase.lobby) {
          notifier.backToLobby();
        }
      },
      child: SolfaBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: IconButton(
              key: const Key('btn_close_battle_screen'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (state.phase != BattlePhase.lobby) {
                  notifier.backToLobby();
                } else if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const CrossedSwordsIcon(
                    size: 18,
                    color: Colors.white,
                    guardColor: Color(0xFFFFE082),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Đấu Trường Âm Nhạc 1v1',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              // Daily Battle Energy Pill (5 turns/day)
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => _handleWatchAdForTurn(context, ref),
                child: Container(
                  key: const Key('badge_battle_turns_appbar'),
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: (state.canStartBattle
                            ? const Color(0xFFF59E0B)
                            : AppColors.wrong)
                        .withOpacity(0.16),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: (state.canStartBattle
                              ? const Color(0xFFF59E0B)
                              : AppColors.wrong)
                          .withOpacity(0.55),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 15,
                        color: state.canStartBattle
                            ? const Color(0xFFF59E0B)
                            : AppColors.wrong,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${state.remainingBattlesToday}/${BattleState.maxDailyFreeBattles}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: state.canStartBattle
                              ? (isDark
                                  ? Colors.white
                                  : const Color(0xFFD97706))
                              : AppColors.wrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Color(state.rankInfo.colorHex).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: Color(state.rankInfo.colorHex).withOpacity(0.55),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.rankInfo.badgeIcon,
                      size: 15,
                      color: isDark
                          ? Colors.white
                          : Color(state.rankInfo.colorHex),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${state.totalStars}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? Colors.white
                            : Color(state.rankInfo.colorHex),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: switch (state.phase) {
                BattlePhase.lobby => _buildLobbyView(context, ref, state, isDark),
                BattlePhase.matchmaking ||
                BattlePhase.vsIntro =>
                  _buildVsMatchmakingView(context, ref, state, isDark),
                BattlePhase.fighting =>
                  _buildFightingArenaView(context, ref, state, isDark),
                BattlePhase.finished =>
                  _buildMatchResultView(context, ref, state, isDark),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLobbyView(
    BuildContext context,
    WidgetRef ref,
    BattleState state,
    bool isDark,
  ) {
    final notifier = ref.read(battleProvider.notifier);
    final rank = state.rankInfo;
    final rankColor = Color(rank.colorHex);
    final winRate = state.totalMatches > 0
        ? ((state.totalWins / state.totalMatches) * 100).round()
        : 0;

    return ListView(
      key: const Key('battle_lobby_view'),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      children: [
        // 1. Compact AoV (Liên Quân) Rank Emblem & Hero Title Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1B4B), const Color(0xFF311042)]
                  : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: rankColor.withOpacity(0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.24),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFE082),
                        width: 2.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      rank.badgeIcon,
                      color: const Color(0xFFFFE082),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Hạng ${rank.tierName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE082).withOpacity(0.22),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                rank.heroTitle,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFFE082),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${state.totalStars}/${rank.nextTierStars} Sao • Chuỗi thắng: x${state.currentWinStreak} (3 thắng +1 Sao)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withOpacity(0.90),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: rank.progressToNextTier,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.18),
                  valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  _buildMiniStatPill('Trận thắng', '${state.totalWins}'),
                  const SizedBox(width: 8),
                  _buildMiniStatPill('Tổng trận', '${state.totalMatches}'),
                  const SizedBox(width: 8),
                  _buildMiniStatPill('Tỷ lệ thắng', '$winRate%'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Compact Daily 5-Battle Energy & Watch-Ad Recovery Card
        _buildDailyTurnsEnergyCard(context, ref, state, isDark),
        const SizedBox(height: 12),

        // 3. Horizontal 3-Card Mode Selector (Liên Quân Arena Style)
        Row(
          children: [
            Expanded(
              child: _buildHorizontalArenaModeCard(
                key: const Key('btn_battle_mode_matchmaking'),
                title: 'ĐẤU HẠNG 1v1',
                subtitle: 'Ghép Rank • +Sao',
                icon: Icons.radar_rounded,
                accent: const Color(0xFF6366F1),
                isSelected: state.mode == BattleMode.smartMatchmaking,
                isDark: isDark,
                onTap: () =>
                    notifier.setBattleMode(BattleMode.smartMatchmaking),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildHorizontalArenaModeCard(
                key: const Key('btn_battle_mode_bot'),
                title: 'ĐẤU MÁY AI',
                subtitle: '4 Cấp độ luyện',
                icon: Icons.smart_toy_rounded,
                accent: const Color(0xFFEC4899),
                isSelected: state.mode == BattleMode.botAi,
                isDark: isDark,
                onTap: () => notifier.setBattleMode(BattleMode.botAi),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildHorizontalArenaModeCard(
                key: const Key('btn_battle_mode_local_pvp'),
                title: '2 NGƯỜI 1 MÁY',
                subtitle: 'Chia đôi màn hình',
                icon: Icons.people_alt_rounded,
                accent: const Color(0xFFF59E0B),
                isSelected: state.mode == BattleMode.localSplitScreen,
                isDark: isDark,
                onTap: () =>
                    notifier.setBattleMode(BattleMode.localSplitScreen),
              ),
            ),
          ],
        ),
        if (state.mode == BattleMode.botAi) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (diff, label, botIcon) in const [
                  (BotDifficulty.rookie, 'Tập Sự', Icons.smart_toy_rounded),
                  (BotDifficulty.academy, 'Tinh Anh', Icons.shield_rounded),
                  (BotDifficulty.maestro, 'Cao Thủ', Icons.auto_awesome_rounded),
                  (BotDifficulty.legend, 'Thách Đấu', Icons.workspace_premium_rounded),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: Key('chip_bot_${diff.name}'),
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        botIcon,
                        size: 15,
                        color: state.botDifficulty == diff
                            ? const Color(0xFFEC4899)
                            : AppColors.textSecondaryLight,
                      ),
                      label: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      selected: state.botDifficulty == diff,
                      onSelected: (_) => notifier.setBotDifficulty(diff),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),

        // 4. Single-Line Compact Topic Filter Strip
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (tId, tLabel, tIcon) in _battleTopics)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: Key('chip_battle_topic_$tId'),
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      tIcon,
                      size: 15,
                      color: state.selectedTopicId == tId
                          ? AppColors.primary
                          : AppColors.textSecondaryLight,
                    ),
                    label: Text(
                      tLabel,
                      style: TextStyle(
                        fontSize: 11.8,
                        fontWeight: state.selectedTopicId == tId
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    selected: state.selectedTopicId == tId,
                    onSelected: (_) => notifier.setSelectedTopicId(tId),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 5. Large AoV Start Battle CTA Button with Crossed Swords
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            key: const Key('btn_start_battle_now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: state.canStartBattle
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFFD97706),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: state.isLoading
                ? null
                : () => _onTapStartOrRematch(context, ref),
            icon: state.canStartBattle
                ? const CrossedSwordsIcon(
                    size: 22,
                    color: Colors.white,
                    guardColor: Color(0xFFFFE082),
                  )
                : const Icon(Icons.smart_display_rounded, size: 22),
            label: Text(
              state.canStartBattle
                  ? 'BẮT ĐẦU GHÉP TRẬN (CÒN ${state.remainingBattlesToday}/${BattleState.maxDailyFreeBattles} LƯỢT)'
                  : 'HẾT LƯỢT • XEM QC HOẶC ĐỔI ĐIỂM HỒI LƯỢT',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        if (state.matchHistory.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildRecentMatchesSection(state, isDark),
        ],
      ],
    );
  }

  Widget _buildRecentMatchesSection(BattleState state, bool isDark) {
    return Container(
      key: const Key('card_battle_match_history'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.12)
              : const Color(0xFFD8E4F8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 17,
                color: Color(0xFF4F46E5),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'NHẬT KÝ ĐẤU TRƯỜNG GẦN ĐÂY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < state.matchHistory.take(5).length; i++) ...[
            if (i > 0) const Divider(height: 10),
            Builder(
              builder: (context) {
                final rec = state.matchHistory[i];
                final badgeColor = rec.isDraw
                    ? AppColors.accentAmber
                    : (rec.didWin ? AppColors.correct : AppColors.wrong);
                final badgeText =
                    rec.isDraw ? 'HÒA' : (rec.didWin ? 'THẮNG' : 'THUA');
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: badgeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'vs ${rec.opponentName} (${rec.modeLabel})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${rec.player1Hp}-${rec.player2Hp} HP • x${rec.maxCombo}',
                      style: const TextStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyTurnsEnergyCard(
    BuildContext context,
    WidgetRef ref,
    BattleState state,
    bool isDark,
  ) {
    final adState = ref.watch(rewardedAdProvider);
    final availablePoints = adState.prestigePoints;
    final canRedeem = availablePoints >= 100;
    final remaining = state.remainingBattlesToday;
    const maxFree = BattleState.maxDailyFreeBattles;
    final hasTurns = remaining > 0;
    final accentColor = hasTurns ? const Color(0xFFF59E0B) : AppColors.wrong;

    return Container(
      key: const Key('battle_daily_turns_card'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withOpacity(0.45),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.bolt_rounded,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasTurns
                          ? 'Năng lượng Đấu Trường: $remaining/$maxFree lượt hôm nay'
                          : 'Đã dùng hết $maxFree/$maxFree lượt miễn phí hôm nay',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: hasTurns ? null : AppColors.wrong,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mỗi ngày 5 lượt miễn phí • Xem QC (15s) hoặc đổi Điểm Uy Tín (hiện có: $availablePointsđ) để hồi lượt',
                      style: const TextStyle(fontSize: 11.2, height: 1.28),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 5 Energy Bolt Segment Capsules
          Row(
            children: [
              for (int i = 0; i < maxFree; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    height: 9,
                    decoration: BoxDecoration(
                      gradient: i < remaining
                          ? const LinearGradient(
                              colors: [
                                Color(0xFFF59E0B),
                                Color(0xFF4F46E5),
                              ],
                            )
                          : null,
                      color: i < remaining
                          ? null
                          : (isDark
                              ? Colors.white.withOpacity(0.12)
                              : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Action Row: Watch Ad (+1 Turn) OR Redeem Prestige Points (+1 Turn)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('btn_battle_watch_ad_turn'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    side: const BorderSide(
                      color: kHeartRedColor,
                      width: 1.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _handleWatchAdForTurn(context, ref),
                  icon: const PulsingRedHeart(size: 13),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '+1 Lượt (Xem QC)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: kHeartRedColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('btn_battle_redeem_points_turn'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    side: BorderSide(
                      color:
                          canRedeem ? AppColors.correct : AppColors.accentAmber,
                      width: 1.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => redeemPrestigePointsForBattleTurns(
                    context,
                    ref,
                    pointsCost: 100,
                    turnsToGrant: 1,
                  ),
                  icon: Icon(
                    Icons.swap_horiz_rounded,
                    size: 15,
                    color:
                        canRedeem ? AppColors.correct : AppColors.accentAmber,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Đổi 100đ → +1 Lượt ($availablePointsđ)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: canRedeem
                            ? AppColors.correct
                            : AppColors.accentAmber,
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

  Widget _buildMiniStatPill(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.13),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalArenaModeCard({
    required Key key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected
          ? accent.withOpacity(isDark ? 0.26 : 0.14)
          : (isDark ? AppColors.surfaceDark : Colors.white),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? accent
                  : (isDark
                      ? Colors.white.withOpacity(0.14)
                      : const Color(0xFFD8E4F8)),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? accent : null,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.2,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVsMatchmakingView(
    BuildContext context,
    WidgetRef ref,
    BattleState state,
    bool isDark,
  ) {
    final notifier = ref.read(battleProvider.notifier);
    final isScanning = state.phase == BattlePhase.matchmaking;
    final rank = state.rankInfo;

    return Padding(
      key: const Key('battle_vs_matchmaking_view'),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.16),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isScanning ? Icons.radar_rounded : Icons.bolt_rounded,
                  size: 16,
                  color: const Color(0xFF6366F1),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isScanning
                        ? 'ĐANG QUÉT RADAR TÌM ĐỐI THỦ CÙNG HẠNG...'
                        : 'ĐÃ KHÓA MỤC TIÊU! CHUẨN BỊ GIAO ĐẤU',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Fighter 1 Card (Player with AoV Rank Frame & Win Streak)
          _buildVsFighterCard(
            name: state.player1Name,
            subtitle: state.player1Title,
            slogan: state.currentWinStreak >= 2
                ? 'Đang giữ Chuỗi ${state.currentWinStreak} Trận Thắng liên tiếp!'
                : 'Danh hiệu: ${rank.heroTitle}',
            icon: rank.badgeIcon,
            accent: const Color(0xFF4F46E5),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Crossed Swords VS Emblem (Liên Quân Style)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.45),
                  blurRadius: 16,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const CrossedSwordsIcon(
              size: 28,
              color: Colors.white,
              guardColor: Color(0xFFFFE082),
            ),
          ),
          const SizedBox(height: 12),

          // Fighter 2 Card (Challenger with AoV Mastery & Taunt Slogan)
          _buildVsFighterCard(
            name: state.player2Name,
            subtitle: state.player2Title,
            slogan: '"${state.player2Slogan}"',
            icon: state.player2AvatarIcon,
            accent: const Color(0xFFEC4899),
            isDark: isDark,
          ),
          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              key: const Key('btn_battle_enter_arena'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC4899),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => notifier.enterArenaNow(),
              icon: const CrossedSwordsIcon(
                size: 20,
                color: Colors.white,
                guardColor: Color(0xFFFFE082),
              ),
              label: const Text(
                'BẮT ĐẦU HIỆP 1 NGAY',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVsFighterCard({
    required String name,
    required String subtitle,
    required String slogan,
    required IconData icon,
    required Color accent,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.75), width: 2.0),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFFE082).withOpacity(0.85),
                width: 1.8,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  slogan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '100 HP',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.correct,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFightingArenaView(
    BuildContext context,
    WidgetRef ref,
    BattleState state,
    bool isDark,
  ) {
    final notifier = ref.read(battleProvider.notifier);
    final audioService = ref.watch(audioServiceProvider);
    final curQ = state.currentQuestion;
    if (curQ == null) return const SizedBox.shrink();

    final showStaff = curQ.isSightReading ||
        (curQ.topicId == 'topic_notes' && state.isRoundResolved);

    return ListView(
      key: const Key('battle_fighting_arena_view'),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
      children: [
        // 1. Top RPG Dual Fighter Health Bar HUD
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.14)
                  : const Color(0xFFD8E4F8),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Fighter 1 HP
                  Expanded(
                    child: _buildFighterHudSide(
                      name: state.player1Name,
                      hp: state.player1Hp,
                      combo: state.player1Combo,
                      color: const Color(0xFF4F46E5),
                      alignRight: false,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Hiệp ${state.currentRoundIndex + 1}/${state.totalRounds}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${(state.roundRemainingDeciseconds / 10).toStringAsFixed(1)}s',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: state.roundRemainingDeciseconds <= 25
                                ? AppColors.wrong
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Fighter 2 HP
                  Expanded(
                    child: _buildFighterHudSide(
                      name: state.player2Name,
                      hp: state.player2Hp,
                      combo: state.player2Combo,
                      color: const Color(0xFFEC4899),
                      alignRight: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Round countdown bar
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (state.roundRemainingDeciseconds / 80.0).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor:
                      isDark ? Colors.white12 : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    state.roundRemainingDeciseconds <= 25
                        ? AppColors.wrong
                        : const Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Floating Combat Damage / Crit Banner with smooth scale entrance
        if (state.combatBannerText != null) ...[
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            key: ValueKey('banner_${state.currentRoundIndex}_${state.combatBannerText}'),
            tween: Tween<double>(begin: 0.92, end: 1.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: Container(
              key: const Key('battle_combat_banner'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: state.lastHitWasCrit
                      ? [const Color(0xFFF59E0B), const Color(0xFFEF4444)]
                      : (state.roundWinner == 'p1'
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [const Color(0xFFEC4899), const Color(0xFFBE185D)]),
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (state.lastHitWasCrit
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF4F46E5))
                        .withOpacity(0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    state.lastHitWasCrit
                        ? Icons.local_fire_department_rounded
                        : (state.roundWinner == 'p1'
                            ? Icons.bolt_rounded
                            : Icons.shield_rounded),
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      state.combatBannerText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),

        // 3. Question Stage (Staff or Audio Orb)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.14)
                  : const Color(0xFFD8E4F8),
            ),
          ),
          child: Column(
            children: [
              Text(
                curQ.prompt.replaceAll(' (hoặc bấm phím đàn)', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (showStaff) ...[
                MusicalStaffWidget(
                  targetNoteKey: curQ.correctOption.optionKey,
                  showNote: state.isRoundResolved,
                  isSightReading: curQ.isSightReading,
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('btn_battle_play_audio'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(
                      color: Color(0xFF6366F1),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => audioService.playAsset(curQ.audioAsset),
                  icon: const Icon(
                    Icons.volume_up_rounded,
                    color: Color(0xFF6366F1),
                  ),
                  label: const Text(
                    'Nghe lại âm thanh hiệp đấu',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4. Answer Controls (Single Player vs Bot/Online OR Dual Split-Screen 1v1)
        if (state.mode == BattleMode.localSplitScreen)
          _buildSplitScreenControls(context, notifier, state, curQ, isDark)
        else
          _buildSingleFighterControls(context, notifier, state, curQ, isDark),

        if (state.isRoundResolved) ...[
          if (curQ.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.08),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: const Color(0xFF4F46E5).withOpacity(0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 14,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      curQ.explanation,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('btn_battle_next_round'),
              onPressed: () => notifier.nextRound(),
              icon: const Icon(Icons.skip_next_rounded),
              label: Text(
                state.isKnockOut ||
                        state.currentRoundIndex + 1 >= state.totalRounds
                    ? 'Xem Kết Quả Trận Đấu'
                    : 'Sang Hiệp Tiếp Theo',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFighterHudSide({
    required String name,
    required int hp,
    required int combo,
    required Color color,
    required bool alignRight,
  }) {
    final hpRatio = (hp / BattleState.maxHp).clamp(0.0, 1.0);
    final hpColor = hp > 50
        ? AppColors.correct
        : (hp > 25 ? AppColors.accentAmber : AppColors.wrong);

    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (alignRight && combo >= 2) ...[
              _buildComboBadge(combo),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            if (!alignRight && combo >= 2) ...[
              const SizedBox(width: 4),
              _buildComboBadge(combo),
            ],
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 1.0, end: hpRatio),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, animatedRatio, _) => LinearProgressIndicator(
              value: animatedRatio,
              minHeight: 9,
              backgroundColor: color.withOpacity(0.14),
              valueColor: AlwaysStoppedAnimation<Color>(hpColor),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$hp / ${BattleState.maxHp} HP',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: hpColor,
          ),
        ),
      ],
    );
  }

  Widget _buildComboBadge(int combo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.2),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 12,
            color: Color(0xFFF59E0B),
          ),
          Text(
            'x$combo',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleFighterControls(
    BuildContext context,
    BattleNotifier notifier,
    BattleState state,
    QuestionModel curQ,
    bool isDark,
  ) {
    const badges = ['A', 'B', 'C', 'D'];
    return Column(
      children: [
        for (int i = 0; i < curQ.options.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildBattleOptionTile(
            key: Key('battle_opt_$i'),
            badge: badges[i % badges.length],
            option: curQ.options[i],
            isResolved: state.isRoundResolved,
            selectedOptionId: state.p1SelectedOptionId,
            accentColor: const Color(0xFF4F46E5),
            isDark: isDark,
            onTap: () => notifier.submitPlayer1Answer(curQ.options[i]),
          ),
        ],
      ],
    );
  }

  Widget _buildSplitScreenControls(
    BuildContext context,
    BattleNotifier notifier,
    BattleState state,
    QuestionModel curQ,
    bool isDark,
  ) {
    const badges = ['A', 'B', 'C', 'D'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Player 1 Pad (Left)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF4F46E5).withOpacity(0.35),
              ),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      size: 13,
                      color: Color(0xFF4F46E5),
                    ),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'NGƯỜI CHƠI 1',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (int i = 0; i < curQ.options.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  _buildBattleOptionTile(
                    key: Key('battle_p1_opt_$i'),
                    badge: badges[i % badges.length],
                    option: curQ.options[i],
                    isResolved: state.isRoundResolved || state.p1LockedOut,
                    selectedOptionId: state.p1SelectedOptionId,
                    accentColor: const Color(0xFF4F46E5),
                    isDark: isDark,
                    compact: true,
                    onTap: () => notifier.submitPlayer1Answer(curQ.options[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Player 2 Pad (Right)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEC4899).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFEC4899).withOpacity(0.35),
              ),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 13,
                      color: Color(0xFFEC4899),
                    ),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'NGƯỜI CHƠI 2',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEC4899),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (int i = 0; i < curQ.options.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  _buildBattleOptionTile(
                    key: Key('battle_p2_opt_$i'),
                    badge: badges[i % badges.length],
                    option: curQ.options[i],
                    isResolved: state.isRoundResolved || state.p2LockedOut,
                    selectedOptionId: state.p2SelectedOptionId,
                    accentColor: const Color(0xFFEC4899),
                    isDark: isDark,
                    compact: true,
                    onTap: () => notifier.submitPlayer2Answer(curQ.options[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBattleOptionTile({
    required Key key,
    required String badge,
    required QuestionOptionModel option,
    required bool isResolved,
    required String? selectedOptionId,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    final isSelected = selectedOptionId == option.id;
    Color borderColor = isDark
        ? Colors.white.withOpacity(0.14)
        : const Color(0xFFD8E4F8);
    Color bgColor = isDark ? AppColors.surfaceDark : Colors.white;

    if (isResolved) {
      if (option.isCorrect) {
        borderColor = AppColors.correct;
        bgColor = AppColors.correct.withOpacity(0.14);
      } else if (isSelected) {
        borderColor = AppColors.wrong;
        bgColor = AppColors.wrong.withOpacity(0.14);
      }
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(13),
        onTap: isResolved ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 22 : 26,
                height: compact ? 22 : 26,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchResultView(
    BuildContext context,
    WidgetRef ref,
    BattleState state,
    bool isDark,
  ) {
    final notifier = ref.read(battleProvider.notifier);
    final p1Won = state.didPlayer1Win && !state.isDraw;
    final bannerColor = state.isDraw
        ? AppColors.accentAmber
        : (p1Won ? AppColors.correct : AppColors.wrong);

    final String headline;
    final IconData headlineIcon;
    if (state.mode == BattleMode.localSplitScreen) {
      headline = state.isDraw
          ? 'HÒA KỊCH TÍNH!'
          : (p1Won
              ? 'NGƯỜI CHƠI 1 CHIẾN THẮNG!'
              : 'NGƯỜI CHƠI 2 CHIẾN THẮNG!');
      headlineIcon = state.isDraw
          ? Icons.handshake_rounded
          : Icons.emoji_events_rounded;
    } else {
      headline = state.isDraw
          ? 'BẤT PHÂN THẮNG BẠI!'
          : (p1Won ? 'CHIẾN THẮNG VINH QUANG!' : 'THẤT BẠI SÁT NÚT!');
      headlineIcon = state.isDraw
          ? Icons.handshake_rounded
          : (p1Won ? Icons.emoji_events_rounded : Icons.shield_rounded);
    }

    return ListView(
      key: const Key('battle_result_view'),
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: bannerColor.withOpacity(0.6), width: 2),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: bannerColor.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  headlineIcon,
                  color: bannerColor,
                  size: 30,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                state.isKnockOut ? 'K.O. HẠ GỤC TUYỆT ĐỐI!' : 'KẾT THÚC TRẬN ĐẤU',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: bannerColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: bannerColor,
                ),
              ),
              const SizedBox(height: 10),
              if (state.mode != BattleMode.localSplitScreen)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          state.starsDeltaLastMatch > 0
                              ? '+${state.starsDeltaLastMatch} Sao Thưởng Chiến Thắng (Hạng ${state.rankInfo.tierName})'
                              : (state.starsDeltaLastMatch < 0
                                  ? '${state.starsDeltaLastMatch} Sao (Hạng ${state.rankInfo.tierName})'
                                  : 'Giữ nguyên Sao (Hạng ${state.rankInfo.tierName})'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (state.winStreakBonusStarGranted) ...[
                const SizedBox(height: 8),
                Container(
                  key: const Key('badge_win_streak_bonus_star'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 16,
                        color: Color(0xFFEC4899),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Tinh Tú Hộ Mệnh (Chuỗi ${state.currentWinStreak} Thắng): +1 Sao Thưởng!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFEC4899),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (state.lastRankUpBonusPoints > 0) ...[
                const SizedBox(height: 8),
                Container(
                  key: const Key('badge_rank_up_bonus'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.correct.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        size: 16,
                        color: AppColors.correct,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Thưởng Thăng Hạng ${state.rankInfo.tierName}: +${state.lastRankUpBonusPoints} Điểm Uy Tín!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.correct,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildResultFighterBox(
                      name: state.player1Name,
                      hp: state.player1Hp,
                      correct: state.player1CorrectCount,
                      maxCombo: state.player1MaxCombo,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildResultFighterBox(
                      name: state.player2Name,
                      hp: state.player2Hp,
                      correct: state.player2CorrectCount,
                      maxCombo: state.player2MaxCombo,
                      color: const Color(0xFFEC4899),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!ref.watch(rewardedAdProvider).questBattleClaimedToday) ...[
          Container(
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
                        'Hoàn thành Nhiệm vụ Chiến binh Đấu Trường!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.correct,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Nhận ngay +40 Điểm Uy Tín thưởng nhiệm vụ ngày',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  key: const Key('btn_battle_claim_quest_battle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.correct,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () async {
                    final pts = await ref
                        .read(rewardedAdProvider.notifier)
                        .claimDailyQuest('battle');
                    if (pts > 0 && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.correct,
                          content: Text(
                            'Đã nhận +$pts Điểm Uy Tín từ nhiệm vụ Chiến binh Đấu Trường!',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Nhận +40đ',
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
        // Daily Turns Status & Watch-Ad Recovery on Result Screen
        _buildDailyTurnsEnergyCard(context, ref, state, isDark),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            key: const Key('btn_battle_rematch'),
            style: ElevatedButton.styleFrom(
              backgroundColor: state.canStartBattle
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => _onTapStartOrRematch(context, ref),
            icon: Icon(
              state.canStartBattle
                  ? Icons.replay_rounded
                  : Icons.smart_display_rounded,
            ),
            label: Text(
              state.canStartBattle
                  ? 'TÁI ĐẤU NGAY (CÒN ${state.remainingBattlesToday}/${BattleState.maxDailyFreeBattles} LƯỢT)'
                  : 'HẾT LƯỢT • XEM QC HOẶC ĐỔI ĐIỂM HỒI LƯỢT',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            key: const Key('btn_battle_back_lobby'),
            onPressed: () => notifier.backToLobby(),
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text(
              'Về Sảnh Đấu Trường',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultFighterBox({
    required String name,
    required int hp,
    required int correct,
    required int maxCombo,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$hp HP',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Đúng: $correct câu • Combo: x$maxCombo',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
