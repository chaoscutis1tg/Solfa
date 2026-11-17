import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../core/providers/app_providers.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';

/// Trạng thái mở khóa vĩnh viễn Bản đồ Scale & Bài Guitar Nâng Cao (50 Gem).
final guitarProUnlockedProvider = StateProvider<bool>((ref) => false);

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
      audioAsset: 'assets/audio/keys/chord_c_maj.wav',
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
      audioAsset: 'assets/audio/keys/chord_d_min.wav',
      tip: 'Ngón 1 chặn 6 dây ngăn 1 (nhấc ngón 2 ra) • Ngón 3 Dây 5 ngăn 3 • Ngón 4 Dây 4 ngăn 3',
    ),
    GuitarChordShape(
      id: 'Bm',
      category: 'barre',
      name: 'Si Thứ Chặn (Bm)',
      formula: 'X - 2 - 4 - 4 - 3 - 2',
      fretsByString1To6: [2, 3, 4, 4, 2, -1],
      fingersByString1To6: [1, 2, 4, 3, 1, 0],
      audioAsset: 'assets/audio/keys/chord_a_min.wav',
      tip: 'Ngón 1 chặn 5 dây dưới tại ngăn 2 • Ngón 2 Dây 2 ngăn 3 • Ngón 3 Dây 4 ngăn 4 • Ngón 4 Dây 3 ngăn 4',
    ),
    GuitarChordShape(
      id: 'B',
      category: 'barre',
      name: 'Si Trưởng Chặn (B)',
      formula: 'X - 2 - 4 - 4 - 4 - 2',
      fretsByString1To6: [2, 4, 4, 4, 2, -1],
      fingersByString1To6: [1, 4, 3, 2, 1, 0],
      audioAsset: 'assets/audio/keys/chord_g_maj.wav',
      tip: 'Ngón 1 chặn 5 dây ngăn 2 • Ngón 2, 3, 4 bấm Dây 4, 3, 2 tại ngăn 4',
    ),
    GuitarChordShape(
      id: 'F#m',
      category: 'barre',
      name: 'Fa Thăng Thứ (F#m)',
      formula: '2 - 4 - 4 - 2 - 2 - 2',
      fretsByString1To6: [2, 2, 2, 4, 4, 2],
      fingersByString1To6: [1, 1, 1, 4, 3, 1],
      audioAsset: 'assets/audio/keys/chord_e_min.wav',
      tip: 'Dịch dáng Fm lên ngăn 2: Ngón 1 chặn 6 dây ngăn 2 • Ngón 3 Dây 5 ngăn 4 • Ngón 4 Dây 4 ngăn 4',
    ),
    GuitarChordShape(
      id: 'Gm',
      category: 'barre',
      name: 'Sol Thứ Chặn (Gm)',
      formula: '3 - 5 - 5 - 3 - 3 - 3',
      fretsByString1To6: [3, 3, 3, 5, 5, 3],
      fingersByString1To6: [1, 1, 1, 4, 3, 1],
      audioAsset: 'assets/audio/keys/chord_d_min.wav',
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
      audioAsset: 'assets/audio/keys/chord_f_maj.wav',
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
      audioAsset: 'assets/audio/keys/chord_g_dom7.wav',
      tip: 'Giữ Đô Trưởng (C) và đặt thêm Ngón 4 (Út) vào Dây 3 ngăn 3 (nốt Sib)',
    ),
    GuitarChordShape(
      id: 'D7',
      category: 'seventh',
      name: 'Rê Bảy Át (D7)',
      formula: 'X - X - 0 - 2 - 1 - 2',
      fretsByString1To6: [2, 1, 2, 0, -1, -1],
      fingersByString1To6: [3, 1, 2, 0, 0, 0],
      audioAsset: 'assets/audio/keys/chord_g_dom7.wav',
      tip: 'Tam giác ngược ở 3 dây dưới: Ngón 1 Dây 2 ngăn 1 • Ngón 2 Dây 3 ngăn 2 • Ngón 3 Dây 1 ngăn 2',
    ),
    GuitarChordShape(
      id: 'E7',
      category: 'seventh',
      name: 'Mi Bảy Át (E7)',
      formula: '0 - 2 - 0 - 1 - 0 - 0',
      fretsByString1To6: [0, 0, 1, 0, 2, 0],
      fingersByString1To6: [0, 0, 1, 0, 2, 0],
      audioAsset: 'assets/audio/keys/chord_g_dom7.wav',
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
      audioAsset: 'assets/audio/keys/chord_g_dom7.wav',
      tip: 'Từ La Trưởng (A) nhấc ngón giữa ở Dây 3 ra để vang Dây 3 buông (Sol G3)',
    ),
    GuitarChordShape(
      id: 'B7',
      category: 'seventh',
      name: 'Si Bảy Át (B7)',
      formula: 'X - 2 - 1 - 2 - 0 - 2',
      fretsByString1To6: [2, 0, 2, 1, 2, -1],
      fingersByString1To6: [4, 0, 3, 1, 2, 0],
      audioAsset: 'assets/audio/keys/chord_g_dom7.wav',
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
      audioAsset: 'assets/audio/keys/chord_a_min7.wav',
      tip: 'Ngón 1 chặn nhẹ Dây 1 & Dây 2 ngăn 1 • Ngón 2 bấm Dây 3 ngăn 2 (Bass dây 4 buông)',
    ),
    GuitarChordShape(
      id: 'Em7',
      category: 'seventh',
      name: 'Mi Bảy Thứ (Em7)',
      formula: '0 - 2 - 2 - 0 - 3 - 0',
      fretsByString1To6: [0, 3, 0, 2, 2, 0],
      fingersByString1To6: [0, 4, 0, 3, 2, 0],
      audioAsset: 'assets/audio/keys/chord_a_min7.wav',
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
      audioAsset: 'assets/audio/keys/chord_c_maj7.wav',
      tip: 'Thế bấm Fa mở cực dễ: Ngón 1 Dây 2 ngăn 1 • Ngón 2 Dây 3 ngăn 2 • Ngón 3 Dây 4 ngăn 3 • Dây 1 buông',
    ),
    GuitarChordShape(
      id: 'Gmaj7',
      category: 'seventh',
      name: 'Sol Bảy Trưởng (Gmaj7)',
      formula: '3 - 2 - 0 - 0 - 0 - 2',
      fretsByString1To6: [2, 0, 0, 0, 2, 3],
      fingersByString1To6: [1, 0, 0, 0, 2, 3],
      audioAsset: 'assets/audio/keys/chord_c_maj7.wav',
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
      audioAsset: 'assets/audio/keys/chord_c_sus4.wav',
      tip: 'Từ Rê Trưởng (D) nhấc ngón giữa khỏi Dây 1 để vang Dây 1 buông (Mi E4) trong trẻo',
    ),
    GuitarChordShape(
      id: 'Dsus4',
      category: 'color',
      name: 'Rê Treo Bậc 4 (Dsus4)',
      formula: 'X - X - 0 - 2 - 3 - 3',
      fretsByString1To6: [3, 3, 2, 0, -1, -1],
      fingersByString1To6: [4, 3, 1, 0, 0, 0],
      audioAsset: 'assets/audio/keys/chord_c_sus4.wav',
      tip: 'Từ Rê Trưởng (D) đặt thêm Ngón 4 vào Dây 1 ngăn 3 (nốt Sol G4)',
    ),
    GuitarChordShape(
      id: 'Esus4',
      category: 'color',
      name: 'Mi Treo Bậc 4 (Esus4)',
      formula: '0 - 2 - 2 - 2 - 0 - 0',
      fretsByString1To6: [0, 0, 2, 2, 2, 0],
      fingersByString1To6: [0, 0, 4, 3, 2, 0],
      audioAsset: 'assets/audio/keys/chord_c_sus4.wav',
      tip: 'Từ Mi Trưởng (E) đặt thêm Ngón 4 vào Dây 3 ngăn 2 (nốt La A3) rồi giải về E',
    ),
    GuitarChordShape(
      id: 'Asus2',
      category: 'color',
      name: 'La Treo Bậc 2 (Asus2)',
      formula: 'X - 0 - 2 - 2 - 0 - 0',
      fretsByString1To6: [0, 0, 2, 2, 0, -1],
      fingersByString1To6: [0, 0, 3, 2, 0, 0],
      audioAsset: 'assets/audio/keys/chord_c_sus4.wav',
      tip: 'Từ La Thứ (Am) nhấc ngón trỏ khỏi Dây 2 để vang cả Dây 2 buông (Si) và Dây 1 buông (Mi)',
    ),
    GuitarChordShape(
      id: 'Asus4',
      category: 'color',
      name: 'La Treo Bậc 4 (Asus4)',
      formula: 'X - 0 - 2 - 2 - 3 - 0',
      fretsByString1To6: [0, 3, 2, 2, 0, -1],
      fingersByString1To6: [0, 4, 3, 2, 0, 0],
      audioAsset: 'assets/audio/keys/chord_c_sus4.wav',
      tip: 'Từ La Thứ (Am) đặt Ngón 4 vào Dây 2 ngăn 3 (nốt Rê D4)',
    ),
    GuitarChordShape(
      id: 'Cadd9',
      category: 'color',
      name: 'Đô Cộng 9 (Cadd9)',
      formula: 'X - 3 - 2 - 0 - 3 - 3',
      fretsByString1To6: [3, 3, 0, 2, 3, -1],
      fingersByString1To6: [4, 3, 0, 1, 2, 0],
      audioAsset: 'assets/audio/keys/chord_c_maj7.wav',
      tip: 'Hợp âm màu Acoustic: Ngón 1 Dây 4 ngăn 2 • Ngón 2 Dây 5 ngăn 3 • Ngón 3 Dây 2 ngăn 3 • Ngón 4 Dây 1 ngăn 3',
    ),
    GuitarChordShape(
      id: 'G/B',
      category: 'color',
      name: 'Sol Bass Si (G/B)',
      formula: 'X - 2 - 0 - 0 - 3 - 3',
      fretsByString1To6: [3, 3, 0, 0, 2, -1],
      fingersByString1To6: [4, 3, 0, 0, 1, 0],
      audioAsset: 'assets/audio/keys/chord_g_maj.wav',
      tip: 'Hợp âm cầu nối Bass đi bộ mượt mà giữa Đô Trưởng (C) và La Thứ (Am)',
    ),
  ];

  /// 6 Bài luyện ngón Guitar thực tế từ Cơ bản đến Nâng cao (Tay trái Spider, Đảo ngón, Nhảy dây, Rải tay phải P-i-m-a, Solo Pentatonic)
  static const List<GuitarWorkoutExercise> fingerWorkouts = [
    GuitarWorkoutExercise(
      id: 'spider_1234',
      title: 'Bài 1: Bò Nhện Cơ Bản (1–2–3–4)',
      levelTag: 'Cơ bản',
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
      title: 'Bài 2: Bò Nhện Ngược (4–3–2–1 • Khỏe Ngón Út)',
      levelTag: 'Cơ bản',
      description:
          'Đánh ngược từ Ngăn 4 lùi về Ngăn 1 (Út 4 → Áp út 3 → Giữa 2 → Trỏ 1) trên Dây 1 & Dây 2 để rèn sức mạnh và độ chính xác cho ngón Út và Áp út.',
      steps: [
        (1, 4, 'Ngón 4 (Út)'),
        (1, 3, 'Ngón 3 (Áp út)'),
        (1, 2, 'Ngón 2 (Giữa)'),
        (1, 1, 'Ngón 1 (Trỏ)'),
        (2, 4, 'Ngón 4 (Út)'),
        (2, 3, 'Ngón 3 (Áp út)'),
        (2, 2, 'Ngón 2 (Giữa)'),
        (2, 1, 'Ngón 1 (Trỏ)'),
      ],
    ),
    GuitarWorkoutExercise(
      id: 'perm_1324',
      title: 'Bài 3: Đảo Ngón Chéo (1–3–2–4 • Tách Ngón)',
      levelTag: 'Trung bình',
      description:
          'Bài tập tách gân ngón tay kinh điển: đánh xen kẽ Trỏ (1) → Áp út (3) → Giữa (2) → Út (4) trên Dây 4 & Dây 3 giúp chuyển hợp âm cực nhanh.',
      steps: [
        (4, 1, 'Ngón 1 (Trỏ)'),
        (4, 3, 'Ngón 3 (Áp út)'),
        (4, 2, 'Ngón 2 (Giữa)'),
        (4, 4, 'Ngón 4 (Út)'),
        (3, 1, 'Ngón 1 (Trỏ)'),
        (3, 3, 'Ngón 3 (Áp út)'),
        (3, 2, 'Ngón 2 (Giữa)'),
        (3, 4, 'Ngón 4 (Út)'),
      ],
    ),
    GuitarWorkoutExercise(
      id: 'string_skip',
      title: 'Bài 4: Nhảy Dây Cách Quãng (String Skipping)',
      levelTag: 'Trung bình',
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
    GuitarWorkoutExercise(
      id: 'arpeggio_ballad',
      title: 'Bài 5: Rải Tay Phải P–i–m–a (Ballad 4/4 • Đô Trưởng)',
      levelTag: 'Trung bình',
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
      id: 'pentatonic_box1',
      title: 'Bài 6: Chạy Ngón Solo Am Pentatonic (Ngăn 5–8)',
      levelTag: 'Nâng cao',
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
  ];
}

class GuitarChordShape {
  final String id;
  final String category; // 'open', 'barre', 'seventh', 'color'
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
  final String levelTag;
  final String description;
  final List<(int stringNum, int fretNum, String fingerLabel)> steps;

  const GuitarWorkoutExercise({
    required this.id,
    required this.title,
    required this.levelTag,
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

class _GuitarStudioSheetState extends ConsumerState<GuitarStudioSheet> {
  /// 0: Bản đồ Cần đàn (Fretboard Map)
  /// 1: Hợp âm Guitar (Chord Shapes - 36 hợp âm)
  /// 2: Bản đồ Scale (Pentatonic & Trưởng/Thứ)
  /// 3: Luyện ngón & Đọc Tab (6 bài tập từ Cơ bản đến Nâng cao)
  late int _selectedTab;

  int _activeString = 5; // Dây 5
  int _activeFret = 3; // Ngăn 3 (Đô C3)
  bool _showNaturalNotesOnly = true;
  bool _showOctaveJumpGuide = false;

  String _selectedChordCategory = 'all'; // 'all', 'open', 'barre', 'seventh', 'color'
  String _selectedChordId = 'C';
  String _selectedScaleId = 'am_pentatonic';

  int _selectedWorkoutIndex = 0;
  int _spiderStep = 0;
  int _spiderStepIntervalMs = 520; // 650ms (Chậm), 520ms (Vừa), 360ms (Nhanh)
  Timer? _spiderTimer;
  bool _isSpiderPlaying = false;

  Timer? _strumTimer;
  int? _activeStrumString;
  int? _activeStrumFret;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.isWorkoutOnlyPage ? 3 : widget.initialTab;
  }

  @override
  void dispose() {
    _spiderTimer?.cancel();
    _strumTimer?.cancel();
    super.dispose();
  }

  /// Phát hợp âm chuẩn xác 100% theo cao độ thực tế của 6 dây trên cần đàn (quét nhanh 35ms như gảy phím thật).
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
    void playNext() {
      if (!mounted || idx >= notes.length) {
        _strumTimer?.cancel();
        return;
      }
      final (s, f) = notes[idx];
      final n = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
      ref.read(audioServiceProvider).playPolyphonicAsset(n.audioAsset);
      idx++;
    }

    playNext();
    _strumTimer = Timer.periodic(
      const Duration(milliseconds: 38),
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
      ref.read(audioServiceProvider).playPolyphonicAsset(note.audioAsset);
      step++;
    }

    playStep();
    _strumTimer = Timer.periodic(
      Duration(milliseconds: isBallad ? 210 : 115),
      (_) => playStep(),
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
        setState(() {
          _spiderStep = (_spiderStep + 1) % workout.steps.length;
        });
        _playCurrentSpiderStep();
      },
    );
  }

  void _stepWorkoutManually(int delta) {
    _spiderTimer?.cancel();
    final workout = GuitarFretboardData.fingerWorkouts[_selectedWorkoutIndex];
    setState(() {
      _isSpiderPlaying = false;
      _spiderStep =
          (_spiderStep + delta + workout.steps.length) % workout.steps.length;
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
    ref.read(audioServiceProvider).playPolyphonicAsset(note.audioAsset);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final audioService = ref.watch(audioServiceProvider);
    final adState = ref.watch(rewardedAdProvider);
    final proUnlocked = ref.watch(guitarProUnlockedProvider);
    final isEn = ref.watch(appSettingsProvider).isEnglish;
    final isWorkoutPage = widget.isWorkoutOnlyPage;

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
                  ? 'Guitar Finger Workouts & Tab'
                  : 'Luyện Ngón Guitar & Đọc Tab')
              : (isEn
                  ? 'Guitar Fretboard, Chords & Scales'
                  : 'Bản Đồ Cần Đàn & Hợp Âm Guitar'),
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            if (!isWorkoutPage) ...[
              // 3 Phân khu trên Trang Bản Đồ Cần Đàn (Map Cần | 36 Hợp Âm | Bản đồ Scale)
              Row(
                children: [
                  for (final (idx, label, icon) in [
                    (0, isEn ? 'Fretboard' : 'Map Cần đàn', Icons.grid_on_rounded),
                    (
                      1,
                      isEn ? 'Chords (36)' : 'Hợp âm (36)',
                      Icons.pan_tool_alt_rounded
                    ),
                    (2, isEn ? 'Scales' : 'Bản đồ Scale', Icons.timeline_rounded),
                  ]) ...[
                    if (idx > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Material(
                        color: _selectedTab == idx
                            ? const Color(0xFFD97706)
                            : (isDark
                                ? AppColors.surfaceDark
                                : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          key: Key('chip_guitar_tab_$idx'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            _spiderTimer?.cancel();
                            _strumTimer?.cancel();
                            setState(() {
                              _isSpiderPlaying = false;
                              _activeStrumString = null;
                              _activeStrumFret = null;
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
                                    ? const Color(0xFFD97706)
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
                                      : const Color(0xFFD97706),
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
              const SizedBox(height: 14),
            ],

            if (isWorkoutPage || _selectedTab == 3)
              _buildTabAndSpiderExerciseTab(audioService, isDark, isEn)
            else if (_selectedTab == 0)
              _buildFretboardMapTab(audioService, isDark, isEn)
            else if (_selectedTab == 1)
              _buildChordShapesTab(audioService, isDark, isEn)
            else
              _buildScaleMapTab(
                context,
                audioService,
                adState,
                proUnlocked,
                isDark,
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
                    audioService.playPolyphonicAsset(activeInfo.audioAsset),
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
        const SizedBox(height: 8),
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
            setState(() {
              _activeString = s;
              _activeFret = f;
            });
            final info = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
            audioService.playPolyphonicAsset(info.audioAsset);
          },
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn
                    ? '3 Golden Rules to Master the Fretboard:'
                    : '3 Quy tắc Vàng để nhớ hết nốt trên cần đàn:',
                style: const TextStyle(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isEn
                    ? '• Step 1 (6 Open Strings): From String 6 (thickest) to String 1: E2 – A2 – D3 – G3 – B3 – E4.\n'
                      '• Step 2 (Anchor Frets on Strings 6 & 5): S6 Fret 3 = G2, S6 Fret 5 = A2, S5 Fret 3 = C3.\n'
                      '• Step 3 (Diagonal Octave Rule): Move down 2 strings + 2 frets (or +3 frets across String 2) to find the same note 1 octave higher!'
                    : '• Bước 1 (Nhớ 6 dây buông Ngăn 0): Từ dây 6 (dày nhất) xuống dây 1: E (Mi) – A (La) – D (Rê) – G (Sol) – B (Si) – e (Mi).\n'
                      '• Bước 2 (Nhớ 3 ngăn mốc trên Dây 6 & Dây 5): Ngăn 3 Dây 6 = Sol (G), Ngăn 5 Dây 6 = La (A), Ngăn 3 Dây 5 = Đô (C).\n'
                      '• Bước 3 (Quy tắc Quãng 8 chéo): Từ Dây 6 hoặc Dây 5, lùi xuống 2 dây + tiến thêm 2 ngăn sẽ gặp lại chính nốt đó cao hơn 1 quãng tám!',
                style: const TextStyle(fontSize: 11.8, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// TAB 2: Thư viện 36 Hợp âm Guitar thực tế (Phân theo 4 nhóm: Mở, Chặn Barre, Hợp âm 7, Hợp âm Màu)
  Widget _buildChordShapesTab(dynamic audioService, bool isDark, bool isEn) {
    final categories = [
      ('all', isEn ? 'All (36)' : 'Tất cả (36)'),
      ('open', isEn ? 'Open (8)' : 'Hợp âm Mở (8)'),
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
        // Bộ lọc 4 nhóm hợp âm (Mở, Chặn, Hợp âm 7, Hợp âm Màu)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < categories.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                ChoiceChip(
                  key: Key('chip_chord_cat_${categories[i].$1}'),
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    categories[i].$2,
                    style: const TextStyle(
                      fontSize: 11.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  selected: _selectedChordCategory == categories[i].$1,
                  onSelected: (_) {
                    _strumTimer?.cancel();
                    final nextList = categories[i].$1 == 'all'
                        ? GuitarFretboardData.commonChords
                        : GuitarFretboardData.commonChords
                            .where((c) => c.category == categories[i].$1)
                            .toList();
                    setState(() {
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
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in filteredChords)
              ChoiceChip(
                key: Key('chip_guitar_chord_${c.id}'),
                visualDensity: VisualDensity.compact,
                label: Text(
                  c.id,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                selected: chord.id == c.id,
                onSelected: (_) {
                  _strumTimer?.cancel();
                  setState(() {
                    _selectedChordId = c.id;
                    _activeStrumString = null;
                    _activeStrumFret = null;
                  });
                  _playChordRealVoicing(c);
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEn
                              ? 'Voicing (S6 → S1): ${chord.formula}'
                              : 'Thế bấm (Dây 6 → Dây 1): ${chord.formula}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => _playChordRealVoicing(chord),
                    icon: const Icon(Icons.volume_up_rounded, size: 15),
                    label: Text(isEn ? 'Play Chord' : 'Gảy hợp âm'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('btn_guitar_chord_strum'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _startChordStrum(chord, isBallad: false),
                      icon: const Icon(Icons.south_rounded, size: 15),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn
                              ? 'Strum (Bass → S1)'
                              : 'Rải từ Bass xuống (Strum)',
                          style: const TextStyle(
                            fontSize: 11.5,
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
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _startChordStrum(chord, isBallad: true),
                      icon: const Icon(Icons.waves_rounded, size: 15),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn
                              ? 'Ballad (Bass-3-2-3-1-3-2-3)'
                              : 'Rải Ballad (Bass-3-2-3-1-3-2-3)',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        InteractiveGuitarFretboard(
          maxFrets: chord.maxFret > 5 ? chord.maxFret : 5,
          chordShape: chord,
          activeString: _activeStrumString,
          activeFret: _activeStrumFret,
          onTapFret: (s, f) {
            final info = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
            audioService.playPolyphonicAsset(info.audioAsset);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Hướng dẫn đặt ngón: ${chord.tip} (Số 1: Ngón trỏ • Số 2: Ngón giữa • Số 3: Áp út • Số 4: Út • O: Dây buông • X: Không gảy)',
          style: const TextStyle(fontSize: 12, height: 1.38),
        ),
      ],
    );
  }

  /// TAB 3: Bản đồ Âm giai (Scale Map - Pentatonic & Trưởng/Thứ)
  Widget _buildScaleMapTab(
    BuildContext context,
    dynamic audioService,
    RewardedAdState adState,
    bool proUnlocked,
    bool isDark,
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
        'a_harmonic_minor',
        'La Thứ Hài Hòa (50 Gem)',
        true,
        {'A', 'B', 'C', 'D', 'E', 'F', 'G#'},
        'A',
        'Âm giai La Thứ Hài Hòa (nâng bậc 7 lên Sol# G#) tạo màu sắc cổ điển & Flamenco cuốn hút trên 12 ngăn.'
      ),
    ];

    final currentScale =
        scales.firstWhere((s) => s.$1 == _selectedScaleId, orElse: () => scales.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Map Scale là gì? Là sơ đồ tô sáng các nốt "an toàn & hòa hợp" của một giọng trên cần đàn. Khi đánh bất kỳ nốt nào nằm trên Map này, tiếng đàn sẽ luôn đúng giọng!',
          style: TextStyle(fontSize: 12, height: 1.38),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final sc in scales)
              ChoiceChip(
                key: Key('chip_guitar_scale_${sc.$1}'),
                visualDensity: VisualDensity.compact,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sc.$3 && !proUnlocked) ...[
                        const SolfaGemIcon(size: 12),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        sc.$2,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                selected: _selectedScaleId == sc.$1,
                onSelected: (_) async {
                  if (sc.$3 && !proUnlocked) {
                    final ok = await ref
                        .read(rewardedAdProvider.notifier)
                        .spendGemsForOneHourSession(gemCost: 50);
                    if (!ok) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Cần 50 Gem để mở khóa vĩnh viễn Full Map Scale 12 ngăn. Hãy hoàn thành nhiệm vụ hoặc xem video ủng hộ nhé!',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    ref.read(guitarProUnlockedProvider.notifier).state = true;
                  }
                  setState(() => _selectedScaleId = sc.$1);
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        InteractiveGuitarFretboard(
          maxFrets: 12,
          scalePitchSet: currentScale.$4,
          scaleRootPitch: currentScale.$5,
          onTapFret: (s, f) {
            final info = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
            audioService.playPolyphonicAsset(info.audioAsset);
          },
        ),
        const SizedBox(height: 8),
        Text(
          currentScale.$6,
          style: const TextStyle(fontSize: 12, height: 1.38),
        ),
      ],
    );
  }

  /// TAB 4 (Trang riêng biệt): 6 Bài Luyện Ngón Guitar & Thực Hành Đọc Tab Chuyên Sâu
  Widget _buildTabAndSpiderExerciseTab(
    dynamic audioService,
    bool isDark,
    bool isEn,
  ) {
    const workouts = GuitarFretboardData.fingerWorkouts;
    final currentWorkout = workouts[_selectedWorkoutIndex % workouts.length];
    final currentStepTuple =
        currentWorkout.steps[_spiderStep % currentWorkout.steps.length];
    final activeString = currentStepTuple.$1;
    final activeFret = currentStepTuple.$2;
    final activeFingerText = currentStepTuple.$3;
    final activeNote = GuitarFretboardData.noteAt(
      stringNumber: activeString,
      fret: activeFret,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEn
              ? 'Select Finger Workout (6 Progressive Exercises):'
              : 'Chọn bài luyện ngón (6 bài từ Cơ bản đến Nâng cao):',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        // Lưới 2 cột gọn gàng cho 6 bài luyện ngón (tiết kiệm 50% chiều dọc để Khuông Tab & Cần đàn hiển thị ngay trên màn hình)
        for (int row = 0; row < (workouts.length / 2).ceil(); row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (int col = 0; col < 2; col++) ...[
                  if (col > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Builder(
                      builder: (_) {
                        final idx = row * 2 + col;
                        if (idx >= workouts.length) {
                          return const SizedBox.shrink();
                        }
                        final w = workouts[idx];
                        final selected = _selectedWorkoutIndex == idx;
                        return Material(
                          color: selected
                              ? const Color(0xFFD97706)
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
                              _playCurrentSpiderStep();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFFD97706)
                                      : (isDark
                                          ? AppColors.borderDark
                                          : AppColors.borderLight),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.white.withOpacity(0.22)
                                          : const Color(0xFFD97706)
                                              .withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: selected
                                            ? Colors.white
                                            : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      w.title.replaceFirst(
                                        RegExp(r'^Bài \d+:\s*'),
                                        '',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.8,
                                        fontWeight: FontWeight.w800,
                                        color: selected ? Colors.white : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentWorkout.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentWorkout.description,
                style: const TextStyle(fontSize: 12, height: 1.38),
              ),
              const SizedBox(height: 10),
              // Thanh điều khiển tốc độ & Chạy mẫu / Tập từng bước (Không tràn khung 360px)
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
                      minimumSize: const Size(34, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _stepWorkoutManually(-1),
                    child: const Icon(Icons.skip_previous_rounded, size: 16),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(34, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _stepWorkoutManually(1),
                    child: const Icon(Icons.skip_next_rounded, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bước ${(_spiderStep % currentWorkout.steps.length) + 1}/${currentWorkout.steps.length}: Dây $activeString • Ngăn $activeFret (${activeNote.fullLabel}) → $activeFingerText',
                      style: const TextStyle(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    key: const Key('btn_toggle_spider_exercise'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSpiderPlaying
                          ? AppColors.wrong
                          : const Color(0xFFD97706),
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: _toggleSpiderExercise,
                    icon: Icon(
                      _isSpiderPlaying
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _isSpiderPlaying
                          ? (isEn ? 'Stop' : 'Dừng tập')
                          : (isEn ? 'Auto Play' : 'Chạy mẫu'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GuitarTabViewerWidget(
          activeStepIndex: _spiderStep % currentWorkout.steps.length,
          isDark: isDark,
          customSteps: currentWorkout.steps
              .map((s) => (s.$1, s.$2))
              .toList(growable: false),
        ),
        const SizedBox(height: 10),
        InteractiveGuitarFretboard(
          maxFrets: currentWorkout.maxFret,
          activeString: activeString,
          activeFret: activeFret,
          showAllNotes: false,
          onTapFret: (s, f) {
            final info = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
            audioService.playPolyphonicAsset(info.audioAsset);
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
    return Container(
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
      badgeColor = fret == 0
          ? const Color(0xFF10B981)
          : const Color(0xFF3B82F6);
      badgeText =
          fret == 0 ? 'O' : 'Ngón ${chordFinger ?? 1}';
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

    return Container(
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
        maxFrets: 4,
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
