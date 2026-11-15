import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfa/app/app.dart';
import 'package:solfa/app/router.dart';
import 'package:solfa/core/audio/audio_service.dart';
import 'package:solfa/core/database/app_database.dart';
import 'package:solfa/core/models/domain_models.dart';
import 'package:solfa/core/providers/app_providers.dart';
import 'package:solfa/features/metronome/application/metronome_controller.dart';
import 'package:solfa/features/practice/application/practice_session_controller.dart';
import 'package:solfa/features/support_developer/application/rewarded_ad_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Solfa SRS Acceptance Test Suite (TC-01 -> TC-14)', () {
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

    testWidgets(
      'TC-01: Mở ứng dụng lần đầu khi offline -> Trang chủ hiển thị bình thường, gợi ý bài Cơ bản',
      (tester) async {
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
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('btn_quick_practice')), findsOneWidget);
        expect(find.textContaining('Luyện tập ngay'), findsOneWidget);
        expect(find.text('Bắt đầu hành trình đầu tiên'), findsOneWidget);
        expect(find.byKey(const Key('btn_first_time_notes')), findsOneWidget);
      },
    );

    test(
      'TC-15: Phòng luyện tập chọn thời gian (60 giây, 15 phút, 1 tiếng, Không giới hạn) & tính điểm nốt đúng/sai',
      () async {
        await db.seedContent();
        await container.read(appSettingsProvider.notifier).loadSettings();
        final sessionNotifier = container.read(practiceSessionProvider.notifier);

        final started = await sessionNotifier.startSession(
          mode: 'topic',
          topicId: 'topic_notes',
          timeLimitSeconds: 60,
          isUnlimitedMode: false,
          seed: 77,
        );
        expect(started, isTrue);

        var state = container.read(practiceSessionProvider);
        expect(state.timeModeLabel, equals('60 giây'));
        expect(state.isContinuousScoringMode, isTrue);

        // Switch duration modes dynamically (15 phút, 1 tiếng, Không giới hạn)
        sessionNotifier.setPracticeDurationOption(900);
        expect(container.read(practiceSessionProvider).timeModeLabel, equals('15 phút'));

        sessionNotifier.setPracticeDurationOption(3600);
        expect(container.read(practiceSessionProvider).timeModeLabel, equals('1 tiếng'));

        sessionNotifier.setPracticeDurationOption(0);
        expect(container.read(practiceSessionProvider).timeModeLabel, equals('Không giới hạn'));

        // Answer 3 notes right and 1 note wrong -> 30 points
        for (int i = 0; i < 4; i++) {
          final q = container.read(practiceSessionProvider).currentQuestion!;
          final opt = i < 3
              ? q.correctOption
              : q.options.firstWhere((o) => !o.isCorrect);
          await sessionNotifier.submitAnswer(opt);
          await sessionNotifier.nextQuestion();
        }

        state = container.read(practiceSessionProvider);
        expect(state.correctCount, equals(3));
        expect(state.wrongCount, equals(1));
        expect(state.scorePoints, equals(30));

        await sessionNotifier.finishSessionNow();
        expect(container.read(practiceSessionProvider).isCompleted, isTrue);
      },
    );

    test(
      'TC-02, TC-03, TC-04, TC-05, TC-13: Làm câu đúng/sai, chống bấm trùng (TC-13), hoàn thành phiên 10 câu (TC-04) & lưu lịch sử (TC-05)',
      () async {
        await db.seedContent();
        await container.read(appSettingsProvider.notifier).loadSettings();
        final sessionNotifier = container.read(practiceSessionProvider.notifier);

        final started = await sessionNotifier.startSession(
          mode: 'quick',
          targetCount: 10,
          seed: 42,
        );
        expect(started, isTrue);

        var state = container.read(practiceSessionProvider);
        expect(state.totalQuestions, equals(10));
        expect(state.topicId, equals('topic_notes'));
        // Decision #2: Basic level supports reference pitch C4
        expect(state.currentQuestion!.supportsReferencePitch, isTrue);

        // Answer 8 questions correctly and 2 questions wrong
        for (int i = 0; i < 10; i++) {
          state = container.read(practiceSessionProvider);
          final q = state.currentQuestion!;
          final chosenOption = i < 8
              ? q.correctOption
              : q.options.firstWhere((o) => !o.isCorrect);

          await sessionNotifier.submitAnswer(chosenOption);

          // TC-13: Rapid consecutive taps on options must only record ONE answer
          await sessionNotifier.submitAnswer(q.correctOption);
          await sessionNotifier.submitAnswer(q.options.last);

          state = container.read(practiceSessionProvider);
          expect(state.recordedAnswers.length, equals(i + 1));
          expect(state.isCurrentAnswered, isTrue);
          expect(state.isCurrentCorrect, equals(i < 8));

          final finished = await sessionNotifier.nextQuestion();
          expect(finished, equals(i == 9));
        }

        // TC-04: Verify session result summary (8/10 = 80% accuracy)
        state = container.read(practiceSessionProvider);
        expect(state.isCompleted, isTrue);
        expect(state.correctCount, equals(8));
        expect(state.wrongCount, equals(2));
        expect(state.accuracyPercent, closeTo(80.0, 0.01));

        // TC-05: Verify history persists in SQLite
        final progress = await db.getOverallProgressStats();
        expect(progress.totalAnswered, equals(10));
        expect(progress.totalCorrect, equals(8));
        expect(progress.recentSessions.length, equals(1));
        expect(progress.pendingReviewCount, equals(2));
      },
    );

    test(
      'TC-06 & Decision #4: Ôn tập câu sai và quy tắc "Đúng 2 lần liên tiếp" mới hoàn thành ôn tập',
      () async {
        await db.seedContent();
        await container.read(appSettingsProvider.notifier).loadSettings();
        final sessionNotifier = container.read(practiceSessionProvider.notifier);

        // 1. Start a short session and answer 1 question wrong
        await sessionNotifier.startSession(
          mode: 'topic',
          topicId: 'topic_notes',
          levelId: 'lvl_notes_basic',
          targetCount: 1,
          seed: 7,
        );
        final q = container.read(practiceSessionProvider).currentQuestion!;
        final wrongOpt = q.options.firstWhere((o) => !o.isCorrect);
        await sessionNotifier.submitAnswer(wrongOpt);
        await sessionNotifier.nextQuestion();

        // Verify item is in review_items with status 'pending' and 0/2 consecutive correct
        var pending = await db.getPendingReviewItems();
        expect(pending.length, equals(1));
        expect(pending.first.questionId, equals(q.id));
        expect(pending.first.correctReviewCount, equals(0));

        // 2. First Review Session: Answer correctly ONCE -> should STILL be pending (1/2)!
        await sessionNotifier.startSession(mode: 'review', targetCount: 5);
        final revQ1 = container.read(practiceSessionProvider).currentQuestion!;
        await sessionNotifier.submitAnswer(revQ1.correctOption);
        await sessionNotifier.nextQuestion();

        pending = await db.getPendingReviewItems();
        expect(pending.length, equals(1),
            reason: 'Không xóa câu sai chỉ sau 1 lần trả lời đúng');
        expect(pending.first.correctReviewCount, equals(1));

        // 3. Second Review Session: Answer correctly a SECOND consecutive time -> mastered!
        await sessionNotifier.startSession(mode: 'review', targetCount: 5);
        final revQ2 = container.read(practiceSessionProvider).currentQuestion!;
        await sessionNotifier.submitAnswer(revQ2.correctOption);
        await sessionNotifier.nextQuestion();

        pending = await db.getPendingReviewItems();
        expect(pending, isEmpty,
            reason: 'Đúng 2 lần liên tiếp được đánh dấu hoàn thành (mastered)');
      },
    );

    test(
      'TC-07: Đổi Light/Dark Mode -> Giao diện đổi nhất quán và được lưu vào SQLite',
      () async {
        await db.seedContent();
        await container.read(appSettingsProvider.notifier).loadSettings();
        final settingsNotifier = container.read(appSettingsProvider.notifier);
        expect(
          container.read(appSettingsProvider).themeMode,
          equals(ThemeMode.light),
        );

        await settingsNotifier.setThemeMode(ThemeMode.dark);
        expect(
          container.read(appSettingsProvider).themeMode,
          equals(ThemeMode.dark),
        );

        final savedInDb = await db.getSetting('theme_mode');
        expect(savedInDb, equals('dark'));
      },
    );

    test(
      'TC-08, TC-09, TC-10, TC-11: Metronome 60 BPM (1s), 120 BPM (0.5s), Tap Tempo lọc nhiễu, và đổi nhịp 3/4 & 4/4',
      () async {
        final metroNotifier = container.read(metronomeProvider.notifier);

        // TC-08: 60 BPM -> 1000 ms per beat
        metroNotifier.setBpm(60);
        expect(
          container.read(metronomeProvider).intervalMs,
          closeTo(1000.0, 0.1),
        );

        // TC-09: 120 BPM -> 500 ms per beat
        metroNotifier.setBpm(120);
        expect(
          container.read(metronomeProvider).intervalMs,
          closeTo(500.0, 0.1),
        );

        // BR-10: Clamp BPM within [30, 300]
        metroNotifier.setBpm(10);
        expect(container.read(metronomeProvider).bpm, equals(30));
        metroNotifier.setBpm(450);
        expect(container.read(metronomeProvider).bpm, equals(300));

        // TC-10 & BR-11: Tap Tempo at ~100 BPM (600 ms intervals) + outlier rejection
        metroNotifier.registerTap(customTimestampMs: 1000);
        metroNotifier.registerTap(customTimestampMs: 1600);
        metroNotifier.registerTap(customTimestampMs: 2200);
        final computed = metroNotifier.registerTap(customTimestampMs: 2800);
        expect(computed, equals(100));
        expect(container.read(metronomeProvider).bpm, equals(100));

        // Outlier tap (< 190ms) is ignored without corrupting BPM
        final outlier = metroNotifier.registerTap(customTimestampMs: 2850);
        expect(outlier, isNull);
        expect(container.read(metronomeProvider).bpm, equals(100));

        // TC-11: Time Signature 3/4 and 4/4
        metroNotifier.setTimeSignature(3, 4);
        expect(
          container.read(metronomeProvider).timeSignature,
          equals('3/4'),
        );
        metroNotifier.setTimeSignature(4, 4);
        expect(
          container.read(metronomeProvider).timeSignature,
          equals('4/4'),
        );
      },
    );

    test(
      'TC-12: Mở quảng cáo khi offline -> Hiển thị thông báo thân thiện, không ảnh hưởng học tập',
      () async {
        final adNotifier = RewardedAdNotifier(
          db,
          customConnectivityCheck: () => false,
        );

        await adNotifier.loadRewardedAd();
        expect(adNotifier.state.status, equals(RewardedAdStatus.offline));
        expect(
          adNotifier.state.statusMessage,
          contains('Không có kết nối Internet'),
        );
      },
    );

    test(
      'TC-14: Nâng cấp phiên bản nội dung / seed lại -> Dữ liệu lịch sử học tập cũ được bảo toàn',
      () async {
        await db.seedContent();
        await container.read(appSettingsProvider.notifier).loadSettings();
        final sessionNotifier = container.read(practiceSessionProvider.notifier);
        await sessionNotifier.startSession(
          mode: 'quick',
          targetCount: 2,
          seed: 99,
        );
        for (int i = 0; i < 2; i++) {
          final q = container.read(practiceSessionProvider).currentQuestion!;
          await sessionNotifier.submitAnswer(q.correctOption);
          await sessionNotifier.nextQuestion();
        }

        final beforeStats = await db.getOverallProgressStats();
        expect(beforeStats.totalAnswered, equals(2));

        // Simulate app content update / re-seeding
        await db.seedContent();

        final afterStats = await db.getOverallProgressStats();
        expect(afterStats.totalAnswered, equals(2));
        expect(afterStats.totalCorrect, equals(2));
        expect(afterStats.recentSessions.length, equals(1));
      },
    );

    test(
      'TC-16: 4 Mức độ Nhận biết nốt (Mức 1..4), trả lời bằng phím Piano & Metronome Tempo Lite (Subdivision + Per-beat state)',
      () async {
        await db.seedContent();
        await container.read(appSettingsProvider.notifier).loadSettings();
        final sessionNotifier = container.read(practiceSessionProvider.notifier);

        // 1. Mức 1 (lvl_notes_basic): Chỉ C4 tự nhiên, không dấu #/b, không câu compare_pitch
        await sessionNotifier.startSession(
          mode: 'topic',
          topicId: 'topic_notes',
          levelId: 'lvl_notes_basic',
          targetCount: 12,
          seed: 11,
        );
        var qList = container.read(practiceSessionProvider).questions;
        expect(qList.length, equals(12));
        for (final q in qList) {
          expect(q.type, isNot(equals('compare_pitch')));
          expect(q.supportsReferencePitch, isTrue);
          for (final opt in q.options) {
            expect(opt.optionKey.contains('#'), isFalse,
                reason: 'Mức 1 không có dấu thăng/giáng');
            expect(opt.optionKey.endsWith('4'), isTrue,
                reason: 'Mức 1 chỉ nằm trong quãng C4');
          }
        }

        // Test trả lời trực tiếp bằng bàn phím Piano
        final firstQ = container.read(practiceSessionProvider).currentQuestion!;
        await sessionNotifier.submitPianoKeyAnswer(firstQ.correctOption.optionKey);
        expect(container.read(practiceSessionProvider).isCurrentCorrect, isTrue);

        // 2. Mức 2 (lvl_notes_inter): Chỉ trong quãng C4 nhưng có dấu #/b
        await sessionNotifier.switchNoteLevelInSession('lvl_notes_inter');
        qList = container.read(practiceSessionProvider).questions;
        expect(
          qList.any((q) => q.options.any((o) => o.optionKey.contains('#'))),
          isTrue,
          reason: 'Mức 2 có các nốt dấu hóa #/b trong C4',
        );
        for (final q in qList) {
          for (final opt in q.options) {
            expect(opt.optionKey.endsWith('4'), isTrue,
                reason: 'Mức 2 chỉ nằm trong quãng C4');
          }
        }

        // 3. Mức 3 (lvl_notes_adv): Đa quãng tám C3–C5 tự nhiên (không dấu #)
        await sessionNotifier.switchNoteLevelInSession('lvl_notes_adv');
        qList = container.read(practiceSessionProvider).questions;
        for (final q in qList) {
          expect(q.supportsReferencePitch, isTrue);
          for (final opt in q.options) {
            expect(opt.optionKey.contains('#'), isFalse,
                reason: 'Mức 3 đa quãng tám tự nhiên không có dấu #/b');
          }
        }

        // 4. Mức 4 (lvl_notes_master): Đa quãng tám C3–C5 đầy đủ #/b & tắt tham chiếu C4
        await sessionNotifier.switchNoteLevelInSession('lvl_notes_master');
        qList = container.read(practiceSessionProvider).questions;
        for (final q in qList) {
          expect(q.supportsReferencePitch, isFalse,
              reason: 'Mức 4 tắt tham chiếu C4');
        }

        // 5. Metronome Tempo Lite sound, Subdivision (1..4) & Per-beat Accent/Normal/Mute
        final metroNotifier = container.read(metronomeProvider.notifier);
        expect(container.read(metronomeProvider).soundType, equals('tempo'));

        metroNotifier.setSubdivision(3);
        expect(container.read(metronomeProvider).subdivision, equals(3));

        // Beat 1 starts at state 2 (Accent) -> cycle to 1 (Normal) -> cycle to 0 (Mute) -> cycle to 2 (Accent)
        expect(container.read(metronomeProvider).beatStateAt(1), equals(2));
        metroNotifier.cycleBeatState(0);
        expect(container.read(metronomeProvider).beatStateAt(1), equals(1));
        metroNotifier.cycleBeatState(0);
        expect(container.read(metronomeProvider).beatStateAt(1), equals(0));
        metroNotifier.cycleBeatState(0);
        expect(container.read(metronomeProvider).beatStateAt(1), equals(2));

        // 6. Metronome Speed Trainer (Automator) & Custom Presets
        metroNotifier.setSubdivision(1);
        metroNotifier.setBpm(100);
        metroNotifier.setAutoSpeedUp(
          enabled: true,
          everyBars: 2,
          incrementBpm: 5,
          targetMaxBpm: 120,
        );
        await metroNotifier.start();
        metroNotifier.advanceFullBarForTest(); // 1 bar completed -> still 100 BPM
        expect(container.read(metronomeProvider).bpm, equals(100));
        metroNotifier.advanceFullBarForTest(); // 2 bars completed -> +5 BPM = 105 BPM
        expect(container.read(metronomeProvider).bpm, equals(105));
        await metroNotifier.stop();

        await db.saveMetronomePreset(
          const MetronomePresetModel(
            id: 'custom_test_1',
            name: 'Mẫu cá nhân 95 BPM',
            bpm: 95,
            numerator: 4,
            denominator: 4,
            soundType: 'tempo',
          ),
        );
        var allPresets = await db.getMetronomePresets();
        expect(allPresets.any((p) => p.id == 'custom_test_1'), isTrue);
        await db.deleteMetronomePreset('custom_test_1');
        allPresets = await db.getMetronomePresets();
        expect(allPresets.any((p) => p.id == 'custom_test_1'), isFalse);

        // 7. Note Mastery Heatmap in OverallProgressStats & Sight-Reading (Đọc nốt nhạc)
        await sessionNotifier.finishSessionNow();
        final statsWithHeatmap = await db.getOverallProgressStats();
        expect(statsWithHeatmap.noteMasteryStats.length, equals(12));
        expect(
          statsWithHeatmap.noteMasteryStats.any((n) => n.totalAnswered > 0),
          isTrue,
        );

        // 8. Chủ đề Đọc nốt nhạc (topic_staff_reading) 4 mức độ & Chuyển đổi Nghe <-> Đọc
        final staffLevels = await db.getLevelsByTopic('topic_staff_reading');
        expect(staffLevels.length, equals(4));

        await sessionNotifier.startSession(
          mode: 'topic',
          topicId: 'topic_staff_reading',
          levelId: 'lvl_staff_basic',
          targetCount: 4,
          seed: 19,
        );
        final staffQ1 = container.read(practiceSessionProvider).currentQuestion!;
        expect(staffQ1.isSightReading, isTrue);
        expect(staffQ1.supportsReferencePitch, isFalse);
        expect(staffQ1.showPianoHelper, isTrue);
        expect(staffQ1.allowBlackKeysOnPiano, isFalse);

        // Chuyển sang Mức 3 (Khóa Sol + Khóa Fa C3-C5) và Mức 4 (Đầy đủ #/b)
        await sessionNotifier.switchNoteLevelInSession('lvl_staff_adv');
        final staffQ3 = container.read(practiceSessionProvider).currentQuestion!;
        expect(staffQ3.isSightReading, isTrue);
        expect(staffQ3.allowBlackKeysOnPiano, isFalse);

        await sessionNotifier.switchNoteLevelInSession('lvl_staff_master');
        final staffQ4 = container.read(practiceSessionProvider).currentQuestion!;
        expect(staffQ4.isSightReading, isTrue);
        expect(staffQ4.allowBlackKeysOnPiano, isTrue);

        // Chuyển đổi trực tiếp giữa Đọc nốt nhạc <-> Nghe nốt ngay trong phiên
        await sessionNotifier.switchNotePracticeModeInSession('topic_notes');
        expect(
          container.read(practiceSessionProvider).topicId,
          equals('topic_notes'),
        );
        expect(
          container.read(practiceSessionProvider).currentQuestion!.isSightReading,
          isFalse,
        );
        await sessionNotifier.switchNotePracticeModeInSession(
          'topic_staff_reading',
        );
        expect(
          container.read(practiceSessionProvider).topicId,
          equals('topic_staff_reading'),
        );
        expect(
          container.read(practiceSessionProvider).currentQuestion!.isSightReading,
          isTrue,
        );
        await sessionNotifier.finishSessionNow();
      },
    );

    testWidgets(
      'TC-17: Kiểm thử độ ổn định giao diện & trải nghiệm người dùng trên màn hình nhỏ (360x680, Light/Dark, không tràn khung)',
      (tester) async {
        // Giả lập màn hình điện thoại nhỏ gọn 360x680 logical pixels
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

        Future<void> pumpFrames([int ms = 350]) async {
          await tester.pump();
          await tester.pump(Duration(milliseconds: ms));
        }

        final router = createSolfaRouter(initialLocation: '/home');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: SolfaApp(customRouter: router),
          ),
        );
        await pumpFrames();

        // 1. Trang chủ (HomeScreen) + Mở Đàn Piano & Tra cứu Khuông nhạc tự do (C3–C5)
        expect(find.byKey(const Key('btn_quick_practice')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('btn_open_free_piano_explorer')),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await pumpFrames(200);
        expect(find.byKey(const Key('btn_open_free_piano_explorer')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_open_free_piano_explorer')));
        await pumpFrames(300);
        expect(find.byKey(const Key('free_piano_explorer_sheet')), findsOneWidget);
        await tester.tap(find.byKey(const Key('explorer_octave_3')));
        await pumpFrames(200);
        expect(find.textContaining('Khóa Fa'), findsWidgets);
        await tester.tap(find.byKey(const Key('explorer_octave_5')));
        await pumpFrames(200);
        await tester.tap(find.byKey(const Key('btn_close_free_piano_explorer')));
        await pumpFrames(250);
        expect(tester.takeException(), isNull);

        // 2. Phòng luyện tập (TopicsScreen) -> Chọn Mức 1..4
        router.go('/topics');
        await pumpFrames();
        expect(
          find.byKey(const Key('topic_note_lvl_lvl_notes_basic')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('topic_note_lvl_lvl_notes_inter')));
        await pumpFrames(200);
        expect(tester.takeException(), isNull);

        // 3. Màn hình làm bài (QuizScreen) với Khuông nhạc Khóa Sol + Đàn Piano + 4 Mức độ
        final sessionNotifier = container.read(practiceSessionProvider.notifier);
        await tester.runAsync(() async {
          await sessionNotifier.startSession(
            mode: 'topic',
            topicId: 'topic_notes',
            levelId: 'lvl_notes_basic',
            targetCount: 4,
            seed: 7,
          );
        });
        router.push('/quiz');
        await pumpFrames();
        expect(find.byKey(const Key('musical_staff_widget')), findsOneWidget);
        expect(find.byKey(const Key('piano_key_C4')), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Trả lời câu hỏi và kiểm tra hiển thị Khuông nhạc Khóa Sol + Feedback không tràn khung
        await tester.runAsync(() async {
          final currentQ = container.read(practiceSessionProvider).currentQuestion!;
          await sessionNotifier.submitAnswer(currentQ.options.first);
        });
        await pumpFrames();
        expect(tester.takeException(), isNull);

        // Đổi sang Mức 3, Mức 4 ngay trên thanh công cụ
        await tester.runAsync(() async {
          await sessionNotifier.switchNoteLevelInSession('lvl_notes_adv');
        });
        await pumpFrames(250);
        expect(tester.takeException(), isNull);

        await tester.runAsync(() async {
          await sessionNotifier.switchNoteLevelInSession('lvl_notes_master');
        });
        await pumpFrames(250);
        expect(tester.takeException(), isNull);

        // Chuyển sang chế độ Đọc nốt nhạc (Sight-Reading) ngay trên thanh công cụ và kiểm tra giao diện 360x680
        await tester.runAsync(() async {
          await sessionNotifier.switchNotePracticeModeInSession(
            'topic_staff_reading',
          );
        });
        await pumpFrames(250);
        expect(
          find.byKey(const Key('sight_reading_instruction_banner')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('musical_staff_widget')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.runAsync(() async {
          final currentQ =
              container.read(practiceSessionProvider).currentQuestion!;
          await sessionNotifier.submitAnswer(currentQ.options.first);
        });
        await pumpFrames(250);
        expect(tester.takeException(), isNull);

        // Hoàn thành phiên -> Màn hình kết quả (SessionResultScreen)
        await tester.runAsync(() async {
          await sessionNotifier.finishSessionNow();
          await container.read(overallProgressProvider.future);
        });
        router.go('/session-result');
        await pumpFrames();
        expect(find.byKey(const Key('result_accuracy_text')), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 4. Màn hình Máy đếm nhịp (MetronomeScreen) với Tempo Lite, Subdivision, Speed Trainer & 6/8
        router.go('/metronome');
        await pumpFrames();
        expect(find.byKey(const Key('metronome_bpm_text')), findsOneWidget);
        await tester.tap(find.byKey(const Key('chip_sig_6_8')));
        await pumpFrames(200);
        await tester.drag(find.byType(ListView).last, const Offset(0, -260));
        await pumpFrames(200);
        await tester.tap(find.byKey(const Key('switch_speed_trainer')));
        await pumpFrames(200);
        expect(tester.takeException(), isNull);

        // 5. Màn hình Tiến trình (ProgressScreen) với Bản đồ độ nhạy từng nốt (Note Heatmap)
        router.go('/progress');
        await pumpFrames(300);
        await tester.drag(find.byType(ListView).last, const Offset(0, -320));
        await pumpFrames(250);
        expect(
          find.byKey(const Key('note_mastery_heatmap_card')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // 6. Màn hình Cài đặt (SettingsScreen) & Chuyển sang Dark Mode
        router.go('/settings');
        await pumpFrames();
        await tester.runAsync(() async {
          await container
              .read(appSettingsProvider.notifier)
              .setThemeMode(ThemeMode.dark);
        });
        await pumpFrames();
        expect(tester.takeException(), isNull);

        // 7. Kiểm tra TopicDetailScreen & QuizScreen cho chủ đề mới có nhãn dài (Giai điệu & Nhịp điệu) trên 360x680
        router.go('/topics/topic_rhythm');
        await pumpFrames(300);
        expect(tester.takeException(), isNull);

        await tester.runAsync(() async {
          await sessionNotifier.startSession(
            mode: 'topic',
            topicId: 'topic_melody',
            levelId: 'lvl_melody_adv',
            targetCount: 4,
            seed: 99,
          );
        });
        router.go('/quiz');
        await pumpFrames(300);
        expect(tester.takeException(), isNull);

        await tester.runAsync(() async {
          final currentQ =
              container.read(practiceSessionProvider).currentQuestion!;
          await sessionNotifier.submitAnswer(currentQ.options.first);
        });
        await pumpFrames(250);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          await sessionNotifier.abandonSessionIfIncomplete();
        });
      },
    );

    test(
      'TC-18: Xử lý ngoại lệ & tình huống biên của người dùng (bấm liên tục, đổi chế độ giữa phiên, ôn tập rỗng, giới hạn BPM)',
      () async {
        // 1. Khởi tạo cơ sở dữ liệu song song (kiểm tra khóa chống race condition _dbInitFuture)
        await Future.wait([
          db.seedContent(),
          container.read(appSettingsProvider.notifier).loadSettings(),
        ]);

        final sessionNotifier = container.read(practiceSessionProvider.notifier);

        // 2. Khi chưa có câu sai nào mà người dùng bấm vào chế độ Ôn tập -> Trả về false kèm thông báo thân thiện, không văng lỗi
        final emptyReviewOk = await sessionNotifier.startSession(
          mode: 'review',
          targetCount: 5,
        );
        expect(emptyReviewOk, isFalse);
        expect(
          container.read(practiceSessionProvider).errorMessage,
          contains('không có câu hỏi nào cần ôn tập'),
        );

        // 3. Bắt đầu phiên ở Nghe nốt, sau đó đổi sang Đọc nốt nhạc + đổi mức độ liên tục và trả lời sai bằng phím Piano
        final startOk = await sessionNotifier.startSession(
          mode: 'topic',
          topicId: 'topic_notes',
          levelId: 'lvl_notes_basic',
          targetCount: 4,
          seed: 101,
        );
        expect(startOk, isTrue);

        // Bấm chuyển chế độ & mức độ liên tiếp
        await sessionNotifier.switchNotePracticeModeInSession(
          'topic_staff_reading',
        );
        await sessionNotifier.switchNoteLevelInSession('lvl_staff_adv');

        final q = container.read(practiceSessionProvider).currentQuestion!;
        expect(q.topicId, equals('topic_staff_reading'));
        expect(q.isSightReading, isTrue);

        // Bấm một phím đàn không trùng với đáp án đúng + cố tình gọi submitAnswer lặp lại nhiều lần
        final wrongOpt = q.options.firstWhere((o) => !o.isCorrect);
        await Future.wait([
          sessionNotifier.submitPianoKeyAnswer(wrongOpt.optionKey),
          sessionNotifier.submitAnswer(q.correctOption),
          sessionNotifier.submitAnswer(wrongOpt),
        ]);

        // Chỉ ghi nhận đúng 1 câu trả lời duy nhất
        expect(
          container.read(practiceSessionProvider).recordedAnswers.length,
          equals(1),
        );
        expect(
          container.read(practiceSessionProvider).wrongCount,
          equals(1),
        );

        // Kết thúc phiên -> kiểm tra SQLite đã cập nhật đúng topic_id = 'topic_staff_reading' và thêm câu sai vào review_items
        await sessionNotifier.finishSessionNow();
        final stats = await db.getOverallProgressStats();
        expect(stats.recentSessions.first.topicId, equals('topic_staff_reading'));
        expect(stats.pendingReviewCount, equals(1));

        // 4. Vào phiên Ôn tập câu sai (mode == 'review'): không cho phép switchNotePracticeModeInSession ghi đè phiên ôn tập
        final reviewOk = await sessionNotifier.startSession(
          mode: 'review',
          targetCount: 5,
        );
        expect(reviewOk, isTrue);
        await sessionNotifier.switchNotePracticeModeInSession('topic_notes');
        expect(
          container.read(practiceSessionProvider).mode,
          equals('review'),
        );
        await sessionNotifier.abandonSessionIfIncomplete();

        // 5. Kiểm tra giới hạn ngoại lệ của Metronome BPM, Subdivision, Volume & Tap Tempo
        final metroNotifier = container.read(metronomeProvider.notifier);
        metroNotifier.setBpm(-999);
        expect(container.read(metronomeProvider).bpm, equals(30));
        metroNotifier.setBpm(99999);
        expect(container.read(metronomeProvider).bpm, equals(300));
        metroNotifier.setSubdivision(0);
        expect(container.read(metronomeProvider).subdivision, equals(1));
        metroNotifier.setSubdivision(99);
        expect(container.read(metronomeProvider).subdivision, equals(4));
        metroNotifier.setVolume(-5.0);
        expect(container.read(metronomeProvider).volume, equals(0.0));
        metroNotifier.setVolume(10.0);
        expect(container.read(metronomeProvider).volume, equals(1.0));
        metroNotifier.cycleBeatState(-1); // Out-of-bounds index -> safe no-op
        metroNotifier.cycleBeatState(99); // Out-of-bounds index -> safe no-op
      },
    );

    test(
      'TC-19: Mở khóa 3 chủ đề mới (Hợp âm, Giai điệu, Nhịp điệu), Combo liên tiếp, Kỷ lục điểm cao & Mục tiêu hàng ngày',
      () async {
        await db.seedContent();
        await container.read(appSettingsProvider.notifier).loadSettings();
        final sessionNotifier = container.read(practiceSessionProvider.notifier);

        // 1. Kiểm tra cả 7 chủ đề đều đã được mở khóa (isEnabled == true)
        final allTopics = await db.getTopics();
        expect(allTopics.length, equals(7));
        expect(allTopics.every((t) => t.isEnabled), isTrue);

        // 2. Kiểm tra sinh câu hỏi cho 3 chủ đề mới (topic_chords, topic_melody, topic_rhythm)
        for (final tId in ['topic_chords', 'topic_melody', 'topic_rhythm']) {
          final levels = await db.getLevelsByTopic(tId);
          expect(levels.length, equals(3));
          for (final lvl in levels) {
            final ok = await sessionNotifier.startSession(
              mode: 'topic',
              topicId: tId,
              levelId: lvl.id,
              targetCount: 6,
              seed: 123,
            );
            expect(ok, isTrue, reason: 'Chủ đề $tId cấp ${lvl.id} phải sinh câu hỏi thành công');
            final qs = container.read(practiceSessionProvider).questions;
            expect(qs.length, equals(6));
            await sessionNotifier.abandonSessionIfIncomplete();
          }
        }

        // 3. Kiểm tra đếm chuỗi Combo liên tiếp, Kỷ lục điểm cao (High Score) & Mục tiêu hôm nay (Daily Goal)
        await sessionNotifier.startSession(
          mode: 'topic',
          topicId: 'topic_chords',
          levelId: 'lvl_chords_basic',
          targetCount: 4,
          seed: 55,
        );

        // Trả lời đúng 3 câu liên tiếp -> currentCombo = 3, maxComboInSession = 3
        for (int i = 0; i < 3; i++) {
          final q = container.read(practiceSessionProvider).currentQuestion!;
          await sessionNotifier.submitAnswer(q.correctOption);
          expect(container.read(practiceSessionProvider).currentCombo, equals(i + 1));
          expect(container.read(practiceSessionProvider).maxComboInSession, equals(i + 1));
          await sessionNotifier.nextQuestion();
        }

        // Câu thứ 4 trả lời sai -> currentCombo reset về 0, nhưng maxComboInSession vẫn giữ = 3
        final q4 = container.read(practiceSessionProvider).currentQuestion!;
        final wrongOpt = q4.options.firstWhere((o) => !o.isCorrect);
        await sessionNotifier.submitAnswer(wrongOpt);
        expect(container.read(practiceSessionProvider).currentCombo, equals(0));
        expect(container.read(practiceSessionProvider).maxComboInSession, equals(3));

        final finished = await sessionNotifier.nextQuestion();
        expect(finished, isTrue);

        final finalState = container.read(practiceSessionProvider);
        expect(finalState.isCompleted, isTrue);
        expect(finalState.isNewHighScore, isTrue);
        expect(finalState.scorePoints, equals(30));

        final stats = await db.getOverallProgressStats();
        expect(stats.bestScore, equals(30));
        expect(stats.bestComboStreak, equals(3));
        expect(stats.todayAnsweredCount, equals(4));
        expect(stats.dailyGoalTarget, equals(20));
      },
    );
  });
}
