import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/crossed_swords_icon.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
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
  bool _isTabletopOpposite180 = false;

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
                  'Đã hồi +1 Lượt Đấu Trường (Hiện có: $turns lượt) & +100 Gem ủng hộ nhà phát triển!',
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
              'Mỗi ngày Đấu Trường tặng 5 lượt miễn phí. Bạn có thể xem 1 video (15 giây) để hồi ngay +1 lượt & nhận +100 Gem, hoặc dùng Gem tích lũy (hiện có: $availablePoints Gem) để đổi sang lượt chơi!',
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
                  'Xem Video 15s (+1 Lượt & +100 Gem)',
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
                icon: const SolfaGemIcon(size: 16),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Đổi 100 Gem → +1 Lượt ($availablePoints Gem)',
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
    final isEn = ref.watch(appSettingsProvider).isEnglish;

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
                Expanded(
                  child: Text(
                    isEn ? '1v1 Music Battle Arena' : 'Đấu Trường Âm Nhạc 1v1',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
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
    final isEn = ref.watch(appSettingsProvider).isEnglish;
    final rank = state.rankInfo;
    final rankColor = Color(rank.colorHex);
    final winRate = state.totalMatches > 0
        ? ((state.totalWins / state.totalMatches) * 100).round()
        : 0;

    return ListView(
      key: const Key('battle_lobby_view'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        // 1. Rank hiện tại & Thanh tiến trình thăng hạng (Tối giản, không nhồi thống kê phụ)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: rankColor.withOpacity(0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: rankColor.withOpacity(0.55),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      rank.badgeIcon,
                      color: rankColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                isEn ? 'Rank ${rank.tierName}' : 'Hạng ${rank.tierName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                rank.heroTitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isEn
                              ? '${state.totalStars} / ${rank.nextTierStars} Stars to next rank'
                              : '${state.totalStars} / ${rank.nextTierStars} Sao để thăng hạng tiếp theo',
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
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: rank.progressToNextTier,
                  minHeight: 6,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Năng lượng đấu trường (Số lượt đấu còn lại & nút phụ không cạnh tranh với CTA chính)
        _buildDailyTurnsEnergyCard(context, ref, state, isDark),
        const SizedBox(height: 16),

        // 3. Chọn chế độ thi đấu (Đồng nhất 1 tông màu Primary khi chọn)
        Text(
          isEn ? 'Battle Mode' : 'Chế độ thi đấu',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildHorizontalArenaModeCard(
                key: const Key('btn_battle_mode_matchmaking'),
                title: isEn ? '1v1 Ranked' : 'Đấu Hạng 1v1',
                subtitle: isEn ? 'Matchmaking' : 'Ghép Rank',
                icon: Icons.radar_rounded,
                accent: AppColors.primary,
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
                title: isEn ? 'vs AI Bot' : 'Đấu Máy AI',
                subtitle: isEn ? '4 Tiers' : '4 Cấp độ',
                icon: Icons.smart_toy_rounded,
                accent: AppColors.primary,
                isSelected: state.mode == BattleMode.botAi,
                isDark: isDark,
                onTap: () => notifier.setBattleMode(BattleMode.botAi),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildHorizontalArenaModeCard(
                key: const Key('btn_battle_mode_local_pvp'),
                title: isEn ? '2P Split' : '2 Người 1 Máy',
                subtitle: isEn ? 'Split-Screen' : 'Chia màn hình',
                icon: Icons.people_alt_rounded,
                accent: AppColors.primary,
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
                            ? AppColors.primary
                            : AppColors.textSecondaryLight,
                      ),
                      label: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
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
        const SizedBox(height: 14),

        // 4. Chọn nội dung thi đấu
        const Text(
          'Nội dung thi đấu',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
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
                        fontSize: 12,
                        fontWeight: state.selectedTopicId == tId
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    selected: state.selectedTopicId == tId,
                    onSelected: (_) => notifier.setSelectedTopicId(tId),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 5. Hành động chính duy nhất: Bắt đầu trận đấu
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            key: const Key('btn_start_battle_now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: state.canStartBattle
                  ? AppColors.primary
                  : AppColors.accentAmber,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: state.isLoading
                ? null
                : () => _onTapStartOrRematch(context, ref),
            icon: state.canStartBattle
                ? const CrossedSwordsIcon(
                    size: 20,
                    color: Colors.white,
                    guardColor: Colors.white,
                  )
                : const Icon(Icons.smart_display_rounded, size: 20),
            label: Text(
              state.canStartBattle
                  ? 'Bắt đầu trận đấu (Còn ${state.remainingBattlesToday}/${BattleState.maxDailyFreeBattles} lượt)'
                  : 'Hết lượt • Xem QC hoặc đổi điểm hồi lượt',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 6. Khu vực "Thành tích & Lịch sử" (Tách biệt khỏi thẻ Rank đầu trang)
        _buildAchievementsAndHistorySection(state, winRate, isDark),
      ],
    );
  }

  Widget _buildAchievementsAndHistorySection(
    BattleState state,
    int winRate,
    bool isDark,
  ) {
    return Container(
      key: const Key('card_battle_match_history'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thành tích & Lịch sử đấu',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMiniStatPill('Trận thắng', '${state.totalWins}', isDark),
              const SizedBox(width: 8),
              _buildMiniStatPill('Tổng trận', '${state.totalMatches}', isDark),
              const SizedBox(width: 8),
              _buildMiniStatPill('Tỷ lệ thắng', '$winRate%', isDark),
              const SizedBox(width: 8),
              _buildMiniStatPill(
                'Chuỗi thắng',
                'x${state.currentWinStreak}',
                isDark,
              ),
            ],
          ),
          if (state.matchHistory.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (int i = 0; i < state.matchHistory.take(5).length; i++) ...[
              if (i > 0) const Divider(height: 10),
              Builder(
                builder: (context) {
                  final rec = state.matchHistory[i];
                  final badgeColor = rec.isDraw
                      ? AppColors.accentAmber
                      : (rec.didWin ? AppColors.correct : AppColors.wrong);
                  final badgeText =
                      rec.isDraw ? 'Hòa' : (rec.didWin ? 'Thắng' : 'Thua');
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${rec.player1Hp}-${rec.player2Hp} HP',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasTurns
              ? (isDark ? AppColors.borderDark : AppColors.borderLight)
              : AppColors.wrong.withOpacity(0.55),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasTurns
                      ? 'Lượt đấu hôm nay: $remaining / $maxFree lượt'
                      : 'Đã hết $maxFree/$maxFree lượt miễn phí hôm nay',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: hasTurns ? null : AppColors.wrong,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SolfaGemIcon(size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '$availablePoints Gem',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
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
                    duration: const Duration(milliseconds: 240),
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < remaining
                          ? AppColors.primary
                          : (isDark
                              ? Colors.white.withOpacity(0.10)
                              : AppColors.borderLight),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Subtle secondary recovery actions (do not compete with Start Match CTA)
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
                    side: BorderSide(
                      color:
                          isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _handleWatchAdForTurn(context, ref),
                  icon: const Icon(Icons.smart_display_outlined, size: 15),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '+1 Lượt (Xem QC)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
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
                      color: canRedeem
                          ? AppColors.correct.withOpacity(0.55)
                          : (isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight),
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
                  icon: const SolfaGemIcon(size: 13),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Đổi 100 Gem → +1 Lượt',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: canRedeem ? AppColors.correct : null,
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

  Widget _buildMiniStatPill(String label, String value, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
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

  String _shortBattlePrompt(String rawPrompt) {
    String out = rawPrompt.replaceAll(' (hoặc bấm phím đàn)', '').trim();
    if (out.startsWith('[')) {
      final closeIdx = out.indexOf(']');
      if (closeIdx != -1 && closeIdx + 1 < out.length) {
        out = out.substring(closeIdx + 1).trim();
      }
    }
    return out;
  }

  Widget _buildFightingArenaView(
    BuildContext context,
    WidgetRef ref,
    BattleState state,
    bool isDark,
  ) {
    final notifier = ref.read(battleProvider.notifier);
    final audioService = ref.watch(audioServiceProvider);
    final p1Q = state.player1Question ?? state.currentQuestion;
    final p2Q = state.player2Question ?? state.currentQuestion;
    if (p1Q == null) return const SizedBox.shrink();

    final showStaff = p1Q.isSightReading ||
        (p1Q.topicId == 'topic_notes' && state.isRoundResolved);

    return TweenAnimationBuilder<double>(
      key: ValueKey('shake_${state.strikeSerial}'),
      tween: Tween<double>(
        begin: state.strikeSerial > 0 ? 1.0 : 0.0,
        end: 0.0,
      ),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      builder: (context, shakeProgress, child) {
        final amplitude = state.strikeCombo >= 3
            ? 8.0
            : (state.strikeCombo == 2 ? 5.0 : 2.5);
        final dx = math.sin(shakeProgress * math.pi * 6) *
            amplitude *
            shakeProgress;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: ListView(
        key: const Key('battle_fighting_arena_view'),
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
        children: [
          // 1. Top RPG Dual Fighter Health Bar HUD + Lightning Bolt Strike Overlay
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: state.strikeSerial > 0 && state.strikeCombo >= 2
                        ? const Color(0xFFF59E0B).withOpacity(0.65)
                        : (isDark
                            ? Colors.white.withOpacity(0.14)
                            : const Color(0xFFD8E4F8)),
                    width: state.strikeSerial > 0 && state.strikeCombo >= 2
                        ? 1.6
                        : 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Fighter 1 HP & Independent Question Progress
                        Expanded(
                          child: _buildFighterHudSide(
                            name: state.player1Name,
                            hp: state.player1Hp,
                            combo: state.player1Combo,
                            questionStep:
                                'Câu ${state.p1RoundIndex + 1}/${state.totalRounds}',
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
                                  color: const Color(0xFFF59E0B)
                                      .withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.flash_on_rounded,
                                      size: 12,
                                      color: Color(0xFFF59E0B),
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'ĐỘC LẬP',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ],
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
                        // Fighter 2 HP & Independent Question Progress
                        Expanded(
                          child: _buildFighterHudSide(
                            name: state.player2Name,
                            hp: state.player2Hp,
                            combo: state.player2Combo,
                            questionStep:
                                'Câu ${state.p2RoundIndex + 1}/${state.totalRounds}',
                            color: const Color(0xFFEC4899),
                            alignRight: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: (state.roundRemainingDeciseconds / 80.0)
                            .clamp(0.0, 1.0),
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
              if (state.strikeSerial > 0 && state.strikeTarget != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('lightning_${state.strikeSerial}'),
                      tween: Tween<double>(begin: 1.0, end: 0.0),
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOut,
                      builder: (context, flashOpacity, _) {
                        if (flashOpacity <= 0.02) {
                          return const SizedBox.shrink();
                        }
                        return CustomPaint(
                          painter: _LightningStrikePainter(
                            strikeRightSide: state.strikeTarget == 'p2',
                            comboLevel: state.strikeCombo,
                            opacity: flashOpacity,
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),

          // 2. Floating Combat Damage / Lightning Combo Banner
          if (state.combatBannerText != null) ...[
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              key: ValueKey(
                  'banner_${state.strikeSerial}_${state.combatBannerText}'),
              tween: Tween<double>(begin: 0.92, end: 1.0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: child,
              ),
              child: Container(
                key: const Key('battle_combat_banner'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: state.lastHitWasCrit || state.strikeCombo >= 2
                        ? [const Color(0xFFF59E0B), const Color(0xFFEC4899)]
                        : (state.roundWinner == 'p1'
                            ? [const Color(0xFF10B981), const Color(0xFF059669)]
                            : [
                                const Color(0xFFEC4899),
                                const Color(0xFFBE185D)
                              ]),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (state.lastHitWasCrit || state.strikeCombo >= 2
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
                      state.lastHitWasCrit || state.strikeCombo >= 2
                          ? Icons.flash_on_rounded
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
                          fontSize: 12.5,
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

          // 3. Independent Combat Interfaces:
          // - In Local Split-Screen: 2 independent stations (Player 1 has their own question & options, Player 2 has their own question & options!)
          // - In 1v1 Bot / Matchmaking: Player 1's own continuous question board (Opponent attacks independently in real time)
          if (state.mode == BattleMode.localSplitScreen && p2Q != null)
            _buildSplitScreenControls(
              context,
              notifier,
              audioService,
              state,
              p1Q,
              p2Q,
              isDark,
            )
          else ...[
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
                    _shortBattlePrompt(p1Q.prompt),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (showStaff) ...[
                    MusicalStaffWidget(
                      targetNoteKey: p1Q.correctOption.optionKey,
                      showNote: state.isRoundResolved,
                      isSightReading: p1Q.isSightReading,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (p1Q.hasQuestionAudio)
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
                        onPressed: () => audioService.playAsset(p1Q.audioAsset),
                        icon: const Icon(
                          Icons.volume_up_rounded,
                          color: Color(0xFF6366F1),
                        ),
                        label: const Text(
                          'Nghe lại âm thanh câu này',
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
            _buildSingleFighterControls(context, notifier, state, p1Q, isDark),
          ],

          if (state.isRoundResolved) ...[
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
      ),
    );
  }

  Widget _buildFighterHudSide({
    required String name,
    required int hp,
    required int combo,
    required String questionStep,
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
        Row(
          mainAxisAlignment:
              alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                '$hp HP • $questionStep',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.8,
                  fontWeight: FontWeight.w800,
                  color: hpColor,
                ),
              ),
            ),
          ],
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
            Icons.flash_on_rounded,
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

  /// Giao diện Chiến đấu 2 Người 1 Máy:
  /// - Hỗ trợ chuyển đổi giữa "Ngồi cạnh nhau (Trái/Phải)" và "Ngồi đối diện bàn (Xoay 180° nửa trên)".
  /// - Mỗi bên có một giao diện câu hỏi, nút nghe và 4 đáp án riêng biệt, đánh độc lập không chờ nhau!
  Widget _buildSplitScreenControls(
    BuildContext context,
    BattleNotifier notifier,
    dynamic audioService,
    BattleState state,
    QuestionModel p1Q,
    QuestionModel p2Q,
    bool isDark,
  ) {
    const badges = ['A', 'B', 'C', 'D'];

    final p1Station = Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 26,
                  minHeight: 26,
                ),
                icon: const Icon(
                  Icons.volume_up_rounded,
                  size: 16,
                  color: Color(0xFF4F46E5),
                ),
                onPressed: () => audioService.playAsset(p1Q.audioAsset),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _shortBattlePrompt(p1Q.prompt),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < p1Q.options.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _buildBattleOptionTile(
              key: Key('battle_p1_opt_$i'),
              badge: badges[i % badges.length],
              option: p1Q.options[i],
              isResolved: state.isRoundResolved || state.p1LockedOut,
              selectedOptionId: state.p1SelectedOptionId,
              accentColor: const Color(0xFF4F46E5),
              isDark: isDark,
              compact: true,
              onTap: () => notifier.submitPlayer1Answer(p1Q.options[i]),
            ),
          ],
        ],
      ),
    );

    final p2Station = Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEC4899),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 26,
                  minHeight: 26,
                ),
                icon: const Icon(
                  Icons.volume_up_rounded,
                  size: 16,
                  color: Color(0xFFEC4899),
                ),
                onPressed: () => audioService.playAsset(p2Q.audioAsset),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _shortBattlePrompt(p2Q.prompt),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < p2Q.options.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _buildBattleOptionTile(
              key: Key('battle_p2_opt_$i'),
              badge: badges[i % badges.length],
              option: p2Q.options[i],
              isResolved: state.isRoundResolved || state.p2LockedOut,
              selectedOptionId: state.p2SelectedOptionId,
              accentColor: const Color(0xFFEC4899),
              isDark: isDark,
              compact: true,
              onTap: () => notifier.submitPlayer2Answer(p2Q.options[i]),
            ),
          ],
        ],
      ),
    );

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('btn_toggle_split_tabletop_180'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: AppColors.primary.withOpacity(0.10),
            ),
            onPressed: () => setState(
              () => _isTabletopOpposite180 = !_isTabletopOpposite180,
            ),
            icon: Icon(
              _isTabletopOpposite180
                  ? Icons.view_column_rounded
                  : Icons.screen_rotation_alt_rounded,
              size: 15,
            ),
            label: Text(
              _isTabletopOpposite180
                  ? 'Chế độ: Ngồi đối diện (180°) • Đổi sang Ngồi cạnh'
                  : 'Đổi sang: Ngồi đối diện bàn (Xoay 180°)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (_isTabletopOpposite180) ...[
          RotatedBox(
            quarterTurns: 2,
            child: p2Station,
          ),
          const SizedBox(height: 10),
          p1Station,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: p1Station),
              const SizedBox(width: 8),
              Expanded(child: p2Station),
            ],
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
                      const SolfaGemIcon(size: 15),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Thưởng Thăng Hạng ${state.rankInfo.tierName}: +${state.lastRankUpBonusPoints} Gem!',
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
                        'Nhận ngay +40 Gem thưởng nhiệm vụ ngày',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
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
                      showGemRewardAnimation(
                        context,
                        gemsAdded: pts,
                        subtitle: 'Nhiệm vụ Chiến binh Đấu Trường',
                        isTestMode: ref.read(audioServiceProvider).isTestMode,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.correct,
                          content: Text(
                            'Đã nhận +$pts Gem từ nhiệm vụ Chiến binh Đấu Trường!',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const SolfaGemIcon(size: 13),
                  label: const Text(
                    'Nhận +40 Gem',
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

/// CustomPainter vẽ hiệu ứng Tia Sét Lôi Điện (Lightning Strike) đánh thẳng vào thanh máu mục tiêu khi tung đòn / dồn Combo.
class _LightningStrikePainter extends CustomPainter {
  final bool strikeRightSide;
  final int comboLevel;
  final double opacity;

  const _LightningStrikePainter({
    required this.strikeRightSide,
    required this.comboLevel,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effOpacity = opacity.clamp(0.0, 1.0);
    if (effOpacity <= 0.01) return;

    final targetX =
        strikeRightSide ? size.width * 0.78 : size.width * 0.22;
    final targetY = size.height * 0.55;

    final Color boltColor = comboLevel >= 3
        ? const Color(0xFFEC4899)
        : (comboLevel >= 2
            ? const Color(0xFFF59E0B)
            : const Color(0xFF38BDF8));

    // Vòng hào quang chấn động tại điểm sét đánh trúng thanh máu
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          boltColor.withOpacity(0.55 * effOpacity),
          boltColor.withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(targetX, targetY),
          radius: comboLevel >= 2 ? 56.0 : 38.0,
        ),
      );
    canvas.drawCircle(
      Offset(targetX, targetY),
      comboLevel >= 2 ? 56.0 : 38.0,
      glowPaint,
    );

    // Đường tia sét chính zig-zag từ đỉnh xuống điểm nổ
    final mainPath = Path()
      ..moveTo(targetX - 10, -6)
      ..lineTo(targetX + 8, size.height * 0.18)
      ..lineTo(targetX - 7, size.height * 0.34)
      ..lineTo(targetX + 6, size.height * 0.46)
      ..lineTo(targetX, targetY);

    final outerBoltPaint = Paint()
      ..color = boltColor.withOpacity(0.85 * effOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = comboLevel >= 2 ? 5.0 : 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(mainPath, outerBoltPaint);

    final coreBoltPaint = Paint()
      ..color = Colors.white.withOpacity(0.95 * effOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(mainPath, coreBoltPaint);

    // Nhánh sét phụ khi dồn Combo (x2, x3+)
    if (comboLevel >= 2) {
      final branchPath = Path()
        ..moveTo(targetX - 7, size.height * 0.34)
        ..lineTo(targetX - 24, size.height * 0.48)
        ..lineTo(targetX - 18, size.height * 0.62);
      final branchPaint = Paint()
        ..color = const Color(0xFFFFE082).withOpacity(0.85 * effOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(branchPath, branchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LightningStrikePainter oldDelegate) {
    return oldDelegate.opacity != opacity ||
        oldDelegate.strikeRightSide != strikeRightSide ||
        oldDelegate.comboLevel != comboLevel;
  }
}
