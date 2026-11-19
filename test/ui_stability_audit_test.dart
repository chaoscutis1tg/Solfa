import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfa/app/app.dart';
import 'package:solfa/app/router.dart';
import 'package:solfa/app/theme/app_theme.dart';
import 'package:solfa/core/audio/audio_service.dart';
import 'package:solfa/core/database/app_database.dart';
import 'package:solfa/core/providers/app_providers.dart';
import 'package:solfa/features/battle/application/battle_controller.dart';
import 'package:solfa/features/battle/presentation/battle_screen.dart';
import 'package:solfa/features/guitar/presentation/custom_melody_composer_screen.dart';
import 'package:solfa/features/guitar/presentation/guitar_studio_sheet.dart';
import 'package:solfa/features/guitar/presentation/interactive_songbook_and_theory_sheet.dart';
import 'package:solfa/features/home/presentation/streak_shield_and_reminder_sheet.dart';
import 'package:solfa/features/metronome/application/metronome_controller.dart';
import 'package:solfa/features/practice/presentation/chord_progression_ear_screen.dart';
import 'package:solfa/features/progress/presentation/achievements_trophy_screen.dart';
import 'package:solfa/features/support_developer/application/rewarded_ad_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UI Stability & Zero-Overflow Stress Audit (360x680 & 320x568, Light & Dark)', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase.inMemory();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          audioServiceProvider.overrideWithValue(AudioService(isTestMode: true)),
          metronomeProvider.overrideWith(
            (ref) => MetronomeNotifier(ref, isTestMode: true),
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<void> pumpClean(WidgetTester tester, [int ms = 250]) async {
      await tester.pump();
      await tester.pump(Duration(milliseconds: ms));
      await tester.pump();
      final err = tester.takeException();
      expect(err, isNull, reason: 'Phát hiện lỗi giao diện: $err');
    }

    testWidgets(
      'AUDIT-01: MainShell 5-Slot Flush NavBar, TopicsScreen (Piano & Guitar), Metronome, Progress, Settings & Support on 360x680 Light & Dark',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 3.0, 680 * 3.0);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.runAsync(() async {
          await db.seedContent();
          await container.read(appSettingsProvider.notifier).loadSettings();
          await container.read(overallProgressProvider.future);
          await container.read(topicsListProvider.future);
        });

        final router = createSolfaRouter(initialLocation: '/home');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: SolfaApp(customRouter: router),
          ),
        );
        await pumpClean(tester, 300);

        // Kiểm tra cả Light Mode và Dark Mode qua tất cả các tab chính
        for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
          await tester.runAsync(() async {
            await container
                .read(appSettingsProvider.notifier)
                .setThemeMode(mode);
          });
          await pumpClean(tester);

          // Tab 0: Home
          await tester.tap(find.byKey(const Key('nav_tab_home')));
          await pumpClean(tester);

          // Tab 1: Topics (Piano & Guitar)
          await tester.tap(find.byKey(const Key('nav_tab_topics')));
          await pumpClean(tester);
          expect(find.byKey(const Key('btn_open_songbook_catalog')), findsOneWidget);

          await tester.tap(find.byKey(const Key('tab_practice_area_guitar')));
          await pumpClean(tester);
          await tester.tap(find.byKey(const Key('tab_practice_area_piano')));
          await pumpClean(tester);

          // Tab 2: Metronome / Tools
          await tester.tap(find.byKey(const Key('nav_tab_metronome')));
          await pumpClean(tester);

          // Tab 3: Progress
          await tester.tap(find.byKey(const Key('nav_tab_progress')));
          await pumpClean(tester);

          // Settings & Support (mở bằng push & đóng bằng pop đúng hành vi người dùng)
          router.push('/settings');
          await pumpClean(tester);
          router.pop();
          await pumpClean(tester);
          router.push('/support-developer');
          await pumpClean(tester);
          router.pop();
          await pumpClean(tester);
        }
      },
    );

    testWidgets(
      'AUDIT-02: SongbookCatalog (20 bài), SongPlayRoom (Ode to Joy & Canon Rock Fret 10-15, Guitar & Piano), Circle of 5ths & Standalone Guitar Tools trên 360x680 Light & Dark',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 3.0, 680 * 3.0);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.runAsync(() async {
          await db.seedContent();
          await container.read(appSettingsProvider.notifier).loadSettings();
        });

        final odeSong = kInteractiveSongbookCatalog.firstWhere(
          (s) => s.id == 'song_ode_to_joy',
        );
        final canonRock = kInteractiveSongbookCatalog.firstWhere(
          (s) => s.id == 'song_canon_rock',
        );

        int keySeq = 0;
        for (final isDark in const [false, true]) {
          final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;

          // 1. Danh sách Kho 20 bản nhạc (lọc Tất cả / Cổ điển / Hiện đại)
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                key: ValueKey('audit_cat_${keySeq++}'),
                theme: theme,
                home: const SongbookCatalogScreen(),
              ),
            ),
          );
          await pumpClean(tester);
          await tester.ensureVisible(
            find.byKey(const Key('chip_song_cat_classical')),
          );
          await tester.tap(find.byKey(const Key('chip_song_cat_classical')));
          await pumpClean(tester, 150);
          await tester.ensureVisible(
            find.byKey(const Key('chip_song_cat_modern')),
          );
          await tester.tap(find.byKey(const Key('chip_song_cat_modern')));
          await pumpClean(tester, 150);
          await tester.ensureVisible(
            find.byKey(const Key('chip_song_cat_all')),
          );
          await tester.tap(find.byKey(const Key('chip_song_cat_all')));
          await pumpClean(tester, 150);

          // 2. Phòng Chơi Đàn Ode to Joy (Guitar + Piano)
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                key: ValueKey('audit_ode_${keySeq++}'),
                theme: theme,
                home: SongPlayRoomScreen(song: odeSong),
              ),
            ),
          );
          await pumpClean(tester);
          await tester.tap(find.byKey(const Key('chip_playroom_piano')));
          await pumpClean(tester, 150);

          // 3. Phòng Chơi Đàn Canon Rock (Fret 10..15, BPM 168, tiêu đề dài)
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                key: ValueKey('audit_canon_${keySeq++}'),
                theme: theme,
                home: SongPlayRoomScreen(song: canonRock),
              ),
            ),
          );
          await pumpClean(tester);
          await tester.tap(find.byKey(const Key('chip_playroom_piano')));
          await pumpClean(tester, 150);

          // 4. Vòng Tròn Bậc 5 & Dịch Capo (toàn bộ 6 giọng + dịch tông)
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                key: ValueKey('audit_circle_${keySeq++}'),
                theme: theme,
                home: const CircleOfFifthsAndCapoScreen(),
              ),
            ),
          );
          await pumpClean(tester);
          for (final k in const ['C', 'G', 'D', 'A', 'E', 'F']) {
            await tester.tap(find.byKey(Key('chip_circle_key_$k')));
            await pumpClean(tester, 100);
          }

          // 5. Các trang Công cụ Guitar mở độc lập (singleTabMode: true)
          for (final tab in const [0, 1, 2]) {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  key: ValueKey('audit_gtr_${tab}_${keySeq++}'),
                  theme: theme,
                  home: GuitarStudioSheet(
                    initialTab: tab,
                    singleTabMode: true,
                  ),
                ),
              ),
            );
            await pumpClean(tester);
          }
        }
      },
    );

    testWidgets(
      'AUDIT-03: Battle Arena (1v1 & 2P Split-Screen Side-by-Side + 180° Tabletop) với câu hỏi Guitar & Khuông nhạc trên 360x680 Light & Dark',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 3.0, 680 * 3.0);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.runAsync(() async {
          await db.seedContent();
          await container.read(appSettingsProvider.notifier).loadSettings();
          await container.read(battleProvider.notifier).restoreTurnFromRewardedAd(
            turns: 10,
          );
        });

        final battleNotifier = container.read(battleProvider.notifier);

        int keySeq = 0;
        for (final isDark in const [false, true]) {
          final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                key: ValueKey('audit_battle_${keySeq++}'),
                theme: theme,
                home: const BattleScreen(),
              ),
            ),
          );
          await pumpClean(tester);

          // Thử các chủ đề có giao diện trực quan phức tạp nhất trong Đấu 1v1 & Chia màn hình 2 người
          for (final topicId in const [
            'topic_guitar_chords',
            'topic_guitar_tabs',
            'topic_staff_reading',
            'all',
          ]) {
            // A. Đấu 1v1 Bot
            await tester.runAsync(() async {
              await battleNotifier.backToLobby();
              battleNotifier.setBattleMode(BattleMode.botAi);
              battleNotifier.setSelectedTopicId(topicId);
              await battleNotifier.startBattle(seed: 42, roundCount: 4);
              await battleNotifier.enterArenaNow();
            });
            await pumpClean(tester, 200);

            // B. Đấu 2 người 1 máy (Ngồi cạnh nhau 1/2 chiều rộng & Xoay 180°)
            await tester.runAsync(() async {
              await battleNotifier.backToLobby();
              battleNotifier.setBattleMode(BattleMode.localSplitScreen);
              battleNotifier.setSelectedTopicId(topicId);
              await battleNotifier.startBattle(seed: 99, roundCount: 4);
              await battleNotifier.enterArenaNow();
            });
            await pumpClean(tester, 200);

            // Chuyển sang chế độ Ngồi đối diện (Xoay 180°)
            await tester.tap(
              find.byKey(const Key('btn_toggle_split_tabletop_180')),
            );
            await pumpClean(tester, 200);
            // Chuyển về lại Ngồi cạnh nhau
            await tester.tap(
              find.byKey(const Key('btn_toggle_split_tabletop_180')),
            );
            await pumpClean(tester, 150);
          }

          await tester.runAsync(() async {
            await battleNotifier.backToLobby();
          });
          await pumpClean(tester);
        }
      },
    );

    testWidgets(
      'AUDIT-04: 4 Tính năng mới v2.0.0 (Dò Vòng Hợp Âm Đệm Hát, Tự Soạn Giai Điệu, Huy Hiệu & Thẻ Thành Tích, Khiên Giữ Chuỗi + Nhắc Giờ Học) trên 360x680 Light & Dark',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 3.0, 680 * 3.0);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.runAsync(() async {
          await db.seedContent();
          await container.read(appSettingsProvider.notifier).loadSettings();
          await container
              .read(rewardedAdProvider.notifier)
              .grantBonusPrestigePoints(200);
          await container.read(overallProgressProvider.future);
        });

        int seq = 0;
        for (final isDark in const [false, true]) {
          final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;

          // 1. Luyện Dò Vòng Hợp Âm Đệm Hát (C -> G -> Am -> F)
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                key: ValueKey('v2_prog_${seq++}'),
                theme: theme,
                home: const ChordProgressionEarScreen(),
              ),
            ),
          );
          await pumpClean(tester);
          for (final ch in const ['C', 'G', 'Am', 'F']) {
            await tester.dragUntilVisible(
              find.byKey(Key('btn_prog_pad_$ch')),
              find.byKey(const Key('screen_chord_progression_ear')),
              const Offset(0, -140),
            );
            await tester.tap(find.byKey(Key('btn_prog_pad_$ch')));
            await pumpClean(tester, 80);
          }
          expect(
            find.byKey(const Key('card_prog_evaluation_result')),
            findsOneWidget,
          );

          // 2. Phòng Tự Soạn Giai Điệu Cá Nhân (Guitar + Piano -> Lưu bài)
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                key: ValueKey('v2_comp_${seq++}'),
                theme: theme,
                home: const SongbookCatalogScreen(),
              ),
            ),
          );
          await pumpClean(tester);
          await tester.tap(find.byKey(const Key('btn_open_melody_composer')));
          await pumpClean(tester, 300);
          await tester.dragUntilVisible(
            find.byKey(const Key('composer_gtr_s1_f0')),
            find.byKey(const Key('screen_custom_melody_composer')),
            const Offset(0, -160),
          );
          await tester.tap(find.byKey(const Key('composer_gtr_s1_f0')));
          await tester.tap(find.byKey(const Key('composer_gtr_s1_f3')));
          await tester.tap(find.byKey(const Key('composer_gtr_s1_f5')));
          await pumpClean(tester, 120);
          await tester.dragUntilVisible(
            find.byKey(const Key('btn_composer_save_song')),
            find.byKey(const Key('screen_custom_melody_composer')),
            const Offset(0, -180),
          );
          await tester.tap(find.byKey(const Key('btn_composer_save_song')));
          await pumpClean(tester, 300);
          expect(
            container.read(customUserSongsProvider).isNotEmpty,
            isTrue,
          );

          // 3. Phòng Truyền Thống Huy Hiệu & Thẻ Vinh Danh Cá Nhân (+25 Gem)
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                key: ValueKey('v2_ach_${seq++}'),
                theme: theme,
                home: const AchievementsTrophyScreen(),
              ),
            ),
          );
          await pumpClean(tester);
          expect(
            find.byKey(const Key('card_player_share_profile')),
            findsOneWidget,
          );
          await tester.tap(
            find.byKey(const Key('btn_copy_share_achievement_card')),
          );
          await pumpClean(tester, 150);

          // 4. Khiên Bảo Vệ Chuỗi (150 Gem) & Giờ Nhắc Luyện Tập Hằng Ngày
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                key: ValueKey('v2_shield_${seq++}'),
                theme: theme,
                home: Builder(
                  builder: (ctx) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        key: const Key('btn_test_open_shield_modal'),
                        onPressed: () => showStreakShieldAndReminderSheet(ctx),
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await pumpClean(tester);
          await tester.tap(find.byKey(const Key('btn_test_open_shield_modal')));
          await pumpClean(tester, 250);
          expect(
            find.byKey(const Key('modal_streak_shield_reminder')),
            findsOneWidget,
          );
          if (!isDark) {
            // Mua +1 Khiên (150 Gem) & Chọn giờ nhắc 20:30
            await tester.ensureVisible(
              find.byKey(const Key('btn_buy_streak_shield')),
            );
            await tester.tap(find.byKey(const Key('btn_buy_streak_shield')));
            await pumpClean(tester, 150);
            expect(
              container.read(streakShieldReminderProvider).shieldCount,
              equals(1),
            );
            await tester.ensureVisible(
              find.byKey(const Key('chip_reminder_time_20:30')),
            );
            await tester.tap(find.byKey(const Key('chip_reminder_time_20:30')));
            await pumpClean(tester, 120);
            expect(
              container.read(streakShieldReminderProvider).reminderEnabled,
              isTrue,
            );
          }
        }
      },
    );

    testWidgets(
      'AUDIT-05: Full-Screen Root Navigation (Zero Double-AppBar) & Toàn bộ vị trí Quảng Cáo Nhận Thưởng trên 360x680 Light & Dark',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 3.0, 680 * 3.0);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.runAsync(() async {
          await db.seedContent();
          await container.read(appSettingsProvider.notifier).loadSettings();
          await container.read(overallProgressProvider.future);
          await container.read(topicsListProvider.future);
        });

        final router = createSolfaRouter(initialLocation: '/home');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: SolfaApp(customRouter: router),
          ),
        );
        await pumpClean(tester);

        for (final isDark in const [false, true]) {
          await tester.runAsync(() async {
            await container.read(appSettingsProvider.notifier).setThemeMode(
                  isDark ? ThemeMode.dark : ThemeMode.light,
                );
          });
          await pumpClean(tester);

          // 1. Thẻ Quảng cáo nhận +100 Gem ở Trang chủ & Nút Streak trên Header MainShell
          await tester.dragUntilVisible(
            find.byKey(const Key('card_home_watch_rewarded_ad')),
            find.byKey(const Key('list_home_screen')),
            const Offset(0, -180),
          );
          expect(
            find.byKey(const Key('card_home_watch_rewarded_ad')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('btn_header_streak_shield')));
          await pumpClean(tester, 250);
          expect(
            find.byKey(const Key('modal_streak_shield_reminder')),
            findsOneWidget,
          );
          Navigator.of(
            tester.element(find.byKey(const Key('modal_streak_shield_reminder'))),
          ).pop();
          await pumpClean(tester, 200);

          // 2. Kiểm định mở Full-Screen cho tất cả 6 trang công cụ (Chỉ có ĐÚNG 1 AppBar hiển thị, không chồng 2 AppBar!)
          for (final routePath in const [
            '/songbook',
            '/chord-progression-ear',
            '/circle-of-fifths',
            '/achievements',
            '/piano-explorer',
            '/guitar-studio?tab=0&workout=0&single=1',
          ]) {
            router.push(routePath);
            await pumpClean(tester, 450);
            expect(
              find.byType(AppBar),
              findsOneWidget,
              reason: 'Route $routePath phải mở full-screen với đúng 1 AppBar duy nhất',
            );
            expect(
              find.byKey(const Key('nav_tab_home')),
              findsNothing,
              reason: 'Route $routePath không được hiện đè thanh menu đáy MainShell',
            );
            if (routePath == '/songbook') {
              expect(
                find.byKey(const Key('banner_songbook_watch_ad')),
                findsOneWidget,
              );
              // Bấm nút [💎] trên AppBar Kho Bản Nhạc mở Trạm Gem mượt mà
              await tester.tap(find.byKey(const Key('btn_songbook_header_gem')));
              await pumpClean(tester, 450);
              router.pop();
              await pumpClean(tester, 400);
            }
            router.pop();
            await pumpClean(tester, 400);
          }

          // 3. Màn hình Kết quả Phiên Luyện Tập chứa thẻ thưởng Quảng Cáo +100 Gem
          router.push('/session-result');
          await pumpClean(tester, 450);
          expect(
            find.byKey(const Key('card_result_watch_rewarded_ad')),
            findsOneWidget,
          );
          router.pop();
          await pumpClean(tester, 400);
        }
      },
    );
  });
}
