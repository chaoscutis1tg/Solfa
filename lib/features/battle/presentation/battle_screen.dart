import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../practice/presentation/widgets/musical_staff_widget.dart';
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
                  child: const Icon(
                    Icons.sports_kabaddi_rounded,
                    color: Colors.white,
                    size: 18,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        // 1. Rank & Stars Hero Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1B4B), const Color(0xFF311042)]
                  : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.38),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      rank.badgeIcon,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BẬC XẾP HẠNG HIỆN TẠI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hạng ${rank.tierName}',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
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
                                '${state.totalStars} / ${rank.nextTierStars} Sao để thăng bậc tiếp theo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.88),
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
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: rank.progressToNextTier,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.18),
                  valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                ),
              ),
              const SizedBox(height: 12),
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
        const SizedBox(height: 18),

        // 2. Choose Battle Mode (Smart Matchmaking / Bot AI / Local 2P Split-Screen)
        const Text(
          '1. Chọn Chế Độ Thi Đấu',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _buildModeOptionCard(
          key: const Key('btn_battle_mode_matchmaking'),
          title: 'Ghép Trận Ngẫu Nhiên 1v1',
          subtitle:
              'Hệ thống quét Radar ghép đối thủ cùng mức Rank, thắng nhận +1 đến +2 Sao',
          icon: Icons.radar_rounded,
          accent: const Color(0xFF6366F1),
          isSelected: state.mode == BattleMode.smartMatchmaking,
          isDark: isDark,
          onTap: () => notifier.setBattleMode(BattleMode.smartMatchmaking),
        ),
        const SizedBox(height: 8),
        _buildModeOptionCard(
          key: const Key('btn_battle_mode_bot'),
          title: 'Khiêu Chiến Bot AI (4 Cấp Độ)',
          subtitle:
              'Luyện phản xạ tốc độ và chuỗi Combo Bạo kích cùng AI từ Tập Sự đến Huyền Thoại',
          icon: Icons.smart_toy_rounded,
          accent: const Color(0xFFEC4899),
          isSelected: state.mode == BattleMode.botAi,
          isDark: isDark,
          onTap: () => notifier.setBattleMode(BattleMode.botAi),
        ),
        if (state.mode == BattleMode.botAi) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (diff, label, botIcon) in const [
                (BotDifficulty.rookie, 'Tập Sự (Dễ)', Icons.smart_toy_rounded),
                (BotDifficulty.academy, 'Học Viện (Vừa)', Icons.school_rounded),
                (BotDifficulty.maestro, 'Nhạc Trưởng (Khó)', Icons.auto_awesome_rounded),
                (BotDifficulty.legend, 'Huyền Thoại (Siêu Cấp)', Icons.workspace_premium_rounded),
              ])
                ChoiceChip(
                  key: Key('chip_bot_${diff.name}'),
                  avatar: Icon(
                    botIcon,
                    size: 16,
                    color: state.botDifficulty == diff
                        ? const Color(0xFFEC4899)
                        : AppColors.textSecondaryLight,
                  ),
                  label: Text(label),
                  selected: state.botDifficulty == diff,
                  onSelected: (_) => notifier.setBotDifficulty(diff),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        _buildModeOptionCard(
          key: const Key('btn_battle_mode_local_pvp'),
          title: 'Đấu 2 Người Trên 1 Máy (Split-Screen)',
          subtitle:
              '2 người chơi đối kháng trực tiếp trên cùng 1 điện thoại — ai bấm đúng nhanh hơn sẽ tung đòn!',
          icon: Icons.people_alt_rounded,
          accent: const Color(0xFFF59E0B),
          isSelected: state.mode == BattleMode.localSplitScreen,
          isDark: isDark,
          onTap: () => notifier.setBattleMode(BattleMode.localSplitScreen),
        ),
        const SizedBox(height: 18),

        // 3. Choose Topic Filter
        const Text(
          '2. Chọn Nội Dung Thi Đấu',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (tId, tLabel, tIcon) in _battleTopics)
              ChoiceChip(
                key: Key('chip_battle_topic_$tId'),
                avatar: Icon(
                  tIcon,
                  size: 16,
                  color: state.selectedTopicId == tId
                      ? AppColors.primary
                      : AppColors.textSecondaryLight,
                ),
                label: Text(
                  tLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: state.selectedTopicId == tId
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
                selected: state.selectedTopicId == tId,
                onSelected: (_) => notifier.setSelectedTopicId(tId),
              ),
          ],
        ),
        const SizedBox(height: 22),

        // 4. Start Battle CTA Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            key: const Key('btn_start_battle_now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: state.isLoading ? null : () => notifier.startBattle(),
            icon: const Icon(Icons.flash_on_rounded, size: 22),
            label: const Text(
              'VÀO ĐẤU TRƯỜNG NGAY (10 HIỆP)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ],
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

  Widget _buildModeOptionCard({
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
          ? accent.withOpacity(isDark ? 0.22 : 0.11)
          : (isDark ? AppColors.surfaceDark : Colors.white),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? accent
                  : (isDark
                      ? Colors.white.withOpacity(0.14)
                      : const Color(0xFFD8E4F8)),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? accent : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected ? accent : AppColors.textSecondaryLight,
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
          const SizedBox(height: 22),

          // Fighter 1 Card
          _buildVsFighterCard(
            name: state.player1Name,
            subtitle: state.player1Title,
            icon: Icons.shield_rounded,
            accent: const Color(0xFF4F46E5),
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // Lightning VS Badge
          Container(
            width: 58,
            height: 58,
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
            child: const Text(
              'VS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Fighter 2 Card
          _buildVsFighterCard(
            name: state.player2Name,
            subtitle: state.player2Title,
            icon: state.player2AvatarIcon,
            accent: const Color(0xFFEC4899),
            isDark: isDark,
          ),
          const SizedBox(height: 28),

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
              icon: const Icon(Icons.bolt_rounded),
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
        border: Border.all(color: accent.withOpacity(0.65), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.16),
              shape: BoxShape.circle,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
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

        // 2. Floating Combat Damage / Crit Banner
        if (state.combatBannerText != null) ...[
          const SizedBox(height: 8),
          Container(
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
                curQ.prompt,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (showStaff)
                MusicalStaffWidget(
                  targetNoteKey: curQ.correctOption.optionKey,
                  showNote: state.isRoundResolved,
                  isSightReading: curQ.isSightReading,
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('btn_battle_play_audio'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
          child: LinearProgressIndicator(
            value: hpRatio,
            minHeight: 9,
            backgroundColor: color.withOpacity(0.14),
            valueColor: AlwaysStoppedAnimation<Color>(hpColor),
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
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            key: const Key('btn_battle_rematch'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            onPressed: () => notifier.startBattle(),
            icon: const Icon(Icons.replay_rounded),
            label: const Text(
              'TÁI ĐẤU NGAY',
              style: TextStyle(fontWeight: FontWeight.w900),
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
