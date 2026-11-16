import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/note_formatter.dart';

/// Interactive/Visual 5-line Musical Staff widget supporting both:
/// - **Ear Training mode (`isSightReading == false`)**:
///   Hides the note (`?`) while listening, then reveals the note on the staff after answering.
/// - **Sight-Reading mode (`isSightReading == true`)**:
///   Plots the note (notehead, stem, 1–2 upper/lower ledger lines, sharp `♯`) on the 5-line staff
///   (Treble Clef `𝄞` including G3–C6 ledger lines, Bass Clef `𝄢` including C3–D4 ledger lines)
///   BEFORE answering while hiding the note name (`?`), then reveals the answer (`✓` / `✗`) after answering.
class MusicalStaffWidget extends StatelessWidget {
  final String? targetNoteKey; // e.g. 'C4', 'G3_SOL', 'A3_SOL', 'C6', 'C4_FA'
  final String? selectedNoteKey; // e.g. 'D4'
  final bool showNote;
  final bool isSightReading;
  final bool? forceBassClef;

  const MusicalStaffWidget({
    super.key,
    required this.targetNoteKey,
    this.selectedNoteKey,
    required this.showNote,
    this.isSightReading = false,
    this.forceBassClef,
  });

  /// Returns true if [rawKey] lies on or beyond a ledger line (outside step 1..11).
  static bool isLedgerLineNoteKey(String? rawKey, {bool? forceBassClef}) {
    final parsed = _ParsedStaffNote.tryParse(rawKey);
    if (parsed == null) return false;
    final useBass = forceBassClef ??
        (parsed.explicitClef == 'bass'
            ? true
            : (parsed.explicitClef == 'treble' ? false : parsed.octave <= 3));
    final step = parsed.staffStep(useBassClef: useBass);
    return step <= 0 || step >= 12;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetParsed = _ParsedStaffNote.tryParse(targetNoteKey);
    final selectedParsed = _ParsedStaffNote.tryParse(selectedNoteKey);

    final hasWrongComparison = showNote &&
        selectedParsed != null &&
        targetParsed != null &&
        selectedParsed.cleanKey != targetParsed.cleanKey;

    final bool useBassClef = forceBassClef ??
        (targetParsed != null
            ? (targetParsed.explicitClef == 'bass'
                ? true
                : (targetParsed.explicitClef == 'treble'
                    ? false
                    : targetParsed.octave <= 3))
            : false);

    final String headerTitle = useBassClef
        ? 'Khuông nhạc Khóa Fa (𝄢)'
        : 'Khuông nhạc Khóa Sol (𝄞)';

    final String? ledgerHint =
        targetParsed?.ledgerLineBadgeLabel(useBassClef: useBassClef);

    final String statusBadgeText;
    if (showNote) {
      final cleanLabel =
          NoteFormatter.toVietnameseLabel(targetParsed?.cleanKey ?? '');
      statusBadgeText = ledgerHint != null
          ? '$cleanLabel • $ledgerHint'
          : 'Vị trí: $cleanLabel';
    } else if (isSightReading) {
      if (ledgerHint != null) {
        statusBadgeText = ledgerHint;
      } else {
        statusBadgeText = useBassClef
            ? 'Đọc Khóa Fa (Dòng 4 = Fa3)'
            : 'Đọc Khóa Sol (Dòng 2 = Sol4)';
      }
    } else {
      statusBadgeText = 'Hiện vị trí nốt sau khi chọn đáp án';
    }

    final Color activeHeaderColor =
        isDark ? AppColors.secondary : AppColors.primary;

    return Container(
      key: const Key('musical_staff_widget'),
      height: isSightReading ? 114 : 96,
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
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
          // Dedicated Header Row (never overlaps high notes on upper ledger lines!)
          SizedBox(
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    headerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: activeHeaderColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: showNote
                          ? AppColors.correct.withOpacity(0.15)
                          : (ledgerHint != null && isSightReading
                              ? AppColors.accentAmber.withOpacity(0.16)
                              : activeHeaderColor.withOpacity(0.12)),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        statusBadgeText,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: showNote
                              ? AppColors.correct
                              : (ledgerHint != null && isSightReading
                                  ? AppColors.accentAmber
                                  : activeHeaderColor),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 5-Line Staff Canvas with spacious upper & lower ledger-line margins
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
  final String cleanKey; // e.g. 'G3', 'C6', 'F#4'
  final String letter; // C, D, E, F, G, A, B
  final bool isSharp;
  final int octave; // 2..6
  final int diatonicIdx; // 0..6
  final String? explicitClef; // 'treble', 'bass', or null

  const _ParsedStaffNote({
    required this.rawKey,
    required this.cleanKey,
    required this.letter,
    required this.isSharp,
    required this.octave,
    required this.diatonicIdx,
    this.explicitClef,
  });

  /// Returns staff step where the 5 main lines are ALWAYS steps 2, 4, 6, 8, 10:
  /// - Step -3 = Space below 2nd lower ledger line (G3 in Treble Clef)
  /// - Step -2 = 2nd ledger line below Line 1 (A3 in Treble Clef)
  /// - Step -1 = Space below 1st lower ledger line (B3 in Treble Clef)
  /// - Step 0  = 1st ledger line below Line 1 (C4 in Treble Clef, E2 in Bass Clef)
  /// - Step 1  = Space below Line 1 (D4 in Treble Clef)
  /// - Step 2  = Line 1 (bottom line: E4 in Treble, G2 in Bass)
  /// - Step 4  = Line 2 (G4 in Treble, B2 in Bass)
  /// - Step 6  = Line 3 (middle line: B4 in Treble, D3 in Bass)
  /// - Step 8  = Line 4 (D5 in Treble, F3 in Bass)
  /// - Step 10 = Line 5 (top line: F5 in Treble, A3 in Bass)
  /// - Step 11 = Space above Line 5 (G5 in Treble, B3 in Bass)
  /// - Step 12 = 1st ledger line above Line 5 (A5 in Treble, C4 in Bass)
  /// - Step 13 = Space above 1st upper ledger line (B5 in Treble, D4 in Bass)
  /// - Step 14 = 2nd ledger line above Line 5 (C6 in Treble, E4 in Bass)
  int staffStep({required bool useBassClef}) {
    if (useBassClef) {
      final rawStep = (octave - 3) * 7 + diatonicIdx + 5;
      return rawStep.clamp(-3, 14);
    } else {
      final rawStep = (octave - 4) * 7 + diatonicIdx;
      return rawStep.clamp(-3, 14);
    }
  }

  /// Human-readable description of ledger line position when outside the 5 main lines.
  String? ledgerLineBadgeLabel({required bool useBassClef}) {
    final step = staffStep(useBassClef: useBassClef);
    if (step == 0) return 'Dòng kẻ phụ 1 dưới';
    if (step == -1) return 'Dưới dòng phụ 1 dưới';
    if (step == -2) return 'Dòng kẻ phụ 2 dưới';
    if (step <= -3) return 'Dưới dòng phụ 2 dưới';
    if (step == 12) return 'Dòng kẻ phụ 1 trên';
    if (step == 13) return 'Trên dòng phụ 1 trên';
    if (step >= 14) return 'Dòng kẻ phụ 2 trên';
    return null;
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
    final upper = key.trim().toUpperCase();
    String? explicitClef;
    if (upper.endsWith('_SOL') || upper.endsWith('_TREBLE')) {
      explicitClef = 'treble';
    } else if (upper.endsWith('_FA') || upper.endsWith('_BASS')) {
      explicitClef = 'bass';
    }
    final cleaned = NoteFormatter.cleanNoteKey(upper);
    if (cleaned.isEmpty) return null;
    final letter = cleaned[0];
    if (!_letterIndex.containsKey(letter)) return null;
    final isSharp = cleaned.contains('#');
    final octaveMatch = RegExp(r'[0-9]').firstMatch(cleaned);
    final octave =
        octaveMatch != null ? (int.tryParse(octaveMatch.group(0)!) ?? 4) : 4;

    return _ParsedStaffNote(
      rawKey: upper,
      cleanKey: cleaned,
      letter: letter,
      isSharp: isSharp,
      octave: octave,
      diatonicIdx: _letterIndex[letter]!,
      explicitClef: explicitClef,
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

    // 5 staff lines centered with spacious room for 2 upper & 2 lower ledger lines:
    // Line 5 (top, step 10) at y = 21.0; Line 1 (bottom, step 2) at y = 49.8
    // Step 14 (2nd upper ledger line, C6) is at y = 6.6
    // Step -3 (below 2nd lower ledger line, G3) is at y = 67.8
    const double lineSpacing = 7.2;
    const double stepHeight = lineSpacing / 2.0; // 3.6px per diatonic step
    const double topLineY = 21.0; // Line 5 (step 10)
    const double bottomLineY =
        topLineY + 4 * lineSpacing; // Line 1 (step 2) = 49.8
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

    final clefColor = isDark ? AppColors.secondary : AppColors.primary;

    if (useBassClef) {
      final clefPainter = TextPainter(
        text: TextSpan(
          text: '𝄢',
          style: TextStyle(
            fontSize: 27,
            height: 1.0,
            color: clefColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      clefPainter.paint(canvas, const Offset(leftX + 3, topLineY - 1));

      // Two clear dots above and below Line 4 (F3 line)
      const line4Y = topLineY + lineSpacing;
      final dotPaint = Paint()
        ..color = clefColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(leftX + 27, line4Y - 3.2), 1.9, dotPaint);
      canvas.drawCircle(const Offset(leftX + 27, line4Y + 3.2), 1.9, dotPaint);
    } else {
      final clefPainter = TextPainter(
        text: TextSpan(
          text: '𝄞',
          style: TextStyle(
            fontSize: 34,
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
      final isLedger = step <= 0 || step >= 12;
      final String label = isLedger
          ? (step <= -2 || step >= 14 ? 'Nốt ? (2 phụ)' : 'Nốt ? (1 phụ)')
          : 'Nốt ?';
      _drawSingleNote(
        canvas: canvas,
        note: targetParsed,
        step: step,
        centerX: size.width * 0.50,
        y: yForStep(step),
        yForStep: yForStep,
        color: clefColor,
        prefixLabel: label,
        highlightLedgerLines: true,
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
        centerX: size.width * 0.35,
        y: yForStep(selStep),
        yForStep: yForStep,
        color: AppColors.wrong,
        prefixLabel: '✗ ${selectedParsed.cleanKey}',
        highlightLedgerLines: false,
      );
      _drawSingleNote(
        canvas: canvas,
        note: targetParsed,
        step: tarStep,
        centerX: size.width * 0.67,
        y: yForStep(tarStep),
        yForStep: yForStep,
        color: AppColors.correct,
        prefixLabel: '✓ ${targetParsed.cleanKey}',
        highlightLedgerLines: true,
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
        prefixLabel: '✓ ${targetParsed.cleanKey}',
        highlightLedgerLines: true,
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
    required bool highlightLedgerLines,
  }) {
    final ledgerColor = highlightLedgerLines
        ? AppColors.accentAmber
        : color.withOpacity(0.88);
    final ledgerPaint = Paint()
      ..color = ledgerColor
      ..strokeWidth = 2.0;

    // Lower ledger lines (below Line 1: step 0 = 1st lower ledger line, step -2 = 2nd lower ledger line)
    if (step <= 0) {
      final low1Y = yForStep(0);
      canvas.drawLine(
        Offset(centerX - 12, low1Y),
        Offset(centerX + 12, low1Y),
        ledgerPaint,
      );
    }
    if (step <= -2) {
      final low2Y = yForStep(-2);
      canvas.drawLine(
        Offset(centerX - 12, low2Y),
        Offset(centerX + 12, low2Y),
        ledgerPaint,
      );
    }

    // Upper ledger lines (above Line 5: step 12 = 1st upper ledger line, step 14 = 2nd upper ledger line)
    if (step >= 12) {
      final high1Y = yForStep(12);
      canvas.drawLine(
        Offset(centerX - 12, high1Y),
        Offset(centerX + 12, high1Y),
        ledgerPaint,
      );
    }
    if (step >= 14) {
      final high2Y = yForStep(14);
      canvas.drawLine(
        Offset(centerX - 12, high2Y),
        Offset(centerX + 12, high2Y),
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
        Offset(centerX - 17, y - sharpPainter.height / 2),
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
      Rect.fromCenter(center: Offset.zero, width: 10.5, height: 7.2),
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
        Offset(centerX + 4.4, y - 19),
        stemPaint,
      );
    } else {
      canvas.drawLine(
        Offset(centerX - 4.4, y),
        Offset(centerX - 4.4, y + 19),
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
      Offset(centerX + 13, (y - labelPainter.height / 2).clamp(1.0, 66.0)),
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
