import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/app_providers.dart';
import '../features/metronome/application/metronome_controller.dart';
import 'theme/app_colors.dart';
import 'widgets/solfa_background.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    final progressAsync = ref.watch(overallProgressProvider);
    final streakDays = progressAsync.valueOrNull?.currentStreakDays ?? 0;

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          titleSpacing: 16,
          title: Row(
            children: [
              const SolfaLogo(size: 36, showShadow: false),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _tabTitles[currentIndex],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.18),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: AppColors.accentAmber.withOpacity(0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.accentAmber,
                    size: 16,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$streakDays',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentAmber,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const Key('btn_open_settings'),
              tooltip: 'Cài đặt',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                context.push('/settings');
              },
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            if (currentIndex == 2 && index != 2) {
              // Stop metronome when leaving the Tools tab (Section 12.4)
              ref.read(metronomeProvider.notifier).stop();
            }
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.headphones_outlined),
              selectedIcon:
                  Icon(Icons.headphones_rounded, color: AppColors.primary),
              label: 'Luyện tập',
            ),
            NavigationDestination(
              icon: Icon(Icons.av_timer_outlined),
              selectedIcon:
                  Icon(Icons.av_timer_rounded, color: AppColors.primary),
              label: 'Công cụ',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon:
                  Icon(Icons.insights_rounded, color: AppColors.primary),
              label: 'Tiến trình',
            ),
          ],
        ),
      ),
    );
  }
}
