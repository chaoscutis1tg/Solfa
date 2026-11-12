import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfa/app/app.dart';
import 'package:solfa/app/router.dart';
import 'package:solfa/core/audio/audio_service.dart';
import 'package:solfa/core/database/app_database.dart';
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
  });
}
