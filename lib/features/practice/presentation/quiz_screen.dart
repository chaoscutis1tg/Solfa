import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/note_formatter.dart';
import '../application/practice_session_controller.dart';
import 'widgets/piano_keyboard_widget.dart';

/// UI-05 (Màn hình câu hỏi Phòng luyện tập) & UI-06 (Phản hồi câu trả lời)
/// - Tự động chuyển sang nốt tiếp theo sau 0.8s khi chọn Đúng.
/// - Dừng lại hiển thị giải thích chi tiết khi chọn Sai.
/// - Bố cục đáp án 2 cột gọn gàng trong 1 màn hình + AlwaysScrollable BouncingScrollPhysics.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with WidgetsBindingObserver {
  bool _navigatedToResult = false;
  Timer? _autoAdvanceTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _goToResultOnce() {
    if (_navigatedToResult || !mounted) return;
    _autoAdvanceTimer?.cancel();
    _navigatedToResult = true;
    context.pushReplacement('/session-result');
  }

  Future<void> _handleSelectOption(QuestionOptionModel option) async {
    final notifier = ref.read(practiceSessionProvider.notifier);
    await notifier.submitAnswer(option);
    if (!mounted) return;

    final currentState = ref.read(practiceSessionProvider);
    final answeredQuestionId = currentState.currentQuestion?.id;

    if (currentState.isCurrentAnswered && currentState.isCurrentCorrect) {
      // Auto-advance after 0.8 seconds when the user selects a CORRECT answer
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = Timer(const Duration(milliseconds: 800), () async {
        if (!mounted || _navigatedToResult) return;
        final latest = ref.read(practiceSessionProvider);
        if (latest.isCompleted) {
          _goToResultOnce();
          return;
        }
        if (latest.isCurrentAnswered &&
            latest.isCurrentCorrect &&
            latest.currentQuestion?.id == answeredQuestionId) {
          final finished = await ref
              .read(practiceSessionProvider.notifier)
              .nextQuestion();
          if (finished) {
            _goToResultOnce();
          }
        }
      });
    } else if (currentState.isCurrentAnswered && !currentState.isCurrentCorrect) {
      // When WRONG, pause for explanation and smoothly ensure the feedback banner is visible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          _scrollController.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  Future<void> _advanceManually() async {
    _autoAdvanceTimer?.cancel();
    final finished =
        await ref.read(practiceSessionProvider.notifier).nextQuestion();
    if (finished) {
      _goToResultOnce();
    } else if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(practiceSessionProvider.notifier);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      notifier.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      notifier.onAppResumed();
    }
  }

  Future<bool> _confirmExitSession() async {
    _autoAdvanceTimer?.cancel();
    final sessionState = ref.read(practiceSessionProvider);
    if (sessionState.isCompleted || sessionState.questions.isEmpty) {
      return true;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kết thúc phiên luyện tập?'),
        content: Text(
          sessionState.answeredCount > 0
              ? 'Bạn đã trả lời ${sessionState.answeredCount} nốt (Đúng: ${sessionState.correctCount}, Sai: ${sessionState.wrongCount}). Bạn muốn lưu kết quả & tính điểm hay thoát phiên?'
              : 'Nếu thoát bây giờ, phiên học hiện tại sẽ được đánh dấu dở dang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Tiếp tục luyện'),
          ),
          if (sessionState.answeredCount > 0)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.correct,
                minimumSize: const Size(120, 40),
              ),
              onPressed: () => Navigator.of(ctx).pop('finish_score'),
              child: const Text('Lưu & Tính điểm'),
            ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.wrong),
            onPressed: () => Navigator.of(ctx).pop('abandon'),
            child: const Text('Thoát phiên'),
          ),
        ],
      ),
    );

    if (action == 'finish_score') {
      await ref.read(practiceSessionProvider.notifier).finishSessionNow();
      _goToResultOnce();
      return false;
    }

    if (action == 'abandon') {
      await ref
          .read(practiceSessionProvider.notifier)
          .abandonSessionIfIncomplete();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Automatically navigate to SessionResultScreen when countdown timer expires
    ref.listen<bool>(
      practiceSessionProvider.select((s) => s.isCompleted),
      (prev, next) {
        if (next && prev != true) {
          _goToResultOnce();
        }
      },
    );

    // Watch ONLY question-level state so 1-second timer ticks never rebuild the quiz body!
    final viewState = ref.watch(
      practiceSessionProvider.select(
        (s) => (
          isLoading: s.isLoading,
          currentQuestion: s.currentQuestion,
          currentIndex: s.currentIndex,
          selectedOption: s.selectedOption,
          isContinuousScoringMode: s.isContinuousScoringMode,
          questionsLength: s.questions.length,
          errorMessage: s.errorMessage,
        ),
      ),
    );

    final audioService = ref.watch(audioServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (viewState.isLoading) {
      return const SolfaBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final question = viewState.currentQuestion;
    if (question == null) {
      return SolfaBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('Phòng luyện tập')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    viewState.errorMessage ?? 'Không có câu hỏi khả dụng.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Quay lại'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final isCurrentAnswered = viewState.selectedOption != null;
    final isCurrentCorrect = viewState.selectedOption?.isCorrect ?? false;
    final isLastFixedQuestion = !viewState.isContinuousScoringMode &&
        (viewState.currentIndex + 1 >= viewState.questionsLength);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canLeave = await _confirmExitSession();
        if (canLeave && context.mounted) {
          context.pop();
        }
      },
      child: SolfaBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Thoát phiên',
              onPressed: () async {
                final canLeave = await _confirmExitSession();
                if (canLeave && context.mounted) {
                  context.pop();
                }
              },
            ),
            title: Text(
              viewState.isContinuousScoringMode
                  ? 'Phòng luyện tập • Nốt #${viewState.currentIndex + 1}'
                  : 'Câu ${viewState.currentIndex + 1} / ${viewState.questionsLength}',
              style:
                  const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: TextButton.icon(
                  key: const Key('btn_finish_session_now'),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.14),
                    foregroundColor:
                        isDark ? AppColors.secondary : AppColors.primaryDark,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  onPressed: () async {
                    _autoAdvanceTimer?.cancel();
                    await ref
                        .read(practiceSessionProvider.notifier)
                        .finishSessionNow();
                    _goToResultOnce();
                  },
                  icon: const Icon(Icons.emoji_events_outlined, size: 16),
                  label: const Text(
                    'Tính điểm',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
              children: [
                // 0. Isolated Live Timer, Duration Selector & Note Scoreboard Header
                const RepaintBoundary(
                  child: _PracticeRoomScoreboardHeader(),
                ),
                const SizedBox(height: 10),

                // 1. Compact Question Studio Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          question.prompt,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Main Audio Studio Player Box (UI-05)
                        ValueListenableBuilder<bool>(
                          valueListenable: audioService.isPlayingNotifier,
                          builder: (context, isPlaying, _) {
                            return Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    key: const Key('btn_play_question_audio'),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(0, 46),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      backgroundColor: isPlaying
                                          ? AppColors.primaryDark
                                          : AppColors.primary,
                                    ),
                                    onPressed: () {
                                      audioService
                                          .playAsset(question.audioAsset);
                                    },
                                    icon: Icon(
                                      isPlaying
                                          ? Icons.graphic_eq_rounded
                                          : Icons.volume_up_rounded,
                                      size: 22,
                                    ),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        isPlaying
                                            ? 'Đang phát... (Nghe lại)'
                                            : 'Nghe âm thanh câu hỏi',
                                        style: const TextStyle(fontSize: 14.5),
                                      ),
                                    ),
                                  ),
                                ),
                                if (question.supportsReferencePitch) ...[
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    key: const Key('btn_play_reference_c4'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 46),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                    ),
                                    onPressed: () {
                                      audioService.playReferenceC4();
                                    },
                                    icon: const Icon(
                                      Icons.music_note_outlined,
                                      size: 17,
                                    ),
                                    label: const Text(
                                      'Đô C4',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),

                        // Visual & Interactive Piano Helper (UC-05)
                        if (question.showPianoHelper) ...[
                          const SizedBox(height: 10),
                          PianoKeyboardWidget(
                            highlightedNoteKey:
                                question.correctOption.optionKey,
                            selectedNoteKey:
                                viewState.selectedOption?.optionKey,
                            showHighlight: isCurrentAnswered,
                            onKeyTap: isCurrentAnswered
                                ? (noteCode) {
                                    audioService.playPianoKey(noteCode);
                                  }
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Row(
                    children: [
                      const Text(
                        'Chọn đáp án:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Đúng: tự chuyển sau 0.8s • Sai: dừng giải thích',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Answer Options in a 2-Column Grid (Fits on 1 screen without scrolling!)
                _buildOptionsGrid(
                  options: question.options,
                  isAnswered: isCurrentAnswered,
                  selectedOptionId: viewState.selectedOption?.id,
                  isDark: isDark,
                ),

                // 3. Instant Feedback Card (UI-06)
                if (isCurrentAnswered)
                  Padding(
                    key: ValueKey<String>('fb_${question.id}'),
                    padding: const EdgeInsets.only(top: 6),
                    child: _FeedbackBanner(
                      isCorrect: isCurrentCorrect,
                      correctLabel: question.correctOption.label,
                      explanation: question.explanation,
                      isLastQuestion: isLastFixedQuestion,
                      isDark: isDark,
                      onReplayAudio: () {
                        audioService.playAsset(question.audioAsset);
                      },
                      onContinue: _advanceManually,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsGrid({
    required List<QuestionOptionModel> options,
    required bool isAnswered,
    required String? selectedOptionId,
    required bool isDark,
  }) {
    const badges = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    final rows = <Widget>[];

    for (int i = 0; i < options.length; i += 2) {
      final first = options[i];
      final badge1 = i < badges.length ? badges[i] : '${i + 1}';

      if (i + 1 < options.length) {
        final second = options[i + 1];
        final badge2 = (i + 1) < badges.length ? badges[i + 1] : '${i + 2}';
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: _OptionButton(
                    badge: badge1,
                    option: first,
                    isAnswered: isAnswered,
                    isSelected: selectedOptionId == first.id,
                    isDark: isDark,
                    onTap: () => _handleSelectOption(first),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OptionButton(
                    badge: badge2,
                    option: second,
                    isAnswered: isAnswered,
                    isSelected: selectedOptionId == second.id,
                    isDark: isDark,
                    onTap: () => _handleSelectOption(second),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionButton(
              badge: badge1,
              option: first,
              isAnswered: isAnswered,
              isSelected: selectedOptionId == first.id,
              isDark: isDark,
              onTap: () => _handleSelectOption(first),
            ),
          ),
        );
      }
    }

    return Column(children: rows);
  }
}

/// Isolated Header for Practice Room Duration Modes (60s, 15m, 1h, Unlimited) & Live Note Scoreboard.
class _PracticeRoomScoreboardHeader extends ConsumerWidget {
  const _PracticeRoomScoreboardHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreState = ref.watch(
      practiceSessionProvider.select(
        (s) => (
          timeLimitSeconds: s.timeLimitSeconds,
          isUnlimitedMode: s.isUnlimitedMode,
          elapsedSeconds: s.elapsedSeconds,
          remainingSeconds: s.remainingSeconds,
          correctCount: s.correctCount,
          wrongCount: s.wrongCount,
          scorePoints: s.scorePoints,
          isContinuous: s.isContinuousScoringMode,
          currentIndex: s.currentIndex,
          questionsLength: s.questions.length,
        ),
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeDurationOption = scoreState.isUnlimitedMode
        ? 0
        : (scoreState.timeLimitSeconds ?? -1);

    final String timerDisplay;
    final double progressValue;
    if (scoreState.timeLimitSeconds != null &&
        scoreState.timeLimitSeconds! > 0) {
      timerDisplay =
          NoteFormatter.formatDurationSeconds(scoreState.remainingSeconds);
      progressValue = (scoreState.remainingSeconds /
              scoreState.timeLimitSeconds!)
          .clamp(0.0, 1.0);
    } else if (scoreState.isUnlimitedMode) {
      timerDisplay =
          '∞ ${NoteFormatter.formatDurationSeconds(scoreState.elapsedSeconds)}';
      progressValue = 1.0;
    } else {
      timerDisplay =
          '${scoreState.currentIndex + 1}/${scoreState.questionsLength} câu';
      progressValue = scoreState.questionsLength > 0
          ? (scoreState.currentIndex + 1) / scoreState.questionsLength
          : 0.0;
    }

    final isLowTime = scoreState.timeLimitSeconds != null &&
        scoreState.remainingSeconds <= 10;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Duration Selector Chips (60s, 15p, 1h, Không giới hạn)
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Thời gian:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: [
                      _QuickTimeModePill(
                        label: '60s',
                        isSelected: activeDurationOption == 60,
                        isDark: isDark,
                        onTap: () => ref
                            .read(practiceSessionProvider.notifier)
                            .setPracticeDurationOption(60),
                      ),
                      const SizedBox(width: 4),
                      _QuickTimeModePill(
                        label: '15p',
                        isSelected: activeDurationOption == 900,
                        isDark: isDark,
                        onTap: () => ref
                            .read(practiceSessionProvider.notifier)
                            .setPracticeDurationOption(900),
                      ),
                      const SizedBox(width: 4),
                      _QuickTimeModePill(
                        label: '1 tiếng',
                        isSelected: activeDurationOption == 3600,
                        isDark: isDark,
                        onTap: () => ref
                            .read(practiceSessionProvider.notifier)
                            .setPracticeDurationOption(3600),
                      ),
                      const SizedBox(width: 4),
                      _QuickTimeModePill(
                        label: 'Tự do',
                        isSelected: activeDurationOption == 0,
                        isDark: isDark,
                        onTap: () => ref
                            .read(practiceSessionProvider.notifier)
                            .setPracticeDurationOption(0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Live Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 4,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isLowTime ? AppColors.wrong : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Row 3: Live Note Scoreboard (Đồng hồ, Nốt Đúng, Nốt Sai, Điểm)
            Row(
              children: [
                Expanded(
                  child: _ScoreBadgeBox(
                    label: scoreState.timeLimitSeconds != null
                        ? 'Còn lại'
                        : 'Thời gian',
                    value: timerDisplay,
                    color: isLowTime ? AppColors.wrong : AppColors.primary,
                    icon: Icons.access_time_filled_rounded,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ScoreBadgeBox(
                    label: 'Nốt đúng',
                    value: '${scoreState.correctCount}',
                    color: AppColors.correct,
                    icon: Icons.check_circle_rounded,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ScoreBadgeBox(
                    label: 'Nốt sai',
                    value: '${scoreState.wrongCount}',
                    color: AppColors.wrong,
                    icon: Icons.cancel_rounded,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ScoreBadgeBox(
                    label: 'Điểm số',
                    value: '${scoreState.scorePoints}',
                    color: AppColors.accentAmber,
                    icon: Icons.stars_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTimeModePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickTimeModePill({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected
            ? AppColors.primary
            : (isDark
                ? Colors.white.withOpacity(0.08)
                : AppColors.primary.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            height: 25,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.primaryDark),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreBadgeBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _ScoreBadgeBox({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12.5, color: color),
              const SizedBox(width: 3),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String badge;
  final QuestionOptionModel option;
  final bool isAnswered;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _OptionButton({
    required this.badge,
    required this.option,
    required this.isAnswered,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = AppColors.primary.withOpacity(0.24);
    Color? bgColor;
    Color badgeBgColor = AppColors.primary.withOpacity(0.12);
    Color badgeTextColor = isDark ? AppColors.secondary : AppColors.primaryDark;
    IconData? trailingIcon;
    Color? iconColor;

    if (isAnswered) {
      if (option.isCorrect) {
        borderColor = AppColors.correct;
        bgColor = isDark ? AppColors.correctBgDark : AppColors.correctBgLight;
        badgeBgColor = AppColors.correct;
        badgeTextColor = Colors.white;
        trailingIcon = Icons.check_circle_rounded;
        iconColor = AppColors.correct;
      } else if (isSelected && !option.isCorrect) {
        borderColor = AppColors.wrong;
        bgColor = isDark ? AppColors.wrongBgDark : AppColors.wrongBgLight;
        badgeBgColor = AppColors.wrong;
        badgeTextColor = Colors.white;
        trailingIcon = Icons.cancel_rounded;
        iconColor = AppColors.wrong;
      }
    }

    return Material(
      color: bgColor ?? Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('option_${option.optionKey}'),
        borderRadius: BorderRadius.circular(14),
        onTap: isAnswered ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width:
                  (isAnswered && (option.isCorrect || isSelected)) ? 2.0 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: badgeTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailingIcon != null)
                Icon(trailingIcon, color: iconColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  final bool isCorrect;
  final String correctLabel;
  final String explanation;
  final bool isLastQuestion;
  final bool isDark;
  final VoidCallback onReplayAudio;
  final VoidCallback onContinue;

  const _FeedbackBanner({
    required this.isCorrect,
    required this.correctLabel,
    required this.explanation,
    required this.isLastQuestion,
    required this.isDark,
    required this.onReplayAudio,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isCorrect ? AppColors.correct : AppColors.wrong;
    final bgColor = isCorrect
        ? (isDark ? AppColors.correctBgDark : AppColors.correctBgLight)
        : (isDark ? AppColors.wrongBgDark : AppColors.wrongBgLight);

    if (isCorrect) {
      // Compact celebratory banner when Correct (since it auto-advances in 0.8s!)
      return Container(
        key: const Key('feedback_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.correct,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Chính xác! +10 điểm • Tự chuyển nốt...',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.correct,
                ),
              ),
            ),
            TextButton(
              key: const Key('btn_next_question'),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.correct,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onContinue,
              child: Text(
                isLastQuestion ? 'Kết quả' : 'Tiếp ngay',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Detailed explanation banner when WRONG (pauses so user can review and tap Next)
    return Container(
      key: const Key('feedback_banner'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_rounded,
                color: accentColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chưa chính xác • Đáp án: $correctLabel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: onReplayAudio,
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: const Text('Nghe lại'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            explanation,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            key: const Key('btn_next_question'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: onContinue,
            icon: Icon(
              isLastQuestion
                  ? Icons.emoji_events_rounded
                  : Icons.arrow_forward_rounded,
              size: 19,
            ),
            label: Text(
              isLastQuestion ? 'Xem kết quả phiên' : 'Đã hiểu • Nốt tiếp theo',
            ),
          ),
        ],
      ),
    );
  }
}
