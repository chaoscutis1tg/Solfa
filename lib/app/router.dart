import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/splash_screen.dart';
import '../features/metronome/presentation/metronome_screen.dart';
import '../features/practice/presentation/quiz_screen.dart';
import '../features/practice/presentation/session_result_screen.dart';
import '../features/progress/presentation/progress_screen.dart';
import '../features/review/presentation/review_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/support_developer/presentation/support_developer_screen.dart';
import '../features/topics/presentation/topic_detail_screen.dart';
import '../features/topics/presentation/topics_screen.dart';
import 'main_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createSolfaRouter({String initialLocation = '/'}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      // UI-01: Splash / Khởi động
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // 4-tab Bottom Navigation Shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: UI-02 Trang chủ
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Tab 2: UI-03 Danh sách chủ đề & UI-04 Chi tiết chủ đề
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/topics',
                builder: (context, state) => const TopicsScreen(),
                routes: [
                  GoRoute(
                    path: ':topicId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final topicId = state.pathParameters['topicId']!;
                      return TopicDetailScreen(topicId: topicId);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Tab 3: UI-10 Máy đếm nhịp (Metronome)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/metronome',
                builder: (context, state) => const MetronomeScreen(),
              ),
            ],
          ),

          // Tab 4: UI-09 Tiến trình & Lịch sử
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
        ],
      ),

      // UI-05 & UI-06: Màn hình câu hỏi & Phản hồi
      GoRoute(
        path: '/quiz',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const QuizScreen(),
      ),

      // UI-07: Kết quả phiên
      GoRoute(
        path: '/session-result',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SessionResultScreen(),
      ),

      // UI-08: Ôn tập câu sai
      GoRoute(
        path: '/review',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReviewScreen(),
      ),

      // UI-11: Cài đặt
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),

      // UI-12: Hỗ trợ nhà phát triển
      GoRoute(
        path: '/support-developer',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SupportDeveloperScreen(),
      ),
    ],
  );
}

