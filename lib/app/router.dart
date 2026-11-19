import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/battle/presentation/battle_screen.dart';
import '../features/guitar/presentation/guitar_studio_sheet.dart';
import '../features/guitar/presentation/interactive_songbook_and_theory_sheet.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/splash_screen.dart';
import '../features/metronome/presentation/metronome_screen.dart';
import '../features/practice/presentation/chord_progression_ear_screen.dart';
import '../features/practice/presentation/quiz_screen.dart';
import '../features/practice/presentation/session_result_screen.dart';
import '../features/practice/presentation/widgets/free_piano_explorer_sheet.dart';
import '../features/progress/presentation/achievements_trophy_screen.dart';
import '../features/progress/presentation/progress_screen.dart';
import '../features/review/presentation/review_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/support_developer/presentation/support_developer_screen.dart';
import '../features/topics/presentation/topic_detail_screen.dart';
import '../features/topics/presentation/topics_screen.dart';
import 'main_shell.dart';

GoRouter createSolfaRouter({String initialLocation = '/'}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
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

      // UI-13: Đấu Trường Âm Nhạc 1v1 (Battle Arena)
      GoRoute(
        path: '/battle',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BattleScreen(),
      ),

      // UI-14: Kho Bản Nhạc Tương Tác (20 bài + Tự soạn) — Full-screen Root Route
      GoRoute(
        path: '/songbook',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SongbookCatalogScreen(),
      ),

      // UI-15: Vòng Tròn Bậc 5 & Dịch Giọng Capo — Full-screen Root Route
      GoRoute(
        path: '/circle-of-fifths',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CircleOfFifthsAndCapoScreen(),
      ),

      // UI-16: Luyện Dò Vòng Hợp Âm Đệm Hát — Full-screen Root Route
      GoRoute(
        path: '/chord-progression-ear',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ChordProgressionEarScreen(),
      ),

      // UI-17: Phòng Truyền Thống Huy Hiệu & Thẻ Thành Tích — Full-screen Root Route
      GoRoute(
        path: '/achievements',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AchievementsTrophyScreen(),
      ),

      // UI-18: Đàn Piano Tự Do & Chép Giai Điệu C3–C5 — Full-screen Root Route
      GoRoute(
        path: '/piano-explorer',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FreePianoExplorerSheet(),
      ),

      // UI-19: Công Cụ Guitar Chuyên Sâu (Map Cần đàn / 44 Hợp âm / Scale / Luyện ngón) — Full-screen Root Route
      GoRoute(
        path: '/guitar-studio',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
          final workout = state.uri.queryParameters['workout'] == '1';
          final single = state.uri.queryParameters['single'] != '0';
          return GuitarStudioSheet(
            initialTab: tab,
            isWorkoutOnlyPage: workout,
            singleTabMode: single,
          );
        },
      ),
    ],
  );
}

