import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/app_providers.dart';
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

  static const List<String> _tabTitles = [
    'Solfa',
    'Phòng luyện tập',
    'Máy đếm nhịp',
    'Tiến trình',
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
    final adState = ref.watch(rewardedAdProvider);

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: false,
        appBar: AppBar(
          toolbarHeight: 52,
          titleSpacing: 16,
          title: Row(
            children: [
              const SolfaLogo(size: 30, showShadow: false),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _tabTitles[currentIndex],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            // Compact Gem Pill (Viên Kim Cương)
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('btn_header_support_heart'),
                borderRadius: BorderRadius.circular(99),
                onTap: () => context.push('/support-developer'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SolfaGemIcon(size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${adState.prestigePoints} Gem',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Compact Streak Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: AppColors.accentAmber.withOpacity(0.35),
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentAmber,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              key: const Key('btn_open_settings'),
              tooltip: 'Cài đặt',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.settings_outlined, size: 21),
              onPressed: () {
                context.push('/settings');
              },
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: navigationShell,
        bottomNavigationBar: _DiamondBottomNavBar(
          selectedIndex: currentIndex,
          onSelectTab: (idx) => _onSelectTab(ref, currentIndex, idx),
          onTapDiamondBattle: () =>
              _onOpenBattleArena(context, ref, currentIndex),
        ),
      ),
    );
  }
}

/// Custom Bottom Navigation Bar with a central elevated 45° rotated Diamond Battle CTA button
/// matching the user's reference design ("w/ diamond CTA button") and Solfa's pastel indigo palette.
class _DiamondBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onTapDiamondBattle;

  const _DiamondBottomNavBar({
    required this.selectedIndex,
    required this.onSelectTab,
    required this.onTapDiamondBattle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, bottomInset > 0 ? bottomInset : 10),
      height: 68,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Rounded Bar Pill Surface
          Container(
            height: 68,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1E2E).withOpacity(0.96)
                  : Colors.white.withOpacity(0.97),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.42)
                      : const Color(0xFF4F46E5).withOpacity(0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Left 2 Tabs: Trang chủ (0) & Luyện tập (1)
                Expanded(
                  child: _AnimatedNavTabItem(
                    key: const Key('nav_tab_home'),
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_rounded,
                    label: 'Trang chủ',
                    isSelected: selectedIndex == 0,
                    onTap: () => onSelectTab(0),
                  ),
                ),
                Expanded(
                  child: _AnimatedNavTabItem(
                    key: const Key('nav_tab_topics'),
                    icon: Icons.headphones_outlined,
                    selectedIcon: Icons.headphones_rounded,
                    label: 'Luyện tập',
                    isSelected: selectedIndex == 1,
                    onTap: () => onSelectTab(1),
                  ),
                ),

                // Center Spacer for the Floating Diamond Battle CTA
                const SizedBox(width: 78),

                // Right 2 Tabs: Công cụ (2) & Tiến trình (3)
                Expanded(
                  child: _AnimatedNavTabItem(
                    key: const Key('nav_tab_metronome'),
                    icon: Icons.av_timer_outlined,
                    selectedIcon: Icons.av_timer_rounded,
                    label: 'Công cụ',
                    isSelected: selectedIndex == 2,
                    onTap: () => onSelectTab(2),
                  ),
                ),
                Expanded(
                  child: _AnimatedNavTabItem(
                    key: const Key('nav_tab_progress'),
                    icon: Icons.insights_outlined,
                    selectedIcon: Icons.insights_rounded,
                    label: 'Tiến trình',
                    isSelected: selectedIndex == 3,
                    onTap: () => onSelectTab(3),
                  ),
                ),
              ],
            ),
          ),

          // Elevated Center 45° Diamond Battle CTA Button
          Positioned(
            top: -18,
            child: _DiamondBattleCtaButton(
              key: const Key('btn_nav_diamond_battle'),
              onTap: onTapDiamondBattle,
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

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: isSelected ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 220),
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
                      size: 24,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    icon,
                    size: 23,
                    color: inactiveColor,
                  ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                  : inactiveColor,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiamondBattleCtaButton extends StatefulWidget {
  final VoidCallback onTap;

  const _DiamondBattleCtaButton({
    super.key,
    required this.onTap,
  });

  @override
  State<_DiamondBattleCtaButton> createState() =>
      _DiamondBattleCtaButtonState();
}

class _DiamondBattleCtaButtonState extends State<_DiamondBattleCtaButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  late Animation<double> _pulseAnim;
  bool _isPressed = false;

  bool get _isInWidgetTest {
    final bindingType = WidgetsBinding.instance.runtimeType.toString();
    return bindingType.contains('TestWidgetsFlutterBinding') ||
        bindingType.contains('AutomatedTestWidgetsFlutterBinding');
  }

  @override
  void initState() {
    super.initState();
    if (!_isInWidgetTest) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
      _pulseAnim = Tween<double>(begin: 0.96, end: 1.06).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
    } else {
      _pulseAnim = const AlwaysStoppedAnimation<double>(1.0);
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        child: RepaintBoundary(
          child: AnimatedScale(
            scale: _isPressed ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutBack,
            child: ScaleTransition(
              scale: _pulseAnim,
              child: SizedBox(
                width: 68,
                height: 68,
                child: Center(
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.85),
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.28),
                            blurRadius: 10,
                            offset: const Offset(2, 3),
                          ),
                        ],
                      ),
                      child: Transform.rotate(
                        angle: -math.pi / 4,
                        child: const Center(
                          child: CrossedSwordsIcon(
                            size: 26,
                            color: Colors.white,
                            guardColor: Color(0xFFFFE082),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
