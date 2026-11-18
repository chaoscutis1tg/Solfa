import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../app/widgets/solfa_guitar_icon.dart';
import '../../../core/providers/app_providers.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';
import '../../support_developer/presentation/support_developer_screen.dart';
import 'interactive_songbook_and_theory_sheet.dart';

const String _kPrefGuitarType = 'solfa_guitar_type_v1';
const String _kPrefGuitarProUnlocked = 'solfa_guitar_pro_unlocked_v1';
const String _kPrefGuitarWorkoutStars = 'solfa_guitar_workout_stars_v1';

/// Chế độ đàn Guitar đang chọn: 'acoustic' (Guitar Thùng Dây Đồng/Gỗ) hoặc 'electric' (Guitar Điện Amp).
final selectedGuitarTypeProvider = StateProvider<String>((ref) => 'acoustic');

/// Trạng thái mở khóa vĩnh viễn Bản đồ Scale & Bài Guitar Nâng Cao (50 Gem hoặc Xem Video Nhận Thưởng).
final guitarProUnlockedProvider = StateProvider<bool>((ref) => false);

/// Lưu số Sao (1..3 Sao) đạt được cho từng bài tập trong 12 bài Lộ trình Guitar (Level 1 -> Level 5).
final guitarWorkoutStarsProvider = StateProvider<Map<String, int>>(
  (ref) => const {
    'spider_1234': 2,
    'spider_4321': 2,
  },
);

Future<void> persistGuitarTypePreference(String type) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefGuitarType, type);
  } catch (_) {}
}

Future<void> persistGuitarProUnlockedPreference(bool unlocked) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefGuitarProUnlocked, unlocked);
  } catch (_) {}
}

Future<void> persistGuitarWorkoutStarsPreference(Map<String, int> stars) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefGuitarWorkoutStars, jsonEncode(stars));
  } catch (_) {}
}

/// Dữ liệu chuẩn 6 dây đàn Guitar (Từ dây 1 mỏng nhất ở trên -> dây 6 dày nhất ở dưới).
class GuitarFretboardData {
  /// Tên 6 dây buông từ Dây 1 (cao nhất) -> Dây 6 (trầm nhất)
  static const List<String> stringLabels = [
    'd1 (e4)',
    'd2 (B3)',
    'd3 (G3)',
    'd4 (D3)',
    'd5 (A2)',
    'd6 (E2)',
  ];

  /// 12 bán âm chuẩn
  static const List<(String pitchClass, String vnName, String audioOctave4)>
      chromaticNotes = [
    ('C', 'Đô', 'c4'),
    ('C#', 'Đô#', 'csharp4'),
    ('D', 'Rê', 'd4'),
    ('D#', 'Rê#', 'dsharp4'),
    ('E', 'Mi', 'e4'),
    ('F', 'Fa', 'f4'),
    ('F#', 'Fa#', 'fsharp4'),
    ('G', 'Sol', 'g4'),
    ('G#', 'Sol#', 'gsharp4'),
    ('A', 'La', 'a4'),
    ('A#', 'La#', 'asharp4'),
    ('B', 'Si', 'b4'),
  ];

  /// Số MIDI chuẩn của 6 dây buông (Dây 1 -> Dây 6: E4=64, B3=59, G3=55, D3=50, A2=45, E2=40)
  static const List<int> openStringMidi = [
    64, // Dây 1: E4 (329.63 Hz)
    59, // Dây 2: B3 (246.94 Hz)
    55, // Dây 3: G3 (196.00 Hz)
    50, // Dây 4: D3 (146.83 Hz)
    45, // Dây 5: A2 (110.00 Hz)
    40, // Dây 6: E2 (82.41 Hz)
  ];

  /// Chỉ số bán âm (0=C .. 11=B) của 6 dây buông (Dây 1 -> Dây 6: E, B, G, D, A, E)
  static const List<int> openStringSemitoneIndex = [
    4, // Dây 1: E4 (Mi)
    11, // Dây 2: B3 (Si)
    7, // Dây 3: G3 (Sol)
    2, // Dây 4: D3 (Rê)
    9, // Dây 5: A2 (La)
    4, // Dây 6: E2 (Mi)
  ];

  /// Trả về thông tin nốt chuẩn xác tuyệt đối theo cao độ vật lý tại `stringNumber` (1..6) và `fret` (0..12).
  static ({String noteCode, String vnLabel, String fullLabel, String audioAsset})
      noteAt({
    required int stringNumber,
    required int fret,
  }) {
    final sIdx = (stringNumber - 1).clamp(0, 5);
    final midi = openStringMidi[sIdx] + fret.clamp(0, 12);
    final semi = midi % 12;
    final octave = ((midi ~/ 12) - 1).clamp(2, 5);
    final info = chromaticNotes[semi];

    final assetPrefix = info.$3.substring(0, info.$3.length - 1);
    final asset = 'assets/audio/notes/$assetPrefix$octave.wav';

    return (
      noteCode: info.$1,
      vnLabel: info.$2,
      fullLabel: '${info.$2} (${info.$1}$octave)',
      audioAsset: asset,
    );
  }

  /// Thư viện 36 Hợp âm Guitar thực tế phân theo 4 nhóm:
  /// - 'open': Hợp âm Trưởng & Thứ mở cơ bản (C, D, E, G, A, Am, Dm, Em)
  /// - 'barre': Hợp âm Chặn (F, Fm, Bm, B, F#m, Gm, Cm, Bb)
  /// - 'seventh': Hợp âm Bảy (C7, D7, E7, G7, A7, B7, Am7, Dm7, Em7, Cmaj7, Fmaj7, Gmaj7)
  /// - 'color': Hợp âm Màu (Csus4, Dsus2, Dsus4, Esus4, Asus2, Asus4, Cadd9, G/B)
  static const List<GuitarChordShape> commonChords = [
    // ================= 1. HỢP ÂM MỞ (TRƯỞNG & THỨ) =================
    GuitarChordShape(
      id: 'C',
      category: 'open',
      name: 'Đô Trưởng (C)',
      formula: 'X - 3 - 2 - 0 - 1 - 0',
      fretsByString1To6: [0, 1, 0, 2, 3, -1],
      fingersByString1To6: [0, 1, 0, 2, 3, 0],
      audioAsset: 'assets/audio/keys/chord_c_maj.wav',
      tip: 'Ngón 1 bấm Dây 2 ngăn 1 • Ngón 2 Dây 4 ngăn 2 • Ngón 3 Dây 5 ngăn 3 (Bỏ dây 6)',
    ),
    GuitarChordShape(
      id: 'D',
      category: 'open',
      name: 'Rê Trưởng (D)',
      formula: 'X - X - 0 - 2 - 3 - 2',
      fretsByString1To6: [2, 3, 2, 0, -1, -1],
      fingersByString1To6: [2, 3, 1, 0, 0, 0],
      audioAsset: 'assets/audio/keys/chord_d_maj.wav',
      tip: 'Hình tam giác ở 3 dây dưới: Ngón 1 Dây 3 ngăn 2 • Ngón 2 Dây 1 ngăn 2 • Ngón 3 Dây 2 ngăn 3',
    ),
    GuitarChordShape(
      id: 'E',
      category: 'open',
      name: 'Mi Trưởng (E)',
      formula: '0 - 2 - 2 - 1 - 0 - 0',
      fretsByString1To6: [0, 0, 1, 2, 2, 0],
      fingersByString1To6: [0, 0, 1, 3, 2, 0],
      audioAsset: 'assets/audio/keys/chord_e_maj.wav',
      tip: 'Giống thế bấm Am nhưng dịch toàn bộ lên 1 dây (Ngón 1 Dây 3 ngăn 1 • Ngón 2&3 Dây 5&4 ngăn 2)',
    ),
    GuitarChordShape(
      id: 'G',
      category: 'open',
      name: 'Sol Trưởng (G)',
      formula: '3 - 2 - 0 - 0 - 0 - 3',
      fretsByString1To6: [3, 0, 0, 0, 2, 3],
      fingersByString1To6: [3, 0, 0, 0, 1, 2],
      audioAsset: 'assets/audio/keys/chord_g_maj.wav',
      tip: 'Ngón 1 Dây 5 ngăn 2 • Ngón 2 Dây 6 ngăn 3 • Ngón 3 Dây 1 ngăn 3 (Vang cả 6 dây)',
    ),
    GuitarChordShape(
      id: 'A',
      category: 'open',
      name: 'La Trưởng (A)',
      formula: 'X - 0 - 2 - 2 - 2 - 0',
      fretsByString1To6: [0, 2, 2, 2, 0, -1],
      fingersByString1To6: [0, 3, 2, 1, 0, 0],
      audioAsset: 'assets/audio/keys/chord_a_maj.wav',
      tip: 'Ngón 1, 2, 3 xếp dọc trên Dây 4, Dây 3, Dây 2 tại ngăn 2 (Bass dây 5 buông)',
    ),
    GuitarChordShape(
      id: 'Am',
      category: 'open',
      name: 'La Thứ (Am)',
      formula: 'X - 0 - 2 - 2 - 1 - 0',
      fretsByString1To6: [0, 1, 2, 2, 0, -1],
      fingersByString1To6: [0, 1, 3, 2, 0, 0],
      audioAsset: 'assets/audio/keys/chord_a_min.wav',
      tip: 'Ngón 1 Dây 2 ngăn 1 • Ngón 2 Dây 4 ngăn 2 • Ngón 3 Dây 3 ngăn 2 (Bass dây 5 La)',
    ),
    GuitarChordShape(
      id: 'Dm',
      category: 'open',
      name: 'Rê Thứ (Dm)',
      formula: 'X - X - 0 - 2 - 3 - 1',
      fretsByString1To6: [1, 3, 2, 0, -1, -1],
      fingersByString1To6: [1, 3, 2, 0, 0, 0],
      audioAsset: 'assets/audio/keys/chord_d_min.wav',
      tip: 'Ngón 1 Dây 1 ngăn 1 • Ngón 2 Dây 3 ngăn 2 • Ngón 3 Dây 2 ngăn 3 (Bass dây 4 Rê)',
    ),
    GuitarChordShape(
      id: 'Em',
      category: 'open',
      name: 'Mi Thứ (Em)',
      formula: '0 - 2 - 2 - 0 - 0 - 0',
      fretsByString1To6: [0, 0, 0, 2, 2, 0],
      fingersByString1To6: [0, 0, 0, 3, 2, 0],
      audioAsset: 'assets/audio/keys/chord_e_min.wav',
      tip: 'Hợp âm dễ nhất: Chỉ cần 2 ngón (Ngón 2 Dây 5 ngăn 2 & Ngón 3 Dây 4 ngăn 2)',
    ),

    // ================= 2. HỢP ÂM CHẶN (BARRE CHORDS) =================
    GuitarChordShape(
      id: 'F',
      category: 'barre',
      name: 'Fa Trưởng Chặn (F)',
      formula: '1 - 3 - 3 - 2 - 1 - 1',
      fretsByString1To6: [1, 1, 2, 3, 3, 1],
      fingersByString1To6: [1, 1, 2, 4, 3, 1],
      audioAsset: 'assets/audio/keys/chord_f_maj.wav',
      tip: 'Ngón 1 chặn cả 6 dây ngăn 1 • Ngón 2 Dây 3 ngăn 2 • Ngón 3 Dây 5 ngăn 3 • Ngón 4 Dây 4 ngăn 3',
    ),
    GuitarChordShape(
      id: 'Fm',
      category: 'barre',
      name: 'Fa Thứ Chặn (Fm)',
      formula: '1 - 3 - 3 - 1 - 1 - 1',
      fretsByString1To6: [1, 1, 1, 3, 3, 1],
      fingersByString1To6: [1, 1, 1, 4, 3, 1],
      audioAsset: 'assets/audio/keys/chord_f_min.wav',
      tip: 'Ngón 1 chặn 6 dây ngăn 1 (nhấc ngón 2 ra) • Ngón 3 Dây 5 ngăn 3 • Ngón 4 Dây 4 ngăn 3',
    ),
    GuitarChordShape(
      id: 'Bm',
      category: 'barre',
      name: 'Si Thứ Chặn (Bm)',
      formula: 'X - 2 - 4 - 4 - 3 - 2',
      fretsByString1To6: [2, 3, 4, 4, 2, -1],
      fingersByString1To6: [1, 2, 4, 3, 1, 0],
      audioAsset: 'assets/audio/keys/chord_b_min.wav',
      tip: 'Ngón 1 chặn 5 dây dưới tại ngăn 2 • Ngón 2 Dây 2 ngăn 3 • Ngón 3 Dây 4 ngăn 4 • Ngón 4 Dây 3 ngăn 4',
    ),
    GuitarChordShape(
      id: 'B',
      category: 'barre',
      name: 'Si Trưởng Chặn (B)',
      formula: 'X - 2 - 4 - 4 - 4 - 2',
      fretsByString1To6: [2, 4, 4, 4, 2, -1],
      fingersByString1To6: [1, 4, 3, 2, 1, 0],
      audioAsset: 'assets/audio/keys/chord_b_maj.wav',
      tip: 'Ngón 1 chặn 5 dây ngăn 2 • Ngón 2, 3, 4 bấm Dây 4, 3, 2 tại ngăn 4',
    ),
    GuitarChordShape(
      id: 'F#m',
      category: 'barre',
      name: 'Fa Thăng Thứ (F#m)',
      formula: '2 - 4 - 4 - 2 - 2 - 2',
      fretsByString1To6: [2, 2, 2, 4, 4, 2],
      fingersByString1To6: [1, 1, 1, 4, 3, 1],
      audioAsset: 'assets/audio/keys/chord_fsharp_min.wav',
      tip: 'Dịch dáng Fm lên ngăn 2: Ngón 1 chặn 6 dây ngăn 2 • Ngón 3 Dây 5 ngăn 4 • Ngón 4 Dây 4 ngăn 4',
    ),
    GuitarChordShape(
      id: 'Gm',
      category: 'barre',
      name: 'Sol Thứ Chặn (Gm)',
      formula: '3 - 5 - 5 - 3 - 3 - 3',
      fretsByString1To6: [3, 3, 3, 5, 5, 3],
      fingersByString1To6: [1, 1, 1, 4, 3, 1],
      audioAsset: 'assets/audio/keys/chord_g_min.wav',
      tip: 'Ngón 1 chặn 6 dây tại ngăn 3 • Ngón 3 Dây 5 ngăn 5 • Ngón 4 Dây 4 ngăn 5',
    ),
    GuitarChordShape(
      id: 'Cm',
      category: 'barre',
      name: 'Đô Thứ Chặn (Cm)',
      formula: 'X - 3 - 5 - 5 - 4 - 3',
      fretsByString1To6: [3, 4, 5, 5, 3, -1],
      fingersByString1To6: [1, 2, 4, 3, 1, 0],
      audioAsset: 'assets/audio/keys/chord_c_min.wav',
      tip: 'Dịch dáng Bm lên ngăn 3: Ngón 1 chặn 5 dây ngăn 3 • Ngón 2 Dây 2 ngăn 4 • Ngón 3&4 Dây 4&3 ngăn 5',
    ),
    GuitarChordShape(
      id: 'Bb',
      category: 'barre',
      name: 'Si Giáng Trưởng (Bb)',
      formula: 'X - 1 - 3 - 3 - 3 - 1',
      fretsByString1To6: [1, 3, 3, 3, 1, -1],
      fingersByString1To6: [1, 4, 3, 2, 1, 0],
      audioAsset: 'assets/audio/keys/chord_bb_maj.wav',
      tip: 'Ngón 1 chặn 5 dây tại ngăn 1 • Ngón 2, 3, 4 bấm Dây 4, 3, 2 tại ngăn 3',
    ),

    // ================= 3. HỢP ÂM BẢY (7TH: DOM7, MIN7, MAJ7) =================
    GuitarChordShape(
      id: 'C7',
      category: 'seventh',
      name: 'Đô Bảy Át (C7)',
      formula: 'X - 3 - 2 - 3 - 1 - 0',
      fretsByString1To6: [0, 1, 3, 2, 3, -1],
      fingersByString1To6: [0, 1, 4, 2, 3, 0],
      audioAsset: 'assets/audio/keys/chord_c_dom7.wav',
      tip: 'Giữ Đô Trưởng (C) và đặt thêm Ngón 4 (Út) vào Dây 3 ngăn 3 (nốt Sib)',
    ),
    GuitarChordShape(
      id: 'D7',
      category: 'seventh',
      name: 'Rê Bảy Át (D7)',
      formula: 'X - X - 0 - 2 - 1 - 2',
      fretsByString1To6: [2, 1, 2, 0, -1, -1],
      fingersByString1To6: [3, 1, 2, 0, 0, 0],
      audioAsset: 'assets/audio/keys/chord_d_dom7.wav',
      tip: 'Tam giác ngược ở 3 dây dưới: Ngón 1 Dây 2 ngăn 1 • Ngón 2 Dây 3 ngăn 2 • Ngón 3 Dây 1 ngăn 2',
    ),
    GuitarChordShape(
      id: 'E7',
      category: 'seventh',
      name: 'Mi Bảy Át (E7)',
      formula: '0 - 2 - 0 - 1 - 0 - 0',
      fretsByString1To6: [0, 0, 1, 0, 2, 0],
      fingersByString1To6: [0, 0, 1, 0, 2, 0],
      audioAsset: 'assets/audio/keys/chord_e_dom7.wav',
      tip: 'Từ Mi Trưởng (E) nhấc ngón áp út khỏi Dây 4 để vang Dây 4 buông (Rê D3)',
    ),
    GuitarChordShape(
      id: 'G7',
      category: 'seventh',
      name: 'Sol Bảy Át (G7)',
      formula: '3 - 2 - 0 - 0 - 0 - 1',
      fretsByString1To6: [1, 0, 0, 0, 2, 3],
      fingersByString1To6: [1, 0, 0, 0, 2, 3],
      audioAsset: 'assets/audio/keys/chord_g_dom7.wav',
      tip: 'Ngón 1 Dây 1 ngăn 1 (Fa) • Ngón 2 Dây 5 ngăn 2 (Si) • Ngón 3 Dây 6 ngăn 3 (Sol)',
    ),
    GuitarChordShape(
      id: 'A7',
      category: 'seventh',
      name: 'La Bảy Át (A7)',
      formula: 'X - 0 - 2 - 0 - 2 - 0',
      fretsByString1To6: [0, 2, 0, 2, 0, -1],
      fingersByString1To6: [0, 3, 0, 2, 0, 0],
      audioAsset: 'assets/audio/keys/chord_a_dom7.wav',
      tip: 'Từ La Trưởng (A) nhấc ngón giữa ở Dây 3 ra để vang Dây 3 buông (Sol G3)',
    ),
    GuitarChordShape(
      id: 'B7',
      category: 'seventh',
      name: 'Si Bảy Át (B7)',
      formula: 'X - 2 - 1 - 2 - 0 - 2',
      fretsByString1To6: [2, 0, 2, 1, 2, -1],
      fingersByString1To6: [4, 0, 3, 1, 2, 0],
      audioAsset: 'assets/audio/keys/chord_b_dom7.wav',
      tip: 'Ngón 1 Dây 4 ngăn 1 • Ngón 2 Dây 5 ngăn 2 • Ngón 3 Dây 3 ngăn 2 • Ngón 4 Dây 1 ngăn 2',
    ),
    GuitarChordShape(
      id: 'Am7',
      category: 'seventh',
      name: 'La Bảy Thứ (Am7)',
      formula: 'X - 0 - 2 - 0 - 1 - 0',
      fretsByString1To6: [0, 1, 0, 2, 0, -1],
      fingersByString1To6: [0, 1, 0, 2, 0, 0],
      audioAsset: 'assets/audio/keys/chord_a_min7.wav',
      tip: 'Từ La Thứ (Am) nhấc ngón áp út khỏi Dây 3 ngăn 2, chỉ còn 2 ngón cực kỳ êm dịu',
    ),
    GuitarChordShape(
      id: 'Dm7',
      category: 'seventh',
      name: 'Rê Bảy Thứ (Dm7)',
      formula: 'X - X - 0 - 2 - 1 - 1',
      fretsByString1To6: [1, 1, 2, 0, -1, -1],
      fingersByString1To6: [1, 1, 2, 0, 0, 0],
      audioAsset: 'assets/audio/keys/chord_d_min7.wav',
      tip: 'Ngón 1 chặn nhẹ Dây 1 & Dây 2 ngăn 1 • Ngón 2 bấm Dây 3 ngăn 2 (Bass dây 4 buông)',
    ),
    GuitarChordShape(
      id: 'Em7',
      category: 'seventh',
      name: 'Mi Bảy Thứ (Em7)',
      formula: '0 - 2 - 2 - 0 - 3 - 0',
      fretsByString1To6: [0, 3, 0, 2, 2, 0],
      fingersByString1To6: [0, 4, 0, 3, 2, 0],
      audioAsset: 'assets/audio/keys/chord_e_min7.wav',
      tip: 'Giữ Mi Thứ (Em) và đặt thêm Ngón 4 vào Dây 2 ngăn 3 (nốt Rê D4)',
    ),
    GuitarChordShape(
      id: 'Cmaj7',
      category: 'seventh',
      name: 'Đô Bảy Trưởng (Cmaj7)',
      formula: 'X - 3 - 2 - 0 - 0 - 0',
      fretsByString1To6: [0, 0, 0, 2, 3, -1],
      fingersByString1To6: [0, 0, 0, 2, 3, 0],
      audioAsset: 'assets/audio/keys/chord_c_maj7.wav',
      tip: 'Từ Đô Trưởng (C) nhấc ngón trỏ khỏi Dây 2 ngăn 1 để vang Dây 2 buông (Si B3)',
    ),
    GuitarChordShape(
      id: 'Fmaj7',
      category: 'seventh',
      name: 'Fa Bảy Trưởng (Fmaj7)',
      formula: 'X - X - 3 - 2 - 1 - 0',
      fretsByString1To6: [0, 1, 2, 3, -1, -1],
      fingersByString1To6: [0, 1, 2, 3, 0, 0],
      audioAsset: 'assets/audio/keys/chord_f_maj7.wav',
      tip: 'Thế bấm Fa mở cực dễ: Ngón 1 Dây 2 ngăn 1 • Ngón 2 Dây 3 ngăn 2 • Ngón 3 Dây 4 ngăn 3 • Dây 1 buông',
    ),
    GuitarChordShape(
      id: 'Gmaj7',
      category: 'seventh',
      name: 'Sol Bảy Trưởng (Gmaj7)',
      formula: '3 - 2 - 0 - 0 - 0 - 2',
      fretsByString1To6: [2, 0, 0, 0, 2, 3],
      fingersByString1To6: [1, 0, 0, 0, 2, 3],
      audioAsset: 'assets/audio/keys/chord_g_maj7.wav',
      tip: 'Ngón 1 Dây 1 ngăn 2 (Fa#) • Ngón 2 Dây 5 ngăn 2 (Si) • Ngón 3 Dây 6 ngăn 3 (Sol)',
    ),

    // ================= 4. HỢP ÂM MÀU (SUS2, SUS4, ADD9, SLASH) =================
    GuitarChordShape(
      id: 'Csus4',
      category: 'color',
      name: 'Đô Treo Bậc 4 (Csus4)',
      formula: 'X - 3 - 3 - 0 - 1 - 0',
      fretsByString1To6: [0, 1, 0, 3, 3, -1],
      fingersByString1To6: [0, 1, 0, 4, 3, 0],
      audioAsset: 'assets/audio/keys/chord_c_sus4.wav',
      tip: 'Từ Đô Trưởng (C) đặt thêm Ngón 4 vào Dây 4 ngăn 3 (nốt Fa) rồi nhả về C',
    ),
    GuitarChordShape(
      id: 'Dsus2',
      category: 'color',
      name: 'Rê Treo Bậc 2 (Dsus2)',
      formula: 'X - X - 0 - 2 - 3 - 0',
      fretsByString1To6: [0, 3, 2, 0, -1, -1],
      fingersByString1To6: [0, 3, 1, 0, 0, 0],
      audioAsset: 'assets/audio/keys/chord_d_sus2.wav',
      tip: 'Từ Rê Trưởng (D) nhấc ngón giữa khỏi Dây 1 để vang Dây 1 buông (Mi E4) trong trẻo',
    ),
    GuitarChordShape(
      id: 'Dsus4',
      category: 'color',
      name: 'Rê Treo Bậc 4 (Dsus4)',
      formula: 'X - X - 0 - 2 - 3 - 3',
      fretsByString1To6: [3, 3, 2, 0, -1, -1],
      fingersByString1To6: [4, 3, 1, 0, 0, 0],
      audioAsset: 'assets/audio/keys/chord_d_sus4.wav',
      tip: 'Từ Rê Trưởng (D) đặt thêm Ngón 4 vào Dây 1 ngăn 3 (nốt Sol G4)',
    ),
    GuitarChordShape(
      id: 'Esus4',
      category: 'color',
      name: 'Mi Treo Bậc 4 (Esus4)',
      formula: '0 - 2 - 2 - 2 - 0 - 0',
      fretsByString1To6: [0, 0, 2, 2, 2, 0],
      fingersByString1To6: [0, 0, 4, 3, 2, 0],
      audioAsset: 'assets/audio/keys/chord_e_sus4.wav',
      tip: 'Từ Mi Trưởng (E) đặt thêm Ngón 4 vào Dây 3 ngăn 2 (nốt La A3) rồi giải về E',
    ),
    GuitarChordShape(
      id: 'Asus2',
      category: 'color',
      name: 'La Treo Bậc 2 (Asus2)',
      formula: 'X - 0 - 2 - 2 - 0 - 0',
      fretsByString1To6: [0, 0, 2, 2, 0, -1],
      fingersByString1To6: [0, 0, 3, 2, 0, 0],
      audioAsset: 'assets/audio/keys/chord_a_sus2.wav',
      tip: 'Từ La Thứ (Am) nhấc ngón trỏ khỏi Dây 2 để vang cả Dây 2 buông (Si) và Dây 1 buông (Mi)',
    ),
    GuitarChordShape(
      id: 'Asus4',
      category: 'color',
      name: 'La Treo Bậc 4 (Asus4)',
      formula: 'X - 0 - 2 - 2 - 3 - 0',
      fretsByString1To6: [0, 3, 2, 2, 0, -1],
      fingersByString1To6: [0, 4, 3, 2, 0, 0],
      audioAsset: 'assets/audio/keys/chord_a_sus4.wav',
      tip: 'Từ La Thứ (Am) đặt Ngón 4 vào Dây 2 ngăn 3 (nốt Rê D4)',
    ),
    GuitarChordShape(
      id: 'Cadd9',
      category: 'color',
      name: 'Đô Cộng 9 (Cadd9)',
      formula: 'X - 3 - 2 - 0 - 3 - 3',
      fretsByString1To6: [3, 3, 0, 2, 3, -1],
      fingersByString1To6: [4, 3, 0, 1, 2, 0],
      audioAsset: 'assets/audio/keys/chord_c_add9.wav',
      tip: 'Hợp âm màu Acoustic: Ngón 1 Dây 4 ngăn 2 • Ngón 2 Dây 5 ngăn 3 • Ngón 3 Dây 2 ngăn 3 • Ngón 4 Dây 1 ngăn 3',
    ),
    GuitarChordShape(
      id: 'G/B',
      category: 'color',
      name: 'Sol Bass Si (G/B)',
      formula: 'X - 2 - 0 - 0 - 3 - 3',
      fretsByString1To6: [3, 3, 0, 0, 2, -1],
      fingersByString1To6: [4, 3, 0, 0, 1, 0],
      audioAsset: 'assets/audio/keys/chord_g_slash_b.wav',
      tip: 'Hợp âm cầu nối Bass đi bộ mượt mà giữa Đô Trưởng (C) và La Thứ (Am)',
    ),

    // ================= 5. HỢP ÂM 5 GUITAR ĐIỆN (POWER CHORDS ROCK/POP) =================
    GuitarChordShape(
      id: 'E5',
      category: 'power',
      name: 'Mi Năm (E5 • Power Chord)',
      formula: '0 - 2 - 2 - X - X - X',
      fretsByString1To6: [-1, -1, -1, 2, 2, 0],
      fingersByString1To6: [0, 0, 0, 3, 2, 0],
      audioAsset: 'assets/audio/keys/chord_e5.wav',
      tip: 'Hợp âm 5 Guitar Điện mở: Gảy mạnh 3 dây trầm (Dây 6 buông + Ngón 2&3 tại Dây 5&4 ngăn 2), bịt 3 dây mỏng',
    ),
    GuitarChordShape(
      id: 'A5',
      category: 'power',
      name: 'La Năm (A5 • Power Chord)',
      formula: 'X - 0 - 2 - 2 - X - X',
      fretsByString1To6: [-1, -1, 2, 2, 0, -1],
      fingersByString1To6: [0, 0, 3, 2, 0, 0],
      audioAsset: 'assets/audio/keys/chord_a5.wav',
      tip: 'Hợp âm 5 gốc Dây 5: Dây 5 buông (La) + Ngón 2 Dây 4 ngăn 2 + Ngón 3 Dây 3 ngăn 2 (bịt dây 6, 2, 1)',
    ),
    GuitarChordShape(
      id: 'G5',
      category: 'power',
      name: 'Sol Năm (G5 • Power Chord)',
      formula: '3 - 5 - 5 - X - X - X',
      fretsByString1To6: [-1, -1, -1, 5, 5, 3],
      fingersByString1To6: [0, 0, 0, 4, 3, 1],
      audioAsset: 'assets/audio/keys/chord_g5.wav',
      tip: 'Thế bấm Power Chord di động trên Dây 6: Ngón 1 Dây 6 ngăn 3 (Sol) • Ngón 3 Dây 5 ngăn 5 • Ngón 4 Dây 4 ngăn 5',
    ),
    GuitarChordShape(
      id: 'C5',
      category: 'power',
      name: 'Đô Năm (C5 • Power Chord)',
      formula: 'X - 3 - 5 - 5 - X - X',
      fretsByString1To6: [-1, -1, 5, 5, 3, -1],
      fingersByString1To6: [0, 0, 4, 3, 1, 0],
      audioAsset: 'assets/audio/keys/chord_c5.wav',
      tip: 'Thế bấm Power Chord di động trên Dây 5: Ngón 1 Dây 5 ngăn 3 (Đô) • Ngón 3 Dây 4 ngăn 5 • Ngón 4 Dây 3 ngăn 5',
    ),
    GuitarChordShape(
      id: 'D5',
      category: 'power',
      name: 'Rê Năm (D5 • Power Chord)',
      formula: 'X - 5 - 7 - 7 - X - X',
      fretsByString1To6: [-1, -1, 7, 7, 5, -1],
      fingersByString1To6: [0, 0, 4, 3, 1, 0],
      audioAsset: 'assets/audio/keys/chord_d5.wav',
      tip: 'Dịch dáng C5 lên 2 ngăn: Ngón 1 Dây 5 ngăn 5 (Rê) • Ngón 3 Dây 4 ngăn 7 • Ngón 4 Dây 3 ngăn 7',
    ),
    GuitarChordShape(
      id: 'B5',
      category: 'power',
      name: 'Si Năm (B5 • Power Chord)',
      formula: 'X - 2 - 4 - 4 - X - X',
      fretsByString1To6: [-1, -1, 4, 4, 2, -1],
      fingersByString1To6: [0, 0, 4, 3, 1, 0],
      audioAsset: 'assets/audio/keys/chord_b5.wav',
      tip: 'Ngón 1 Dây 5 ngăn 2 (Si) • Ngón 3 Dây 4 ngăn 4 • Ngón 4 Dây 3 ngăn 4 (Thay thế Bm chặn cực nhanh khi chơi Rock/Pop)',
    ),
    GuitarChordShape(
      id: 'F5',
      category: 'power',
      name: 'Fa Năm (F5 • Power Chord)',
      formula: '1 - 3 - 3 - X - X - X',
      fretsByString1To6: [-1, -1, -1, 3, 3, 1],
      fingersByString1To6: [0, 0, 0, 4, 3, 1],
      audioAsset: 'assets/audio/keys/chord_f5.wav',
      tip: 'Ngón 1 Dây 6 ngăn 1 (Fa) • Ngón 3 Dây 5 ngăn 3 • Ngón 4 Dây 4 ngăn 3 (Không cần chặn cả 6 dây như Fa Trưởng)',
    ),
    GuitarChordShape(
      id: 'F#5',
      category: 'power',
      name: 'Fa Thăng Năm (F#5 • Power Chord)',
      formula: '2 - 4 - 4 - X - X - X',
      fretsByString1To6: [-1, -1, -1, 4, 4, 2],
      fingersByString1To6: [0, 0, 0, 4, 3, 1],
      audioAsset: 'assets/audio/keys/chord_fsharp5.wav',
      tip: 'Dịch dáng F5 lên ngăn 2: Ngón 1 Dây 6 ngăn 2 (Fa#) • Ngón 3 Dây 5 ngăn 4 • Ngón 4 Dây 4 ngăn 4',
    ),
  ];

  /// 12 Bài luyện ngón, Rải âm Fingerstyle, Vòng hợp âm & Riff/Solo phân theo Lộ trình 5 Cấp độ (Level 1 -> Level 5)
  /// cho cả Guitar Thùng (Acoustic) và Guitar Điện (Electric).
  static const List<GuitarWorkoutExercise> fingerWorkouts = [
    // ================= CẤP ĐỘ 1 (LEVEL 1: KHỞI ĐỘNG & KIỂM SOÁT NGÓN) =================
    GuitarWorkoutExercise(
      id: 'spider_1234',
      title: 'Bài 1: Bò Nhện Chuẩn (1–2–3–4 • Mở Khẩu Độ)',
      levelNumber: 1,
      levelTag: 'Lv.1 • Cơ bản',
      guitarStyle: 'acoustic',
      styleBadge: 'Guitar Thùng • Khởi động',
      description:
          'Mỗi ngón tay trái phụ trách 1 ngăn liên tiếp (Trỏ 1 – Giữa 2 – Áp út 3 – Út 4) leo từ Dây 6 sang Dây 5. Giữ đầu ngón tay vuông góc và bấm sát thanh sắt ngăn đàn.',
      steps: [
        (6, 1, 'Ngón 1 (Trỏ)'),
        (6, 2, 'Ngón 2 (Giữa)'),
        (6, 3, 'Ngón 3 (Áp út)'),
        (6, 4, 'Ngón 4 (Út)'),
        (5, 1, 'Ngón 1 (Trỏ)'),
        (5, 2, 'Ngón 2 (Giữa)'),
        (5, 3, 'Ngón 3 (Áp út)'),
        (5, 4, 'Ngón 4 (Út)'),
      ],
    ),
    GuitarWorkoutExercise(
      id: 'spider_4321',
      title: 'Bài 2: Alternate Picking Lùi (4–3–2–1 • Khỏe Ngón Út)',
      levelNumber: 1,
      levelTag: 'Lv.1 • Cơ bản',
      guitarStyle: 'electric',
      styleBadge: 'Guitar Điện • Phím gảy ↓↑',
      description:
          'Cầm phím gảy (Pick) đánh xen kẽ Xuống (↓) – Lên (↑) lùi từ Ngăn 4 về Ngăn 1 (Út 4 → Áp út 3 → Giữa 2 → Trỏ 1) trên Dây 1 & Dây 2 để làm khỏe ngón Út.',
      steps: [
        (1, 4, 'Ngón 4 (Phím ↓)'),
        (1, 3, 'Ngón 3 (Phím ↑)'),
        (1, 2, 'Ngón 2 (Phím ↓)'),
        (1, 1, 'Ngón 1 (Phím ↑)'),
        (2, 4, 'Ngón 4 (Phím ↓)'),
        (2, 3, 'Ngón 3 (Phím ↑)'),
        (2, 2, 'Ngón 2 (Phím ↓)'),
        (2, 1, 'Ngón 1 (Phím ↑)'),
      ],
    ),

    // ================= CẤP ĐỘ 2 (LEVEL 2: RẢI BALLAD, VALSE & POWER RIFF) =================
    GuitarWorkoutExercise(
      id: 'arpeggio_ballad',
      title: 'Bài 3: Rải Tay Phải P–i–m–a (Ballad 4/4 • Đô Trưởng)',
      levelNumber: 2,
      levelTag: 'Lv.2 • Đệm rải',
      guitarStyle: 'acoustic',
      styleBadge: 'Guitar Thùng • Ballad 4/4',
      description:
          'Giữ thế bấm Đô Trưởng (C) bằng tay trái, tay phải rải công thức Ballad kinh điển: Cái P (Dây 5) – Trỏ i (3) – Giữa m (2) – Trỏ i (3) – Áp út a (1) – Trỏ i (3) – Giữa m (2) – Trỏ i (3).',
      steps: [
        (5, 3, 'Cái P (Bass Đô)'),
        (3, 0, 'Trỏ i (Dây 3)'),
        (2, 1, 'Giữa m (Dây 2)'),
        (3, 0, 'Trỏ i (Dây 3)'),
        (1, 0, 'Áp út a (Dây 1)'),
        (3, 0, 'Trỏ i (Dây 3)'),
        (2, 1, 'Giữa m (Dây 2)'),
        (3, 0, 'Trỏ i (Dây 3)'),
      ],
    ),
    GuitarWorkoutExercise(
      id: 'acoustic_valse_bolero',
      title: 'Bài 4: Đệm Valse 3/4 & Đảo Bass Bolero (La Thứ Am)',
      levelNumber: 2,
      levelTag: 'Lv.2 • Đệm hát',
      guitarStyle: 'acoustic',
      styleBadge: 'Guitar Thùng • Valse & Bolero',
      description:
          'Giữ hợp âm La Thứ (Am): Phách 1 gảy Bass chính Dây 5 buông (La) → rải dây 3–2–1 → đảo sang Bass phụ Dây 4 ngăn 2 (Mi) tạo nhịp điệu trầm bổng tự nhiên.',
      steps: [
        (5, 0, 'Cái P (Bass La)'),
        (3, 2, 'Trỏ i (La A3)'),
        (2, 1, 'Giữa m (Đô C4)'),
        (1, 0, 'Áp út a (Mi E4)'),
        (4, 2, 'Cái P (Bass phụ Mi)'),
        (3, 2, 'Trỏ i (La A3)'),
        (2, 1, 'Giữa m (Đô C4)'),
        (1, 0, 'Áp út a (Mi E4)'),
      ],
    ),
    GuitarWorkoutExercise(
      id: 'electric_power_riff',
      title: 'Bài 5: Riff Hợp Âm 5 Rock Kinh Điển (E5 – G5 – A5 – C5)',
      levelNumber: 2,
      levelTag: 'Lv.2 • Riff Điện',
      guitarStyle: 'electric',
      styleBadge: 'Guitar Điện • Power Chords',
      description:
          'Đánh câu Riff Rock bất hủ bằng thế bấm Hợp âm 5 (Root + Quãng 5): E5 (Dây 6 buông + Dây 5 ngăn 2) → G5 (Ngăn 3–5) → A5 (Dây 5 buông + Dây 4 ngăn 2) → C5 (Ngăn 3–5).',
      steps: [
        (6, 0, 'Root E5 (Mi E2)'),
        (5, 2, 'Quãng 5 (Si B2)'),
        (6, 3, 'Root G5 (Sol G2)'),
        (5, 5, 'Quãng 5 (Rê D3)'),
        (5, 0, 'Root A5 (La A2)'),
        (4, 2, 'Quãng 5 (Mi E3)'),
        (5, 3, 'Root C5 (Đô C3)'),
        (4, 5, 'Quãng 5 (Sol G3)'),
      ],
    ),

    // ================= CẤP ĐỘ 3 (LEVEL 3: TÁCH NGÓN, LEGATO & VÒNG CANON) =================
    GuitarWorkoutExercise(
      id: 'perm_1324',
      title: 'Bài 6: Đảo Ngón Chéo & Legato (1–3–2–4 • Tách Ngón)',
      levelNumber: 3,
      levelTag: 'Lv.3 • Trung bình',
      guitarStyle: 'electric',
      styleBadge: 'Guitar Điện • Legato H/P',
      description:
          'Bài tập tách gân ngón tay và luyến Hammer-on: đánh xen kẽ Trỏ (1) → Áp út (3) → Giữa (2) → Út (4) trên Dây 4 & Dây 3 giúp chuyển hợp âm và chạy câu cực nhanh.',
      steps: [
        (4, 1, 'Ngón 1 (Trỏ)'),
        (4, 3, 'Ngón 3 (Hammer)'),
        (4, 2, 'Ngón 2 (Giữa)'),
        (4, 4, 'Ngón 4 (Hammer)'),
        (3, 1, 'Ngón 1 (Trỏ)'),
        (3, 3, 'Ngón 3 (Hammer)'),
        (3, 2, 'Ngón 2 (Giữa)'),
        (3, 4, 'Ngón 4 (Hammer)'),
      ],
    ),
    GuitarWorkoutExercise(
      id: 'acoustic_canon_pop',
      title: 'Bài 7: Vòng Hợp Âm Canon & Pop (C – G/B – Am – Fmaj7)',
      levelNumber: 3,
      levelTag: 'Lv.3 • Vòng Hòa Âm',
      guitarStyle: 'acoustic',
      styleBadge: 'Guitar Thùng • Bass Đi Bộ',
      description:
          'Luyện đường Bass đi bộ (Walking Bass) mượt mà nối 4 hợp âm Pop/Ballad quốc dân: Đô (Dây 5 ngăn 3) → Si (Dây 5 ngăn 2) → La (Dây 5 buông) → Fa (Dây 4 ngăn 3).',
      steps: [
        (5, 3, 'Bass C (Đô C3)'),
        (2, 1, 'Nốt giai điệu C4'),
        (5, 2, 'Bass G/B (Si B2)'),
        (2, 3, 'Nốt giai điệu D4'),
        (5, 0, 'Bass Am (La A2)'),
        (2, 1, 'Nốt giai điệu C4'),
        (4, 3, 'Bass Fmaj7 (Fa F3)'),
        (3, 2, 'Nốt giai điệu A3'),
      ],
    ),
    GuitarWorkoutExercise(
      id: 'string_skip',
      title: 'Bài 8: Nhảy Dây Cách Quãng (String Skipping)',
      levelNumber: 3,
      levelTag: 'Lv.3 • Trung bình',
      guitarStyle: 'acoustic',
      styleBadge: 'Guitar Thùng • Nhảy dây',
      description:
          'Nhảy cách qua 1 dây đàn (Dây 6 → Dây 4 → Dây 5 → Dây 3) để luyện sự chính xác đồng bộ giữa tay phải gảy dây và tay trái bấm phím.',
      steps: [
        (6, 1, 'Ngón 1 (Dây 6)'),
        (6, 2, 'Ngón 2 (Dây 6)'),
        (4, 1, 'Ngón 1 (Dây 4)'),
        (4, 2, 'Ngón 2 (Dây 4)'),
        (5, 3, 'Ngón 3 (Dây 5)'),
        (5, 4, 'Ngón 4 (Dây 5)'),
        (3, 3, 'Ngón 3 (Dây 3)'),
        (3, 4, 'Ngón 4 (Dây 3)'),
      ],
    ),

    // ================= CẤP ĐỘ 4 (LEVEL 4: CÂU LICK INTRO & SOLO PENTATONIC/BLUES) =================
    GuitarWorkoutExercise(
      id: 'acoustic_fingerstyle_lick',
      title: 'Bài 9: Câu Lick Intro Fingerstyle Mộc Mạc (Mi Thứ Em)',
      levelNumber: 4,
      levelTag: 'Lv.4 • Fingerstyle',
      guitarStyle: 'acoustic',
      styleBadge: 'Guitar Thùng • Intro Lick',
      description:
          'Câu Intro Acoustic đậm chất tự sự ở giọng Mi Thứ (Em): kết hợp dây 6 buông trầm ấm với giai điệu trên Dây 1 & Dây 2 (Ngăn 0 – 3 – 2 – 0).',
      steps: [
        (6, 0, 'Bass Mi (Dây 6)'),
        (1, 0, 'Dây 1 buông (Mi)'),
        (1, 3, 'Ngón 3 (Sol G4)'),
        (1, 2, 'Ngón 2 (Fa# F#4)'),
        (1, 0, 'Dây 1 buông (Mi)'),
        (2, 3, 'Ngón 3 (Rê D4)'),
        (2, 0, 'Dây 2 buông (Si)'),
        (3, 0, 'Dây 3 buông (Sol)'),
      ],
    ),
    GuitarWorkoutExercise(
      id: 'pentatonic_box1',
      title: 'Bài 10: Chạy Ngón Solo Am Pentatonic (Box 1 • Ngăn 5–8)',
      levelNumber: 4,
      levelTag: 'Lv.4 • Nâng cao',
      guitarStyle: 'electric',
      styleBadge: 'Guitar Điện • Solo Box 1',
      description:
          'Chạy mẫu Solo Ngũ cung La Thứ (Box 1 tại Ngăn 5–8): Dây 6 (5–8) → Dây 5 (5–7) → Dây 4 (5–7) → Dây 3 (5–7). Ngón 1 giữ trụ ở Ngăn 5, Ngón 3 bấm Ngăn 7, Ngón 4 bấm Ngăn 8.',
      steps: [
        (6, 5, 'Ngón 1 (La A2)'),
        (6, 8, 'Ngón 4 (Đô C3)'),
        (5, 5, 'Ngón 1 (Rê D3)'),
        (5, 7, 'Ngón 3 (Mi E3)'),
        (4, 5, 'Ngón 1 (Sol G3)'),
        (4, 7, 'Ngón 3 (La A3)'),
        (3, 5, 'Ngón 1 (Đô C4)'),
        (3, 7, 'Ngón 3 (Rê D4)'),
      ],
    ),
    GuitarWorkoutExercise(
      id: 'electric_blues_lick',
      title: 'Bài 11: Câu Lick Blues & Nốt Blue Note (A Blues • Ngăn 5–8)',
      levelNumber: 4,
      levelTag: 'Lv.4 • Blues Lead',
      guitarStyle: 'electric',
      styleBadge: 'Guitar Điện • Blues Lick',
      description:
          'Đi qua nốt "Blue Note" đặc trưng (Rê# tại Dây 5 Ngăn 6 & Dây 3 Ngăn 8) để tạo màu sắc Blues/Rock đầy cảm xúc và cá tính.',
      steps: [
        (6, 5, 'Ngón 1 (Gốc La)'),
        (6, 8, 'Ngón 4 (Đô C3)'),
        (5, 5, 'Ngón 1 (Rê D3)'),
        (5, 6, 'Ngón 2 (Blue Note Rê#)'),
        (5, 7, 'Ngón 3 (Mi E3)'),
        (4, 5, 'Ngón 1 (Sol G3)'),
        (4, 7, 'Ngón 3 (Gốc La A3)'),
        (3, 8, 'Ngón 4 (Blue Note Rê#)'),
      ],
    ),

    // ================= CẤP ĐỘ 5 (LEVEL 5: CHẠY LEAD TỐC ĐỘ CAO & MASTER) =================
    GuitarWorkoutExercise(
      id: 'electric_funk_groove',
      title: 'Bài 12: Chạy Lead Tốc Độ Cao 3 Dây Mỏng (Mi Thứ • Ngăn 7–10)',
      levelNumber: 5,
      levelTag: 'Lv.5 • Master Solo',
      guitarStyle: 'electric',
      styleBadge: 'Guitar Điện • High Lead',
      description:
          'Mẫu chạy Lead cao trào trên 3 dây mỏng ở thế tay cao (Ngăn 7–10): kết hợp Alternate Picking và kết câu tại nốt chủ âm Mi (Dây 3 Ngăn 9).',
      steps: [
        (1, 7, 'Ngón 1 (Si B4)'),
        (1, 10, 'Ngón 4 (Rê D5)'),
        (1, 7, 'Ngón 1 (Si B4)'),
        (2, 10, 'Ngón 4 (La A4)'),
        (2, 8, 'Ngón 2 (Sol G4)'),
        (2, 7, 'Ngón 1 (Fa# F#4)'),
        (3, 9, 'Ngón 3 (Chủ âm Mi)'),
        (3, 7, 'Ngón 1 (Rê D4)'),
      ],
    ),
  ];
}

class GuitarChordShape {
  final String id;
  final String category; // 'open', 'barre', 'seventh', 'color', 'power'
  final String name;
  final String formula;
  final List<int> fretsByString1To6;
  final List<int> fingersByString1To6;
  final String audioAsset;
  final String tip;

  const GuitarChordShape({
    required this.id,
    this.category = 'open',
    required this.name,
    required this.formula,
    required this.fretsByString1To6,
    required this.fingersByString1To6,
    required this.audioAsset,
    required this.tip,
  });

  int get maxFret {
    int m = 4;
    for (final f in fretsByString1To6) {
      if (f > m) m = f;
    }
    return m;
  }
}

class GuitarWorkoutExercise {
  final String id;
  final String title;
  final int levelNumber; // 1..5
  final String levelTag;
  final String guitarStyle; // 'acoustic' | 'electric'
  final String styleBadge;
  final String description;
  final List<(int stringNum, int fretNum, String fingerLabel)> steps;

  const GuitarWorkoutExercise({
    required this.id,
    required this.title,
    this.levelNumber = 1,
    required this.levelTag,
    this.guitarStyle = 'acoustic',
    this.styleBadge = 'Guitar',
    required this.description,
    required this.steps,
  });

  int get maxFret {
    int m = 5;
    for (final s in steps) {
      if (s.$2 > m) m = s.$2;
    }
    return m;
  }
}

/// Mở Trang Bản Đồ Cần Đàn 6 Dây, Thư Viện 36 Hợp Âm & Bản Đồ Scale (Full-screen Page, KHÔNG dùng Bottom Sheet trượt lên).
Future<void> showGuitarStudioSheet(
  BuildContext context, {
  int initialTab = 0,
  bool isWorkoutOnlyPage = false,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (ctx) => GuitarStudioSheet(
        initialTab: initialTab,
        isWorkoutOnlyPage: isWorkoutOnlyPage,
      ),
    ),
  );
}

/// Mở Trang Luyện Ngón Guitar & Thực Hành Tab Chuyên Sâu tách biệt hoàn toàn với Map Cần Đàn.
Future<void> showGuitarFingerWorkoutPage(BuildContext context) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (ctx) => const GuitarStudioSheet(
        initialTab: 3,
        isWorkoutOnlyPage: true,
      ),
    ),
  );
}

class GuitarStudioSheet extends ConsumerStatefulWidget {
  final int initialTab;
  final bool isWorkoutOnlyPage;

  const GuitarStudioSheet({
    super.key,
    this.initialTab = 0,
    this.isWorkoutOnlyPage = false,
  });

  @override
  ConsumerState<GuitarStudioSheet> createState() => _GuitarStudioSheetState();
}

/// Thanh chuyển nhanh 2 chế độ đàn: Guitar Thùng (Acoustic) <-> Guitar Điện (Electric)
/// Đổi đồng thời cả Âm sắc vật lý (guitar_acoustic / guitar_electric) và Giáo trình gợi ý.
class GuitarTypeSwitchBar extends ConsumerWidget {
  final ValueChanged<String>? onChanged;

  const GuitarTypeSwitchBar({
    super.key,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guitarType = ref.watch(selectedGuitarTypeProvider);
    final isElectric = guitarType == 'electric';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = ref.watch(appSettingsProvider).isEnglish;

    void selectType(String type) {
      ref.read(selectedGuitarTypeProvider.notifier).state = type;
      unawaited(persistGuitarTypePreference(type));
      final audio = ref.read(audioServiceProvider);
      audio.setGuitarType(type);
      // Phát ngay âm thanh mẫu đặc trưng của từng cây đàn (Hợp âm G Thùng vs Hợp âm E5 Điện)
      final previewChord = type == 'electric'
          ? 'assets/audio/keys/chord_e5.wav'
          : 'assets/audio/keys/chord_g_maj.wav';
      audio.playGuitarAsset(previewChord, overrideGuitarType: type);
      onChanged?.call(type);
    }

    return Container(
      key: const Key('guitar_type_switch_bar'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('btn_guitar_type_acoustic'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => selectType('acoustic'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: !isElectric
                      ? const Color(0xFFD97706)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SolfaGuitarIcon(
                      size: 16,
                      isElectric: false,
                      color: !isElectric
                          ? Colors.white
                          : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn
                              ? 'Acoustic Guitar (Steel)'
                              : 'Guitar Thùng (Acoustic)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: !isElectric ? Colors.white : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              key: const Key('btn_guitar_type_electric'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => selectType('electric'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: isElectric
                      ? const Color(0xFF6366F1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SolfaGuitarIcon(
                      size: 16,
                      isElectric: true,
                      color: isElectric
                          ? Colors.white
                          : const Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn
                              ? 'Electric Guitar (Rock/Lead)'
                              : 'Guitar Điện (Electric)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isElectric ? Colors.white : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuitarStudioSheetState extends ConsumerState<GuitarStudioSheet>
    with WidgetsBindingObserver {
  /// 0: Bản đồ Cần đàn (Fretboard Map)
  /// 1: Hợp âm Guitar (Chord Shapes - 44 hợp âm gồm Mở, Chặn, Bảy, Màu & Hợp âm 5 Điện)
  /// 2: Bản đồ Scale (7 Âm giai: Pentatonic, Blues, Trưởng/Thứ & Hài hòa)
  /// 3: Luyện ngón, Mẫu chạy & Đọc Tab (12 bài từ Level 1 -> Level 5)
  late int _selectedTab;

  int _activeString = 5; // Dây 5
  int _activeFret = 3; // Ngăn 3 (Đô C3)
  bool _showNaturalNotesOnly = true;
  bool _showOctaveJumpGuide = false;

  String _selectedChordCategory = 'all'; // 'all', 'open', 'barre', 'seventh', 'color', 'power'
  String _selectedChordId = 'C';
  String _selectedScaleId = 'am_pentatonic';

  String _workoutStyleFilter = 'all'; // 'all', 'acoustic', 'electric'
  int _selectedWorkoutIndex = 0;
  int _spiderStep = 0;
  int _spiderStepIntervalMs = 500; // 680ms (Chậm), 500ms (Vừa), 330ms (Nhanh)
  Timer? _spiderTimer;
  bool _isSpiderPlaying = false;

  Timer? _strumTimer;
  int? _activeStrumString;
  int? _activeStrumFret;

  Timer? _tunerLoopTimer;
  int? _loopingTunerString; // 1..6 khi đang bật lặp so dây

  Timer? _progLoopTimer;
  String? _activeProgressionId;
  int _activeProgressionStep = 0;

  Timer? _scaleRunTimer;
  int? _activeScaleRunString;
  int? _activeScaleRunFret;
  bool _isScaleRunPlaying = false;

  Timer? _jamLoopTimer;
  String? _activeJamTrackId;
  int _activeJamStep = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedTab = widget.isWorkoutOnlyPage ? 3 : widget.initialTab;
    unawaited(_loadPersistedGuitarState());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopAllAuxiliaryTimers();
      ref.read(audioServiceProvider).stop(includePolyphony: true);
      if (mounted) {
        setState(() {
          _isSpiderPlaying = false;
          _isScaleRunPlaying = false;
          _loopingTunerString = null;
          _activeProgressionId = null;
          _activeJamTrackId = null;
          _activeStrumString = null;
          _activeStrumFret = null;
          _activeScaleRunString = null;
          _activeScaleRunFret = null;
        });
      }
    }
  }

  Future<void> _loadPersistedGuitarState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final savedType = prefs.getString(_kPrefGuitarType);
      if (savedType == 'acoustic' || savedType == 'electric') {
        ref.read(selectedGuitarTypeProvider.notifier).state = savedType!;
        ref.read(audioServiceProvider).setGuitarType(savedType);
      }
      final savedPro = prefs.getBool(_kPrefGuitarProUnlocked);
      if (savedPro == true) {
        ref.read(guitarProUnlockedProvider.notifier).state = true;
      }
      final savedStarsJson = prefs.getString(_kPrefGuitarWorkoutStars);
      if (savedStarsJson != null && savedStarsJson.isNotEmpty) {
        final decoded = jsonDecode(savedStarsJson);
        if (decoded is Map) {
          final parsed = <String, int>{};
          decoded.forEach((k, v) {
            if (k is String && v is num) {
              parsed[k] = v.toInt().clamp(1, 3);
            }
          });
          if (parsed.isNotEmpty) {
            ref.read(guitarWorkoutStarsProvider.notifier).state = parsed;
          }
        }
      }
    } catch (_) {}
  }

  void _stopAllAuxiliaryTimers() {
    _spiderTimer?.cancel();
    _strumTimer?.cancel();
    _tunerLoopTimer?.cancel();
    _progLoopTimer?.cancel();
    _scaleRunTimer?.cancel();
    _jamLoopTimer?.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAllAuxiliaryTimers();
    super.dispose();
  }

  /// Phát hợp âm chuẩn xác 100% theo cao độ thực tế của 6 dây trên cần đàn (quét nhanh như gảy phím thật theo đúng âm sắc Guitar Thùng / Guitar Điện).
  void _playChordRealVoicing(GuitarChordShape chord) {
    _strumTimer?.cancel();
    final List<(int stringNum, int fretNum)> notes = [];
    for (int s = 6; s >= 1; s--) {
      final f = chord.fretsByString1To6[s - 1];
      if (f >= 0) {
        notes.add((s, f));
      }
    }
    if (notes.isEmpty) return;
    int idx = 0;
    final audio = ref.read(audioServiceProvider);
    void playNext() {
      if (!mounted || idx >= notes.length) {
        _strumTimer?.cancel();
        return;
      }
      final (s, f) = notes[idx];
      final n = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
      audio.playGuitarAsset(n.audioAsset);
      idx++;
    }

    playNext();
    _strumTimer = Timer.periodic(
      const Duration(milliseconds: 32),
      (_) => playNext(),
    );
  }

  void _startChordStrum(
    GuitarChordShape chord, {
    required bool isBallad,
  }) {
    _strumTimer?.cancel();
    final List<(int stringNum, int fretNum)> sequence = [];

    if (!isBallad) {
      // Quạt / Rải từ dây Bass (dây số lớn nhất không bịt X) xuống dây 1
      for (int s = 6; s >= 1; s--) {
        final fret = chord.fretsByString1To6[s - 1];
        if (fret >= 0) {
          sequence.add((s, fret));
        }
      }
    } else {
      // Rải Ballad kinh điển: Bass – 3 – 2 – 3 – 1 – 3 – 2 – 3
      int bassString = 6;
      for (int s = 6; s >= 4; s--) {
        if (chord.fretsByString1To6[s - 1] >= 0) {
          bassString = s;
          break;
        }
      }
      final pattern = [bassString, 3, 2, 3, 1, 3, 2, 3];
      for (final s in pattern) {
        final fret = chord.fretsByString1To6[s - 1];
        if (fret >= 0) {
          sequence.add((s, fret));
        }
      }
    }

    if (sequence.isEmpty) return;

    int step = 0;
    final audio = ref.read(audioServiceProvider);
    void playStep() {
      if (!mounted || step >= sequence.length) {
        _strumTimer?.cancel();
        if (mounted) {
          setState(() {
            _activeStrumString = null;
            _activeStrumFret = null;
          });
        }
        return;
      }
      final (s, f) = sequence[step];
      setState(() {
        _activeStrumString = s;
        _activeStrumFret = f;
      });
      final note = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
      audio.playGuitarAsset(note.audioAsset);
      step++;
    }

    playStep();
    _strumTimer = Timer.periodic(
      Duration(milliseconds: isBallad ? 210 : 115),
      (_) => playStep(),
    );
  }

  void _awardThreeStarsForCurrentWorkout(GuitarWorkoutExercise workout) {
    final currentMap = ref.read(guitarWorkoutStarsProvider);
    final prevStars = currentMap[workout.id] ?? 0;
    if (prevStars < 3) {
      final updated = {
        ...currentMap,
        workout.id: 3,
      };
      ref.read(guitarWorkoutStarsProvider.notifier).state = updated;
      unawaited(persistGuitarWorkoutStarsPreference(updated));
    }
  }

  /// So dây chuẩn 6 dây (Dây 6 E2 -> Dây 1 e4) có chế độ lặp tự động để vặn khóa đàn.
  void _tapTunerOpenString(int stringNumber, {bool toggleLoop = false}) {
    _tunerLoopTimer?.cancel();
    final info = GuitarFretboardData.noteAt(stringNumber: stringNumber, fret: 0);
    final audio = ref.read(audioServiceProvider);
    if (toggleLoop && _loopingTunerString == stringNumber) {
      setState(() => _loopingTunerString = null);
      return;
    }
    setState(() {
      _activeString = stringNumber;
      _activeFret = 0;
      if (toggleLoop) {
        _loopingTunerString = stringNumber;
      }
    });
    audio.playGuitarAsset(info.audioAsset);
    if (_loopingTunerString == stringNumber) {
      _tunerLoopTimer = Timer.periodic(
        const Duration(milliseconds: 1400),
        (_) {
          if (!mounted || _loopingTunerString != stringNumber) {
            _tunerLoopTimer?.cancel();
            return;
          }
          audio.playGuitarAsset(info.audioAsset);
        },
      );
    }
  }

  /// Chạy tự động Vòng Hợp Âm thực tế (Canon, Ballad, Bolero, Rock Power Chords) để luyện chuyển tay.
  void _toggleChordProgressionLoop(String progId, List<String> chordIds) {
    _progLoopTimer?.cancel();
    _strumTimer?.cancel();
    if (_activeProgressionId == progId) {
      setState(() {
        _activeProgressionId = null;
        _activeProgressionStep = 0;
      });
      return;
    }
    setState(() {
      _selectedChordCategory = 'all';
      _activeProgressionId = progId;
      _activeProgressionStep = 0;
      _selectedChordId = chordIds.first;
    });
    final firstChord = GuitarFretboardData.commonChords.firstWhere(
      (c) => c.id == chordIds.first,
      orElse: () => GuitarFretboardData.commonChords.first,
    );
    _playChordRealVoicing(firstChord);

    _progLoopTimer = Timer.periodic(
      const Duration(milliseconds: 1450),
      (_) {
        if (!mounted || _activeProgressionId != progId) {
          _progLoopTimer?.cancel();
          return;
        }
        final nextStep = (_activeProgressionStep + 1) % chordIds.length;
        final nextId = chordIds[nextStep];
        final nextChord = GuitarFretboardData.commonChords.firstWhere(
          (c) => c.id == nextId,
          orElse: () => GuitarFretboardData.commonChords.first,
        );
        setState(() {
          _activeProgressionStep = nextStep;
          _selectedChordId = nextId;
        });
        _playChordRealVoicing(nextChord);
      },
    );
  }

  /// Chạy nghe mẫu toàn bộ các nốt trong Âm giai (Scale Run) trên cần đàn.
  void _toggleScaleRunPreview(Set<String> pitchSet, String rootPitch) {
    _scaleRunTimer?.cancel();
    if (_isScaleRunPlaying) {
      setState(() {
        _isScaleRunPlaying = false;
        _activeScaleRunString = null;
        _activeScaleRunFret = null;
      });
      return;
    }
    final sequence = <(int stringNum, int fretNum, String asset)>[];
    for (int s = 6; s >= 1; s--) {
      for (int f = 0; f <= 8; f++) {
        final n = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
        if (pitchSet.contains(n.noteCode)) {
          sequence.add((s, f, n.audioAsset));
          if (sequence.length >= 12) break;
        }
      }
      if (sequence.length >= 12) break;
    }
    if (sequence.isEmpty) return;

    int idx = 0;
    final audio = ref.read(audioServiceProvider);
    void playScaleStep() {
      if (!mounted || idx >= sequence.length) {
        _scaleRunTimer?.cancel();
        if (mounted) {
          setState(() {
            _isScaleRunPlaying = false;
            _activeScaleRunString = null;
            _activeScaleRunFret = null;
          });
        }
        return;
      }
      final step = sequence[idx];
      setState(() {
        _isScaleRunPlaying = true;
        _activeScaleRunString = step.$1;
        _activeScaleRunFret = step.$2;
      });
      audio.playGuitarAsset(step.$3);
      idx++;
    }

    playScaleStep();
    _scaleRunTimer = Timer.periodic(
      const Duration(milliseconds: 340),
      (_) => playScaleStep(),
    );
  }

  /// Chế độ Nhạc Nền Đệm Tập (Backing Track Jam Loop): Phát vòng hòa âm nền để người học tự do gảy Solo trên Bản đồ Scale!
  void _toggleBackingTrackJam(String jamId, List<String> chordAssets, String targetScaleId) {
    _jamLoopTimer?.cancel();
    if (_activeJamTrackId == jamId) {
      setState(() {
        _activeJamTrackId = null;
        _activeJamStep = 0;
      });
      return;
    }
    setState(() {
      _activeJamTrackId = jamId;
      _activeJamStep = 0;
      _selectedScaleId = targetScaleId;
    });
    final audio = ref.read(audioServiceProvider);
    audio.playGuitarAsset(chordAssets.first);
    _jamLoopTimer = Timer.periodic(
      const Duration(milliseconds: 1650),
      (_) {
        if (!mounted || _activeJamTrackId != jamId) {
          _jamLoopTimer?.cancel();
          return;
        }
        final nextIdx = (_activeJamStep + 1) % chordAssets.length;
        setState(() => _activeJamStep = nextIdx);
        audio.playGuitarAsset(chordAssets[nextIdx]);
      },
    );
  }

  void _toggleSpiderExercise() {
    if (_isSpiderPlaying) {
      _spiderTimer?.cancel();
      setState(() => _isSpiderPlaying = false);
      return;
    }
    setState(() {
      _isSpiderPlaying = true;
      _spiderStep = 0;
    });
    _playCurrentSpiderStep();
    _spiderTimer = Timer.periodic(
      Duration(milliseconds: _spiderStepIntervalMs),
      (_) {
        if (!mounted) return;
        final workout =
            GuitarFretboardData.fingerWorkouts[_selectedWorkoutIndex];
        final nextStep = (_spiderStep + 1) % workout.steps.length;
        if (nextStep == workout.steps.length - 1) {
          _awardThreeStarsForCurrentWorkout(workout);
        }
        setState(() {
          _spiderStep = nextStep;
        });
        _playCurrentSpiderStep();
      },
    );
  }

  void _stepWorkoutManually(int delta) {
    _spiderTimer?.cancel();
    final workout = GuitarFretboardData.fingerWorkouts[_selectedWorkoutIndex];
    final nextStep =
        (_spiderStep + delta + workout.steps.length) % workout.steps.length;
    if (nextStep == workout.steps.length - 1) {
      _awardThreeStarsForCurrentWorkout(workout);
    }
    setState(() {
      _isSpiderPlaying = false;
      _spiderStep = nextStep;
    });
    _playCurrentSpiderStep();
  }

  void _playCurrentSpiderStep() {
    final workout = GuitarFretboardData.fingerWorkouts[_selectedWorkoutIndex];
    final step = workout.steps[_spiderStep % workout.steps.length];
    final note = GuitarFretboardData.noteAt(
      stringNumber: step.$1,
      fret: step.$2,
    );
    ref.read(audioServiceProvider).playGuitarAsset(note.audioAsset);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final audioService = ref.watch(audioServiceProvider);
    final adState = ref.watch(rewardedAdProvider);
    final proUnlocked = ref.watch(guitarProUnlockedProvider);
    final guitarType = ref.watch(selectedGuitarTypeProvider);
    final isElectric = guitarType == 'electric';
    final accentColor =
        isElectric ? const Color(0xFF6366F1) : const Color(0xFFD97706);
    final isEn = ref.watch(appSettingsProvider).isEnglish;
    final isWorkoutPage = widget.isWorkoutOnlyPage;

    // Đồng bộ âm sắc Guitar trong AudioService
    audioService.setGuitarType(guitarType);

    return Scaffold(
      key: const Key('guitar_studio_sheet'),
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('btn_close_guitar_studio'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isWorkoutPage
              ? (isEn
                  ? 'Guitar Workouts, Licks & Tab (Lv.1–5)'
                  : 'Luyện Ngón, Mẫu Chạy & Đọc Tab (Lv.1–5)')
              : (isEn
                  ? 'Guitar Fretboard, 44 Chords & Scales'
                  : 'Bản Đồ Cần Đàn, 44 Hợp Âm & Scale'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            // Thanh chuyển nhanh chế độ: Guitar Thùng (Acoustic) <-> Guitar Điện (Electric)
            GuitarTypeSwitchBar(
              onChanged: (type) {
                if (!mounted) return;
                if (_selectedTab == 1 && type == 'electric' && _selectedChordCategory == 'all') {
                  setState(() => _selectedChordId = 'E5');
                }
              },
            ),
            const SizedBox(height: 10),

            if (!isWorkoutPage) ...[
              // 4 Phân khu trên Trang Bản Đồ Cần Đàn (Map Cần | 44 Hợp Âm | Bản đồ Scale | Bản nhạc & Capo)
              Row(
                children: [
                  for (final (posIdx, idx, label, icon) in [
                    (0, 0, isEn ? 'Fretboard' : 'Map Cần đàn', Icons.grid_on_rounded),
                    (
                      1,
                      1,
                      isEn ? 'Chords (44)' : 'Hợp âm (44)',
                      Icons.pan_tool_alt_rounded
                    ),
                    (2, 2, isEn ? 'Scales (7)' : 'Bản đồ Scale', Icons.timeline_rounded),
                    (
                      3,
                      4,
                      isEn ? 'Songs & Capo' : 'Bản nhạc & Capo',
                      Icons.queue_music_rounded
                    ),
                  ]) ...[
                    if (posIdx > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Material(
                        color: _selectedTab == idx
                            ? accentColor
                            : (isDark
                                ? AppColors.surfaceDark
                                : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          key: Key('chip_guitar_tab_$idx'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            _stopAllAuxiliaryTimers();
                            setState(() {
                              _isSpiderPlaying = false;
                              _isScaleRunPlaying = false;
                              _loopingTunerString = null;
                              _activeProgressionId = null;
                              _activeStrumString = null;
                              _activeStrumFret = null;
                              _activeScaleRunString = null;
                              _activeScaleRunFret = null;
                              _selectedTab = idx;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedTab == idx
                                    ? accentColor
                                    : (isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icon,
                                  size: 18,
                                  color: _selectedTab == idx
                                      ? Colors.white
                                      : accentColor,
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _selectedTab == idx
                                          ? Colors.white
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],

            if (isWorkoutPage || _selectedTab == 3)
              _buildTabAndSpiderExerciseTab(context, audioService, isDark, isEn, accentColor)
            else if (_selectedTab == 0)
              _buildFretboardMapTab(audioService, isDark, isEn)
            else if (_selectedTab == 1)
              _buildChordShapesTab(audioService, isDark, isEn)
            else if (_selectedTab == 4)
              const InteractiveSongbookAndTheoryTab()
            else
              _buildScaleMapTab(
                context,
                audioService,
                adState,
                proUnlocked,
                isDark,
                isEn,
              ),
          ],
        ),
      ),
    );
  }

  /// TAB 1: Bản đồ Cần đàn (Fretboard Map) & Mẹo nhớ nhanh nốt trên 6 dây
  Widget _buildFretboardMapTab(dynamic audioService, bool isDark, bool isEn) {
    final activeInfo = GuitarFretboardData.noteAt(
      stringNumber: _activeString,
      fret: _activeFret,
    );
    final octaveTargetString =
        _activeString >= 3 ? _activeString - 2 : null;
    final octaveTargetFret = octaveTargetString != null
        ? _activeFret + ((_activeString == 4 || _activeString == 3) ? 3 : 2)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.touch_app_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEn
                      ? 'Selected: String $_activeString • Fret $_activeFret = ${activeInfo.fullLabel}'
                      : 'Đang chọn: Dây $_activeString • Ngăn $_activeFret = ${activeInfo.fullLabel}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () =>
                    audioService.playGuitarAsset(activeInfo.audioAsset),
                icon: const Icon(Icons.volume_up_rounded, size: 15),
                label: Text(
                  isEn ? 'Play' : 'Nghe nốt',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Bộ So Dây Đàn 6 Dây Chuẩn (6E - 5A - 4D - 3G - 2B - 1e) kèm chế độ Lặp để vặn khóa đàn
        Container(
          key: const Key('guitar_standard_tuner_bar'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: 15,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(width: 5),
                Text(
                  isEn ? 'Tune:' : 'So dây:',
                  style: const TextStyle(
                    fontSize: 11.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                for (final (sNum, sLbl, hzLbl) in const [
                  (6, '6E', '82.4Hz'),
                  (5, '5A', '110Hz'),
                  (4, '4D', '146.8Hz'),
                  (3, '3G', '196Hz'),
                  (2, '2B', '246.9Hz'),
                  (1, '1e', '329.6Hz'),
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: InkWell(
                      key: Key('btn_tuner_string_$sNum'),
                      borderRadius: BorderRadius.circular(7),
                      onTap: () => _tapTunerOpenString(sNum),
                      onLongPress: () =>
                          _tapTunerOpenString(sNum, toggleLoop: true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _loopingTunerString == sNum
                              ? AppColors.correct
                              : (_activeString == sNum && _activeFret == 0
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFFD97706).withOpacity(0.12)),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sLbl,
                              style: TextStyle(
                                fontSize: 10.8,
                                fontWeight: FontWeight.w900,
                                color: (_loopingTunerString == sNum ||
                                        (_activeString == sNum &&
                                            _activeFret == 0))
                                    ? Colors.white
                                    : const Color(0xFFD97706),
                              ),
                            ),
                            Text(
                              hzLbl,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: (_loopingTunerString == sNum ||
                                        (_activeString == sNum &&
                                            _activeFret == 0))
                                    ? Colors.white.withOpacity(0.9)
                                    : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                InkWell(
                  key: const Key('btn_tuner_toggle_loop'),
                  borderRadius: BorderRadius.circular(7),
                  onTap: () => _tapTunerOpenString(
                    _activeString,
                    toggleLoop: true,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _loopingTunerString != null
                          ? AppColors.correct
                          : AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          size: 13,
                          color: _loopingTunerString != null
                              ? Colors.white
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _loopingTunerString != null
                              ? (isEn ? 'Looping' : 'Đang lặp')
                              : (isEn ? 'Loop' : 'Lặp'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: _loopingTunerString != null
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        ChromaticCentsTunerChallengeCard(
          activeStringNumber: _activeString,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            FilterChip(
              visualDensity: VisualDensity.compact,
              label: Text(
                isEn ? '7 Natural Notes (C–B)' : '7 nốt tự nhiên (Đô–Si)',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              selected: _showNaturalNotesOnly,
              onSelected: (v) => setState(() => _showNaturalNotesOnly = v),
            ),
            FilterChip(
              visualDensity: VisualDensity.compact,
              label: Text(
                isEn ? 'Octave Jump Guide' : 'Mẹo Quãng 8 chéo',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              selected: _showOctaveJumpGuide,
              onSelected: (v) => setState(() => _showOctaveJumpGuide = v),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InteractiveGuitarFretboard(
          maxFrets: 12,
          activeString: _activeString,
          activeFret: _activeFret,
          secondaryString:
              (_showOctaveJumpGuide && octaveTargetFret != null && octaveTargetFret <= 12)
                  ? octaveTargetString
                  : null,
          secondaryFret:
              (_showOctaveJumpGuide && octaveTargetFret != null && octaveTargetFret <= 12)
                  ? octaveTargetFret
                  : null,
          showAllNotes: true,
          naturalOnly: _showNaturalNotesOnly,
          onTapFret: (s, f) {
            _tunerLoopTimer?.cancel();
            setState(() {
              _loopingTunerString = null;
              _activeString = s;
              _activeFret = f;
            });
            final info = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
            audioService.playGuitarAsset(info.audioAsset);
          },
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Text(
            isEn
                ? '• 6 Open Strings: E2–A2–D3–G3–B3–E4 • Anchors: S6F3=G, S6F5=A, S5F3=C • Octave Jump: Down 2 strings + 2 frets (+3 across S2).'
                : '• 6 Dây buông: E–A–D–G–B–e • Mốc chuẩn: Dây 6 Ngăn 3 = Sol, Ngăn 5 = La, Dây 5 Ngăn 3 = Đô • Quãng 8 chéo: Xuống 2 dây + tiến 2 ngăn.',
            style: const TextStyle(fontSize: 11.4, height: 1.35, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  /// TAB 2: Thư viện 44 Hợp âm Guitar thực tế (Phân theo 5 nhóm: Mở, Chặn Barre, Hợp âm 7, Hợp âm Màu & Hợp âm 5 Power Chords)
  Widget _buildChordShapesTab(dynamic audioService, bool isDark, bool isEn) {
    final categories = [
      ('all', isEn ? 'All (44)' : 'Tất cả (44)'),
      ('open', isEn ? 'Open (8)' : 'Hợp âm Mở (8)'),
      ('power', isEn ? 'Power 5th (8)' : 'Hợp âm 5 Điện (8)'),
      ('barre', isEn ? 'Barre (8)' : 'Hợp âm Chặn (8)'),
      ('seventh', isEn ? '7th (12)' : 'Hợp âm Bảy (12)'),
      ('color', isEn ? 'Color (8)' : 'Hợp âm Màu (8)'),
    ];
    final filteredChords = _selectedChordCategory == 'all'
        ? GuitarFretboardData.commonChords
        : GuitarFretboardData.commonChords
            .where((c) => c.category == _selectedChordCategory)
            .toList();
    final chord = filteredChords.firstWhere(
      (c) => c.id == _selectedChordId,
      orElse: () => filteredChords.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bộ lọc 5 nhóm hợp âm (Mở, Hợp âm 5 Power, Chặn, Hợp âm 7, Hợp âm Màu)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < categories.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                ChoiceChip(
                  key: Key('chip_chord_cat_${categories[i].$1}'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(
                    categories[i].$2,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  selected: _selectedChordCategory == categories[i].$1,
                  onSelected: (_) {
                    _strumTimer?.cancel();
                    _progLoopTimer?.cancel();
                    final nextList = categories[i].$1 == 'all'
                        ? GuitarFretboardData.commonChords
                        : GuitarFretboardData.commonChords
                            .where((c) => c.category == categories[i].$1)
                            .toList();
                    setState(() {
                      _activeProgressionId = null;
                      _selectedChordCategory = categories[i].$1;
                      _selectedChordId = nextList.first.id;
                      _activeStrumString = null;
                      _activeStrumFret = null;
                    });
                    _playChordRealVoicing(nextList.first);
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Thanh trượt ngang chọn hợp âm thông minh (1 hàng gọn gàng để Cần đàn luôn hiển thị ngay trên màn hình)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < filteredChords.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                ChoiceChip(
                  key: Key('chip_guitar_chord_${filteredChords[i].id}'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(
                    filteredChords[i].id,
                    style: const TextStyle(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  selected: chord.id == filteredChords[i].id,
                  onSelected: (_) {
                    final c = filteredChords[i];
                    _strumTimer?.cancel();
                    _progLoopTimer?.cancel();
                    setState(() {
                      _activeProgressionId = null;
                      _selectedChordId = c.id;
                      _activeStrumString = null;
                      _activeStrumFret = null;
                    });
                    _playChordRealVoicing(c);
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Thanh luyện chuyển Vòng Hợp Âm tự động (Canon, Ballad, Bolero, Rock Power Chords)
        Container(
          key: const Key('guitar_chord_progression_bar'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(
                  Icons.autorenew_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  isEn ? 'Loop:' : 'Vòng:',
                  style: const TextStyle(
                    fontSize: 11.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                for (final (pId, pLbl, pChords) in const [
                  ('canon', 'Canon (C–G–Am–F)', ['C', 'G', 'Am', 'F']),
                  ('ballad', 'Ballad (Am–F–C–G)', ['Am', 'F', 'C', 'G']),
                  ('bolero', 'Bolero (Am–Dm–E7–Am)', ['Am', 'Dm', 'E7', 'Am']),
                  ('rock5', 'Rock 5 (E5–G5–A5–C5)', ['E5', 'G5', 'A5', 'C5']),
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      key: Key('btn_chord_prog_$pId'),
                      borderRadius: BorderRadius.circular(7),
                      onTap: () => _toggleChordProgressionLoop(pId, pChords),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _activeProgressionId == pId
                              ? AppColors.correct
                              : AppColors.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _activeProgressionId == pId
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              size: 13,
                              color: _activeProgressionId == pId
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              pLbl,
                              style: TextStyle(
                                fontSize: 10.8,
                                fontWeight: FontWeight.w800,
                                color: _activeProgressionId == pId
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chord.name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          isEn
                              ? 'Voicing (S6 → S1): ${chord.formula}'
                              : 'Thế bấm (Dây 6 → Dây 1): ${chord.formula}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _playChordRealVoicing(chord),
                    icon: const Icon(Icons.volume_up_rounded, size: 15),
                    label: Text(isEn ? 'Play' : 'Gảy hợp âm'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('btn_guitar_chord_strum'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _startChordStrum(chord, isBallad: false),
                      icon: const Icon(Icons.south_rounded, size: 14),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn
                              ? 'Strum (Bass → S1)'
                              : 'Rải từ Bass xuống (Strum)',
                          style: const TextStyle(
                            fontSize: 11.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('btn_guitar_chord_ballad_arpeggio'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _startChordStrum(chord, isBallad: true),
                      icon: const Icon(Icons.waves_rounded, size: 14),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn
                              ? 'Ballad (Bass-3-2-3-1-3-2-3)'
                              : 'Rải Ballad (Bass-3-2-3-1-3-2-3)',
                          style: const TextStyle(
                            fontSize: 11.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                chord.tip,
                style: TextStyle(
                  fontSize: 11.2,
                  height: 1.32,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        InteractiveGuitarFretboard(
          maxFrets: chord.maxFret > 5 ? chord.maxFret : 5,
          chordShape: chord,
          activeString: _activeStrumString,
          activeFret: _activeStrumFret,
          onTapFret: (s, f) {
            final info = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
            audioService.playGuitarAsset(info.audioAsset);
          },
        ),
      ],
    );
  }

  /// TAB 3: Bản đồ 7 Âm giai (Scale Map - Pentatonic, Blues, Trưởng/Thứ & Hài hòa)
  Widget _buildScaleMapTab(
    BuildContext context,
    dynamic audioService,
    RewardedAdState adState,
    bool proUnlocked,
    bool isDark,
    bool isEn,
  ) {
    const scales = [
      (
        'am_pentatonic',
        'Am Pentatonic',
        false,
        {'A', 'C', 'D', 'E', 'G'},
        'A',
        'Scale phổ biến số 1 để chạy ngón Solo & ngẫu hứng (gồm 5 nốt: La – Đô – Rê – Mi – Sol). Chấm Đỏ là nốt chủ âm (Root A).'
      ),
      (
        'a_blues',
        'A Blues (6 nốt)',
        false,
        {'A', 'C', 'D', 'D#', 'E', 'G'},
        'A',
        'Âm giai La Thứ Blues (thêm nốt Blue Note Rê# D#) tạo chất lửa đặc trưng cho Guitar Điện & Acoustic Blues.'
      ),
      (
        'c_major',
        'Đô Trưởng (C)',
        false,
        {'C', 'D', 'E', 'F', 'G', 'A', 'B'},
        'C',
        'Âm giai 7 nốt tự nhiên (Đô–Rê–Mi–Fa–Sol–La–Si), nền tảng để dò giai điệu bài hát và đệm câu lót (Intro/Outro).'
      ),
      (
        'em_pentatonic',
        'Em Pentatonic',
        false,
        {'E', 'G', 'A', 'B', 'D'},
        'E',
        'Ngũ cung Mi Thứ (Mi – Sol – La – Si – Rê) tận dụng toàn bộ các dây buông trên cần đàn Guitar.'
      ),
      (
        'g_major',
        'Sol Trưởng (G)',
        false,
        {'G', 'A', 'B', 'C', 'D', 'E', 'F#'},
        'G',
        'Âm giai Sol Trưởng (có 1 dấu thăng Fa#), song song với giọng Mi Thứ (Em).'
      ),
      (
        'dm_pentatonic',
        'Dm Pentatonic',
        false,
        {'D', 'F', 'G', 'A', 'C'},
        'D',
        'Ngũ cung Rê Thứ (Rê – Fa – Sol – La – Đô) rất hợp cho các bản Ballad trầm buồn và Bolero.'
      ),
      (
        'a_harmonic_minor',
        'La Thứ Hài Hòa (${RewardedAdState.kGuitarProScaleGemCost} Gem)',
        true,
        {'A', 'B', 'C', 'D', 'E', 'F', 'G#'},
        'A',
        'Âm giai La Thứ Hài Hòa (nâng bậc 7 lên Sol# G#) tạo màu sắc cổ điển, Neo-Classical & Flamenco cuốn hút trên 12 ngăn.'
      ),
    ];

    final currentScale =
        scales.firstWhere((s) => s.$1 == _selectedScaleId, orElse: () => scales.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thanh trượt ngang 7 Âm giai gọn trên 1 dòng
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < scales.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                ChoiceChip(
                  key: Key('chip_guitar_scale_${scales[i].$1}'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (scales[i].$3 && !proUnlocked) ...[
                        const SolfaGemIcon(size: 12),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        scales[i].$2,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  selected: _selectedScaleId == scales[i].$1,
                  onSelected: (_) async {
                    final sc = scales[i];
                    if (sc.$3 && !proUnlocked) {
                      final ok = await ref
                          .read(rewardedAdProvider.notifier)
                          .spendGemsForOneHourSession(
                            gemCost: RewardedAdState.kGuitarProScaleGemCost,
                          );
                      if (!ok) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Cần ${RewardedAdState.kGuitarProScaleGemCost} Gem để mở khóa vĩnh viễn Full Map Scale 12 ngăn. Hãy xem video ngắn để nhận ngay +100 Gem miễn phí nhé!',
                              ),
                              action: SnackBarAction(
                                label: 'Nhận +100 Gem',
                                onPressed: () {
                                  showRewardedVideoAdSimulationDialog(
                                    context,
                                    ref,
                                  );
                                },
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      ref.read(guitarProUnlockedProvider.notifier).state = true;
                      unawaited(persistGuitarProUnlockedPreference(true));
                    }
                    _scaleRunTimer?.cancel();
                    setState(() {
                      _isScaleRunPlaying = false;
                      _activeScaleRunString = null;
                      _activeScaleRunFret = null;
                      _selectedScaleId = sc.$1;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
        if (!proUnlocked) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.35),
              ),
            ),
            child: Row(
              children: [
                const SolfaGemIcon(size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isEn
                        ? 'Watch short ads for +100 Gems & unlock Pro Scales (${RewardedAdState.kGuitarProScaleGemCost} Gems)!'
                        : 'Mở khóa Scale VIP (${RewardedAdState.kGuitarProScaleGemCost} Gem): Xem video ngắn nhận +100 Gem!',
                    style: const TextStyle(
                      fontSize: 11.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const Key('btn_guitar_watch_ad_gems'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () async {
                    await showRewardedVideoAdSimulationDialog(context, ref);
                    if (mounted &&
                        ref.read(rewardedAdProvider).prestigePoints >=
                            RewardedAdState.kGuitarProScaleGemCost) {
                      final ok = await ref
                          .read(rewardedAdProvider.notifier)
                          .spendGemsForOneHourSession(
                            gemCost: RewardedAdState.kGuitarProScaleGemCost,
                          );
                      if (ok && mounted) {
                        ref.read(guitarProUnlockedProvider.notifier).state =
                            true;
                        unawaited(persistGuitarProUnlockedPreference(true));
                      }
                    }
                  },
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 14),
                  label: const Text(
                    '+100 Gem',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        InteractiveGuitarFretboard(
          maxFrets: 12,
          activeString: _activeScaleRunString,
          activeFret: _activeScaleRunFret,
          scalePitchSet: currentScale.$4,
          scaleRootPitch: currentScale.$5,
          onTapFret: (s, f) {
            final info = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
            audioService.playGuitarAsset(info.audioAsset);
          },
        ),
        const SizedBox(height: 6),
        // Thanh Nhạc Nền Đệm Tập (Backing Track Jam Loop: Bật hòa âm nền để gảy Solo tự do trên cần đàn!)
        Container(
          key: const Key('guitar_backing_track_jam_bar'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(
                  Icons.album_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  isEn ? 'Backing Jam:' : 'Nhạc nền Jam:',
                  style: const TextStyle(
                    fontSize: 11.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                for (final (jId, jLbl, jScale, jChords) in const [
                  (
                    'jam_am',
                    'Am Ballad (Am–F–C–G)',
                    'am_pentatonic',
                    [
                      'assets/audio/keys/chord_a_min.wav',
                      'assets/audio/keys/chord_f_maj.wav',
                      'assets/audio/keys/chord_c_maj.wav',
                      'assets/audio/keys/chord_g_maj.wav',
                    ]
                  ),
                  (
                    'jam_blues',
                    'A Blues Rock (A5–D5–E5)',
                    'a_blues',
                    [
                      'assets/audio/keys/chord_a5.wav',
                      'assets/audio/keys/chord_d5.wav',
                      'assets/audio/keys/chord_a5.wav',
                      'assets/audio/keys/chord_e5.wav',
                    ]
                  ),
                  (
                    'jam_cpop',
                    'C Canon Pop (C–G–Am–F)',
                    'c_major',
                    [
                      'assets/audio/keys/chord_c_maj.wav',
                      'assets/audio/keys/chord_g_maj.wav',
                      'assets/audio/keys/chord_a_min.wav',
                      'assets/audio/keys/chord_f_maj.wav',
                    ]
                  ),
                  (
                    'jam_em',
                    'Em Acoustic (Em–C–G–D)',
                    'em_pentatonic',
                    [
                      'assets/audio/keys/chord_e_min.wav',
                      'assets/audio/keys/chord_c_maj.wav',
                      'assets/audio/keys/chord_g_maj.wav',
                      'assets/audio/keys/chord_d_maj.wav',
                    ]
                  ),
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      key: Key('btn_backing_jam_$jId'),
                      borderRadius: BorderRadius.circular(7),
                      onTap: () =>
                          _toggleBackingTrackJam(jId, jChords, jScale),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _activeJamTrackId == jId
                              ? AppColors.correct
                              : AppColors.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _activeJamTrackId == jId
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              size: 13,
                              color: _activeJamTrackId == jId
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              jLbl,
                              style: TextStyle(
                                fontSize: 10.8,
                                fontWeight: FontWeight.w800,
                                color: _activeJamTrackId == jId
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  currentScale.$6,
                  style: const TextStyle(fontSize: 11.4, height: 1.35),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                key: const Key('btn_play_guitar_scale_run'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isScaleRunPlaying
                      ? AppColors.wrong
                      : AppColors.primary,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _toggleScaleRunPreview(
                  currentScale.$4,
                  currentScale.$5,
                ),
                icon: Icon(
                  _isScaleRunPlaying
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  size: 16,
                ),
                label: Text(
                  _isScaleRunPlaying
                      ? (isEn ? 'Stop' : 'Dừng')
                      : (isEn ? 'Play Scale' : 'Chạy Scale'),
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// TAB 4 (Trang riêng biệt): Lộ Trình 5 Cấp Độ Tinh Gọn Trên 1 Màn Hình (12 Bài Luyện Ngón, Fingerstyle, Vòng Hợp Âm & Riff/Solo)
  Widget _buildTabAndSpiderExerciseTab(
    BuildContext context,
    dynamic audioService,
    bool isDark,
    bool isEn,
    Color accentColor,
  ) {
    const allWorkouts = GuitarFretboardData.fingerWorkouts;
    final starsMap = ref.watch(guitarWorkoutStarsProvider);
    final totalStars = starsMap.values.fold<int>(0, (sum, v) => sum + v);
    final maxPossibleStars = allWorkouts.length * 3;

    final filteredIndices = <int>[];
    for (int i = 0; i < allWorkouts.length; i++) {
      if (_workoutStyleFilter == 'all' ||
          allWorkouts[i].guitarStyle == _workoutStyleFilter) {
        filteredIndices.add(i);
      }
    }
    if (!filteredIndices.contains(_selectedWorkoutIndex) &&
        filteredIndices.isNotEmpty) {
      _selectedWorkoutIndex = filteredIndices.first;
    }

    final currentWorkout =
        allWorkouts[_selectedWorkoutIndex % allWorkouts.length];
    final currentStepIndex = _spiderStep % currentWorkout.steps.length;
    final currentStepTuple = currentWorkout.steps[currentStepIndex];
    final activeString = currentStepTuple.$1;
    final activeFret = currentStepTuple.$2;
    final activeFingerText = currentStepTuple.$3;
    final activeNote = GuitarFretboardData.noteAt(
      stringNumber: activeString,
      fret: activeFret,
    );
    final currentWorkoutStars = starsMap[currentWorkout.id] ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Thanh gộp thông minh: Bộ lọc (Tất cả 12 / Thùng / Điện) + Tổng Sao (★) + Nút +100 Gem trên cùng 1 hàng
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (code, lbl) in [
                ('all', isEn ? 'All (12)' : 'Tất cả (12)'),
                ('acoustic', isEn ? 'Acoustic (6)' : 'Đàn Thùng (6)'),
                ('electric', isEn ? 'Electric (6)' : 'Đàn Điện (6)'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: Key('chip_workout_filter_$code'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(
                      lbl,
                      style: const TextStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: _workoutStyleFilter == code,
                    onSelected: (_) {
                      _spiderTimer?.cancel();
                      setState(() {
                        _isSpiderPlaying = false;
                        _workoutStyleFilter = code;
                        _spiderStep = 0;
                        if (code == 'acoustic') {
                          ref.read(selectedGuitarTypeProvider.notifier).state =
                              'acoustic';
                          audioService.setGuitarType('acoustic');
                          unawaited(persistGuitarTypePreference('acoustic'));
                        } else if (code == 'electric') {
                          ref.read(selectedGuitarTypeProvider.notifier).state =
                              'electric';
                          audioService.setGuitarType('electric');
                          unawaited(persistGuitarTypePreference('electric'));
                        }
                      });
                    },
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '★ $totalStars/$maxPossibleStars',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                key: const Key('btn_workout_watch_ad_gems'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: accentColor.withOpacity(0.14),
                ),
                onPressed: () {
                  showRewardedVideoAdSimulationDialog(context, ref);
                },
                icon: const SolfaGemIcon(size: 12),
                label: const Text(
                  '+100 Gem',
                  style: TextStyle(fontSize: 10.8, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // 2. Thanh trượt ngang chọn bài tập (Carousel 1 hàng gọn gàng giúp Khuông Tab & Cần đàn hiển thị ngay trước mắt!)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int cellPos = 0;
                  cellPos < filteredIndices.length;
                  cellPos++) ...[
                if (cellPos > 0) const SizedBox(width: 6),
                Builder(
                  builder: (_) {
                    final idx = filteredIndices[cellPos];
                    final w = allWorkouts[idx];
                    final selected = _selectedWorkoutIndex == idx;
                    final isElWorkout = w.guitarStyle == 'electric';
                    final cardColor = isElWorkout
                        ? const Color(0xFF6366F1)
                        : const Color(0xFFD97706);
                    final wStars = starsMap[w.id] ?? 1;
                    return Material(
                      color: selected
                          ? cardColor
                          : (isDark ? AppColors.surfaceDark : Colors.white),
                      borderRadius: BorderRadius.circular(11),
                      child: InkWell(
                        key: Key('card_guitar_workout_${w.id}'),
                        borderRadius: BorderRadius.circular(11),
                        onTap: () {
                          _spiderTimer?.cancel();
                          setState(() {
                            _isSpiderPlaying = false;
                            _selectedWorkoutIndex = idx;
                            _spiderStep = 0;
                          });
                          ref
                              .read(selectedGuitarTypeProvider.notifier)
                              .state = w.guitarStyle;
                          audioService.setGuitarType(w.guitarStyle);
                          unawaited(persistGuitarTypePreference(w.guitarStyle));
                          _playCurrentSpiderStep();
                        },
                        child: Container(
                          width: 152,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: selected
                                  ? cardColor
                                  : (isDark
                                      ? AppColors.borderDark
                                      : AppColors.borderLight),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.white.withOpacity(0.24)
                                          : cardColor.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Lv.${w.levelNumber}',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: selected
                                            ? Colors.white
                                            : cardColor,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '★' * wStars,
                                    style: TextStyle(
                                      fontSize: 9.8,
                                      color: selected
                                          ? const Color(0xFFFDE047)
                                          : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                w.title.replaceFirst(
                                  RegExp(r'^Bài \d+:\s*'),
                                  '',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? Colors.white : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 3. Bảng điều khiển bài tập + Thanh Tiến Độ Nốt 1–8 Trực Quan
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: accentColor.withOpacity(0.24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      currentWorkout.levelTag,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      currentWorkout.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '★' * currentWorkoutStars +
                        '☆' * (3 - currentWorkoutStars),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                currentWorkout.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.2, height: 1.32),
              ),
              const SizedBox(height: 8),

              // Thanh Tiến Độ Nốt Trực Quan & Đếm Nhịp 1–8 (Bấm trực tiếp vào từng phách để nghe & xem thế tay)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(currentWorkout.steps.length, (sIdx) {
                    final st = currentWorkout.steps[sIdx];
                    final noteInfo = GuitarFretboardData.noteAt(
                      stringNumber: st.$1,
                      fret: st.$2,
                    );
                    final isCurrentBeat = sIdx == currentStepIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: InkWell(
                        key: Key('btn_workout_beat_$sIdx'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          _spiderTimer?.cancel();
                          setState(() {
                            _isSpiderPlaying = false;
                            _spiderStep = sIdx;
                          });
                          _playCurrentSpiderStep();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 42,
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrentBeat
                                ? AppColors.correct
                                : (isDark
                                    ? AppColors.surfaceDark
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCurrentBeat
                                  ? AppColors.correct
                                  : accentColor.withOpacity(0.35),
                              width: isCurrentBeat ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${sIdx + 1}',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: isCurrentBeat
                                      ? Colors.white
                                      : accentColor,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  noteInfo.vnLabel,
                                  style: TextStyle(
                                    fontSize: 10.2,
                                    fontWeight: FontWeight.w800,
                                    color: isCurrentBeat ? Colors.white : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 6),

              // Thanh điều khiển tốc độ & Chạy mẫu / Tập từng bước gọn gàng
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (ms, lbl) in [
                    (680, isEn ? 'Slow' : 'Chậm'),
                    (500, isEn ? 'Normal' : 'Vừa'),
                    (330, isEn ? 'Fast' : 'Nhanh'),
                  ])
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      label: Text(
                        lbl,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      selected: _spiderStepIntervalMs == ms,
                      onSelected: (_) {
                        setState(() => _spiderStepIntervalMs = ms);
                        if (_isSpiderPlaying) {
                          _spiderTimer?.cancel();
                          _isSpiderPlaying = false;
                          _toggleSpiderExercise();
                        }
                      },
                    ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(32, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _stepWorkoutManually(-1),
                    child: const Icon(Icons.skip_previous_rounded, size: 15),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(32, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _stepWorkoutManually(1),
                    child: const Icon(Icons.skip_next_rounded, size: 15),
                  ),
                  ElevatedButton.icon(
                    key: const Key('btn_toggle_spider_exercise'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isSpiderPlaying ? AppColors.wrong : accentColor,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _toggleSpiderExercise,
                    icon: Icon(
                      _isSpiderPlaying
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _isSpiderPlaying
                          ? (isEn ? 'Stop' : 'Dừng tập')
                          : (isEn ? 'Auto Play' : 'Chạy mẫu'),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Phách ${currentStepIndex + 1}/${currentWorkout.steps.length}: Dây $activeString • Ngăn $activeFret (${activeNote.fullLabel}) → $activeFingerText',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GuitarTabViewerWidget(
          activeStepIndex: currentStepIndex,
          isDark: isDark,
          customSteps: currentWorkout.steps
              .map((s) => (s.$1, s.$2))
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        InteractiveGuitarFretboard(
          maxFrets: currentWorkout.maxFret,
          activeString: activeString,
          activeFret: activeFret,
          showAllNotes: false,
          onTapFret: (s, f) {
            final info = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
            audioService.playGuitarAsset(info.audioAsset);
          },
        ),
      ],
    );
  }
}

/// Widget vẽ Cần đàn Guitar 6 dây x N ngăn tương tác trực tiếp (Hỗ trợ Map nốt, Hợp âm, Scale và Câu hỏi Quiz).
class InteractiveGuitarFretboard extends StatelessWidget {
  final int maxFrets;
  final int? activeString; // 1..6
  final int? activeFret; // 0..maxFrets
  final int? secondaryString;
  final int? secondaryFret;
  final bool hideActiveNoteName; // Khi dùng làm đề bài Quiz hỏi tên nốt
  final bool showAllNotes;
  final bool naturalOnly;
  final GuitarChordShape? chordShape;
  final Set<String>? scalePitchSet;
  final String? scaleRootPitch;
  final void Function(int stringNumber, int fret)? onTapFret;

  const InteractiveGuitarFretboard({
    super.key,
    this.maxFrets = 12,
    this.activeString,
    this.activeFret,
    this.secondaryString,
    this.secondaryFret,
    this.hideActiveNoteName = false,
    this.showAllNotes = false,
    this.naturalOnly = true,
    this.chordShape,
    this.scalePitchSet,
    this.scaleRootPitch,
    this.onTapFret,
  });

  @override
  Widget build(BuildContext context) {
    final cellWidth = maxFrets <= 5 ? 56.0 : 48.0;
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF78350F), width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hàng đánh số ngăn đàn (Ngăn 0..maxFrets)
                  Row(
                    children: [
                      const SizedBox(width: 48),
                      for (int f = 0; f <= maxFrets; f++)
                        SizedBox(
                          width: cellWidth,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const {3, 5, 7, 9, 12}.contains(f)
                                    ? const Color(0xFFF59E0B).withOpacity(0.25)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                f == 0 ? 'Buông' : 'Ng.$f',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: const {3, 5, 7, 9, 12}.contains(f)
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                  color: const {3, 5, 7, 9, 12}.contains(f)
                                      ? const Color(0xFFFBBF24)
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 6 Dây đàn (Dây 1 ở trên -> Dây 6 ở dưới)
                  for (int s = 1; s <= 6; s++)
                    Row(
                      children: [
                        SizedBox(
                          width: 48,
                          height: 30,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              GuitarFretboardData.stringLabels[s - 1],
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFDE68A),
                              ),
                            ),
                          ),
                        ),
                        for (int f = 0; f <= maxFrets; f++)
                          _buildFretCell(s, f, cellWidth),
                      ],
                    ),
                ],
              ),
            ),
            if (chordShape != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Chú giải: O = Dây buông • X = Bịt dây • Ngón 1: Trỏ • Ngón 2: Giữa • Ngón 3: Áp út • Ngón 4: Út',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFretCell(int stringNumber, int fret, double cellWidth) {
    final note = GuitarFretboardData.noteAt(
      stringNumber: stringNumber,
      fret: fret,
    );
    final isTarget = activeString == stringNumber && activeFret == fret;
    final isSecondary =
        secondaryString == stringNumber && secondaryFret == fret;

    // Kiểm tra thế bấm hợp âm nếu có
    int? chordFret;
    int? chordFinger;
    if (chordShape != null) {
      chordFret = chordShape!.fretsByString1To6[stringNumber - 1];
      chordFinger = chordShape!.fingersByString1To6[stringNumber - 1];
    }
    final isChordHit = chordShape != null && chordFret == fret && fret >= 0;
    final isChordMuted = chordShape != null && chordFret == -1 && fret == 0;

    // Kiểm tra Scale nếu có
    final isInScale =
        scalePitchSet != null && scalePitchSet!.contains(note.noteCode);
    final isScaleRoot = isInScale && scaleRootPitch == note.noteCode;

    final isNatural = !note.noteCode.contains('#');
    final shouldShowNoteBadge = isTarget ||
        isSecondary ||
        isChordHit ||
        isChordMuted ||
        isInScale ||
        (showAllNotes && (!naturalOnly || isNatural));

    Color badgeColor = const Color(0xFF334155);
    String badgeText = note.vnLabel;

    if (isTarget) {
      badgeColor = chordShape != null
          ? const Color(0xFFF59E0B)
          : const Color(0xFFEF4444);
      badgeText = hideActiveNoteName
          ? '?'
          : (chordShape != null ? '♪ ${note.vnLabel}' : note.vnLabel);
    } else if (isSecondary) {
      badgeColor = const Color(0xFFF59E0B);
      badgeText = '${note.vnLabel} (+8)';
    } else if (isChordMuted) {
      badgeColor = const Color(0xFF64748B);
      badgeText = 'X';
    } else if (isChordHit) {
      final isBarreFinger1 =
          chordShape?.category == 'barre' && (chordFinger ?? 1) == 1 && fret > 0;
      badgeColor = fret == 0
          ? const Color(0xFF10B981)
          : (isBarreFinger1
              ? const Color(0xFF8B5CF6)
              : const Color(0xFF3B82F6));
      badgeText = fret == 0
          ? 'O'
          : (isBarreFinger1 ? 'Chặn 1' : 'Ngón ${chordFinger ?? 1}');
    } else if (isScaleRoot) {
      badgeColor = const Color(0xFFEF4444);
      badgeText = '${note.vnLabel} (Gốc)';
    } else if (isInScale) {
      badgeColor = const Color(0xFF2563EB);
      badgeText = note.vnLabel;
    }

    final stringThickness = 0.9 + (stringNumber * 0.32);

    return GestureDetector(
      onTap: onTapFret != null ? () => onTapFret!(stringNumber, fret) : null,
      child: Container(
        width: cellWidth,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: fret == 0
                  ? const Color(0xFFFef3c7)
                  : const Color(0xFF94A3B8).withOpacity(0.45),
              width: fret == 0 ? 3.0 : 1.2,
            ),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Dây đàn ngang
            Container(
              height: stringThickness,
              width: double.infinity,
              color: stringNumber >= 4
                  ? const Color(0xFFD97706).withOpacity(0.75)
                  : const Color(0xFFE2E8F0).withOpacity(0.75),
            ),
            if (shouldShowNoteBadge)
              Container(
                constraints: BoxConstraints(
                  minWidth: 22,
                  maxWidth: cellWidth - 4,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.85),
                    width: isTarget || isScaleRoot ? 1.5 : 0.8,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    badgeText,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9.8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Khuông Tab Guitar 6 dây trực quan (hiển thị bài tập Spider 1-2-3-4 hoặc câu hỏi đọc Tab).
class GuitarTabViewerWidget extends StatelessWidget {
  final int activeStepIndex;
  final bool isDark;
  final int? highlightString; // 1..6
  final int? highlightFret;
  final List<(int, int)>? customSteps;

  const GuitarTabViewerWidget({
    super.key,
    this.activeStepIndex = 0,
    required this.isDark,
    this.highlightString,
    this.highlightFret,
    this.customSteps,
  });

  @override
  Widget build(BuildContext context) {
    const tabStrings = ['e|', 'B|', 'G|', 'D|', 'A|', 'E|'];
    final steps = customSteps ??
        const [
          (6, 1),
          (6, 2),
          (6, 3),
          (6, 4),
          (5, 1),
          (5, 2),
          (5, 3),
          (5, 4),
        ];

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int s = 1; s <= 6; s++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        tabStrings[s - 1],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 1,
                            color: Colors.grey.withOpacity(0.45),
                          ),
                          if (highlightString != null && highlightFret != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 48),
                              child: s == highlightString
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$highlightFret',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : const SizedBox(height: 16),
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(steps.length, (idx) {
                                final st = steps[idx];
                                final isHere = st.$1 == s;
                                final isActive = idx == activeStepIndex && isHere;
                                if (!isHere) {
                                  return const SizedBox(width: 22, height: 16);
                                }
                                return Container(
                                  width: 22,
                                  height: 16,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppColors.correct
                                        : AppColors.primary.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '${st.$2}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: isActive
                                          ? Colors.white
                                          : AppColors.primary,
                                    ),
                                  ),
                                );
                              }),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Khung hiển thị trực quan Cần đàn / Hợp âm / Tab Guitar ngay trong phòng câu hỏi QuizScreen.
class GuitarQuestionBoardWidget extends StatelessWidget {
  final String topicId;
  final String optionKey;
  final bool isRevealed;

  const GuitarQuestionBoardWidget({
    super.key,
    required this.topicId,
    required this.optionKey,
    required this.isRevealed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Các câu hỏi thuần lý thuyết vòng hợp âm / Capo / công thức tay phải / ký hiệu kỹ thuật không cần vẽ bảng cần đàn thừa
    if (optionKey.startsWith('GTR_THEORY_') ||
        optionKey.startsWith('GTR_TECH_') ||
        optionKey == 'GTR_TAB_BALLAD_44' ||
        optionKey == 'GTR_TAB_PIMA' ||
        optionKey == 'GTR_TAB_VALSE_34') {
      return const SizedBox.shrink(key: Key('guitar_question_board'));
    }

    if (optionKey == 'GTR_TAB_SPIDER') {
      return GuitarTabViewerWidget(
        key: const Key('guitar_question_board'),
        isDark: isDark,
      );
    }

    // Format optionKey: e.g. 'GTR_S5_F3' (Dây 5 Ngăn 3), 'GTR_CHORD_Am', 'GTR_TAB_S6_F3'
    if (optionKey.startsWith('GTR_CHORD_')) {
      final chordId = optionKey.replaceFirst('GTR_CHORD_', '');
      final chord = GuitarFretboardData.commonChords.firstWhere(
        (c) => c.id == chordId,
        orElse: () => GuitarFretboardData.commonChords.first,
      );
      return InteractiveGuitarFretboard(
        key: const Key('guitar_question_board'),
        maxFrets: chord.maxFret > 4 ? chord.maxFret : 4,
        chordShape: chord,
      );
    }

    if (optionKey.startsWith('GTR_TAB_')) {
      final parts = optionKey.split('_');
      final sNum = parts.length >= 4
          ? (int.tryParse(parts[2].replaceFirst('S', '')) ?? 6)
          : 6;
      final fNum = parts.length >= 4
          ? (int.tryParse(parts[3].replaceFirst('F', '')) ?? 3)
          : 3;
      return GuitarTabViewerWidget(
        key: const Key('guitar_question_board'),
        isDark: isDark,
        highlightString: sNum,
        highlightFret: fNum,
      );
    }

    if (optionKey.startsWith('GTR_SCALE_')) {
      final isEm = optionKey.contains('EM');
      final isAm = optionKey.contains('AM');
      final Set<String> pitchSet = isEm
          ? const {'E', 'G', 'A', 'B', 'D'}
          : (isAm
              ? const {'A', 'C', 'D', 'E', 'G'}
              : const {'C', 'D', 'E', 'F', 'G', 'A', 'B'});
      final String rootPitch = isEm ? 'E' : (isAm ? 'A' : 'C');
      return InteractiveGuitarFretboard(
        key: const Key('guitar_question_board'),
        maxFrets: 5,
        scalePitchSet: pitchSet,
        scaleRootPitch: rootPitch,
      );
    }

    // Mặc định: Hỏi vị trí nốt trên Cần đàn (GTR_S{s}_F{f})
    int sNum = 5;
    int fNum = 3;
    if (optionKey.startsWith('GTR_S')) {
      final parts = optionKey.split('_');
      if (parts.length >= 3) {
        sNum = int.tryParse(parts[1].replaceFirst('S', '')) ?? 5;
        fNum = int.tryParse(parts[2].replaceFirst('F', '')) ?? 3;
      }
    }
    return InteractiveGuitarFretboard(
      key: const Key('guitar_question_board'),
      maxFrets: fNum > 5 ? 12 : 5,
      activeString: sNum,
      activeFret: fNum,
      hideActiveNoteName: !isRevealed,
    );
  }
}
