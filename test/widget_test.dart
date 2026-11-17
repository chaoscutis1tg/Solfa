import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfa/app/app.dart';
import 'package:solfa/app/router.dart';
import 'package:solfa/core/audio/audio_service.dart';
import 'package:solfa/core/database/app_database.dart';
import 'package:solfa/core/localization/app_locale.dart';
import 'package:solfa/core/models/domain_models.dart';
import 'package:solfa/core/providers/app_providers.dart';
import 'package:solfa/core/security/solfa_integrity_guard.dart';
import 'package:solfa/features/battle/application/battle_controller.dart';
import 'package:solfa/features/guitar/presentation/guitar_studio_sheet.dart';
import 'package:solfa/features/metronome/application/metronome_controller.dart';
import 'package:solfa/features/practice/application/practice_session_controller.dart';
import 'package:solfa/features/practice/presentation/widgets/musical_staff_widget.dart';
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
        await tester.tap(find.byKey(const Key('explorer_harmony_C_maj')));
        await pumpFrames(200);
        expect(find.textContaining('Hợp âm Đô Trưởng'), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_close_free_piano_explorer')));
        await pumpFrames(250);
        expect(tester.takeException(), isNull);

        // 2. Phòng luyện tập (TopicsScreen) -> Lưới 2 cột thẻ lớn -> Chạm mở Modal chọn Mức 1..4
        router.go('/topics');
        await pumpFrames();
        expect(find.byKey(const Key('topic_grid_card_topic_notes')), findsOneWidget);
        expect(find.byKey(const Key('topic_grid_card_topic_staff_reading')), findsOneWidget);
        await tester.tap(find.byKey(const Key('topic_grid_card_topic_notes')));
        await pumpFrames(300);
        expect(
          find.byKey(const Key('topic_note_lvl_lvl_notes_basic')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('topic_note_lvl_lvl_notes_inter')));
        await pumpFrames(200);
        Navigator.of(tester.element(find.byKey(const Key('modal_topic_practice_setup')))).pop();
        await pumpFrames(250);
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
        expect(find.byKey(const Key('btn_play_question_audio')), findsOneWidget);
        // Bàn phím Piano đã được loại bỏ khỏi QuizScreen để tối giản giao diện học
        expect(find.byKey(const Key('piano_key_C4')), findsNothing);
        expect(tester.takeException(), isNull);

        // Trả lời câu hỏi và kiểm tra hiển thị Khuông nhạc Khóa Sol + Feedback không tràn khung
        await tester.runAsync(() async {
          final currentQ = container.read(practiceSessionProvider).currentQuestion!;
          await sessionNotifier.submitAnswer(currentQ.options.first);
        });
        await pumpFrames();
        expect(tester.takeException(), isNull);

        // Đổi sang Mức 3, Mức 4
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

        // Chuyển sang chế độ Đọc nốt nhạc (Sight-Reading) và kiểm tra giao diện 360x680 + tự động phát âm thanh
        await tester.runAsync(() async {
          await sessionNotifier.switchNotePracticeModeInSession(
            'topic_staff_reading',
          );
        });
        await pumpFrames(250);
        expect(
          find.byKey(const Key('btn_play_question_audio')),
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

        // 7. Kiểm tra thêm kích thước màn hình trung bình (390x844), màn hình lớn (430x932) & System Mode
        for (final size in const [
          Size(390, 844),
          Size(430, 932),
          Size(360, 680),
        ]) {
          tester.view.physicalSize = Size(size.width * 3.0, size.height * 3.0);
          await pumpFrames(250);
          expect(tester.takeException(), isNull, reason: 'resize to $size');

          router.go('/home');
          await pumpFrames(250);
          expect(tester.takeException(), isNull, reason: 'home at $size');

          router.go('/topics');
          await pumpFrames(250);
          expect(tester.takeException(), isNull, reason: 'topics at $size');

          router.go('/metronome');
          await pumpFrames(250);
          expect(tester.takeException(), isNull, reason: 'metronome at $size');

          router.go('/progress');
          await pumpFrames(250);
          expect(tester.takeException(), isNull, reason: 'progress at $size');
        }

        await tester.runAsync(() async {
          await container
              .read(appSettingsProvider.notifier)
              .setThemeMode(ThemeMode.system);
        });
        await pumpFrames(250);
        expect(tester.takeException(), isNull, reason: 'system mode');

        await tester.runAsync(() async {
          await container
              .read(appSettingsProvider.notifier)
              .setThemeMode(ThemeMode.dark);
        });
        await pumpFrames(250);
        expect(tester.takeException(), isNull, reason: 'back to dark mode');

        // 8. Kiểm tra TopicDetailScreen & QuizScreen cho chủ đề mới có nhãn dài (Giai điệu & Nhịp điệu) trên 360x680
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

        // 9. Kiểm tra Modal chọn Cấp độ & Thời gian (modal_topic_practice_setup), Phân khu Học Guitar & Pháp lý Gem / Chống hack trên màn 360x680
        router.go('/topics');
        await pumpFrames(300);
        await tester.tap(find.text('Luyện đọc nốt'));
        await pumpFrames(300);
        expect(
          find.byKey(const Key('modal_topic_practice_setup')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('btn_modal_start_practice')), findsOneWidget);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byKey(const Key('modal_topic_practice_setup')))).pop();
        await pumpFrames(250);

        // Chuyển sang phân khu "Học Guitar & Cần đàn" trên màn 360x680
        await tester.tap(find.byKey(const Key('tab_practice_area_guitar')));
        await pumpFrames(300);
        expect(find.byKey(const Key('topic_grid_card_topic_guitar_notes')), findsOneWidget);
        expect(find.byKey(const Key('topic_grid_card_topic_guitar_chords')), findsOneWidget);
        expect(find.byKey(const Key('topic_grid_card_topic_guitar_scales')), findsOneWidget);
        expect(find.byKey(const Key('topic_grid_card_topic_guitar_tabs')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('topic_grid_card_guitar_studio')));
        await pumpFrames(300);
        expect(find.byKey(const Key('guitar_studio_sheet')), findsOneWidget);
        await tester.tap(find.byKey(const Key('chip_guitar_tab_1')));
        await pumpFrames(250);
        await tester.tap(find.byKey(const Key('chip_guitar_tab_2')));
        await pumpFrames(250);
        await tester.tap(find.byKey(const Key('chip_guitar_tab_3')));
        await pumpFrames(250);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('btn_close_guitar_studio')));
        await pumpFrames(250);
        await tester.tap(find.byKey(const Key('tab_practice_area_piano')));
        await pumpFrames(250);

        router.go('/settings');
        await pumpFrames(300);
        await tester.scrollUntilVisible(
          find.byKey(const Key('tile_anti_tamper_status')),
          250.0,
          scrollable: find.byType(Scrollable).last,
        );
        await pumpFrames(250);
        expect(find.byKey(const Key('tile_anti_tamper_status')), findsOneWidget);
        await tester.tap(find.byKey(const Key('tile_anti_tamper_status')));
        await pumpFrames(300);
        expect(find.textContaining('Quy định Đơn vị thưởng ảo (Gem)'), findsOneWidget);
        expect(find.textContaining('SolfaIntegrityGuard'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Đã hiểu'));
        await pumpFrames(250);
        expect(tester.takeException(), isNull);
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

        // 4. Kiểm tra tùy chỉnh Mục tiêu hàng ngày (Daily Goal) & Đổi cấp độ trực tiếp trong phiên cho Hợp âm
        await container.read(appSettingsProvider.notifier).setDailyGoalTarget(30);
        final updatedStats = await db.getOverallProgressStats();
        expect(updatedStats.dailyGoalTarget, equals(30));

        await sessionNotifier.startSession(
          mode: 'topic',
          topicId: 'topic_chords',
          levelId: 'lvl_chords_basic',
          targetCount: 4,
          seed: 77,
        );
        await sessionNotifier.switchNoteLevelInSession('lvl_chords_inter');
        expect(
          container.read(practiceSessionProvider).levelId,
          equals('lvl_chords_inter'),
        );
        await sessionNotifier.abandonSessionIfIncomplete();
      },
    );

    test(
      'TC-20: Kiểm định thuật toán Random câu hỏi & đáp án (Phân phối đồng đều, Không lặp liên tiếp, Đảo vị trí A/B/C/D & Đáp án nhiễu ngẫu nhiên trên cả 7 chủ đề / 23 cấp độ)',
      () async {
        await db.seedContent();
        await container.read(appSettingsProvider.notifier).loadSettings();
        final generator = container.read(hybridQuestionGeneratorProvider);
        final sessionNotifier = container.read(practiceSessionProvider.notifier);

        // 1. Kiểm tra phân phối đồng đều tuyệt đối (Stratified Bag) ở Mức 1 (7 nốt C4..B4):
        // Trong 14 câu hỏi, 7 câu đầu phải chứa đủ cả 7 nốt C4..B4 và 7 câu sau cũng chứa đủ cả 7 nốt C4..B4!
        final stratifiedBatch = await generator.generateSessionQuestions(
          mode: 'topic',
          topicId: 'topic_notes',
          levelId: 'lvl_notes_basic',
          targetCount: 14,
          seed: 2026,
        );
        expect(stratifiedBatch.questions.length, equals(14));
        final round1Notes = stratifiedBatch.questions
            .sublist(0, 7)
            .map((q) => q.correctOption.optionKey)
            .toSet();
        final round2Notes = stratifiedBatch.questions
            .sublist(7, 14)
            .map((q) => q.correctOption.optionKey)
            .toSet();
        expect(
          round1Notes,
          equals({'C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4'}),
          reason: 'Mỗi chu kỳ 7 câu Mức 1 phải xuất hiện đủ cả 7 nốt tự nhiên không thiên vị',
        );
        expect(
          round2Notes,
          equals({'C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4'}),
        );

        // 2. Kiểm tra đảo ngẫu nhiên vị trí A/B/C/D và đáp án nhiễu (distractors):
        // Nốt Đô (C4) và Si (B4) không bao giờ bị cố định ở vị trí A (index 0) hay D (index 3)
        final largeBatch = await generator.generateSessionQuestions(
          mode: 'topic',
          topicId: 'topic_notes',
          levelId: 'lvl_notes_basic',
          targetCount: 56,
          seed: 909,
        );
        final Set<int> allCorrectIndices = {};
        final Set<int> c4Positions = {};
        final Set<int> b4Positions = {};
        final Set<String> c4DistractorSets = {};

        for (final q in largeBatch.questions) {
          final correctIdx = q.options.indexWhere((o) => o.isCorrect);
          allCorrectIndices.add(correctIdx);
          if (q.correctOption.optionKey == 'C4') {
            c4Positions.add(correctIdx);
            final distractorSig = q.options
                .where((o) => !o.isCorrect)
                .map((o) => o.optionKey)
                .toList()
              ..sort();
            c4DistractorSets.add(distractorSig.join(','));
          }
          if (q.correctOption.optionKey == 'B4') {
            b4Positions.add(correctIdx);
          }
        }
        expect(
          allCorrectIndices,
          equals({0, 1, 2, 3}),
          reason: 'Đáp án đúng phải phân bổ đủ ở cả 4 vị trí A, B, C, D',
        );
        expect(
          c4Positions.length,
          greaterThan(1),
          reason: 'Nốt Đô (C4) không được cố định ở đáp án A',
        );
        expect(
          b4Positions.length,
          greaterThan(1),
          reason: 'Nốt Si (B4) không được cố định ở đáp án D',
        );
        expect(
          c4DistractorSets.length,
          greaterThan(1),
          reason: 'Các phương án nhiễu (distractors) cho cùng 1 nốt phải được lấy mẫu ngẫu nhiên đa dạng',
        );

        // 3. Duyệt toàn bộ 7 chủ đề & 23 cấp độ: Không có 2 câu liên tiếp trùng âm thanh hoặc trùng đáp án đúng
        final allTopics = await db.getTopics();
        expect(allTopics.length, equals(7));

        for (final topic in allTopics) {
          final levels = await db.getLevelsByTopic(topic.id);
          expect(levels, isNotEmpty);

          for (final level in levels) {
            final res = await generator.generateSessionQuestions(
              mode: 'topic',
              topicId: topic.id,
              levelId: level.id,
              targetCount: 20,
            );
            expect(
              res.questions.length,
              equals(20),
              reason: 'Topic ${topic.id} / Level ${level.id} phải tạo đủ 20 câu',
            );

            for (int i = 0; i < res.questions.length; i++) {
              final q = res.questions[i];
              expect(q.options.where((o) => o.isCorrect).length, equals(1));
              final optLabels = q.options.map((o) => o.label).toSet();
              final optKeys =
                  q.options.map((o) => o.optionKey.toUpperCase()).toSet();
              expect(
                optLabels.length,
                equals(q.options.length),
                reason: 'Không được có 2 phương án trùng nhãn hiển thị',
              );
              expect(
                optKeys.length,
                equals(q.options.length),
                reason: 'Không được có 2 phương án trùng mã optionKey',
              );

              if (i > 0) {
                final prev = res.questions[i - 1];
                expect(
                  q.audioAsset == prev.audioAsset && q.type == prev.type,
                  isFalse,
                  reason:
                      'Không được lặp lại cùng file âm thanh & loại câu hỏi ở 2 câu liên tiếp (${topic.id}/${level.id} tại câu $i)',
                );
                if (q.options.length >= 4 && prev.options.length >= 4) {
                  expect(
                    q.correctOption.optionKey.toUpperCase() ==
                            prev.correctOption.optionKey.toUpperCase() &&
                        q.type == prev.type,
                    isFalse,
                    reason:
                        'Không được lặp lại cùng đáp án đúng ở 2 câu liên tiếp (${topic.id}/${level.id} tại câu $i)',
                  );
                }
              }
            }
          }
        }

        // 4. Kiểm tra nạp thêm câu hỏi (refill) ở chế độ tính giờ (60s) qua ranh giới câu 20 -> 21 không bị lặp
        await sessionNotifier.startSession(
          mode: 'topic',
          topicId: 'topic_intervals',
          levelId: 'lvl_intervals_basic',
          timeLimitSeconds: 60,
          seed: 303,
        );
        for (int i = 0; i < 22; i++) {
          final curQ = container.read(practiceSessionProvider).currentQuestion!;
          await sessionNotifier.submitAnswer(curQ.correctOption);
          await sessionNotifier.nextQuestion();
        }
        final fullQuestions = container.read(practiceSessionProvider).questions;
        expect(fullQuestions.length, greaterThanOrEqualTo(35));
        expect(
          fullQuestions[19].audioAsset,
          isNot(equals(fullQuestions[20].audioAsset)),
          reason: 'Câu nối tiếp giữa 2 đợt sinh câu hỏi (câu 20 -> 21) không được trùng nhau',
        );
        expect(
          fullQuestions[19].correctOption.optionKey,
          isNot(equals(fullQuestions[20].correctOption.optionKey)),
        );
        await sessionNotifier.abandonSessionIfIncomplete();
      },
    );

    testWidgets(
      'TC-21: Nút Nav Diamond Chiến đấu ở giữa & Đấu Trường Âm Nhạc 1v1 (Ghép trận, Bot AI 4 cấp, Đấu 2 người Split-Screen, Thanh máu HP, Bạo kích Combo & Bậc Xếp Hạng)',
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

        Future<void> pumpFrames([int ms = 350]) async {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(Duration(milliseconds: ms));
          await tester.pump();
        }

        final router = createSolfaRouter(initialLocation: '/home');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: SolfaApp(customRouter: router),
          ),
        );
        await pumpFrames();

        // 1. Kiểm tra Nút Diamond CTA Chiến đấu nằm chính giữa thanh Bottom Nav
        expect(find.byKey(const Key('btn_nav_diamond_battle')), findsOneWidget);
        expect(find.byKey(const Key('nav_tab_home')), findsOneWidget);
        expect(find.byKey(const Key('nav_tab_topics')), findsOneWidget);
        expect(find.byKey(const Key('nav_tab_metronome')), findsOneWidget);
        expect(find.byKey(const Key('nav_tab_progress')), findsOneWidget);

        // Bấm vào nút Diamond ở giữa -> Mở màn hình Đấu Trường Âm Nhạc 1v1 (/battle)
        await tester.tap(find.byKey(const Key('btn_nav_diamond_battle')));
        await pumpFrames(350);
        expect(find.byKey(const Key('battle_lobby_view')), findsOneWidget);
        expect(tester.takeException(), isNull);

        final battleNotifier = container.read(battleProvider.notifier);
        expect(
          container.read(battleProvider).remainingBattlesToday,
          equals(BattleState.maxDailyFreeBattles),
          reason: 'Mỗi ngày người chơi được cấp mặc định 5 lượt Đấu Trường miễn phí',
        );
        expect(find.byKey(const Key('battle_daily_turns_card')), findsOneWidget);

        // 2. Chế độ 1: Ghép Trận Ngẫu Nhiên 1v1 (Smart Matchmaking) + Bạo kích Combo -> Hạ gục K.O. & Thưởng +2 ⭐ (Trừ 1 lượt: 5 -> 4)
        await tester.runAsync(() async {
          battleNotifier.setBattleMode(BattleMode.smartMatchmaking);
          battleNotifier.setSelectedTopicId('all');
          await battleNotifier.startBattle(seed: 88, roundCount: 8);
        });
        await pumpFrames(250);
        expect(
          find.byKey(const Key('battle_vs_matchmaking_view')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.runAsync(() async {
          await battleNotifier.enterArenaNow();
        });
        await pumpFrames(250);
        expect(
          find.byKey(const Key('battle_fighting_arena_view')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // Trả lời đúng liên tiếp cho tới khi K.O. đối thủ (player2Hp == 0)
        await tester.runAsync(() async {
          while (container.read(battleProvider).phase == BattlePhase.fighting) {
            final curQ = container.read(battleProvider).currentQuestion!;
            await battleNotifier.submitPlayer1Answer(curQ.correctOption);
            await battleNotifier.nextRound();
          }
        });
        await pumpFrames(250);

        final afterMatch1 = container.read(battleProvider);
        expect(afterMatch1.phase, equals(BattlePhase.finished));
        expect(afterMatch1.didPlayer1Win, isTrue);
        expect(afterMatch1.player2Hp, equals(0));
        expect(afterMatch1.player1MaxCombo, greaterThanOrEqualTo(3));
        expect(afterMatch1.starsDeltaLastMatch, equals(2));
        expect(afterMatch1.totalStars, equals(2));
        expect(afterMatch1.totalWins, equals(1));
        expect(afterMatch1.currentWinStreak, equals(1));
        expect(afterMatch1.firstBloodTaken, isTrue);
        expect(afterMatch1.player2Title.contains('Nhạc viện'), isFalse);
        expect(afterMatch1.player2Title.contains('Học viện'), isFalse);
        expect(afterMatch1.remainingBattlesToday, equals(4));
        expect(find.byKey(const Key('battle_result_view')), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 3. Chế độ 2: Đấu 2 Người Trên 1 Máy (Local Split-Screen 1v1)
        await tester.runAsync(() async {
          await battleNotifier.backToLobby();
          battleNotifier.setBattleMode(BattleMode.localSplitScreen);
          battleNotifier.setSelectedTopicId('topic_notes');
          await battleNotifier.startBattle(seed: 105, roundCount: 4);
          await battleNotifier.enterArenaNow();
        });
        await pumpFrames(250);
        expect(find.byKey(const Key('battle_p1_opt_0')), findsOneWidget);
        expect(find.byKey(const Key('battle_p2_opt_0')), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Hiệp 1: 2 bên có câu hỏi độc lập (player1Question != player2Question), kèm hiệu ứng Sét đánh (strikeSerial / strikeTarget)
        await tester.runAsync(() async {
          final p1Q = container.read(battleProvider).player1Question!;
          final p2Q = container.read(battleProvider).player2Question!;
          expect(p1Q.id, isNot(equals(p2Q.id)),
              reason: '2 bên đánh riêng phải có 2 câu hỏi độc lập');
          final wrongOpt = p1Q.options.firstWhere((o) => !o.isCorrect);
          await battleNotifier.submitPlayer1Answer(wrongOpt);
          expect(container.read(battleProvider).p1LockedOut, isTrue);
          expect(container.read(battleProvider).player1Hp, equals(88));
          expect(container.read(battleProvider).isRoundResolved, isFalse);

          await battleNotifier.submitPlayer2Answer(p2Q.correctOption);
          final hpAfterFirstHit = container.read(battleProvider).player1Hp;
          // Rapid double-tap on already resolved round must be ignored safely
          await battleNotifier.submitPlayer2Answer(p2Q.correctOption);
          await battleNotifier.submitPlayer1Answer(p1Q.correctOption);
          expect(container.read(battleProvider).player1Hp, equals(hpAfterFirstHit));
          expect(container.read(battleProvider).isRoundResolved, isTrue);
          expect(container.read(battleProvider).roundWinner, equals('p2'));
          expect(container.read(battleProvider).strikeTarget, equals('p1'));
          expect(container.read(battleProvider).strikeSerial, greaterThan(0));
          expect(container.read(battleProvider).player1Hp, lessThan(88));
        });
        await pumpFrames(200);
        expect(tester.takeException(), isNull);

        // 4. Kiểm tra Bot AI Huyền Thoại (phân tầng câu hỏi Cơ bản/Trung bình/Nâng cao) & tạm dừng khi khóa màn hình (onAppPaused/onAppResumed)
        await tester.runAsync(() async {
          await battleNotifier.backToLobby();
          battleNotifier.setBattleMode(BattleMode.botAi);
          battleNotifier.setBotDifficulty(BotDifficulty.legend);
          battleNotifier.setSelectedTopicId('topic_chords');
          await battleNotifier.startBattle(seed: 77, roundCount: 8);
          await battleNotifier.enterArenaNow();
          battleNotifier.onAppPaused();
          battleNotifier.onAppResumed();
        });
        await pumpFrames(200);
        final legendQuestions = container.read(battleProvider).questions;
        expect(legendQuestions.length, equals(8));
        expect(
          legendQuestions.map((q) => q.levelId).toSet().length,
          greaterThanOrEqualTo(2),
          reason: 'Bot Huyền Thoại phải trộn câu hỏi từ nhiều cấp độ (Cơ bản/Trung bình/Nâng cao)',
        );
        expect(tester.takeException(), isNull);

        // 5. Kiểm tra chuyển Dark Mode ngay trong Đấu Trường trên màn hình nhỏ 360x680 (không lỗi tràn khung)
        await tester.runAsync(() async {
          await container
              .read(appSettingsProvider.notifier)
              .setThemeMode(ThemeMode.dark);
        });
        await pumpFrames(250);
        expect(tester.takeException(), isNull);

        await tester.runAsync(() async {
          await battleNotifier.backToLobby();
        });
        await pumpFrames(250);
        expect(find.byKey(const Key('battle_lobby_view')), findsOneWidget);
        expect(container.read(battleProvider).remainingBattlesToday, equals(2));

        // 6. Kiểm tra giới hạn 5 lượt/ngày: Dùng nốt 2 lượt còn lại (2 -> 1 -> 0) và kiểm tra chặn lượt thứ 6 + Xem QC hồi +1 lượt
        await tester.runAsync(() async {
          final ok4 = await battleNotifier.startBattle(seed: 111, roundCount: 4);
          expect(ok4, isTrue);
          expect(container.read(battleProvider).remainingBattlesToday, equals(1));
          await battleNotifier.backToLobby();

          final ok5 = await battleNotifier.startBattle(seed: 222, roundCount: 4);
          expect(ok5, isTrue);
          expect(container.read(battleProvider).remainingBattlesToday, equals(0));
          expect(container.read(battleProvider).canStartBattle, isFalse);
          await battleNotifier.backToLobby();

          // Lượt thứ 6 khi đã hết 5 lượt miễn phí -> bị chặn (trả về false)
          final ok6Blocked =
              await battleNotifier.startBattle(seed: 333, roundCount: 4);
          expect(ok6Blocked, isFalse);
          expect(container.read(battleProvider).phase, equals(BattlePhase.lobby));
        });
        await pumpFrames(250);
        expect(tester.takeException(), isNull);

        // Xem 1 quảng cáo (hồi +1 lượt đấu & +100 Điểm Uy Tín ủng hộ nhà phát triển) -> Có thể vào trận lại ngay!
        await tester.runAsync(() async {
          await container
              .read(rewardedAdProvider.notifier)
              .completeWatchingAd(watchedToEnd: true);
          await battleNotifier.restoreTurnFromRewardedAd(turns: 1);
          expect(container.read(battleProvider).remainingBattlesToday, equals(1));
          expect(container.read(battleProvider).adRestoredTurnsToday, equals(1));
          expect(container.read(battleProvider).canStartBattle, isTrue);

          final okAfterAd =
              await battleNotifier.startBattle(seed: 444, roundCount: 4);
          expect(okAfterAd, isTrue);
          expect(container.read(battleProvider).remainingBattlesToday, equals(0));
          await battleNotifier.backToLobby();
        });
        await pumpFrames(250);
        expect(tester.takeException(), isNull);

        // 7. Kiểm tra Đổi Điểm Uy Tín (100đ -> +1 Lượt Đấu) ngay tại Đấu Trường & tại Trạm Đổi Điểm (/support-developer)
        expect(container.read(rewardedAdProvider).prestigePoints, equals(100));
        expect(container.read(rewardedAdProvider).supportedCount, equals(1));
        expect(find.byKey(const Key('btn_battle_redeem_points_turn')), findsOneWidget);

        await tester.runAsync(() async {
          final redeemed = await container
              .read(rewardedAdProvider.notifier)
              .spendPrestigePointsForTurns(pointsCost: 100, turnsGranted: 1);
          expect(redeemed, isTrue);
          await battleNotifier.restoreTurnFromRewardedAd(turns: 1);
        });
        await pumpFrames(250);
        expect(container.read(rewardedAdProvider).prestigePoints, equals(0));
        expect(container.read(rewardedAdProvider).totalPrestigePoints, equals(100));
        expect(container.read(rewardedAdProvider).spentPrestigePoints, equals(100));
        // Danh hiệu vinh danh vĩnh viễn vẫn giữ nguyên dù đã đổi hết điểm khả dụng!
        expect(container.read(rewardedAdProvider).supportedCount, equals(1));
        expect(
          container.read(rewardedAdProvider).supporterBadgeTitle,
          equals('Người đồng hành Âm nhạc'),
        );
        expect(container.read(battleProvider).remainingBattlesToday, equals(1));

        // Kiểm tra giao diện Trạm Đổi Điểm Uy Tín trên màn hình Hỗ trợ nhà phát triển (/support-developer)
        await tester.tap(find.byKey(const Key('btn_close_battle_screen')));
        await pumpFrames(300);
        await tester.tap(find.byKey(const Key('btn_header_support_heart')));
        await pumpFrames(350);
        expect(find.byKey(const Key('card_redeem_prestige_points')), findsOneWidget);
        expect(find.byKey(const Key('btn_redeem_100_points')), findsOneWidget);
        expect(find.byKey(const Key('btn_redeem_250_points')), findsOneWidget);
        expect(find.byKey(const Key('btn_redeem_400_points')), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Tích lũy thêm 3 lượt ủng hộ (+300đ) và bấm trực tiếp nút Đổi gói 250đ -> +3 Lượt Đấu Trường
        await tester.runAsync(() async {
          for (int i = 0; i < 3; i++) {
            await container
                .read(rewardedAdProvider.notifier)
                .completeWatchingAd(watchedToEnd: true);
          }
        });
        await pumpFrames(250);
        expect(container.read(rewardedAdProvider).prestigePoints, equals(300));
        expect(container.read(rewardedAdProvider).supportedCount, equals(4));

        await tester.ensureVisible(
          find.byKey(const Key('btn_redeem_250_points')),
        );
        await pumpFrames(250);
        await tester.tap(find.byKey(const Key('btn_redeem_250_points')));
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        await pumpFrames(300);
        expect(container.read(rewardedAdProvider).prestigePoints, equals(50));
        expect(container.read(rewardedAdProvider).spentPrestigePoints, equals(350));
        expect(container.read(rewardedAdProvider).supportedCount, equals(4));
        expect(container.read(battleProvider).remainingBattlesToday, equals(4));
        expect(container.read(battleProvider).matchHistory.isNotEmpty, isTrue);

        // 8. Kiểm tra Nhiệm Vụ Hàng Ngày (+100 Điểm Uy Tín) & Chép Nhạc Giai Điệu
        await tester.runAsync(() async {
          await container
              .read(rewardedAdProvider.notifier)
              .recordMelodicDictationCompleted();
          final p1 = await container
              .read(rewardedAdProvider.notifier)
              .claimDailyQuest('practice');
          final p2 = await container
              .read(rewardedAdProvider.notifier)
              .claimDailyQuest('battle');
          final p3 = await container
              .read(rewardedAdProvider.notifier)
              .claimDailyQuest('dictation');
          expect(p1 + p2 + p3, equals(100));
        });
        await pumpFrames(200);
        expect(
          container.read(rewardedAdProvider).claimedQuestsCountToday,
          equals(3),
        );
        expect(container.read(rewardedAdProvider).prestigePoints, equals(150));
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'TC-22: Kiểm định toàn diện các bài học Nhận biết nốt (Mức 1..4), Đọc nốt nhạc (Mức 1..4) & Hệ thống thông tin người dùng (SQLite + Progress + Clear Data)',
      () async {
        await db.seedContent();
        await container.read(appSettingsProvider.notifier).loadSettings();
        final sessionNotifier =
            container.read(practiceSessionProvider.notifier);

        // 1. Kiểm tra cả 4 mức độ Nhận biết nốt (lvl_notes_basic -> inter -> adv -> master)
        const noteLevels = [
          'lvl_notes_basic',
          'lvl_notes_inter',
          'lvl_notes_adv',
          'lvl_notes_master',
        ];
        for (final lvlId in noteLevels) {
          final ok = await sessionNotifier.startSession(
            mode: 'topic',
            topicId: 'topic_notes',
            levelId: lvlId,
            targetCount: 10,
            seed: 2026,
          );
          expect(ok, isTrue, reason: 'Khởi tạo $lvlId phải thành công');
          final state = container.read(practiceSessionProvider);
          expect(state.topicId, equals('topic_notes'));
          expect(state.levelId, equals(lvlId));
          expect(state.questions.length, equals(10));

          for (final q in state.questions) {
            expect(q.prompt.contains('phím đàn'), isFalse,
                reason: 'Prompt không còn nhắc bấm phím đàn trong phòng học');
            expect(q.options.length, equals(4));
            final labels = q.options.map((o) => o.label).toSet();
            expect(labels.length, equals(4),
                reason: '4 đáp án A/B/C/D không bao giờ trùng lặp');
            expect(q.options.where((o) => o.isCorrect).length, equals(1));
          }

          // Trả lời đúng 8 câu, sai 2 câu để kiểm tra hệ thống lưu thông tin người dùng
          for (int i = 0; i < 10; i++) {
            final curQ =
                container.read(practiceSessionProvider).currentQuestion!;
            final chosen = i < 8
                ? curQ.correctOption
                : curQ.options.firstWhere((o) => !o.isCorrect);
            await sessionNotifier.submitAnswer(chosen);
            await sessionNotifier.nextQuestion();
          }
          expect(container.read(practiceSessionProvider).isCompleted, isTrue);
        }

        // 2. Sau khi đã có lịch sử học tập, bấm Luyện tập nhanh (mode: 'quick') vẫn ổn định vào Nhận biết nốt (topic_notes)
        final quickOk = await sessionNotifier.startSession(
          mode: 'quick',
          levelId: 'lvl_notes_inter',
          targetCount: 5,
          seed: 777,
        );
        expect(quickOk, isTrue);
        expect(
          container.read(practiceSessionProvider).topicId,
          equals('topic_notes'),
        );
        expect(
          container.read(practiceSessionProvider).levelId,
          equals('lvl_notes_inter'),
        );
        await sessionNotifier.abandonSessionIfIncomplete();

        // 3. Kiểm tra hệ thống thông tin người dùng (OverallProgressStats)
        final stats = await db.getOverallProgressStats();
        expect(stats.totalAnswered, equals(40));
        expect(stats.totalCorrect, equals(32));
        expect(stats.overallAccuracyPercent, closeTo(80.0, 0.01));
        expect(stats.currentStreakDays, greaterThanOrEqualTo(1));
        expect(stats.todayAnsweredCount, equals(40));
        expect(stats.isDailyGoalReached, isTrue);
        expect(stats.bestScore, equals(80));
        expect(stats.bestComboStreak, equals(8));
        expect(stats.noteMasteryStats.length, equals(12));
        expect(
          stats.topicStats
              .firstWhere((t) => t.topicId == 'topic_notes')
              .completedSessions,
          equals(4),
        );
        expect(
          stats.topicStats
              .firstWhere((t) => t.topicId == 'topic_notes')
              .totalAnswered,
          equals(40),
        );

        // 4. Kiểm tra chức năng Xóa dữ liệu lịch sử học tập (clearLearningHistory) bảo toàn 7 chủ đề & 23 cấp độ
        await db.clearLearningHistory();
        final clearedStats = await db.getOverallProgressStats();
        expect(clearedStats.totalAnswered, equals(0));
        expect(clearedStats.pendingReviewCount, equals(0));
        expect(clearedStats.bestScore, equals(0));
        final topicsAfterClear = await db.getTopics(onlyEnabled: true);
        expect(topicsAfterClear.length, equals(7));

        // 5. Kiểm tra hệ thống Dòng kẻ phụ (Ledger Lines: G3_SOL..C6 & C4_FA..D4_FA) và chế độ "Chuyên luyện Dòng kẻ phụ"
        for (final ledgerKey in const [
          'G3_SOL',
          'A3_SOL',
          'B3_SOL',
          'C4',
          'A5',
          'B5',
          'C6',
          'C4_FA',
          'D4_FA',
        ]) {
          expect(
            MusicalStaffWidget.isLedgerLineNoteKey(ledgerKey),
            isTrue,
            reason: '$ledgerKey phải được nhận diện là nốt trên dòng kẻ phụ',
          );
        }
        for (final inStaffKey in const ['E4', 'G4', 'B4', 'D5', 'F5']) {
          expect(
            MusicalStaffWidget.isLedgerLineNoteKey(inStaffKey),
            isFalse,
            reason: '$inStaffKey nằm trong 5 dòng kẻ chính của Khóa Sol',
          );
        }

        for (final staffLvl in const [
          'lvl_staff_basic',
          'lvl_staff_inter',
          'lvl_staff_adv',
          'lvl_staff_master',
        ]) {
          final ledgerOk = await sessionNotifier.startSession(
            mode: 'topic',
            topicId: 'topic_staff_reading',
            levelId: staffLvl,
            targetCount: 10,
            seed: 888,
            ledgerOnly: true,
          );
          expect(ledgerOk, isTrue);
          final ledgerQuestions =
              container.read(practiceSessionProvider).questions;
          expect(ledgerQuestions.length, equals(10));
          for (final q in ledgerQuestions) {
            expect(
              MusicalStaffWidget.isLedgerLineNoteKey(q.correctOption.optionKey),
              isTrue,
              reason:
                  'Ở chế độ Chuyên dòng kẻ phụ ($staffLvl), 100% câu hỏi phải thuộc dòng kẻ phụ (${q.correctOption.optionKey})',
            );
          }
          await sessionNotifier.abandonSessionIfIncomplete();
        }

        // 6. Kiểm tra Hệ Kinh Tế Gem (50 Gem cho 1 tiếng, +20 Gem mục tiêu hôm nay) & Chống Hack SolfaIntegrityGuard
        final sigValid = SolfaIntegrityGuard.computeWalletSignature(
          supportedCount: 2,
          bonusGems: 50,
          spentGems: 50,
        );
        expect(
          SolfaIntegrityGuard.verifyWalletSignature(
            supportedCount: 2,
            bonusGems: 50,
            spentGems: 50,
            savedSignature: sigValid,
          ),
          isTrue,
        );
        expect(
          SolfaIntegrityGuard.verifyWalletSignature(
            supportedCount: 2,
            bonusGems: 999999, // giả lập hack sửa điểm Gem trong SQLite
            spentGems: 50,
            savedSignature: sigValid,
          ),
          isFalse,
          reason: 'SolfaIntegrityGuard phải phát hiện hành vi sửa điểm Gem trái phép',
        );
        expect(
          SolfaIntegrityGuard.isSystemClockValid(
            lastVerifiedEpochMs: 1700000000000,
            currentEpochMs: 1700000000000 - (2 * 3600 * 1000), // chỉnh lùi 2 tiếng
          ),
          isFalse,
          reason: 'SolfaIntegrityGuard phải phát hiện hành vi chỉnh lùi giờ hệ thống',
        );

        final adNotifier = container.read(rewardedAdProvider.notifier);
        // Khi chưa có Gem (0 Gem), mở gói 1 tiếng (50 Gem) phải từ chối
        expect(await adNotifier.spendGemsForOneHourSession(), isFalse);
        // Nhận thưởng hoàn thành Mục tiêu hôm nay (+20 Gem) và Nhiệm vụ Khởi động (+30 Gem) => tổng 50 Gem
        final dailyBonus = await adNotifier.awardDailyGoalBonusIfEligible();
        expect(dailyBonus, equals(20));
        // Nhận lần 2 trong cùng ngày sẽ trả về 0 (chống nhận trùng)
        expect(await adNotifier.awardDailyGoalBonusIfEligible(), equals(0));
        final practiceQuest = await adNotifier.claimDailyQuest('practice');
        expect(practiceQuest, equals(30));
        expect(container.read(rewardedAdProvider).prestigePoints, equals(50));
        // Đủ 50 Gem -> mở khóa phiên luyện tập chuyên sâu 1 tiếng thành công, trừ 50 Gem
        expect(await adNotifier.spendGemsForOneHourSession(), isTrue);
        expect(container.read(rewardedAdProvider).prestigePoints, equals(0));
        // 7. Kiểm tra cả 4 bài học Chế độ Guitar từ Cơ bản -> Trung bình -> Nâng cao & Lưu lịch sử / Ôn câu sai
        for (final gtrTopic in const [
          'topic_guitar_notes',
          'topic_guitar_chords',
          'topic_guitar_scales',
          'topic_guitar_tabs',
        ]) {
          for (final suffix in const ['basic', 'inter', 'adv']) {
            final gtrOk = await sessionNotifier.startSession(
              mode: 'topic',
              topicId: gtrTopic,
              levelId: '${gtrTopic.replaceFirst('topic_', 'lvl_')}_$suffix',
              targetCount: 6,
              seed: 555,
            );
            expect(gtrOk, isTrue,
                reason: 'Khởi tạo $gtrTopic ($suffix) phải thành công');
            final gtrQuestions =
                container.read(practiceSessionProvider).questions;
            expect(gtrQuestions.length, equals(6));
            for (final q in gtrQuestions) {
              expect(q.options.length, equals(4));
              expect(
                q.correctOption.optionKey.startsWith('GTR_'),
                isTrue,
                reason: 'Câu hỏi $gtrTopic phải gắn mã sơ đồ trực quan GTR_',
              );
              final wavFile = File(q.audioAsset);
              expect(
                wavFile.existsSync(),
                isTrue,
                reason: 'File âm thanh ${q.audioAsset} của $gtrTopic phải tồn tại thật trên ổ đĩa',
              );
              expect(wavFile.lengthSync(), greaterThan(1000));
            }
            await sessionNotifier.abandonSessionIfIncomplete();
          }
        }

        // Kiểm tra toàn bộ 78 vị trí trên Cần đàn Guitar (6 dây x 13 ngăn 0..12) và 8 hợp âm Guitar đều phát đúng cao độ vật lý & có file WAV thật
        expect(
          GuitarFretboardData.noteAt(stringNumber: 6, fret: 0).audioAsset,
          equals('assets/audio/notes/e2.wav'),
        );
        expect(
          GuitarFretboardData.noteAt(stringNumber: 5, fret: 0).audioAsset,
          equals('assets/audio/notes/a2.wav'),
        );
        expect(
          GuitarFretboardData.noteAt(stringNumber: 4, fret: 0).audioAsset,
          equals('assets/audio/notes/d3.wav'),
        );
        expect(
          GuitarFretboardData.noteAt(stringNumber: 3, fret: 0).audioAsset,
          equals('assets/audio/notes/g3.wav'),
        );
        expect(
          GuitarFretboardData.noteAt(stringNumber: 2, fret: 0).audioAsset,
          equals('assets/audio/notes/b3.wav'),
        );
        expect(
          GuitarFretboardData.noteAt(stringNumber: 1, fret: 0).audioAsset,
          equals('assets/audio/notes/e4.wav'),
        );
        expect(
          GuitarFretboardData.noteAt(stringNumber: 1, fret: 12).audioAsset,
          equals('assets/audio/notes/e5.wav'),
        );
        for (int s = 1; s <= 6; s++) {
          for (int f = 0; f <= 12; f++) {
            final note = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
            final file = File(note.audioAsset);
            expect(
              file.existsSync(),
              isTrue,
              reason: 'Dây $s ngăn $f (${note.fullLabel}) thiếu file ${note.audioAsset}',
            );
          }
        }
        for (final chord in GuitarFretboardData.commonChords) {
          final file = File(chord.audioAsset);
          expect(
            file.existsSync(),
            isTrue,
            reason: 'Hợp âm ${chord.id} thiếu file ${chord.audioAsset}',
          );
        }

        // Hoàn thành 1 phiên Guitar (5 đúng, 1 sai) -> Kiểm tra lưu tên bài trên Trang chủ & Danh sách Ôn câu sai
        final gtrPlayOk = await sessionNotifier.startSession(
          mode: 'topic',
          topicId: 'topic_guitar_notes',
          levelId: 'lvl_guitar_notes_adv',
          targetCount: 6,
          seed: 999,
        );
        expect(gtrPlayOk, isTrue);
        for (int i = 0; i < 6; i++) {
          final curQ = container.read(practiceSessionProvider).currentQuestion!;
          final chosen = i < 5
              ? curQ.correctOption
              : curQ.options.firstWhere((o) => !o.isCorrect);
          await sessionNotifier.submitAnswer(chosen);
          await sessionNotifier.nextQuestion();
        }
        expect(container.read(practiceSessionProvider).isCompleted, isTrue);
        final afterGtrStats = await db.getOverallProgressStats();
        expect(
          afterGtrStats.recentSessions.first.topicName,
          equals('Nhớ nốt Cần đàn Guitar'),
        );
        expect(
          afterGtrStats.recentSessions.first.levelName,
          equals('Mức 3: Nâng cao'),
        );
        final gtrReviewItems = await db.getPendingReviewItems();
        expect(gtrReviewItems.length, equals(1));
        expect(
          gtrReviewItems.first.topicName,
          equals('Nhớ nốt Cần đàn Guitar'),
        );

        // 8. Kiểm tra Nhận diện Quốc gia/Khu vực (EU 2018/302 & 174+ Quốc gia), Chuyển đổi Ngôn ngữ (VI <-> EN) & Ký hiệu Nhạc lý
        final vnInfo = AppLocale.detectCountry(overrideCountryCode: 'VN');
        expect(vnInfo.countryCode, equals('VN'));
        expect(vnInfo.defaultLanguageCode, equals('vi'));
        expect(vnInfo.isEuMember, isFalse);

        final deInfo = AppLocale.detectCountry(overrideCountryCode: 'DE');
        expect(deInfo.countryCode, equals('DE'));
        expect(deInfo.defaultLanguageCode, equals('en'));
        expect(deInfo.isEuMember, isTrue);
        expect(deInfo.regulatoryRegion, contains('EU 2018/302'));

        final egInfo = AppLocale.detectCountry(overrideCountryCode: 'EG');
        expect(egInfo.countryCode, equals('EG'));
        expect(egInfo.defaultLanguageCode, equals('en'));

        final settingsNotifier = container.read(appSettingsProvider.notifier);
        await settingsNotifier.loadSettings();
        expect(container.read(appSettingsProvider).isEnglish, isFalse);

        // Khi chọn quốc gia Đức (EU) ở chế độ Auto -> Ngôn ngữ tự động chuyển sang Tiếng Anh ('en')
        await settingsNotifier.setCountryCodeOverride('DE');
        expect(container.read(appSettingsProvider).detectedCountry.countryCode,
            equals('DE'));
        expect(container.read(appSettingsProvider).isEnglish, isTrue);

        // Dịch tự động thuật ngữ nhạc lý sang chuẩn Quốc tế C-D-E khi ở chế độ Tiếng Anh
        final translatedNote = AppLocale.localizeMusicalText(
          'Khóa Sol • Dòng kẻ phụ • Đô Trưởng',
          true,
        );
        expect(translatedNote, contains('Treble Clef'));
        expect(translatedNote, contains('Ledger Line'));
        expect(translatedNote, contains('C Major'));

        // Người dùng vẫn có thể chủ động chuyển về Tiếng Việt ('vi') hoặc Tiếng Anh ('en')
        await settingsNotifier.setLanguageMode('vi');
        expect(container.read(appSettingsProvider).isEnglish, isFalse);
        await settingsNotifier.setCountryCodeOverride('');
        await settingsNotifier.setLanguageMode('auto');
        expect(container.read(appSettingsProvider).isEnglish, isFalse);
      },
    );
  });
}
