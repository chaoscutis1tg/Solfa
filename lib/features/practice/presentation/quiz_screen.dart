import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/note_formatter.dart';
import '../../guitar/presentation/guitar_studio_sheet.dart';
import '../application/practice_session_controller.dart';
import 'widgets/musical_staff_widget.dart';

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

  void _safeLeaveQuiz() {
    _autoAdvanceTimer?.cancel();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _handleSelectOption(QuestionOptionModel option) async {
    final notifier = ref.read(practiceSessionProvider.notifier);
    await notifier.submitAnswer(option);
    if (!mounted) return;
    _postAnswerReaction();
  }

  void _postAnswerReaction() {
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

    // Cancel any pending auto-advance timer whenever a new question/level/mode resets selectedOption
    ref.listen<QuestionOptionModel?>(
      practiceSessionProvider.select((s) => s.selectedOption),
      (prev, next) {
        if (next == null) {
          _autoAdvanceTimer?.cancel();
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
                    onPressed: _safeLeaveQuiz,
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
          _safeLeaveQuiz();
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
                  _safeLeaveQuiz();
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
                          _concisePrompt(question.prompt),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Audio Studio Replay Bar (Auto-plays on question entry; tap to replay anytime)
                        ValueListenableBuilder<bool>(
                          valueListenable: audioService.isPlayingNotifier,
                          builder: (context, isPlaying, _) {
                            return Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    key: const Key('btn_play_question_audio'),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(0, 44),
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
                                      size: 20,
                                    ),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        isPlaying
                                            ? 'Đang phát... (Nghe lại)'
                                            : 'Nghe lại âm thanh câu hỏi',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ),
                                ),
                                if (question.supportsReferencePitch) ...[
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    key: const Key('btn_play_reference_c4'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 44),
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

                        // Visual 5-Line Musical Staff (Piano/Theory) or Interactive Guitar Fretboard/Tab Board (Guitar Mode)
                        if (question.topicId.startsWith('topic_guitar_')) ...[
                          const SizedBox(height: 12),
                          GuitarQuestionBoardWidget(
                            topicId: question.topicId,
                            optionKey: question.correctOption.optionKey,
                            isRevealed: isCurrentAnswered,
                          ),
                        ] else if (question.showPianoHelper) ...[
                          const SizedBox(height: 12),
                          MusicalStaffWidget(
                            targetNoteKey: question.correctOption.optionKey,
                            selectedNoteKey:
                                viewState.selectedOption?.optionKey,
                            showNote: isCurrentAnswered,
                            isSightReading: question.isSightReading,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 5),
                  child: Text(
                    'Chọn đáp án:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
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

  String _concisePrompt(String rawPrompt) {
    final cleaned = rawPrompt
        .replaceAll(RegExp(r'^\[[^\]]+\]\s*'), '')
        .replaceAll(' (hoặc bấm trực tiếp phím đàn)', '')
        .replaceAll(' (hoặc bấm phím đàn)', '')
        .trim();
    return cleaned.isEmpty ? rawPrompt : cleaned;
  }

  Widget _buildOptionsGrid({
    required List<QuestionOptionModel> options,
    required bool isAnswered,
    required String? selectedOptionId,
    required bool isDark,
  }) {
    const badges = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    final rows = <Widget>[];
    final useSingleColumn =
        options.length <= 4 && options.any((o) => o.label.length > 18);

    if (useSingleColumn) {
      for (int i = 0; i < options.length; i++) {
        final opt = options[i];
        final badge = i < badges.length ? badges[i] : '${i + 1}';
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionButton(
              badge: badge,
              option: opt,
              isAnswered: isAnswered,
              isSelected: selectedOptionId == opt.id,
              isDark: isDark,
              onTap: () => _handleSelectOption(opt),
            ),
          ),
        );
      }
      return Column(children: rows);
    }

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

/// Isolated Header for Progress, Time, and Compact Score/Combo (Section 3.4).
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
          scorePoints: s.scorePoints,
          currentCombo: s.currentCombo,
          currentIndex: s.currentIndex,
          questionsLength: s.questions.length,
        ),
      ),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          'Câu ${scoreState.currentIndex + 1} / ${scoreState.questionsLength}';
      progressValue = scoreState.questionsLength > 0
          ? (scoreState.currentIndex + 1) / scoreState.questionsLength
          : 0.0;
    }

    final isLowTime = scoreState.timeLimitSeconds != null &&
        scoreState.remainingSeconds <= 10;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1.Thanh tiến trình và thời gian
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 6,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                isLowTime ? AppColors.wrong : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Điểm số và Combo ở dạng thông tin nhỏ gọn
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: isLowTime
                        ? AppColors.wrong
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    timerDisplay,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isLowTime ? AppColors.wrong : null,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (scoreState.currentCombo >= 2) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentAmber.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'Combo x${scoreState.currentCombo}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentAmber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '${scoreState.scorePoints} điểm',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: option.label.length > 26 ? 13.0 : 14.0,
                    fontWeight: FontWeight.w700,
                    height: 1.22,
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
