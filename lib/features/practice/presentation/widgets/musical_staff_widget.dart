import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/note_formatter.dart';

/// Interactive/Visual 5-line Treble Clef (Khóa Sol) Musical Staff widget.
/// - Hidden mode (`showNote == false`): Displays the 5 staff lines, Treble Clef,
///   and a mystery '?' note indicator so the learner relies on ear training first.
/// - Revealed mode (`showNote == true`): Plots the exact position of the target
///   note (and compares it side-by-side with the user's selected note if wrong).
class MusicalStaffWidget extends StatelessWidget {
  final String? targetNoteKey; // e.g. 'C4', 'F#4', 'G3', 'C5'
  final String? selectedNoteKey; // e.g. 'D4'
  final bool showNote;

  const MusicalStaffWidget({
    super.key,
    required this.targetNoteKey,
    this.selectedNoteKey,
    required this.showNote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasWrongComparison = showNote &&
        selectedNoteKey != null &&
        targetNoteKey != null &&
        selectedNoteKey!.toUpperCase() != targetNoteKey!.toUpperCase();

    return Container(
      key: const Key('musical_staff_widget'),
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              : AppColors.primary.withOpacity(0.22),
          width: 1.2,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TrebleStaffPainter(
                targetNoteKey: targetNoteKey,
                selectedNoteKey: hasWrongComparison ? selectedNoteKey : null,
                showNote: showNote,
                isDark: isDark,
              ),
            ),
          ),
          // Top-right badge showing state or note position explanation
          Positioned(
            right: 4,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: showNote
                    ? AppColors.correct.withOpacity(0.15)
                    : AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                showNote
                    ? 'Khuông nhạc: ${NoteFormatter.toVietnameseLabel(targetNoteKey ?? '')}'
                    : 'Khuông nhạc Khóa Sol (Ẩn khi đang nghe)',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: showNote ? AppColors.correct : AppColors.primary,
                ),
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
  final int displayStepFromC4; // Diatonic step where C4=0, E4=2 (Line 1), F5=10 (Line 5)
  final String octaveTag; // '' or '8vb'

  const _ParsedStaffNote({
    required this.rawKey,
    required this.letter,
    required this.isSharp,
    required this.octave,
    required this.displayStepFromC4,
    required this.octaveTag,
  });

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

    final diatonicIdx = _letterIndex[letter]!;
    // If octave is 3, display in octave 4 position with '8vb' tag so it fits cleanly inside the 5-line staff
    final effectiveOctave = octave < 4 ? 4 : (octave > 5 ? 5 : octave);
    final stepFromC4 = (effectiveOctave - 4) * 7 + diatonicIdx;
    final tag = octave < 4 ? '8vb (Quãng 3)' : '';

    return _ParsedStaffNote(
      rawKey: cleaned,
      letter: letter,
      isSharp: isSharp,
      octave: octave,
      displayStepFromC4: stepFromC4,
      octaveTag: tag,
    );
  }
}

class _TrebleStaffPainter extends CustomPainter {
  final String? targetNoteKey;
  final String? selectedNoteKey;
  final bool showNote;
  final bool isDark;

  _TrebleStaffPainter({
    required this.targetNoteKey,
    required this.selectedNoteKey,
    required this.showNote,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lineColor = isDark
        ? Colors.white.withOpacity(0.32)
        : const Color(0xFF334155).withOpacity(0.42);
    final staffPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke;

    // 5 staff lines: Line 1 (bottom, E4 = step 2) to Line 5 (top, F5 = step 10)
    // Distance between adjacent lines = 2 diatonic steps = lineSpacing
    const double lineSpacing = 9.0;
    const double stepHeight = lineSpacing / 2.0; // 4.5px per diatonic step
    const double topLineY = 24.0; // F5 (step 10)
    const double bottomLineY = topLineY + 4 * lineSpacing; // E4 (step 2) = 60.0
    const double leftX = 8.0;
    final double rightX = size.width - 8.0;

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
        ..strokeWidth = 2.6,
    );

    // Draw Treble Clef symbol (𝄞) on the left
    final clefPainter = TextPainter(
      text: TextSpan(
        text: '𝄞',
        style: TextStyle(
          fontSize: 42,
          height: 1.0,
          color: isDark ? AppColors.secondary : AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    clefPainter.paint(canvas, const Offset(leftX + 4, topLineY - 4));

    if (!showNote) {
      // Draw Mystery '?' Badge in center of staff
      final centerX = size.width * 0.54;
      const centerY = (topLineY + bottomLineY) / 2;
      final circlePaint = Paint()
        ..color = AppColors.primary.withOpacity(isDark ? 0.25 : 0.14)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, centerY), 14, circlePaint);

      final borderPaint = Paint()
        ..color = AppColors.primary.withOpacity(0.55)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(centerX, centerY), 14, borderPaint);

      final qPainter = TextPainter(
        text: const TextSpan(
          text: '?',
          style: TextStyle(
            fontSize: 16,
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

    final targetParsed = _ParsedStaffNote.tryParse(targetNoteKey);
    final selectedParsed = _ParsedStaffNote.tryParse(selectedNoteKey);

    double yForStep(int stepFromC4) {
      // E4 is step 2 at bottomLineY
      return bottomLineY - (stepFromC4 - 2) * stepHeight;
    }

    if (selectedParsed != null && targetParsed != null) {
      // Draw user's wrong note on the left, and correct target note on the right
      _drawSingleNote(
        canvas: canvas,
        note: selectedParsed,
        centerX: size.width * 0.40,
        y: yForStep(selectedParsed.displayStepFromC4),
        yForStep: yForStep,
        color: AppColors.wrong,
        prefixLabel: '✗ ${selectedParsed.rawKey}',
      );
      _drawSingleNote(
        canvas: canvas,
        note: targetParsed,
        centerX: size.width * 0.72,
        y: yForStep(targetParsed.displayStepFromC4),
        yForStep: yForStep,
        color: AppColors.correct,
        prefixLabel: '✓ ${targetParsed.rawKey}',
      );
    } else if (targetParsed != null) {
      _drawSingleNote(
        canvas: canvas,
        note: targetParsed,
        centerX: size.width * 0.56,
        y: yForStep(targetParsed.displayStepFromC4),
        yForStep: yForStep,
        color: AppColors.correct,
        prefixLabel:
            '✓ ${targetParsed.rawKey}${targetParsed.octaveTag.isNotEmpty ? " (${targetParsed.octaveTag})" : ""}',
      );
    }
  }

  void _drawSingleNote({
    required Canvas canvas,
    required _ParsedStaffNote note,
    required double centerX,
    required double y,
    required double Function(int) yForStep,
    required Color color,
    required String prefixLabel,
  }) {
    final ledgerPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..strokeWidth = 1.6;

    // Ledger line for C4 (step 0)
    if (note.displayStepFromC4 <= 0) {
      final c4Y = yForStep(0);
      canvas.drawLine(
        Offset(centerX - 11, c4Y),
        Offset(centerX + 11, c4Y),
        ledgerPaint,
      );
    }
    // Ledger line for A5 (step 12) or B5 (step 13)
    if (note.displayStepFromC4 >= 12) {
      final a5Y = yForStep(12);
      canvas.drawLine(
        Offset(centerX - 11, a5Y),
        Offset(centerX + 11, a5Y),
        ledgerPaint,
      );
    }

    // Draw Sharp (#) if applicable
    if (note.isSharp) {
      final sharpPainter = TextPainter(
        text: TextSpan(
          text: '♯',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      sharpPainter.paint(
        canvas,
        Offset(centerX - 18, y - sharpPainter.height / 2),
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
      Rect.fromCenter(center: Offset.zero, width: 11.5, height: 8.2),
      noteHeadPaint,
    );
    canvas.restore();

    // Draw Note Stem (up if below B4 [step 6], down if B4 or above)
    final stemPaint = Paint()
      ..color = color
      ..strokeWidth = 1.8;
    final stemUp = note.displayStepFromC4 < 6;
    if (stemUp) {
      canvas.drawLine(
        Offset(centerX + 4.8, y),
        Offset(centerX + 4.8, y - 24),
        stemPaint,
      );
    } else {
      canvas.drawLine(
        Offset(centerX - 4.8, y),
        Offset(centerX - 4.8, y + 24),
        stemPaint,
      );
    }

    // Draw Label next to notehead
    final labelPainter = TextPainter(
      text: TextSpan(
        text: prefixLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(centerX + 10, (y - labelPainter.height / 2).clamp(16.0, 62.0)),
    );
  }

  @override
  bool shouldRepaint(covariant _TrebleStaffPainter oldDelegate) {
    return oldDelegate.targetNoteKey != targetNoteKey ||
        oldDelegate.selectedNoteKey != selectedNoteKey ||
        oldDelegate.showNote != showNote ||
        oldDelegate.isDark != isDark;
  }
}
