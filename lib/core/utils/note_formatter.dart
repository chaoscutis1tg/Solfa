/// Utility for formatting musical note names in bilingual Vietnamese + International notation
/// (UC-05: Đô (C), Rê (D), Mi (E), Fa (F), Sol (G), La (A), Si (B)) and time durations.
class NoteFormatter {
  static const Map<String, String> solfegeMap = {
    'C': 'Đô',
    'C#': 'Đô thăng',
    'Db': 'Rê giáng',
    'D': 'Rê',
    'D#': 'Rê thăng',
    'Eb': 'Mi giáng',
    'E': 'Mi',
    'F': 'Fa',
    'F#': 'Fa thăng',
    'Gb': 'Sol giáng',
    'G': 'Sol',
    'G#': 'Sol thăng',
    'Ab': 'La giáng',
    'A': 'La',
    'A#': 'La thăng',
    'Bb': 'Si giáng',
    'B': 'Si',
  };

  /// Returns e.g. "Đô (C)" or "Đô 4 (C4)" if includeOctave is true.
  static String formatBilingual(String pitchClass, {int? octave, bool includeOctave = false}) {
    final vi = solfegeMap[pitchClass] ?? pitchClass;
    if (includeOctave && octave != null) {
      return '$vi $octave ($pitchClass$octave)';
    }
    return '$vi ($pitchClass)';
  }

  static String formatDurationSeconds(int totalSeconds) {
    if (totalSeconds <= 0) return '0 giây';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}g ${minutes}p';
    }
    if (minutes > 0) {
      return seconds > 0 ? '${minutes}p ${seconds}s' : '$minutes phút';
    }
    return '$seconds giây';
  }
}

