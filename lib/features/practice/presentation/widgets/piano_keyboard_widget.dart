import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Visual & interactive 1-octave Piano keyboard helper for Note Recognition (UC-05).
/// Highlights the correct note key AFTER the user has submitted their answer,
/// and allows tapping keys to preview their pitch.
class PianoKeyboardWidget extends StatefulWidget {
  final String? highlightedNoteKey; // e.g. 'C4', 'F4', 'F#4'
  final List<String>? highlightedNoteKeys; // Multi-note highlight for chords/intervals
  final String? selectedNoteKey; // User's selected option key
  final bool showHighlight;
  final bool enableBlackKeys;
  final ValueChanged<String>? onKeyTap;

  const PianoKeyboardWidget({
    super.key,
    this.highlightedNoteKey,
    this.highlightedNoteKeys,
    this.selectedNoteKey,
    this.showHighlight = false,
    this.enableBlackKeys = true,
    this.onKeyTap,
  });

  @override
  State<PianoKeyboardWidget> createState() => _PianoKeyboardWidgetState();
}

class _PianoKeyboardWidgetState extends State<PianoKeyboardWidget> {
  String? _activeTappedKey;

  static const List<(String key, String solfege, String letter)> _whiteKeys = [
    ('C4', 'Đô', 'C'),
    ('D4', 'Rê', 'D'),
    ('E4', 'Mi', 'E'),
    ('F4', 'Fa', 'F'),
    ('G4', 'Sol', 'G'),
    ('A4', 'La', 'A'),
    ('B4', 'Si', 'B'),
  ];

  void _handleTap(String keyCode) {
    if (widget.onKeyTap == null) return;
    setState(() => _activeTappedKey = keyCode);
    widget.onKeyTap!(keyCode);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted && _activeTappedKey == keyCode) {
        setState(() => _activeTappedKey = null);
      }
    });
  }

  String _normalizeToOctave4(String? rawKey) {
    if (rawKey == null || rawKey.isEmpty) return '';
    final pitchClass = rawKey.replaceAll(RegExp(r'[0-9]'), '').toUpperCase();
    return '${pitchClass}4';
  }

  @override
  Widget build(BuildContext context) {
    final normalizedTargets = <String>{};
    final singleTarget = _normalizeToOctave4(widget.highlightedNoteKey);
    if (singleTarget.isNotEmpty) {
      normalizedTargets.add(singleTarget);
    }
    if (widget.highlightedNoteKeys != null) {
      for (final k in widget.highlightedNoteKeys!) {
        final norm = _normalizeToOctave4(k);
        if (norm.isNotEmpty) normalizedTargets.add(norm);
      }
    }
    final normalizedSelected = _normalizeToOctave4(widget.selectedNoteKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 100,
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F2138), Color(0xFF2D3052)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final whiteKeyWidth = constraints.maxWidth / _whiteKeys.length;
              final blackKeyWidth = whiteKeyWidth * 0.62;

              return Stack(
                children: [
                  // White keys
                  Row(
                    children: _whiteKeys.map((entry) {
                      final keyCode = entry.$1;
                      final isTarget = widget.showHighlight &&
                          normalizedTargets.contains(keyCode);
                      final isWrongSelected = widget.showHighlight &&
                          normalizedSelected == keyCode &&
                          !isTarget;
                      final isTapped = _activeTappedKey == keyCode;

                      Color keyColor = Colors.white;
                      if (isTarget) {
                        keyColor = AppColors.correct;
                      } else if (isWrongSelected) {
                        keyColor = AppColors.wrong;
                      } else if (isTapped) {
                        keyColor = AppColors.primaryLight;
                      }

                      final textColor = (isTarget || isWrongSelected)
                          ? Colors.white
                          : AppColors.textPrimaryLight;

                      return Expanded(
                        child: GestureDetector(
                          key: Key('piano_key_$keyCode'),
                          onTap: widget.onKeyTap != null
                              ? () => _handleTap(keyCode)
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 1.8),
                            decoration: BoxDecoration(
                              color: keyColor,
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(10),
                                top: Radius.circular(4),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.22),
                                  blurRadius: 3,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.bottomCenter,
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  entry.$2,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  entry.$3,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: textColor.withOpacity(0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // Black keys (2-group: C#, D#; 3-group: F#, G#, A#)
                  ...[
                    (0, 'C#4', 'C#'),
                    (1, 'D#4', 'D#'),
                    (3, 'F#4', 'F#'),
                    (4, 'G#4', 'G#'),
                    (5, 'A#4', 'A#'),
                  ].map((bKey) {
                    final leftIndex = bKey.$1;
                    final noteCode = bKey.$2;
                    final shortLabel = bKey.$3;
                    final isTarget = widget.showHighlight &&
                        normalizedTargets.contains(noteCode);
                    final isWrongSelected = widget.showHighlight &&
                        normalizedSelected == noteCode &&
                        !isTarget;
                    final isTapped = _activeTappedKey == noteCode;

                    Color blackColor = widget.enableBlackKeys
                        ? const Color(0xFF171828)
                        : const Color(0xFF171828).withOpacity(0.45);
                    if (isTarget) {
                      blackColor = AppColors.correct;
                    } else if (isWrongSelected) {
                      blackColor = AppColors.wrong;
                    } else if (isTapped) {
                      blackColor = AppColors.primary;
                    }

                    final leftOffset =
                        (leftIndex + 1) * whiteKeyWidth - (blackKeyWidth / 2);
                    return Positioned(
                      left: leftOffset,
                      top: 0,
                      width: blackKeyWidth,
                      height: 54,
                      child: GestureDetector(
                        key: Key('piano_key_$noteCode'),
                        onTap: (widget.onKeyTap != null &&
                                (widget.enableBlackKeys || widget.showHighlight))
                            ? () => _handleTap(noteCode)
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          alignment: Alignment.bottomCenter,
                          padding: const EdgeInsets.only(bottom: 5),
                          decoration: BoxDecoration(
                            color: blackColor,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(7),
                              top: Radius.circular(3),
                            ),
                            border: Border.all(
                              color: widget.enableBlackKeys
                                  ? Colors.white24
                                  : Colors.black54,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: widget.enableBlackKeys
                              ? Text(
                                  shortLabel,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white70,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            widget.showHighlight
                ? '💡 Chạm phím đàn để nghe đối chiếu cao độ'
                : '🎹 Chạm phím đàn hoặc chọn đáp án bên dưới',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withOpacity(0.82),
            ),
          ),
        ),
      ],
    );
  }
}
