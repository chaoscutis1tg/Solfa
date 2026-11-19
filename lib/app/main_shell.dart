import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/app_providers.dart';
import '../features/home/presentation/streak_shield_and_reminder_sheet.dart';
import '../features/metronome/application/metronome_controller.dart';
import '../features/support_developer/application/rewarded_ad_controller.dart';
import 'theme/app_colors.dart';
import 'widgets/crossed_swords_icon.dart';
import 'widgets/solfa_background.dart';
import 'widgets/solfa_gem_icon.dart';
import 'widgets/solfa_logo.dart';

class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({
    super.key,
    required this.navigationShell,
  });

  static const List<String> _tabTitlesVi = [
    'ChaoNote',
    'Phòng luyện tập',
    'Máy đếm nhịp',
    'Tiến trình',
  ];

  static const List<String> _tabTitlesEn = [
    'ChaoNote',
    'Practice Room',
    'Metronome',
    'Progress',
  ];

  void _onSelectTab(WidgetRef ref, int currentIndex, int targetIndex) {
    if (currentIndex == 2 && targetIndex != 2) {
      // Stop metronome when leaving the Tools tab (Section 12.4)
      ref.read(metronomeProvider.notifier).stop();
    }
    navigationShell.goBranch(
      targetIndex,
      initialLocation: targetIndex == navigationShell.currentIndex,
    );
  }

  void _onOpenBattleArena(BuildContext context, WidgetRef ref, int currentIndex) {
    if (currentIndex == 2) {
      ref.read(metronomeProvider.notifier).stop();
    }
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
    context.push('/battle');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    final progressAsync = ref.watch(overallProgressProvider);
    final streakDays = progressAsync.valueOrNull?.currentStreakDays ?? 0;
    final shieldCount = ref.watch(streakShieldReminderProvider).shieldCount;
    final adState = ref.watch(rewardedAdProvider);
    final isEn = ref.watch(appSettingsProvider).isEnglish;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: false,
        appBar: AppBar(
          toolbarHeight: 52,
          titleSpacing: 16,
          title: Row(
            children: [
              if (currentIndex == 0) ...[
                const SolfaLogo(size: 28, showShadow: false),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    (isEn ? _tabTitlesEn : _tabTitlesVi)[currentIndex],
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            // Compact Gem Pill: [💎 220] (chỉ hiện Icon + Số, gọn gàng & hiện đại)
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('btn_header_support_heart'),
                borderRadius: BorderRadius.circular(99),
                onTap: () => context.push('/support-developer'),
                child: Container(
                  height: 28,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(isDark ? 0.16 : 0.11),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color:
                          AppColors.primary.withOpacity(isDark ? 0.45 : 0.32),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SolfaGemIcon(size: 13.5),
                      const SizedBox(width: 4),
                      Text(
                        '${adState.prestigePoints}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Compact Streak & Shield Pill: [🔥 0 🛡️] -> Mở bảng Khiên Giữ Chuỗi & Giờ Nhắc Học ở mọi tab
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('btn_header_streak_shield'),
                borderRadius: BorderRadius.circular(99),
                onTap: () => showStreakShieldAndReminderSheet(context),
                child: Container(
                  height: 28,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        AppColors.accentAmber.withOpacity(isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: AppColors.accentAmber
                          .withOpacity(isDark ? 0.45 : 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: AppColors.accentAmber,
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$streakDays',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFD97706),
                        ),
                      ),
                      if (shieldCount > 0) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.shield_rounded,
                          color: Color(0xFF0EA5E9),
                          size: 12.5,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              key: const Key('btn_open_settings'),
              tooltip: isEn ? 'Settings' : 'Cài đặt',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: const EdgeInsets.all(6),
              icon: const Icon(Icons.settings_outlined, size: 20),
              onPressed: () {
                context.push('/settings');
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: navigationShell,
        bottomNavigationBar: _DiamondBottomNavBar(
          selectedIndex: currentIndex,
          isEn: isEn,
          onSelectTab: (idx) => _onSelectTab(ref, currentIndex, idx),
          onTapDiamondBattle: () =>
              _onOpenBattleArena(context, ref, currentIndex),
        ),
      ),
    );
  }
}

/// Thanh điều hướng đáy phẳng (Flush 5-Slot Navigation Dock):
/// - Nút Đấu trường 1v1 nằm ngang hàng gọn gàng bên trong thanh menu (không nhô cao lên trên).
/// - Tab đang chọn có hiệu ứng vạch sáng trên đỉnh + khung pill màu nổi bật + phóng to icon mượt mà.
class _DiamondBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final bool isEn;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onTapDiamondBattle;

  const _DiamondBottomNavBar({
    required this.selectedIndex,
    required this.isEn,
    required this.onSelectTab,
    required this.onTapDiamondBattle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(12, 4, 12, bottomInset > 0 ? bottomInset : 10),
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF161B2C).withOpacity(0.97)
            : Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.10)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.45)
                : const Color(0xFF4F46E5).withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _AnimatedNavTabItem(
              key: const Key('nav_tab_home'),
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: isEn ? 'Home' : 'Trang chủ',
              isSelected: selectedIndex == 0,
              onTap: () => onSelectTab(0),
            ),
          ),
          Expanded(
            child: _AnimatedNavTabItem(
              key: const Key('nav_tab_topics'),
              icon: Icons.headphones_outlined,
              selectedIcon: Icons.headphones_rounded,
              label: isEn ? 'Practice' : 'Luyện tập',
              isSelected: selectedIndex == 1,
              onTap: () => onSelectTab(1),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: _InlineBattleNavButton(
                key: const Key('btn_nav_diamond_battle'),
                label: isEn ? 'Battle' : 'Chiến đấu',
                onTap: onTapDiamondBattle,
              ),
            ),
          ),
          Expanded(
            child: _AnimatedNavTabItem(
              key: const Key('nav_tab_metronome'),
              icon: Icons.av_timer_outlined,
              selectedIcon: Icons.av_timer_rounded,
              label: isEn ? 'Tools' : 'Công cụ',
              isSelected: selectedIndex == 2,
              onTap: () => onSelectTab(2),
            ),
          ),
          Expanded(
            child: _AnimatedNavTabItem(
              key: const Key('nav_tab_progress'),
              icon: Icons.insights_outlined,
              selectedIcon: Icons.insights_rounded,
              label: isEn ? 'Progress' : 'Tiến trình',
              isSelected: selectedIndex == 3,
              onTap: () => onSelectTab(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedNavTabItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedNavTabItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final activeTextColor =
        isDark ? const Color(0xFF93C5FD) : AppColors.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(isDark ? 0.22 : 0.11)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(isDark ? 0.45 : 0.24)
                : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Vạch sáng trên đỉnh tab đang chọn (Active Indicator Pill)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: isSelected ? 22 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            AnimatedScale(
              scale: isSelected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: isSelected
                  ? ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Icon(
                        selectedIcon,
                        size: 22,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      icon,
                      size: 21,
                      color: inactiveColor,
                    ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? activeTextColor : inactiveColor,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút Chiến đấu 1v1 thiết kế phẳng ngang hàng với 4 tab menu (không nhô cao khỏi thanh điều hướng).
class _InlineBattleNavButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _InlineBattleNavButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  State<_InlineBattleNavButton> createState() => _InlineBattleNavButtonState();
}

class _InlineBattleNavButtonState extends State<_InlineBattleNavButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: 'Đấu trường Chiến đấu 1v1',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(isDark ? 0.20 : 0.45),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withOpacity(0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CrossedSwordsIcon(
                  size: 20,
                  color: Colors.white,
                  guardColor: Color(0xFFFFE082),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.1,
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
}
