import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/note_formatter.dart';

/// Interactive/Visual 5-line Musical Staff widget supporting both:
/// - **Ear Training mode (`isSightReading == false`)**:
///   Hides the note (`?`) while listening, then reveals the note on the staff after answering.
/// - **Sight-Reading mode (`isSightReading == true`)**:
///   Plots the note (notehead, stem, ledger lines, sharp `♯`) on the 5-line staff
///   (Treble Clef `𝄞` for C4–B5, Bass Clef `𝄢` for C3–B3) BEFORE answering while
///   hiding the note name (`?`), then reveals the answer (`✓` / `✗`) after answering.
class MusicalStaffWidget extends StatelessWidget {
  final String? targetNoteKey; // e.g. 'C4', 'F#4', 'G3', 'C5'
  final String? selectedNoteKey; // e.g. 'D4'
  final bool showNote;
  final bool isSightReading;

  const MusicalStaffWidget({
    super.key,
    required this.targetNoteKey,
    this.selectedNoteKey,
    required this.showNote,
    this.isSightReading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasWrongComparison = showNote &&
        selectedNoteKey != null &&
        targetNoteKey != null &&
        selectedNoteKey!.toUpperCase() != targetNoteKey!.toUpperCase();

    final targetParsed = _ParsedStaffNote.tryParse(targetNoteKey);
    final useBassClef = targetParsed != null && targetParsed.octave <= 3;

    final String headerTitle = useBassClef
        ? '🎼 Khuông nhạc Khóa Fa (𝄢)'
        : '🎼 Khuông nhạc Khóa Sol (𝄞)';

    final String statusBadgeText;
    if (showNote) {
      statusBadgeText =
          'Vị trí: ${NoteFormatter.toVietnameseLabel(targetNoteKey ?? '')}';
    } else if (isSightReading) {
      statusBadgeText = useBassClef
          ? '👁️ Đọc Khóa Fa (Dòng 4 = Fa3)'
          : '👁️ Đọc Khóa Sol (Dòng 2 = Sol4)';
    } else {
      statusBadgeText = 'Hiện vị trí nốt sau khi chọn đáp án';
    }

    final Color activeHeaderColor = isSightReading
        ? (isDark ? AppColors.secondary : const Color(0xFF635BFF))
        : (isDark ? AppColors.secondary : AppColors.primary);

    return Container(
      key: const Key('musical_staff_widget'),
      height: isSightReading ? 90 : 82,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1E36).withOpacity(0.92)
            : const Color(0xFFF6F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: showNote
              ? (hasWrongComparison
                  ? AppColors.wrong.withOpacity(0.45)
                  : AppColors.correct.withOpacity(0.45))
              : activeHeaderColor.withOpacity(isSightReading ? 0.42 : 0.22),
          width: isSightReading && !showNote ? 1.5 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dedicated Header Row (never overlaps high notes on the staff!)
          SizedBox(
            height: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    headerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: activeHeaderColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: showNote
                          ? AppColors.correct.withOpacity(0.15)
                          : activeHeaderColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        statusBadgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color:
                              showNote ? AppColors.correct : activeHeaderColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 5-Line Staff Canvas
          Expanded(
            child: CustomPaint(
              painter: _MusicalStaffPainter(
                targetNoteKey: targetNoteKey,
                selectedNoteKey: hasWrongComparison ? selectedNoteKey : null,
                showNote: showNote,
                isSightReading: isSightReading,
                useBassClef: useBassClef,
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedStaffNote {
  final String rawKey;
  final String letter; // C, D, E, F, G, A, B
  final bool isSharp;
  final int octave; // 3, 4, 5
  final int diatonicIdx; // 0..6

  const _ParsedStaffNote({
    required this.rawKey,
    required this.letter,
    required this.isSharp,
    required this.octave,
    required this.diatonicIdx,
  });

  /// Returns staff step where:
  /// - Step 0 = 1st ledger line below Line 1 (C4 in Treble Clef, E2 in Bass Clef)
  /// - Step 2 = Line 1 (bottom line: E4 in Treble, G2 in Bass)
  /// - Step 4 = Line 2 (G4 in Treble, B2 in Bass)
  /// - Step 6 = Line 3 (middle line: B4 in Treble, D3 in Bass)
  /// - Step 8 = Line 4 (D5 in Treble, F3 in Bass)
  /// - Step 10 = Line 5 (top line: F5 in Treble, A3 in Bass)
  /// - Step 12 = 1st ledger line above Line 5 (A5 in Treble, C4 in Bass)
  int staffStep({required bool useBassClef}) {
    if (useBassClef) {
      // In Bass Clef: C3 is Space 2 (step 5), F3 is Line 4 (step 8), A3 is Line 5 (step 10), B3 is step 11, C4 is step 12
      final rawStep = (octave - 3) * 7 + diatonicIdx + 5;
      return rawStep.clamp(0, 13);
    } else {
      // In Treble Clef: C4 is step 0, E4 is Line 1 (step 2), F5 is Line 5 (step 10), B5 is step 13
      final effectiveOctave = octave < 4 ? 4 : (octave > 5 ? 5 : octave);
      return (effectiveOctave - 4) * 7 + diatonicIdx;
    }
  }

  static const Map<String, int> _letterIndex = {
    'C': 0,
    'D': 1,
    'E': 2,
    'F': 3,
    'G': 4,
    'A': 5,
    'B': 6,
  };

  static _ParsedStaffNote? tryParse(String? key) {
    if (key == null || key.trim().isEmpty) return null;
    final cleaned = key.trim().toUpperCase();
    final letter = cleaned[0];
    if (!_letterIndex.containsKey(letter)) return null;
    final isSharp = cleaned.contains('#');
    final octaveMatch = RegExp(r'[0-9]').firstMatch(cleaned);
    final octave =
        octaveMatch != null ? (int.tryParse(octaveMatch.group(0)!) ?? 4) : 4;

    return _ParsedStaffNote(
      rawKey: cleaned,
      letter: letter,
      isSharp: isSharp,
      octave: octave,
      diatonicIdx: _letterIndex[letter]!,
    );
  }
}

class _MusicalStaffPainter extends CustomPainter {
  final String? targetNoteKey;
  final String? selectedNoteKey;
  final bool showNote;
  final bool isSightReading;
  final bool useBassClef;
  final bool isDark;

  _MusicalStaffPainter({
    required this.targetNoteKey,
    required this.selectedNoteKey,
    required this.showNote,
    required this.isSightReading,
    required this.useBassClef,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lineColor = isDark
        ? Colors.white.withOpacity(0.32)
        : const Color(0xFF334155).withOpacity(0.42);
    final staffPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // 5 staff lines: Line 1 (bottom, step 2) to Line 5 (top, step 10)
    const double lineSpacing = 7.6;
    const double stepHeight = lineSpacing / 2.0; // 3.8px per diatonic step
    const double topLineY = 11.0; // Line 5 (step 10)
    const double bottomLineY = topLineY + 4 * lineSpacing; // Line 1 (step 2) = 41.4
    const double leftX = 6.0;
    final double rightX = size.width - 6.0;

    for (int line = 0; line < 5; line++) {
      final y = topLineY + line * lineSpacing;
      canvas.drawLine(Offset(leftX, y), Offset(rightX, y), staffPaint);
    }

    // Draw double barline at right end
    canvas.drawLine(
      Offset(rightX - 4, topLineY),
      Offset(rightX - 4, bottomLineY),
      staffPaint..strokeWidth = 1.2,
    );
    canvas.drawLine(
      Offset(rightX, topLineY),
      Offset(rightX, bottomLineY),
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.4,
    );

    final clefColor = isSightReading
        ? (isDark ? AppColors.secondary : const Color(0xFF635BFF))
        : (isDark ? AppColors.secondary : AppColors.primary);

    if (useBassClef) {
      // Draw Bass Clef (𝄢) + explicit F3 two-dot marker straddling Line 4 (topLineY + lineSpacing)
      final clefPainter = TextPainter(
        text: TextSpan(
          text: '𝄢',
          style: TextStyle(
            fontSize: 28,
            height: 1.0,
            color: clefColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      clefPainter.paint(canvas, const Offset(leftX + 3, topLineY - 1));

      // Two clear dots above and below Line 4 (F3 line) for unmistakable Bass Clef reading
      const line4Y = topLineY + lineSpacing;
      final dotPaint = Paint()
        ..color = clefColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(leftX + 27, line4Y - 3.2), 1.9, dotPaint);
      canvas.drawCircle(const Offset(leftX + 27, line4Y + 3.2), 1.9, dotPaint);
    } else {
      // Draw Treble Clef symbol (𝄞) on the left
      final clefPainter = TextPainter(
        text: TextSpan(
          text: '𝄞',
          style: TextStyle(
            fontSize: 36,
            height: 1.0,
            color: clefColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      clefPainter.paint(canvas, const Offset(leftX + 3, topLineY - 3));
    }

    double yForStep(int step) {
      return bottomLineY - (step - 2) * stepHeight;
    }

    final targetParsed = _ParsedStaffNote.tryParse(targetNoteKey);
    final selectedParsed = _ParsedStaffNote.tryParse(selectedNoteKey);

    // Case 1: Ear-Training before answering -> Hide note position and draw Mystery '?' Badge
    if (!showNote && !isSightReading) {
      final centerX = size.width * 0.52;
      const centerY = (topLineY + bottomLineY) / 2;
      final circlePaint = Paint()
        ..color = AppColors.primary.withOpacity(isDark ? 0.25 : 0.14)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, centerY), 12, circlePaint);

      final borderPaint = Paint()
        ..color = AppColors.primary.withOpacity(0.55)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(centerX, centerY), 12, borderPaint);

      final qPainter = TextPainter(
        text: const TextSpan(
          text: '?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      qPainter.paint(
        canvas,
        Offset(centerX - qPainter.width / 2, centerY - qPainter.height / 2),
      );
      return;
    }

    // Case 2: Sight-Reading before answering -> Plot the target note on the staff with '?' label!
    if (!showNote && isSightReading && targetParsed != null) {
      final step = targetParsed.staffStep(useBassClef: useBassClef);
      _drawSingleNote(
        canvas: canvas,
        note: targetParsed,
        step: step,
        centerX: size.width * 0.52,
        y: yForStep(step),
        yForStep: yForStep,
        color: clefColor,
        prefixLabel: 'Nốt ?',
      );
      return;
    }

    // Case 3: Revealed state (after answering in either Ear Training or Sight-Reading)
    if (selectedParsed != null && targetParsed != null) {
      final selStep = selectedParsed.staffStep(useBassClef: useBassClef);
      final tarStep = targetParsed.staffStep(useBassClef: useBassClef);
      _drawSingleNote(
        canvas: canvas,
        note: selectedParsed,
        step: selStep,
        centerX: size.width * 0.36,
        y: yForStep(selStep),
        yForStep: yForStep,
        color: AppColors.wrong,
        prefixLabel: '✗ ${selectedParsed.rawKey}',
      );
      _drawSingleNote(
        canvas: canvas,
        note: targetParsed,
        step: tarStep,
        centerX: size.width * 0.68,
        y: yForStep(tarStep),
        yForStep: yForStep,
        color: AppColors.correct,
        prefixLabel: '✓ ${targetParsed.rawKey}',
      );
    } else if (targetParsed != null) {
      final tarStep = targetParsed.staffStep(useBassClef: useBassClef);
      _drawSingleNote(
        canvas: canvas,
        note: targetParsed,
        step: tarStep,
        centerX: size.width * 0.50,
        y: yForStep(tarStep),
        yForStep: yForStep,
        color: AppColors.correct,
        prefixLabel: '✓ ${targetParsed.rawKey}',
      );
    }
  }

  void _drawSingleNote({
    required Canvas canvas,
    required _ParsedStaffNote note,
    required int step,
    required double centerX,
    required double y,
    required double Function(int) yForStep,
    required Color color,
    required String prefixLabel,
  }) {
    final ledgerPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..strokeWidth = 1.5;

    // Ledger line below Line 1 (step 0)
    if (step <= 0) {
      final lowLedgerY = yForStep(0);
      canvas.drawLine(
        Offset(centerX - 10, lowLedgerY),
        Offset(centerX + 10, lowLedgerY),
        ledgerPaint,
      );
    }
    // Ledger line above Line 5 (step 12 or 13)
    if (step >= 12) {
      final highLedgerY = yForStep(12);
      canvas.drawLine(
        Offset(centerX - 10, highLedgerY),
        Offset(centerX + 10, highLedgerY),
        ledgerPaint,
      );
    }

    // Draw Sharp (#) if applicable
    if (note.isSharp) {
      final sharpPainter = TextPainter(
        text: TextSpan(
          text: '♯',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      sharpPainter.paint(
        canvas,
        Offset(centerX - 16, y - sharpPainter.height / 2),
      );
    }

    // Draw tilted oval Notehead
    canvas.save();
    canvas.translate(centerX, y);
    canvas.rotate(-0.28);
    final noteHeadPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 10.5, height: 7.4),
      noteHeadPaint,
    );
    canvas.restore();

    // Draw Note Stem (up if below middle line [step 6], down if step 6 or above)
    final stemPaint = Paint()
      ..color = color
      ..strokeWidth = 1.7;
    final stemUp = step < 6;
    if (stemUp) {
      canvas.drawLine(
        Offset(centerX + 4.4, y),
        Offset(centerX + 4.4, y - 20),
        stemPaint,
      );
    } else {
      canvas.drawLine(
        Offset(centerX - 4.4, y),
        Offset(centerX - 4.4, y + 20),
        stemPaint,
      );
    }

    // Draw Label next to notehead
    final labelPainter = TextPainter(
      text: TextSpan(
        text: prefixLabel,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(centerX + 9, (y - labelPainter.height / 2).clamp(2.0, 38.0)),
    );
  }

  @override
  bool shouldRepaint(covariant _MusicalStaffPainter oldDelegate) {
    return oldDelegate.targetNoteKey != targetNoteKey ||
        oldDelegate.selectedNoteKey != selectedNoteKey ||
        oldDelegate.showNote != showNote ||
        oldDelegate.isSightReading != isSightReading ||
        oldDelegate.useBassClef != useBassClef ||
        oldDelegate.isDark != isDark;
  }
}
