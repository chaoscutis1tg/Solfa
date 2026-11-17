import 'dart:io' show Platform;
import 'dart:ui' show Locale, PlatformDispatcher;

/// Thông tin Quốc gia / Khu vực được nhận diện cục bộ (100% Offline, không dùng GPS/Internet)
class DetectedCountryInfo {
  final String countryCode;
  final String nameVi;
  final String nameEn;
  final String flagEmoji;
  final String regulatoryRegion;
  final bool isEuMember;
  final String defaultLanguageCode;

  const DetectedCountryInfo({
    required this.countryCode,
    required this.nameVi,
    required this.nameEn,
    required this.flagEmoji,
    required this.regulatoryRegion,
    this.isEuMember = false,
    required this.defaultLanguageCode,
  });

  String displayName(bool isEn) => isEn ? nameEn : nameVi;
}

/// Quản lý Đa ngôn ngữ (Tiếng Việt / Tiếng Anh), Nhận diện Quốc gia & Chuyển đổi Ký hiệu Nhạc lý
class AppLocale {
  /// Danh sách 27 quốc gia thành viên Liên minh Châu Âu (EU) + EEA áp dụng Quy định (EU) 2018/302 & GDPR
  static const Set<String> euCountryCodes = {
    'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR',
    'DE', 'GR', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL',
    'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE', 'IS', 'LI', 'NO',
  };

  /// Danh mục Quốc gia tiêu biểu trong 174+ quốc gia phân phối trên Google Play
  static const Map<String, DetectedCountryInfo> _knownCountries = {
    'VN': DetectedCountryInfo(
      countryCode: 'VN',
      nameVi: 'Việt Nam',
      nameEn: 'Vietnam',
      flagEmoji: '🇻🇳',
      regulatoryRegion: 'ASEAN • Nghị định 13/2023/NĐ-CP',
      isEuMember: false,
      defaultLanguageCode: 'vi',
    ),
    'US': DetectedCountryInfo(
      countryCode: 'US',
      nameVi: 'Hoa Kỳ',
      nameEn: 'United States',
      flagEmoji: '🇺🇸',
      regulatoryRegion: 'North America • CCPA / COPPA',
      isEuMember: false,
      defaultLanguageCode: 'en',
    ),
    'GB': DetectedCountryInfo(
      countryCode: 'GB',
      nameVi: 'Vương quốc Anh',
      nameEn: 'United Kingdom',
      flagEmoji: '🇬🇧',
      regulatoryRegion: 'Europe • UK GDPR',
      isEuMember: false,
      defaultLanguageCode: 'en',
    ),
    'FR': DetectedCountryInfo(
      countryCode: 'FR',
      nameVi: 'Pháp (EU)',
      nameEn: 'France (EU)',
      flagEmoji: '🇫🇷',
      regulatoryRegion: 'EU 2018/302 & GDPR',
      isEuMember: true,
      defaultLanguageCode: 'en',
    ),
    'DE': DetectedCountryInfo(
      countryCode: 'DE',
      nameVi: 'Đức (EU)',
      nameEn: 'Germany (EU)',
      flagEmoji: '🇩🇪',
      regulatoryRegion: 'EU 2018/302 & GDPR',
      isEuMember: true,
      defaultLanguageCode: 'en',
    ),
    'IT': DetectedCountryInfo(
      countryCode: 'IT',
      nameVi: 'Ý (EU)',
      nameEn: 'Italy (EU)',
      flagEmoji: '🇮🇹',
      regulatoryRegion: 'EU 2018/302 & GDPR',
      isEuMember: true,
      defaultLanguageCode: 'en',
    ),
    'ES': DetectedCountryInfo(
      countryCode: 'ES',
      nameVi: 'Tây Ban Nha (EU)',
      nameEn: 'Spain (EU)',
      flagEmoji: '🇪🇸',
      regulatoryRegion: 'EU 2018/302 & GDPR',
      isEuMember: true,
      defaultLanguageCode: 'en',
    ),
    'NL': DetectedCountryInfo(
      countryCode: 'NL',
      nameVi: 'Hà Lan (EU)',
      nameEn: 'Netherlands (EU)',
      flagEmoji: '🇳🇱',
      regulatoryRegion: 'EU 2018/302 & GDPR',
      isEuMember: true,
      defaultLanguageCode: 'en',
    ),
    'PL': DetectedCountryInfo(
      countryCode: 'PL',
      nameVi: 'Ba Lan (EU)',
      nameEn: 'Poland (EU)',
      flagEmoji: '🇵🇱',
      regulatoryRegion: 'EU 2018/302 & GDPR',
      isEuMember: true,
      defaultLanguageCode: 'en',
    ),
    'SE': DetectedCountryInfo(
      countryCode: 'SE',
      nameVi: 'Thụy Điển (EU)',
      nameEn: 'Sweden (EU)',
      flagEmoji: '🇸🇪',
      regulatoryRegion: 'EU 2018/302 & GDPR',
      isEuMember: true,
      defaultLanguageCode: 'en',
    ),
    'JP': DetectedCountryInfo(
      countryCode: 'JP',
      nameVi: 'Nhật Bản',
      nameEn: 'Japan',
      flagEmoji: '🇯🇵',
      regulatoryRegion: 'APAC • APPI',
      isEuMember: false,
      defaultLanguageCode: 'en',
    ),
    'KR': DetectedCountryInfo(
      countryCode: 'KR',
      nameVi: 'Hàn Quốc',
      nameEn: 'South Korea',
      flagEmoji: '🇰🇷',
      regulatoryRegion: 'APAC • PIPA',
      isEuMember: false,
      defaultLanguageCode: 'en',
    ),
    'SG': DetectedCountryInfo(
      countryCode: 'SG',
      nameVi: 'Singapore',
      nameEn: 'Singapore',
      flagEmoji: '🇸🇬',
      regulatoryRegion: 'ASEAN • PDPA',
      isEuMember: false,
      defaultLanguageCode: 'en',
    ),
    'AU': DetectedCountryInfo(
      countryCode: 'AU',
      nameVi: 'Úc',
      nameEn: 'Australia',
      flagEmoji: '🇦🇺',
      regulatoryRegion: 'Oceania • Privacy Act',
      isEuMember: false,
      defaultLanguageCode: 'en',
    ),
    'CA': DetectedCountryInfo(
      countryCode: 'CA',
      nameVi: 'Canada',
      nameEn: 'Canada',
      flagEmoji: '🇨🇦',
      regulatoryRegion: 'North America • PIPEDA',
      isEuMember: false,
      defaultLanguageCode: 'en',
    ),
    'EG': DetectedCountryInfo(
      countryCode: 'EG',
      nameVi: 'Ai Cập',
      nameEn: 'Egypt',
      flagEmoji: '🇪🇬',
      regulatoryRegion: 'MENA • Global Google Play',
      isEuMember: false,
      defaultLanguageCode: 'en',
    ),
    'AL': DetectedCountryInfo(
      countryCode: 'AL',
      nameVi: 'Albania',
      nameEn: 'Albania',
      flagEmoji: '🇦🇱',
      regulatoryRegion: 'Europe • Global Google Play',
      isEuMember: false,
      defaultLanguageCode: 'en',
    ),
  };

  /// Kiểm tra môi trường chạy kiểm thử tự động (Flutter Test)
  static bool get isFlutterTestEnvironment {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Tự động nhận diện Quốc gia từ Locale hệ thống hoàn toàn Offline
  static DetectedCountryInfo detectCountry({String? overrideCountryCode}) {
    if (overrideCountryCode != null && overrideCountryCode.isNotEmpty) {
      final upper = overrideCountryCode.toUpperCase();
      if (_knownCountries.containsKey(upper)) {
        return _knownCountries[upper]!;
      }
      return _buildGenericCountry(upper);
    }

    if (isFlutterTestEnvironment) {
      return _knownCountries['VN']!;
    }

    try {
      final Locale sysLocale = PlatformDispatcher.instance.locale;
      final String lang = sysLocale.languageCode.toLowerCase();
      final String country = (sysLocale.countryCode ?? '').toUpperCase();

      if (lang == 'vi' || country == 'VN') {
        return _knownCountries['VN']!;
      }
      if (country.isNotEmpty) {
        if (_knownCountries.containsKey(country)) {
          return _knownCountries[country]!;
        }
        return _buildGenericCountry(country);
      }
    } catch (_) {}

    // Fallback theo múi giờ UTC+7 (Việt Nam)
    if (DateTime.now().timeZoneOffset.inHours == 7) {
      return _knownCountries['VN']!;
    }
    return _knownCountries['US']!;
  }

  static DetectedCountryInfo _buildGenericCountry(String code) {
    final isEu = euCountryCodes.contains(code);
    return DetectedCountryInfo(
      countryCode: code,
      nameVi: isEu ? 'Quốc gia EU ($code)' : 'Quốc tế ($code)',
      nameEn: isEu ? 'EU Member State ($code)' : 'International ($code)',
      flagEmoji: isEu ? '🇪🇺' : '🌐',
      regulatoryRegion:
          isEu ? 'EU 2018/302 & GDPR' : 'Global Google Play (174+ Regions)',
      isEuMember: isEu,
      defaultLanguageCode: code == 'VN' ? 'vi' : 'en',
    );
  }

  /// Danh sách quốc gia có thể chọn hoặc xem trước trong Cài đặt
  static List<DetectedCountryInfo> get selectableCountries =>
      _knownCountries.values.toList(growable: false);

  /// Xác định mã ngôn ngữ hiệu lực ('vi' hoặc 'en')
  static String resolveLanguageCode({
    required String languageMode,
    String? countryCodeOverride,
  }) {
    if (languageMode == 'vi') return 'vi';
    if (languageMode == 'en') return 'en';
    // 'auto'
    final detected = detectCountry(overrideCountryCode: countryCodeOverride);
    return detected.defaultLanguageCode;
  }

  /// Dịch tên Chủ đề sang Tiếng Anh khi ở chế độ English
  static String localizeTopicName(String topicId, String fallbackVi, bool isEn) {
    if (!isEn) return fallbackVi;
    switch (topicId) {
      case 'topic_notes':
        return 'Pitch Ear Training';
      case 'topic_staff_reading':
        return 'Staff Note Reading';
      case 'topic_intervals':
        return 'Interval Ear Training';
      case 'topic_keys':
        return 'Key Signatures & Tonality';
      case 'topic_chords':
        return 'Chord Recognition';
      case 'topic_melody':
        return 'Melodic Dictation';
      case 'topic_rhythm':
        return 'Rhythm & Time Signatures';
      case 'topic_guitar_notes':
        return 'Guitar Fretboard Notes';
      case 'topic_guitar_chords':
        return 'Guitar Chords';
      case 'topic_guitar_scales':
        return 'Guitar Scale Maps';
      case 'topic_guitar_tabs':
        return 'Guitar Tab & Fingerpicking';
      default:
        return fallbackVi;
    }
  }

  /// Dịch mô tả ngắn Chủ đề sang Tiếng Anh
  static String localizeTopicSubtitle(String topicId, String fallbackVi, bool isEn) {
    if (!isEn) return fallbackVi;
    switch (topicId) {
      case 'topic_notes':
        return 'Pitch recognition C3–C5 • 4 levels';
      case 'topic_staff_reading':
        return 'Treble, Bass & Ledger lines • 4 levels';
      case 'topic_intervals':
        return '2nd to Octave intervals • 3 levels';
      case 'topic_keys':
        return 'Major, Minor & Key signatures • 3 levels';
      case 'topic_chords':
        return 'Triads & 7th chords • 3 levels';
      case 'topic_melody':
        return '3–5 note melodic patterns • 3 levels';
      case 'topic_rhythm':
        return 'Meters 2/4, 3/4, 4/4, 6/8 • 3 levels';
      case 'topic_guitar_notes':
        return '6 open strings E-A-D-G-B-E & Frets 1–12';
      case 'topic_guitar_chords':
        return 'Open chords, Barre chords & Fingerings';
      case 'topic_guitar_scales':
        return 'Am/Em Pentatonic, C Major & Solo shapes';
      case 'topic_guitar_tabs':
        return '6-line Tab reading, Arpeggio & 1-2-3-4';
      default:
        return fallbackVi;
    }
  }

  /// Dịch tên Mức độ sang Tiếng Anh
  static String localizeLevelName(String levelId, String fallbackVi, bool isEn) {
    if (!isEn) return fallbackVi;
    if (levelId.endsWith('_basic')) return 'Level 1: Basic';
    if (levelId.endsWith('_inter')) return 'Level 2: Intermediate';
    if (levelId.endsWith('_adv')) {
      if (levelId.startsWith('level_notes_') || levelId.startsWith('level_staff_')) {
        return 'Level 3: Hard';
      }
      return 'Level 3: Advanced';
    }
    if (levelId.endsWith('_master')) return 'Level 4: Master';
    return fallbackVi;
  }

  /// Chuyển đổi thông minh nội dung câu hỏi, đáp án & giải thích sang Tiếng Anh / Ký hiệu Quốc tế (C-D-E)
  static String localizeMusicalText(String text, bool isEn) {
    if (!isEn || text.isEmpty) return text;
    var out = text;

    // Cụm câu hỏi phổ biến
    final Map<String, String> phraseMap = {
      'Nghe và chọn đúng tên nốt nhạc vừa phát': 'Listen and identify the musical note played',
      'Nghe và xác định cao độ nốt nhạc': 'Listen and identify the pitch',
      'Quan sát khuông nhạc và cho biết đây là nốt gì': 'Look at the musical staff and identify this note',
      'Quan sát vị trí trên khuông nhạc và chọn tên nốt đúng': 'Identify the note shown on the musical staff',
      'Dòng kẻ phụ': 'Ledger Line',
      'dòng kẻ phụ': 'ledger line',
      'Khóa Sol': 'Treble Clef',
      'khóa Sol': 'treble clef',
      'Khóa Fa': 'Bass Clef',
      'khóa Fa': 'bass clef',
      'Trên Cần đàn Guitar chuẩn (E-A-D-G-B-E)': 'On a standard Guitar fretboard (E-A-D-G-B-E)',
      'Hợp âm': 'Chord',
      'hợp âm': 'chord',
      'Giọng Trưởng (Major)': 'Major Key (Bright)',
      'Giọng Thứ (Minor)': 'Minor Key (Melancholic)',
      'Đô Trưởng': 'C Major',
      'Sol Trưởng': 'G Major',
      'Rê Trưởng': 'D Major',
      'La Trưởng': 'A Major',
      'Mi Trưởng': 'E Major',
      'Fa Trưởng': 'F Major',
      'La Thứ': 'A Minor',
      'Mi Thứ': 'E Minor',
      'Rê Thứ': 'D Minor',
      'Si Thứ': 'B Minor',
      'Ngăn': 'Fret',
      'ngăn': 'fret',
      'Dây buông': 'Open string',
      'dây buông': 'open string',
      'Dây số': 'String',
      'dây số': 'string',
      'Quãng 2 thứ': 'Minor 2nd',
      'Quãng 2 trưởng': 'Major 2nd',
      'Quãng 3 thứ': 'Minor 3rd',
      'Quãng 3 trưởng': 'Major 3rd',
      'Quãng 4 đúng': 'Perfect 4th',
      'Quãng 5 đúng': 'Perfect 5th',
      'Quãng 6 thứ': 'Minor 6th',
      'Quãng 6 trưởng': 'Major 6th',
      'Quãng 7 thứ': 'Minor 7th',
      'Quãng 7 trưởng': 'Major 7th',
      'Quãng 8 đúng': 'Perfect Octave (8ve)',
      'Quãng 1 đúng': 'Perfect Unison',
      'Nốt tròn': 'Whole note',
      'Nốt trắng': 'Half note',
      'Nốt đen': 'Quarter note',
      'Nốt móc đơn': 'Eighth note',
      'Nốt móc kép': 'Sixteenth note',
      'phách': 'beats',
      'Đô (C': 'C (Do - C',
      'Rê (D': 'D (Re - D',
      'Mi (E': 'E (Mi - E',
      'Fa (F': 'F (Fa - F',
      'Sol (G': 'G (Sol - G',
      'La (A': 'A (La - A',
      'Si (B': 'B (Ti - B',
    };

    phraseMap.forEach((vi, en) {
      out = out.replaceAll(vi, en);
    });

    // Ký hiệu nốt đơn lẻ "Đô (C)" -> "C (Do)"
    out = out
        .replaceAll('Đô# (C#)', 'C# (Do#)')
        .replaceAll('Rê# (D#)', 'D# (Re#)')
        .replaceAll('Fa# (F#)', 'F# (Fa#)')
        .replaceAll('Sol# (G#)', 'G# (Sol#)')
        .replaceAll('La# (A#)', 'A# (La#)')
        .replaceAll('Si giáng (Bb)', 'Bb (Ti flat)')
        .replaceAll('Mi giáng (Eb)', 'Eb (Mi flat)');

    return out;
  }
}

