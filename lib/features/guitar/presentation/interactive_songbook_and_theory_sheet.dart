import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../core/audio/audio_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';
import '../../support_developer/presentation/support_developer_screen.dart';
import 'custom_melody_composer_screen.dart';
import 'guitar_studio_sheet.dart';

const String _kUnlockedVipSongsPrefsKey = 'solfa_unlocked_vip_songs_v1';
const String _kSongStarsPrefsKey = 'solfa_songbook_stars_v1';

/// Provider lưu danh sách ID các bản nhạc VIP đã mở khóa vĩnh viễn bằng Gem (300 - 500 Gem).
final unlockedVipSongsProvider = StateProvider<Set<String>>((ref) => <String>{});

/// Provider lưu số Sao (1..3) đạt được cho từng bản nhạc trong Kho Bản Nhạc & Tab Chạy.
final songbookStarsProvider = StateProvider<Map<String, int>>((ref) => <String, int>{});

Future<void> loadSongbookPreferences(WidgetRef ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final unlockedList =
        prefs.getStringList(_kUnlockedVipSongsPrefsKey) ?? const <String>[];
    ref.read(unlockedVipSongsProvider.notifier).state = unlockedList.toSet();

    final rawStars = prefs.getStringList(_kSongStarsPrefsKey) ?? const <String>[];
    final map = <String, int>{};
    for (final entry in rawStars) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        final stars = int.tryParse(parts[1]) ?? 0;
        if (stars > 0) map[parts[0]] = stars.clamp(1, 3);
      }
    }
    ref.read(songbookStarsProvider.notifier).state = map;
  } catch (_) {}
}

Future<void> persistUnlockedVipSongs(Set<String> unlocked) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kUnlockedVipSongsPrefsKey, unlocked.toList());
  } catch (_) {}
}

Future<void> persistSongbookStars(Map<String, int> stars) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final encoded = stars.entries.map((e) => '${e.key}:${e.value}').toList();
    await prefs.setStringList(_kSongStarsPrefsKey, encoded);
  } catch (_) {}
}

/// Một nốt trong bản nhạc tương tác (khớp 100% giữa Cần đàn Guitar 6 dây và Phím đàn Piano).
class SongTabNote {
  final int stringNumber; // 1 (e4) .. 6 (E2)
  final int fret; // 0..15
  final String pitchKey; // e.g., 'E4', 'F#4', 'C5'
  final String noteLabel; // e.g., 'Mi (E4)'
  final String audioAsset; // e.g., 'assets/audio/notes/e4.wav'
  final String? chordSymbol;

  const SongTabNote({
    required this.stringNumber,
    required this.fret,
    required this.pitchKey,
    required this.noteLabel,
    required this.audioAsset,
    this.chordSymbol,
  });
}

/// Mô hình Bản Nhạc Tương Tác (12 Bản Cổ điển Public Domain + 8 Bản Hiện đại / V-Pop Style).
class InteractiveSongItem {
  final String id;
  final String category; // 'classical' | 'modern'
  final String titleVi;
  final String titleEn;
  final String composer;
  final String genreBadge;
  final int defaultBpm;
  final int gemCost; // 0 = Miễn phí, 300..500 = VIP
  final List<String> chordProgression;
  final List<SongTabNote> notes;

  const InteractiveSongItem({
    required this.id,
    required this.category,
    required this.titleVi,
    required this.titleEn,
    required this.composer,
    required this.genreBadge,
    required this.defaultBpm,
    required this.gemCost,
    required this.chordProgression,
    required this.notes,
  });

  bool get isVip => gemCost > 0;
  bool get isClassical => category == 'classical';
}

/// Hàm tiện ích tạo nốt chuẩn với file WAV thực tế 100% (`assets/audio/notes/...`).
const SongTabNote _nE3 = SongTabNote(stringNumber: 4, fret: 2, pitchKey: 'E3', noteLabel: 'Mi (E3)', audioAsset: 'assets/audio/notes/e3.wav');
const SongTabNote _nG3 = SongTabNote(stringNumber: 3, fret: 0, pitchKey: 'G3', noteLabel: 'Sol (G3)', audioAsset: 'assets/audio/notes/g3.wav');
const SongTabNote _nGs3 = SongTabNote(stringNumber: 3, fret: 1, pitchKey: 'G#3', noteLabel: 'Sol# (G#3)', audioAsset: 'assets/audio/notes/gsharp3.wav');
const SongTabNote _nA3 = SongTabNote(stringNumber: 3, fret: 2, pitchKey: 'A3', noteLabel: 'La (A3)', audioAsset: 'assets/audio/notes/a3.wav');
const SongTabNote _nB3 = SongTabNote(stringNumber: 2, fret: 0, pitchKey: 'B3', noteLabel: 'Si (B3)', audioAsset: 'assets/audio/notes/b3.wav');
const SongTabNote _nC4 = SongTabNote(stringNumber: 2, fret: 1, pitchKey: 'C4', noteLabel: 'Đô (C4)', audioAsset: 'assets/audio/notes/c4.wav');
const SongTabNote _nD4 = SongTabNote(stringNumber: 2, fret: 3, pitchKey: 'D4', noteLabel: 'Rê (D4)', audioAsset: 'assets/audio/notes/d4.wav');
const SongTabNote _nE4 = SongTabNote(stringNumber: 1, fret: 0, pitchKey: 'E4', noteLabel: 'Mi (E4)', audioAsset: 'assets/audio/notes/e4.wav');
const SongTabNote _nF4 = SongTabNote(stringNumber: 1, fret: 1, pitchKey: 'F4', noteLabel: 'Fa (F4)', audioAsset: 'assets/audio/notes/f4.wav');
const SongTabNote _nFs4 = SongTabNote(stringNumber: 1, fret: 2, pitchKey: 'F#4', noteLabel: 'Fa# (F#4)', audioAsset: 'assets/audio/notes/fsharp4.wav');
const SongTabNote _nG4 = SongTabNote(stringNumber: 1, fret: 3, pitchKey: 'G4', noteLabel: 'Sol (G4)', audioAsset: 'assets/audio/notes/g4.wav');
const SongTabNote _nGs4 = SongTabNote(stringNumber: 1, fret: 4, pitchKey: 'G#4', noteLabel: 'Sol# (G#4)', audioAsset: 'assets/audio/notes/gsharp4.wav');
const SongTabNote _nA4 = SongTabNote(stringNumber: 1, fret: 5, pitchKey: 'A4', noteLabel: 'La (A4)', audioAsset: 'assets/audio/notes/a4.wav');
const SongTabNote _nB4 = SongTabNote(stringNumber: 1, fret: 7, pitchKey: 'B4', noteLabel: 'Si (B4)', audioAsset: 'assets/audio/notes/b4.wav');
const SongTabNote _nC5 = SongTabNote(stringNumber: 1, fret: 8, pitchKey: 'C5', noteLabel: 'Đô (C5)', audioAsset: 'assets/audio/notes/c5.wav');
const SongTabNote _nCs5 = SongTabNote(stringNumber: 1, fret: 9, pitchKey: 'C#5', noteLabel: 'Đô# (C#5)', audioAsset: 'assets/audio/notes/csharp5.wav');
const SongTabNote _nD5 = SongTabNote(stringNumber: 1, fret: 10, pitchKey: 'D5', noteLabel: 'Rê (D5)', audioAsset: 'assets/audio/notes/d5.wav');
const SongTabNote _nDs5 = SongTabNote(stringNumber: 1, fret: 11, pitchKey: 'D#5', noteLabel: 'Rê# (D#5)', audioAsset: 'assets/audio/notes/dsharp5.wav');
const SongTabNote _nE5 = SongTabNote(stringNumber: 1, fret: 12, pitchKey: 'E5', noteLabel: 'Mi (E5)', audioAsset: 'assets/audio/notes/e5.wav');
const SongTabNote _nFs5 = SongTabNote(stringNumber: 1, fret: 14, pitchKey: 'F#5', noteLabel: 'Fa# (F#5)', audioAsset: 'assets/audio/notes/fsharp5.wav');
const SongTabNote _nG5 = SongTabNote(stringNumber: 1, fret: 15, pitchKey: 'G5', noteLabel: 'Sol (G5)', audioAsset: 'assets/audio/notes/g5.wav');

SongTabNote _withChord(SongTabNote base, String chord) => SongTabNote(
      stringNumber: base.stringNumber,
      fret: base.fret,
      pitchKey: base.pitchKey,
      noteLabel: base.noteLabel,
      audioAsset: base.audioAsset,
      chordSymbol: chord,
    );

/// 20 Bản Nhạc Chia 2 Nhóm Rõ Ràng: 12 Bản Cổ Điển (Public Domain 100%) + 8 Bản Hiện Đại / V-Pop & Chill Style.
final List<InteractiveSongItem> kInteractiveSongbookCatalog = [
  // ===================== NHÓM 1: 12 BẢN CỔ ĐIỂN (CLASSICAL) =====================
  InteractiveSongItem(
    id: 'song_ode_to_joy',
    category: 'classical',
    titleVi: 'Ode to Joy (Khúc Hoan Ca)',
    titleEn: 'Ode to Joy (Symphony No. 9)',
    composer: 'L. van Beethoven (1824 • Cổ điển)',
    genreBadge: 'Cổ điển • Dễ',
    defaultBpm: 96,
    gemCost: 0,
    chordProgression: ['C', 'G', 'Am', 'F', 'C', 'G', 'C'],
    notes: [
      _withChord(_nE4, 'C'), _nE4, _nF4, _withChord(_nG4, 'G'),
      _nG4, _nF4, _withChord(_nE4, 'Am'), _nD4,
      _withChord(_nC4, 'F'), _nC4, _withChord(_nD4, 'G'), _nE4,
      _nE4, _nD4, _withChord(_nC4, 'C'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_twinkle_star',
    category: 'classical',
    titleVi: 'Twinkle Twinkle Little Star',
    titleEn: 'Twinkle Twinkle Little Star',
    composer: 'W. A. Mozart (1781 • Cổ điển)',
    genreBadge: 'Cổ điển • Khởi động',
    defaultBpm: 92,
    gemCost: 0,
    chordProgression: ['C', 'F', 'C', 'G', 'C'],
    notes: [
      _withChord(_nC4, 'C'), _nC4, _nG4, _nG4,
      _withChord(_nA4, 'F'), _nA4, _withChord(_nG4, 'C'),
      _withChord(_nF4, 'F'), _nF4, _withChord(_nE4, 'C'), _nE4,
      _withChord(_nD4, 'G'), _nD4, _withChord(_nC4, 'C'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_greensleeves',
    category: 'classical',
    titleVi: 'Greensleeves (Giai Điệu Hoàng Gia)',
    titleEn: 'Greensleeves (16th Century)',
    composer: 'Dân ca Anh Thế kỷ 16 (Cổ điển)',
    genreBadge: 'Cổ điển • Waltz 3/4',
    defaultBpm: 100,
    gemCost: 0,
    chordProgression: ['Am', 'G', 'F', 'E7', 'Am'],
    notes: [
      _withChord(_nA3, 'Am'), _nC4, _withChord(_nD4, 'G'), _nE4,
      _withChord(_nF4, 'F'), _nE4, _withChord(_nD4, 'G'), _nB3,
      _nG3, _withChord(_nA3, 'Am'), _nB3, _nC4,
      _withChord(_nA3, 'E7'), _withChord(_nA3, 'Am'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_minuet_g',
    category: 'classical',
    titleVi: 'Minuet in G Major (Vũ Khúc Bach)',
    titleEn: 'Minuet in G Major (BWV Anh. 114)',
    composer: 'J. S. Bach (1725 • Cổ điển Baroque)',
    genreBadge: 'Cổ điển • Baroque',
    defaultBpm: 108,
    gemCost: 0,
    chordProgression: ['G', 'C', 'D', 'G'],
    notes: [
      _withChord(_nD4, 'G'), _nG3, _nA3, _nB3, _nC4,
      _withChord(_nD4, 'G'), _nG3, _nG3,
      _withChord(_nE4, 'C'), _nC4, _nD4, _nE4,
      _withChord(_nFs4, 'D'), _withChord(_nG4, 'G'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_happy_birthday',
    category: 'classical',
    titleVi: 'Happy Birthday (Khúc Mừng Sinh Nhật)',
    titleEn: 'Happy Birthday Classic',
    composer: 'Truyền thống Quốc tế (Public Domain)',
    genreBadge: 'Cổ điển • Phổ biến',
    defaultBpm: 104,
    gemCost: 0,
    chordProgression: ['C', 'G7', 'C', 'F', 'C', 'G7', 'C'],
    notes: [
      _withChord(_nG3, 'C'), _nG3, _nA3, _nG3, _nC4, _withChord(_nB3, 'G7'),
      _nG3, _nG3, _nA3, _nG3, _nD4, _withChord(_nC4, 'C'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_swan_lake',
    category: 'classical',
    titleVi: 'Swan Lake (Hồ Thiên Nga)',
    titleEn: 'Swan Lake Theme (Tchaikovsky)',
    composer: 'P. I. Tchaikovsky (1876 • Cổ điển)',
    genreBadge: 'Cổ điển • Giao hưởng',
    defaultBpm: 106,
    gemCost: 0,
    chordProgression: ['Am', 'F', 'Dm', 'E7', 'Am'],
    notes: [
      _withChord(_nE4, 'Am'), _nA3, _nB3, _nC4, _nD4,
      _withChord(_nE4, 'Am'), _nC4, _nE4,
      _withChord(_nC4, 'F'), _nE4, _withChord(_nA3, 'Dm'),
      _nC4, _withChord(_nB3, 'E7'), _withChord(_nA3, 'Am'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_moonlight_sonata',
    category: 'classical',
    titleVi: 'Moonlight Sonata (Khúc Ánh Trăng)',
    titleEn: 'Moonlight Sonata Op. 27 No. 2',
    composer: 'L. van Beethoven (1801 • Cổ điển)',
    genreBadge: 'VIP • Rải hợp âm',
    defaultBpm: 84,
    gemCost: 300,
    chordProgression: ['Am', 'G', 'F', 'E7', 'Am'],
    notes: [
      _withChord(_nA3, 'Am'), _nC4, _nE4, _nA3, _nC4, _nE4,
      _withChord(_nG3, 'G'), _nB3, _nE4,
      _withChord(_nA3, 'F'), _nC4, _withChord(_nE4, 'Am'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_romance_damour',
    category: 'classical',
    titleVi: 'Romance d\'Amour (Guitar Cổ Điển)',
    titleEn: 'Romance d\'Amour (Spanish Romance)',
    composer: 'Khuyết danh TK 19 (Cổ điển Tây Ban Nha)',
    genreBadge: 'VIP • Fingerstyle',
    defaultBpm: 108,
    gemCost: 300,
    chordProgression: ['Em', 'Am', 'B7', 'Em'],
    notes: [
      _withChord(_nB4, 'Em'), _nB4, _nB4, _nB4,
      _withChord(_nA4, 'Am'), _nG4, _withChord(_nFs4, 'B7'), _nE4,
      _withChord(_nG4, 'Em'), _nB4, _nE5, _withChord(_nB4, 'Em'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_vivaldi_spring',
    category: 'classical',
    titleVi: 'Vivaldi Spring (Bốn Mùa – Mùa Xuân)',
    titleEn: 'The Four Seasons: Spring (Vivaldi)',
    composer: 'Antonio Vivaldi (1725 • Cổ điển)',
    genreBadge: 'VIP • Tươi sáng',
    defaultBpm: 122,
    gemCost: 350,
    chordProgression: ['C', 'G', 'C', 'F', 'G', 'C'],
    notes: [
      _withChord(_nC4, 'C'), _nE4, _nE4, _nE4, _nD4, _nC4, _withChord(_nG4, 'G'),
      _nG4, _nF4, _withChord(_nE4, 'C'), _nE4, _nE4,
      _withChord(_nD4, 'G'), _withChord(_nC4, 'C'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_fur_elise_rock',
    category: 'classical',
    titleVi: 'Für Elise Rock & Classic (Thư Gửi Elise)',
    titleEn: 'Für Elise Rock Lead (Beethoven)',
    composer: 'L. van Beethoven (1810 • Cổ điển / Rock)',
    genreBadge: 'VIP • Lead Kinh điển',
    defaultBpm: 124,
    gemCost: 350,
    chordProgression: ['Am', 'E7', 'Am', 'C', 'G', 'Am'],
    notes: [
      _withChord(_nE5, 'Am'), _nDs5, _nE5, _nDs5, _nE5,
      _withChord(_nB4, 'E7'), _nD5, _nC5, _withChord(_nA4, 'Am'),
      _nC4, _nE4, _nA4, _withChord(_nB4, 'E7'), _withChord(_nA4, 'Am'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_turkish_march_rock',
    category: 'classical',
    titleVi: 'Turkish March Rock (Hành Khúc Thổ Nhĩ Kỳ)',
    titleEn: 'Turkish March Rock (Rondo Alla Turca)',
    composer: 'W. A. Mozart (1783 • Cổ điển / Rock)',
    genreBadge: 'VIP • Chạy ngón nhanh',
    defaultBpm: 138,
    gemCost: 400,
    chordProgression: ['Am', 'E7', 'Am', 'Dm', 'E7', 'Am'],
    notes: [
      _withChord(_nB3, 'Am'), _nA3, _nGs3, _nA3, _nC4,
      _nD4, _nC4, _nB3, _nC4, _withChord(_nE4, 'E7'),
      _withChord(_nF4, 'Dm'), _nE4, _nD4, _withChord(_nA4, 'Am'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_canon_rock',
    category: 'classical',
    titleVi: 'Canon Rock in D (Bản Solo Huyền Thoại)',
    titleEn: 'Canon Rock in D (Neo-Classical Lead)',
    composer: 'Johann Pachelbel (1680 • Phối Rock Solo)',
    genreBadge: 'BOSS VIP • 168 BPM',
    defaultBpm: 168,
    gemCost: 500,
    chordProgression: ['D5', 'A5', 'Bm', 'F#m', 'G5', 'D5', 'G5', 'A5'],
    notes: [
      _withChord(_nFs5, 'D5'), _withChord(_nE5, 'A5'), _withChord(_nD5, 'Bm'), _withChord(_nCs5, 'F#m'),
      _withChord(_nB4, 'G5'), _withChord(_nA4, 'D5'), _withChord(_nB4, 'G5'), _withChord(_nCs5, 'A5'),
      _withChord(_nD5, 'D5'), _nFs5, _withChord(_nG5, 'G5'), _withChord(_nE5, 'A5'),
      _nFs5, _nD5, _nA4, _withChord(_nD5, 'D5'),
    ],
  ),

  // ===================== NHÓM 2: 8 BẢN HIỆN ĐẠI / V-POP & CHILL STYLE =====================
  InteractiveSongItem(
    id: 'song_vpop_ballad_canon',
    category: 'modern',
    titleVi: 'Nơi Này Có Giai Điệu (Style V-Pop Ballad)',
    titleEn: 'Sweet V-Pop Ballad Hook (C-G-Am-F)',
    composer: 'Phong cách V-Pop Ballad (Kiểu Sơn Tùng M-TP)',
    genreBadge: 'Hiện đại • Miễn phí',
    defaultBpm: 94,
    gemCost: 0,
    chordProgression: ['C', 'G', 'Am', 'Em', 'F', 'C', 'Dm', 'G'],
    notes: [
      _withChord(_nE4, 'C'), _nG4, _nA4, _withChord(_nG4, 'G'),
      _nE4, _nD4, _withChord(_nC4, 'Am'), _nD4,
      _nE4, _withChord(_nF4, 'F'), _nE4, _withChord(_nD4, 'G'),
      _nE4, _withChord(_nC4, 'C'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_vpop_rain_acoustic',
    category: 'modern',
    titleVi: 'Cơn Mưa Tháng Năm (Style V-Pop Acoustic)',
    titleEn: 'Rainy Acoustic V-Pop (Am-F-C-G)',
    composer: 'Phong cách Acoustic Ballad Hiện đại',
    genreBadge: 'Hiện đại • Miễn phí',
    defaultBpm: 98,
    gemCost: 0,
    chordProgression: ['Am', 'F', 'C', 'G'],
    notes: [
      _withChord(_nE4, 'Am'), _nD4, _nC4, _nA3,
      _withChord(_nC4, 'F'), _nD4, _nE4,
      _withChord(_nG4, 'C'), _nE4, _nD4, _withChord(_nB3, 'G'),
      _nC4, _nD4, _withChord(_nA3, 'Am'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_mck_chill_rnb',
    category: 'modern',
    titleVi: 'Chìm Trong Đêm (Style Chill R&B / Rap-Melody)',
    titleEn: 'Late Night Chill R&B Hook (Style MCK)',
    composer: 'Phong cách Chill R&B / Rap-Melody (Kiểu MCK)',
    genreBadge: 'VIP • R&B Chill',
    defaultBpm: 92,
    gemCost: 300,
    chordProgression: ['Dm7', 'G7', 'Cmaj7', 'Am7'],
    notes: [
      _withChord(_nF4, 'Dm7'), _nE4, _nD4, _nC4,
      _withChord(_nB3, 'G7'), _nD4, _nG4,
      _withChord(_nE4, 'Cmaj7'), _nD4, _nC4, _nG3,
      _withChord(_nA3, 'Am7'), _nC4, _withChord(_nE4, 'Am7'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_st_pentatonic_vpop',
    category: 'modern',
    titleVi: 'Lạc Bước Cổ Trang (Style Pentatonic V-Pop)',
    titleEn: 'Eastern Pentatonic V-Pop Lead',
    composer: 'Phong cách Ngũ Cung Hiện Đại (Kiểu Sơn Tùng)',
    genreBadge: 'VIP • Ngũ cung V-Pop',
    defaultBpm: 112,
    gemCost: 350,
    chordProgression: ['Am', 'G', 'F', 'E7', 'Am'],
    notes: [
      _withChord(_nA4, 'Am'), _nG4, _nE4, _nD4, _nE4,
      _withChord(_nG4, 'G'), _nA4, _nC5, _nA4,
      _withChord(_nG4, 'F'), _nE4, _nD4,
      _withChord(_nE4, 'E7'), _withChord(_nA4, 'Am'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_lofi_rap_hook',
    category: 'modern',
    titleVi: 'Đêm Không Ngủ (Style Lo-Fi Rap Hook)',
    titleEn: 'Sleepless Lo-Fi Rap Guitar Riff',
    composer: 'Phong cách Indie / Lo-Fi Rap (Kiểu MCK & Đen)',
    genreBadge: 'VIP • Lo-Fi Chill',
    defaultBpm: 90,
    gemCost: 350,
    chordProgression: ['Em', 'C', 'G', 'D'],
    notes: [
      _withChord(_nB3, 'Em'), _nE4, _nG4, _nFs4,
      _withChord(_nE4, 'C'), _nD4, _nC4,
      _withChord(_nB3, 'G'), _nD4, _nG4,
      _withChord(_nFs4, 'D'), _nE4, _withChord(_nE3, 'Em'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_city_synth_pop',
    category: 'modern',
    titleVi: 'Ánh Đèn Thành Phố (Style Synth-Pop V-Pop)',
    titleEn: 'Neon City Synth-Pop Groove',
    composer: 'Phong cách Pop Dance Hiện đại (F-G-Em-Am)',
    genreBadge: 'VIP • Pop Dance',
    defaultBpm: 118,
    gemCost: 400,
    chordProgression: ['F', 'G', 'Em', 'Am'],
    notes: [
      _withChord(_nA4, 'F'), _nG4, _nF4, _nG4,
      _withChord(_nB4, 'G'), _nA4, _nG4,
      _withChord(_nG4, 'Em'), _nE4, _nG4, _nA4,
      _withChord(_nC5, 'Am'), _nB4, _withChord(_nA4, 'Am'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_sunset_guitar_rnb',
    category: 'modern',
    titleVi: 'Giai Điệu Hoàng Hôn (Style Guitar R&B)',
    titleEn: 'Golden Sunset R&B Guitar Groove',
    composer: 'Phong cách R&B Acoustic Hiện đại',
    genreBadge: 'VIP • R&B Guitar',
    defaultBpm: 96,
    gemCost: 400,
    chordProgression: ['C', 'E7', 'Am', 'F', 'G', 'C'],
    notes: [
      _withChord(_nG4, 'C'), _nE4, _nC4, _nD4,
      _withChord(_nGs4, 'E7'), _nE4, _nB3,
      _withChord(_nC4, 'Am'), _nE4, _nA4,
      _withChord(_nF4, 'F'), _withChord(_nG4, 'G'), _withChord(_nC5, 'C'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_epic_vpop_lead',
    category: 'modern',
    titleVi: 'Sóng Gió Biển Đêm (Style Epic V-Pop Lead)',
    titleEn: 'Midnight Waves Epic V-Pop Solo',
    composer: 'Phong cách V-Pop Cao Trào & Guitar Điện',
    genreBadge: 'VIP • Solo Cao Trào',
    defaultBpm: 128,
    gemCost: 450,
    chordProgression: ['Am', 'F', 'G', 'Em', 'F', 'G', 'Am'],
    notes: [
      _withChord(_nA4, 'Am'), _nC5, _nD5, _nE5,
      _withChord(_nD5, 'F'), _nC5, _withChord(_nB4, 'G'), _nA4,
      _withChord(_nG4, 'Em'), _nA4, _nB4,
      _withChord(_nC5, 'F'), _withChord(_nD5, 'G'), _withChord(_nE5, 'Am'),
    ],
  ),
];

/// Mở thẳng màn hình Danh sách Kho Bản Nhạc (20 bài Cổ điển & Hiện đại).
Future<void> openSongbookCatalogScreen(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  final isRouterPage = ModalRoute.of(context)?.settings is Page;
  if (router != null && isRouterPage) {
    return router.push('/songbook');
  }
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => const SongbookCatalogScreen(),
    ),
  );
}

/// Mở thẳng màn hình Vòng Tròn Bậc 5 & Dịch Giọng Capo độc lập.
Future<void> openCircleOfFifthsAndCapoScreen(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  final isRouterPage = ModalRoute.of(context)?.settings is Page;
  if (router != null && isRouterPage) {
    return router.push('/circle-of-fifths');
  }
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => const CircleOfFifthsAndCapoScreen(),
    ),
  );
}

// =============================================================================
// MÀN HÌNH 1: DANH SÁCH KHO BẢN NHẠC (CỔ ĐIỂN & HIỆN ĐẠI / V-POP)
// =============================================================================
class SongbookCatalogScreen extends ConsumerStatefulWidget {
  const SongbookCatalogScreen({super.key});

  @override
  ConsumerState<SongbookCatalogScreen> createState() =>
      _SongbookCatalogScreenState();
}

class _SongbookCatalogScreenState extends ConsumerState<SongbookCatalogScreen> {
  String _selectedCategory = 'all'; // 'all' | 'classical' | 'modern'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        loadSongbookPreferences(ref);
        loadCustomUserSongs(ref);
      }
    });
  }

  Future<void> _onTapSongCard(
    InteractiveSongItem song,
    bool isUnlocked,
  ) async {
    if (isUnlocked) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SongPlayRoomScreen(song: song),
        ),
      );
      return;
    }

    // Hộp thoại xác nhận mở khóa bản nhạc VIP bằng Gem
    final currentGems = ref.read(rewardedAdProvider).prestigePoints;
    final hasEnough = currentGems >= song.gemCost;
    final isEn = ref.read(appSettingsProvider).isEnglish;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SolfaGemIcon(size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEn ? 'Unlock VIP Track?' : 'Mở khóa bản nhạc VIP?',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isEn
                  ? '"${song.titleEn}"\n\nRequires ${song.gemCost} Gems to unlock permanently for both 6-String Guitar & Piano.\nYour balance: $currentGems Gems.'
                  : '"${song.titleVi}" (${song.composer})\n\n'
                      'Cần ${song.gemCost} Gem để mở khóa vĩnh viễn và chơi trực tiếp trên Đàn Guitar 6 Dây & Đàn Piano.\n'
                      'Số dư hiện tại của bạn: $currentGems Gem.',
              style: const TextStyle(fontSize: 13.2, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(isEn ? 'Later' : 'Để sau'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        backgroundColor: hasEnough
                            ? AppColors.primary
                            : const Color(0xFFF59E0B),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          hasEnough
                              ? (isEn
                                  ? 'Unlock (${song.gemCost}G)'
                                  : 'Mở (${song.gemCost} Gem)')
                              : (isEn ? 'Watch Ad (+100G)' : 'Xem QC (+100G)'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
    );

    if (confirmed != true || !mounted) return;
    if (!hasEnough) {
      await showSolfaRewardedVideoAdModal(context, ref);
      return;
    }

    final ok = await ref
        .read(rewardedAdProvider.notifier)
        .spendGemsForOneHourSession(gemCost: song.gemCost);
    if (!ok || !mounted) return;

    final updated = {...ref.read(unlockedVipSongsProvider), song.id};
    ref.read(unlockedVipSongsProvider.notifier).state = updated;
    unawaited(persistUnlockedVipSongs(updated));

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SongPlayRoomScreen(song: song),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = ref.watch(appSettingsProvider).isEnglish;
    final adState = ref.watch(rewardedAdProvider);
    final unlockedSongs = ref.watch(unlockedVipSongsProvider);
    final songStars = ref.watch(songbookStarsProvider);
    final customSongs = ref.watch(customUserSongsProvider);

    final allSongs = [...customSongs, ...kInteractiveSongbookCatalog];
    final classicalCount =
        kInteractiveSongbookCatalog.where((s) => s.isClassical).length;
    final modernCount =
        kInteractiveSongbookCatalog.where((s) => !s.isClassical).length;
    final filteredSongs = _selectedCategory == 'all'
        ? allSongs
        : (_selectedCategory == 'custom'
            ? customSongs
            : kInteractiveSongbookCatalog
                .where((s) => s.category == _selectedCategory)
                .toList());

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          titleSpacing: 0,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isEn ? 'Interactive Songbook' : 'Kho Bản Nhạc Tương Tác',
              maxLines: 1,
            ),
          ),
          actions: [
            TextButton.icon(
              key: const Key('btn_open_melody_composer'),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.correct.withOpacity(0.14),
                foregroundColor: AppColors.correct,
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                final created = await openCustomMelodyComposerScreen(context);
                if (created != null && context.mounted) {
                  setState(() => _selectedCategory = 'custom');
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SongPlayRoomScreen(song: created),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                isEn ? 'Compose' : 'Tự soạn',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                key: const Key('btn_songbook_header_gem'),
                borderRadius: BorderRadius.circular(99),
                onTap: () => openGemStationScreen(context),
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(isDark ? 0.16 : 0.11),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SolfaGemIcon(size: 13.5),
                      const SizedBox(width: 4),
                      Text(
                        '${adState.prestigePoints}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Thanh lọc danh mục rõ ràng: Tất cả | Cổ điển | Hiện đại | Bài của tôi
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  for (final (catId, lbl) in [
                    (
                      'all',
                      isEn
                          ? 'All (${allSongs.length})'
                          : 'Tất cả (${allSongs.length})',
                    ),
                    (
                      'classical',
                      isEn
                          ? '🎻 Classical ($classicalCount)'
                          : '🎻 Cổ điển ($classicalCount)',
                    ),
                    (
                      'modern',
                      isEn
                          ? '🎧 Modern ($modernCount)'
                          : '🎧 Hiện đại ($modernCount)',
                    ),
                    (
                      'custom',
                      isEn
                          ? '✍️ My Riffs (${customSongs.length})'
                          : '✍️ Bài của tôi (${customSongs.length})',
                    ),
                  ]) ...[
                    if (catId != 'all') const SizedBox(width: 6),
                    ChoiceChip(
                      key: Key('chip_song_cat_$catId'),
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        lbl,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _selectedCategory == catId
                              ? Colors.white
                              : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight),
                        ),
                      ),
                      selected: _selectedCategory == catId,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = catId),
                    ),
                  ],
                ],
              ),
            ),
            // Thanh nhận Gem miễn phí mở khóa bài nhạc VIP (Rewarded Video Ad chính thức)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                key: const Key('banner_songbook_watch_ad'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.14 : 0.10),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.42),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.smart_display_rounded,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEn
                            ? 'Unlock VIP tracks: Watch 15s ad for +100 Gems'
                            : 'Mở bài VIP: Xem QC 15s nhận +100 Gem miễn phí',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      key: const Key('btn_songbook_watch_ad'),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 28),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () =>
                          showSolfaRewardedVideoAdModal(context, ref),
                      icon: const SolfaGemIcon(size: 12),
                      label: const Text(
                        '+100G',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: filteredSongs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.edit_note_rounded,
                              size: 42,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isEn
                                  ? 'No custom melodies yet.\nTap "+ Compose" above to create your own!'
                                  : 'Bạn chưa có giai điệu tự soạn nào.\nBấm nút "+ Tự soạn" ở góc trên để sáng tác ngay nhé!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                key: const Key('list_songbook_catalog'),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                itemCount: filteredSongs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final song = filteredSongs[idx];
                  final isUnlocked =
                      !song.isVip || unlockedSongs.contains(song.id);
                  final stars = songStars[song.id] ?? 0;
                  final accent = song.isClassical
                      ? AppColors.primary
                      : const Color(0xFF8B5CF6);

                  return Material(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      key: Key('song_catalog_item_${song.id}'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _onTapSongCard(song, isUnlocked),
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: !isUnlocked
                                ? const Color(0xFFF59E0B).withOpacity(0.45)
                                : (isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                song.isClassical
                                    ? Icons.music_note_rounded
                                    : Icons.headphones_rounded,
                                color: accent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 3,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accent.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          song.genreBadge,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        isEn
                                            ? '${song.defaultBpm} BPM • ${song.notes.length} notes'
                                            : '${song.defaultBpm} BPM • ${song.notes.length} nốt',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isEn ? song.titleEn : song.titleVi,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    song.composer,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isUnlocked)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B)
                                        .withOpacity(0.55),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SolfaGemIcon(size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${song.gemCost}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (int s = 1; s <= 3; s++)
                                        Icon(
                                          Icons.star_rounded,
                                          size: 14,
                                          color: s <= stars
                                              ? const Color(0xFFFBBF24)
                                              : Colors.grey.withOpacity(0.32),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (song.category == 'custom') ...[
                                        InkWell(
                                          key: Key(
                                            'btn_delete_custom_song_${song.id}',
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(99),
                                          onTap: () => deleteCustomUserSong(
                                            ref,
                                            song.id,
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.all(3),
                                            child: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 16,
                                              color: AppColors.wrong,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius:
                                              BorderRadius.circular(99),
                                        ),
                                        child: Text(
                                          isEn ? 'Play' : 'Chơi ngay',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
        ),
      ),
    );
  }
}

// =============================================================================
// MÀN HÌNH 2: PHÒNG CHƠI BẢN NHẠC TƯƠNG TÁC TRỰC TIẾP TRÊN ĐÀN GUITAR / PIANO
// =============================================================================
class SongPlayRoomScreen extends ConsumerStatefulWidget {
  final InteractiveSongItem song;

  const SongPlayRoomScreen({
    super.key,
    required this.song,
  });

  @override
  ConsumerState<SongPlayRoomScreen> createState() => _SongPlayRoomScreenState();
}

class _SongPlayRoomScreenState extends ConsumerState<SongPlayRoomScreen>
    with WidgetsBindingObserver {
  bool _isPianoMode = false; // false = Cần đàn Guitar 6 dây | true = Đàn Piano
  double _speedFactor = 1.0; // 0.5 | 0.75 | 1.0
  bool _isAutoPlaying = false;
  int _currentNoteIndex = 0;
  int _hitCount = 0;
  int _attemptCount = 0;
  int _combo = 0;
  int _maxCombo = 0;
  bool _songCompleted = false;
  String? _feedbackMessage;
  Color _feedbackColor = AppColors.correct;
  Timer? _playTimer;
  AudioService? _audioServiceRef;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audioServiceRef = ref.read(audioServiceProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playTimer?.cancel();
    _audioServiceRef?.stop(includePolyphony: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopAutoPlay();
    }
  }

  void _stopAutoPlay() {
    _playTimer?.cancel();
    if (mounted) {
      setState(() => _isAutoPlaying = false);
    }
  }

  void _playNoteAudio(SongTabNote note, AudioService audio) {
    if (_isPianoMode) {
      audio.playPolyphonicAsset(note.audioAsset);
    } else {
      audio.playGuitarAsset(note.audioAsset);
    }
  }

  void _toggleAutoPlay(AudioService audio) {
    if (_isAutoPlaying) {
      _stopAutoPlay();
      return;
    }
    final effectiveBpm =
        (widget.song.defaultBpm * _speedFactor).round().clamp(35, 240);
    final intervalMs = (60000 / effectiveBpm).round();

    final isEn = ref.read(appSettingsProvider).isEnglish;
    setState(() {
      _isAutoPlaying = true;
      _songCompleted = false;
      _feedbackMessage =
          isEn ? 'Playing melody demo...' : 'Đang phát mẫu giai điệu...';
      _feedbackColor = AppColors.primary;
    });

    _playNoteAudio(widget.song.notes[_currentNoteIndex], audio);

    _playTimer?.cancel();
    _playTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!mounted) {
        _playTimer?.cancel();
        return;
      }
      final nextIdx = (_currentNoteIndex + 1) % widget.song.notes.length;
      setState(() => _currentNoteIndex = nextIdx);
      _playNoteAudio(widget.song.notes[nextIdx], audio);
    });
  }

  void _resetSong() {
    _stopAutoPlay();
    setState(() {
      _currentNoteIndex = 0;
      _hitCount = 0;
      _attemptCount = 0;
      _combo = 0;
      _maxCombo = 0;
      _songCompleted = false;
      _feedbackMessage = null;
    });
  }

  void _handleInstrumentInput({
    required bool isCorrect,
    required String playedAudioAsset,
    required String wrongHint,
    required AudioService audio,
  }) {
    _stopAutoPlay();
    if (_isPianoMode) {
      audio.playPolyphonicAsset(playedAudioAsset);
    } else {
      audio.playGuitarAsset(playedAudioAsset);
    }

    if (ref.read(appSettingsProvider).hapticFeedbackEnabled &&
        !audio.isTestMode) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }

    setState(() {
      _attemptCount++;
      if (isCorrect) {
        _hitCount++;
        _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;
        _feedbackMessage = 'PERFECT! Combo x$_combo';
        _feedbackColor = AppColors.correct;

        if (_currentNoteIndex + 1 >= widget.song.notes.length) {
          _songCompleted = true;
          final acc = _attemptCount > 0 ? (_hitCount / _attemptCount) : 1.0;
          final earnedStars = acc >= 0.9 ? 3 : (acc >= 0.7 ? 2 : 1);
          final prevStars =
              ref.read(songbookStarsProvider)[widget.song.id] ?? 0;
          if (earnedStars > prevStars) {
            final nextMap = {
              ...ref.read(songbookStarsProvider),
              widget.song.id: earnedStars,
            };
            ref.read(songbookStarsProvider.notifier).state = nextMap;
            unawaited(persistSongbookStars(nextMap));
          }
          audio.playSessionCompleteFanfare();
        } else {
          _currentNoteIndex++;
        }
      } else {
        _combo = 0;
        _feedbackMessage = wrongHint;
        _feedbackColor = AppColors.wrong;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = ref.watch(appSettingsProvider).isEnglish;
    final audio = ref.watch(audioServiceProvider);
    final guitarType = ref.watch(selectedGuitarTypeProvider);
    audio.setGuitarType(guitarType);
    final song = widget.song;
    final currentNote = song.notes[_currentNoteIndex];
    final accuracyPct = _attemptCount > 0
        ? ((_hitCount / _attemptCount) * 100).round()
        : 100;
    final progress = (_songCompleted
            ? 1.0
            : (_currentNoteIndex / song.notes.length))
        .clamp(0.0, 1.0);

    // Tự động tính khung 6 ngăn Guitar xoay quanh nốt hiện tại (vd: 0..5 hoặc 7..12 hoặc 10..15 cho Canon Rock!)
    final int windowStartFret = currentNote.fret <= 5
        ? 0
        : (currentNote.fret <= 10 ? 5 : 10);
    final int windowEndFret = windowStartFret + 5;

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          titleSpacing: 0,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isEn ? song.titleEn : song.titleVi,
              maxLines: 1,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.correct.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'x$_combo • $accuracyPct%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.correct,
                    ),
                  ),
                ),
              ),
            ),
            const SolfaHeaderGemPill(),
          ],
        ),
        body: SafeArea(
          child: ListView(
            key: const Key('song_play_room_view'),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
            children: [
              // 1. Chọn Nhạc cụ chơi trực tiếp: Đàn Guitar 6 Dây <-> Đàn Piano
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      key: const Key('chip_playroom_guitar'),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn ? '🎸 Play Guitar' : '🎸 Chơi bằng Đàn Guitar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: !_isPianoMode
                                ? Colors.white
                                : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                          ),
                        ),
                      ),
                      selected: !_isPianoMode,
                      onSelected: (_) => setState(() => _isPianoMode = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      key: const Key('chip_playroom_piano'),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn ? '🎹 Play Piano' : '🎹 Chơi bằng Đàn Piano',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _isPianoMode
                                ? Colors.white
                                : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                          ),
                        ),
                      ),
                      selected: _isPianoMode,
                      onSelected: (_) => setState(() => _isPianoMode = true),
                    ),
                  ),
                ],
              ),
              if (!_isPianoMode) ...[
                const SizedBox(height: 8),
                const GuitarTypeSwitchBar(),
              ],
              const SizedBox(height: 10),

              // 2. Thanh Tốc độ (50%/75%/100%) + Nghe mẫu + Làm lại (Gọn 1 hàng không tràn mép phải!)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (final spd in const [0.5, 0.75, 1.0]) ...[
                          if (spd != 0.5) const SizedBox(width: 4),
                          Expanded(
                            child: InkWell(
                              key: Key('chip_play_speed_${(spd * 100).round()}'),
                              borderRadius: BorderRadius.circular(9),
                              onTap: () {
                                setState(() => _speedFactor = spd);
                                if (_isAutoPlaying) {
                                  _stopAutoPlay();
                                  _toggleAutoPlay(audio);
                                }
                              },
                              child: Container(
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _speedFactor == spd
                                      ? AppColors.primary
                                      : AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  '${(spd * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: _speedFactor == spd
                                        ? Colors.white
                                        : (isDark
                                            ? AppColors.textPrimaryDark
                                            : AppColors.textPrimaryLight),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              key: const Key('btn_songbook_autoplay'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isAutoPlaying
                                    ? AppColors.wrong
                                    : AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 32),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              onPressed: () => _toggleAutoPlay(audio),
                              icon: Icon(
                                _isAutoPlaying
                                    ? Icons.stop_rounded
                                    : Icons.play_arrow_rounded,
                                size: 16,
                              ),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _isAutoPlaying
                                      ? (isEn ? 'Stop' : 'Dừng mẫu')
                                      : (isEn ? 'Demo' : 'Nghe mẫu'),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 34,
                          height: 32,
                          child: IconButton(
                            key: const Key('btn_song_reset'),
                            padding: EdgeInsets.zero,
                            tooltip: isEn ? 'Restart' : 'Chơi lại từ đầu',
                            onPressed: _resetSong,
                            icon: const Icon(Icons.replay_rounded, size: 19),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.correct,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. Hàng Nốt Chạy Đúng Thứ Tự Từ Trái Sang Phải (Nốt Hiện Tại -> Các Nốt Sắp Tới)
              RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _songCompleted
                                  ? (isEn
                                      ? '🎉 Completed "${song.titleEn}"!'
                                      : '🎉 Hoàn thành xuất sắc bài "${song.titleVi}"!')
                                  : (isEn
                                      ? 'Note #${_currentNoteIndex + 1}/${song.notes.length}: ${currentNote.pitchKey} (${_isPianoMode ? 'Key ${currentNote.pitchKey}' : 'String ${currentNote.stringNumber} • Fret ${currentNote.fret}'})'
                                      : 'Nốt #${_currentNoteIndex + 1}/${song.notes.length}: ${currentNote.noteLabel} (${_isPianoMode ? 'Phím ${currentNote.pitchKey}' : 'Dây ${currentNote.stringNumber} • Ngăn ${currentNote.fret}'})'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                          if (currentNote.chordSymbol != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFF59E0B).withOpacity(0.22),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                currentNote.chordSymbol!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFBBF24),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Hiển thị 5 nốt kế tiếp nhau từ trái sang phải (Nốt hiện tại luôn đứng ĐẦU bên trái!)
                      Row(
                        children: [
                          for (int offset = 0; offset < 5; offset++) ...[
                            if (offset > 0) const SizedBox(width: 6),
                            Expanded(
                              child: Builder(
                                builder: (_) {
                                  final idx = _currentNoteIndex + offset;
                                  if (idx >= song.notes.length) {
                                    return Container(
                                      height: 66,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.03),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white10,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        isEn ? 'End' : 'Hết',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white24,
                                        ),
                                      ),
                                    );
                                  }
                                  final n = song.notes[idx];
                                  final isCurrent = offset == 0 && !_songCompleted;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    height: 66,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? AppColors.primary
                                          : Colors.white.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isCurrent
                                            ? const Color(0xFF38BDF8)
                                            : Colors.white12,
                                        width: isCurrent ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            isCurrent
                                                ? (isEn ? 'PLAY NOW' : 'BẤM NGAY')
                                                : '#${idx + 1}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: isCurrent
                                                  ? const Color(0xFFFDE047)
                                                  : Colors.white54,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            _isPianoMode
                                                ? n.pitchKey
                                                : 'D${n.stringNumber}•Ng${n.fret}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            n.noteLabel.split(' ').first,
                                            maxLines: 1,
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              color: Color(0xFF93C5FD),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_feedbackMessage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _feedbackColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _feedbackMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: _feedbackColor == AppColors.correct
                                  ? const Color(0xFF4ADE80)
                                  : (_feedbackColor == AppColors.wrong
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFF93C5FD)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 4. CÂY ĐÀN TƯƠNG TÁC TRỰC TIẾP (BẤM THẲNG VÀO DÂY/NGĂN GUITAR HOẶC PHÍM PIANO ĐANG SÁNG!)
              if (_songCompleted)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.correct.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.correct.withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isEn
                            ? '🎉 SONG COMPLETED!'
                            : '🎉 HOÀN THÀNH BẢN NHẠC!',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.correct,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int s = 1; s <= 3; s++)
                            Icon(
                              Icons.star_rounded,
                              size: 28,
                              color: s <=
                                      (accuracyPct >= 90
                                          ? 3
                                          : (accuracyPct >= 70 ? 2 : 1))
                                  ? const Color(0xFFFBBF24)
                                  : Colors.grey.withOpacity(0.32),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isEn
                            ? 'Accuracy: $accuracyPct% • Best Combo: x$_maxCombo'
                            : 'Độ chính xác: $accuracyPct% • Combo tối đa: x$_maxCombo',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          key: const Key('btn_song_complete_watch_ad'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 42),
                          ),
                          onPressed: () =>
                              showSolfaRewardedVideoAdModal(context, ref),
                          icon: const Icon(
                            Icons.smart_display_rounded,
                            size: 18,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isEn
                                  ? 'Bonus: Watch 15s Ad (+100 Gems & +1 Turn)'
                                  : 'Thưởng thêm: Xem QC 15s (+100 Gem & +1 Lượt Đấu)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(isEn ? 'Other Songs' : 'Chọn bài khác'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _resetSong,
                              child: Text(isEn ? 'Play Again' : 'Chơi lại'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else if (!_isPianoMode)
                _buildInteractivePlayableGuitarBoard(
                  currentNote: currentNote,
                  windowStartFret: windowStartFret,
                  windowEndFret: windowEndFret,
                  audio: audio,
                  isEn: isEn,
                )
              else
                _buildInteractivePlayablePianoBoard(
                  currentNote: currentNote,
                  audio: audio,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cần đàn Guitar 6 dây tương tác trực tiếp (căn khung 6 ngăn xoay quanh nốt hiện tại để dễ chạm bằng ngón tay).
  Widget _buildInteractivePlayableGuitarBoard({
    required SongTabNote currentNote,
    required int windowStartFret,
    required int windowEndFret,
    required AudioService audio,
    required bool isEn,
  }) {
    const stringLabels = ['d1 (e4)', 'd2 (B3)', 'd3 (G3)', 'd4 (D3)', 'd5 (A2)', 'd6 (E2)'];

    return Container(
      key: const Key('playable_guitar_board'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF231811),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD97706).withOpacity(0.55),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn
                ? '🎸 Tap the highlighted fret cell (Frets $windowStartFret–$windowEndFret)'
                : '🎸 Chạm đúng ô đang sáng trên cần đàn (Ngăn $windowStartFret–$windowEndFret)',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFDE047),
            ),
          ),
          const SizedBox(height: 8),
          // Header số ngăn
          Row(
            children: [
              const SizedBox(width: 54),
              for (int f = windowStartFret; f <= windowEndFret; f++)
                Expanded(
                  child: Center(
                    child: Text(
                      f == 0
                          ? (isEn ? 'Open' : 'Buông')
                          : (isEn ? 'Fr.$f' : 'Ng.$f'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: f == currentNote.fret
                            ? const Color(0xFF38BDF8)
                            : Colors.white60,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // 6 Dây đàn có thể chạm từng ô
          for (int s = 1; s <= 6; s++)
            SizedBox(
              height: 42,
              child: Row(
                children: [
                  SizedBox(
                    width: 54,
                    child: Text(
                      stringLabels[s - 1],
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: s == currentNote.stringNumber
                            ? const Color(0xFFFDE047)
                            : Colors.white70,
                      ),
                    ),
                  ),
                  for (int f = windowStartFret; f <= windowEndFret; f++)
                    Expanded(
                      child: InkWell(
                        key: Key('play_guitar_cell_s${s}_f$f'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          final tappedInfo = GuitarFretboardData.noteAt(
                            stringNumber: s,
                            fret: f,
                          );
                          final isMatch = s == currentNote.stringNumber &&
                              f == currentNote.fret;
                          _handleInstrumentInput(
                            isCorrect: isMatch,
                            playedAudioAsset: isMatch
                                ? currentNote.audioAsset
                                : tappedInfo.audioAsset,
                            wrongHint:
                                'Chưa đúng! Hãy chạm vào Dây ${currentNote.stringNumber} • Ngăn ${currentNote.fret} (${currentNote.noteLabel})',
                            audio: audio,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: f == 0
                                    ? const Color(0xFFFDE68A)
                                    : Colors.white24,
                                width: f == 0 ? 2.5 : 1.0,
                              ),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 1.2 + (s * 0.32),
                                color: s >= 4
                                    ? const Color(0xFFD97706).withOpacity(0.75)
                                    : Colors.white54,
                              ),
                              if (s == currentNote.stringNumber &&
                                  f == currentNote.fret)
                                Container(
                                  width: 34,
                                  height: 30,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: const Color(0xFFFDE047),
                                      width: 2.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF38BDF8)
                                            .withOpacity(0.55),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    f == 0 ? '0' : '$f',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
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
            ),
        ],
      ),
    );
  }

  /// Bàn phím Đàn Piano tương tác trực tiếp (tự động chọn đúng quãng tám chứa nốt cần bấm để bấm cực dễ!).
  Widget _buildInteractivePlayablePianoBoard({
    required SongTabNote currentNote,
    required AudioService audio,
  }) {
    final targetOctave = currentNote.pitchKey.endsWith('5')
        ? 5
        : (currentNote.pitchKey.endsWith('3') ? 3 : 4);
    final whiteKeys = [
      ('C$targetOctave', 'Đô', 'assets/audio/notes/c$targetOctave.wav'),
      ('D$targetOctave', 'Rê', 'assets/audio/notes/d$targetOctave.wav'),
      ('E$targetOctave', 'Mi', 'assets/audio/notes/e$targetOctave.wav'),
      ('F$targetOctave', 'Fa', 'assets/audio/notes/f$targetOctave.wav'),
      ('G$targetOctave', 'Sol', 'assets/audio/notes/g$targetOctave.wav'),
      ('A$targetOctave', 'La', 'assets/audio/notes/a$targetOctave.wav'),
      ('B$targetOctave', 'Si', 'assets/audio/notes/b$targetOctave.wav'),
    ];
    final blackKeys = [
      (0, 'C#$targetOctave', 'Đô#', 'assets/audio/notes/csharp$targetOctave.wav'),
      (1, 'D#$targetOctave', 'Rê#', 'assets/audio/notes/dsharp$targetOctave.wav'),
      (3, 'F#$targetOctave', 'Fa#', 'assets/audio/notes/fsharp$targetOctave.wav'),
      (4, 'G#$targetOctave', 'Sol#', 'assets/audio/notes/gsharp$targetOctave.wav'),
      (5, 'A#$targetOctave', 'La#', 'assets/audio/notes/asharp$targetOctave.wav'),
    ];

    return Container(
      key: const Key('playable_piano_board'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.5),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎹 Bấm đúng phím Piano đang phát sáng (Quãng tám $targetOctave)',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFDE047),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 175,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final whiteW = constraints.maxWidth / whiteKeys.length;
                final blackW = whiteW * 0.62;
                return Stack(
                  children: [
                    // 7 Phím trắng
                    Row(
                      children: [
                        for (final (pk, vn, asset) in whiteKeys)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1.5),
                              child: InkWell(
                                key: Key('play_piano_key_$pk'),
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(10),
                                ),
                                onTap: () {
                                  final isMatch = pk == currentNote.pitchKey;
                                  _handleInstrumentInput(
                                    isCorrect: isMatch,
                                    playedAudioAsset: asset,
                                    wrongHint:
                                        'Sai phím! Hãy bấm phím ${currentNote.noteLabel}',
                                    audio: audio,
                                  );
                                },
                                child: Container(
                                  alignment: Alignment.bottomCenter,
                                  padding: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: pk == currentNote.pitchKey
                                        ? const Color(0xFF38BDF8)
                                        : Colors.white,
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(10),
                                    ),
                                    border: Border.all(
                                      color: pk == currentNote.pitchKey
                                          ? const Color(0xFFFDE047)
                                          : Colors.black26,
                                      width: pk == currentNote.pitchKey ? 2.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        vn,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: pk == currentNote.pitchKey
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        pk,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: pk == currentNote.pitchKey
                                              ? Colors.white
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // 5 Phím đen
                    for (final (slot, pk, vn, asset) in blackKeys)
                      Positioned(
                        left: (slot + 1) * whiteW - (blackW / 2),
                        top: 0,
                        width: blackW,
                        height: 104,
                        child: InkWell(
                          key: Key('play_piano_key_$pk'),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(8),
                          ),
                          onTap: () {
                            final isMatch = pk == currentNote.pitchKey;
                            _handleInstrumentInput(
                              isCorrect: isMatch,
                              playedAudioAsset: asset,
                              wrongHint:
                                  'Sai phím! Hãy bấm phím ${currentNote.noteLabel}',
                              audio: audio,
                            );
                          },
                          child: Container(
                            alignment: Alignment.bottomCenter,
                            padding: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: pk == currentNote.pitchKey
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF1F2937),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(8),
                              ),
                              border: Border.all(
                                color: pk == currentNote.pitchKey
                                    ? const Color(0xFFFDE047)
                                    : Colors.black,
                                width: pk == currentNote.pitchKey ? 2.2 : 1,
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                vn,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MÀN HÌNH 3: VÒNG TRÒN BẬC 5 (CIRCLE OF FIFTHS) & MÁY DỊCH GIỌNG CAPO ĐỘC LẬP
// =============================================================================
class CircleOfFifthsAndCapoScreen extends ConsumerStatefulWidget {
  const CircleOfFifthsAndCapoScreen({super.key});

  @override
  ConsumerState<CircleOfFifthsAndCapoScreen> createState() =>
      _CircleOfFifthsAndCapoScreenState();
}

class _CircleOfFifthsAndCapoScreenState
    extends ConsumerState<CircleOfFifthsAndCapoScreen> {
  int _selectedCircleKeyIndex = 0;
  int _transposeSemitones = 0;
  String _selectedProgressionPresetId = 'canon';

  static const List<(String major, String minor, String sharpsFlats, List<String> diatonicChords, List<String> chordAudio)>
      _circleOfFifthsKeys = [
    ('C', 'Am', '0 dấu hóa', ['C', 'Dm', 'Em', 'F', 'G', 'Am'], ['assets/audio/keys/chord_c_maj.wav', 'assets/audio/keys/chord_d_min.wav', 'assets/audio/keys/chord_e_min.wav', 'assets/audio/keys/chord_f_maj.wav', 'assets/audio/keys/chord_g_maj.wav', 'assets/audio/keys/chord_a_min.wav']),
    ('G', 'Em', '1 dấu # (F#)', ['G', 'Am', 'Bm', 'C', 'D', 'Em'], ['assets/audio/keys/chord_g_maj.wav', 'assets/audio/keys/chord_a_min.wav', 'assets/audio/keys/chord_b_min.wav', 'assets/audio/keys/chord_c_maj.wav', 'assets/audio/keys/chord_d_maj.wav', 'assets/audio/keys/chord_e_min.wav']),
    ('D', 'Bm', '2 dấu # (F#, C#)', ['D', 'Em', 'F#m', 'G', 'A', 'Bm'], ['assets/audio/keys/chord_d_maj.wav', 'assets/audio/keys/chord_e_min.wav', 'assets/audio/keys/chord_fsharp_min.wav', 'assets/audio/keys/chord_g_maj.wav', 'assets/audio/keys/chord_a_maj.wav', 'assets/audio/keys/chord_b_min.wav']),
    ('A', 'F#m', '3 dấu #', ['A', 'Bm', 'C#m', 'D', 'E', 'F#m'], ['assets/audio/keys/chord_a_maj.wav', 'assets/audio/keys/chord_b_min.wav', 'assets/audio/keys/chord_c_min.wav', 'assets/audio/keys/chord_d_maj.wav', 'assets/audio/keys/chord_e_maj.wav', 'assets/audio/keys/chord_fsharp_min.wav']),
    ('E', 'C#m', '4 dấu #', ['E', 'F#m', 'G#m', 'A', 'B', 'C#m'], ['assets/audio/keys/chord_e_maj.wav', 'assets/audio/keys/chord_fsharp_min.wav', 'assets/audio/keys/chord_g_min.wav', 'assets/audio/keys/chord_a_maj.wav', 'assets/audio/keys/chord_b_maj.wav', 'assets/audio/keys/chord_c_min.wav']),
    ('F', 'Dm', '1 dấu b (Bb)', ['F', 'Gm', 'Am', 'Bb', 'C', 'Dm'], ['assets/audio/keys/chord_f_maj.wav', 'assets/audio/keys/chord_g_min.wav', 'assets/audio/keys/chord_a_min.wav', 'assets/audio/keys/chord_bb_maj.wav', 'assets/audio/keys/chord_c_maj.wav', 'assets/audio/keys/chord_d_min.wav']),
  ];

  static const List<String> _chromaticRoots = [
    'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'
  ];

  static String _transposeChordSymbol(String chord, int semitones) {
    if (semitones == 0) return chord;
    String root = chord;
    String suffix = '';
    if (chord.length >= 2 && (chord[1] == '#' || chord[1] == 'b')) {
      root = chord.substring(0, 2);
      suffix = chord.substring(2);
    } else if (chord.isNotEmpty) {
      root = chord.substring(0, 1);
      suffix = chord.substring(1);
    }
    const alias = {'Db': 'C#', 'D#': 'Eb', 'Gb': 'F#', 'G#': 'Ab', 'A#': 'Bb'};
    final normalizedRoot = alias[root] ?? root;
    final idx = _chromaticRoots.indexOf(normalizedRoot);
    if (idx < 0) return chord;
    final newIdx = (idx + semitones) % 12;
    final wrappedIdx = newIdx < 0 ? newIdx + 12 : newIdx;
    return '${_chromaticRoots[wrappedIdx]}$suffix';
  }

  /// Phát chuẩn xác từng hợp âm trong Vòng Tròn Bậc 5 (dùng file WAV hợp âm thật; với C#m & G#m rải 3 nốt hợp âm thật đa âm để chuẩn cao độ 100%).
  void _playCircleChord(String chordSymbol, String fallbackAsset, AudioService audio) {
    final List<String>? customTriad = switch (chordSymbol) {
      'C#m' => const [
          'assets/audio/notes/csharp3.wav',
          'assets/audio/notes/e3.wav',
          'assets/audio/notes/gsharp3.wav',
        ],
      'G#m' => const [
          'assets/audio/notes/gsharp3.wav',
          'assets/audio/notes/b3.wav',
          'assets/audio/notes/dsharp4.wav',
        ],
      _ => null,
    };
    if (customTriad != null) {
      for (int i = 0; i < customTriad.length; i++) {
        Future<void>.delayed(Duration(milliseconds: i * 28), () {
          if (mounted) audio.playGuitarAsset(customTriad[i]);
        });
      }
      return;
    }
    audio.playGuitarAsset(fallbackAsset);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = ref.watch(appSettingsProvider).isEnglish;
    final audio = ref.watch(audioServiceProvider);
    audio.setGuitarType(ref.watch(selectedGuitarTypeProvider));
    final currentKey = _circleOfFifthsKeys[_selectedCircleKeyIndex];
    final baseProgression = _selectedProgressionPresetId == 'canon'
        ? const ['D', 'A', 'Bm', 'F#m', 'G', 'D', 'G', 'A']
        : (_selectedProgressionPresetId == 'pop'
            ? const ['C', 'G', 'Am', 'F']
            : const ['F#m', 'D', 'A', 'E']);
    final transposedChords = [
      for (final c in baseProgression)
        _transposeChordSymbol(c, _transposeSemitones),
    ];
    final recommendedCapoFret = _selectedProgressionPresetId == 'canon'
        ? 2
        : (_selectedProgressionPresetId == 'ballad_fsharp' ? 2 : 0);

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          titleSpacing: 0,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isEn
                  ? 'Circle of Fifths & Capo'
                  : 'Vòng Tròn Bậc 5 & Dịch Capo',
              maxLines: 1,
            ),
          ),
          actions: const [
            SolfaHeaderGemPill(),
          ],
        ),
        body: ListView(
          key: const Key('screen_circle_fifths_capo'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            // 1. Vòng Tròn Hòa Âm Bậc 5
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn
                        ? '1. Interactive Circle of Fifths (Tap Key & Hear Chords)'
                        : '1. Vòng Tròn Hòa Âm Bậc 5 (Chọn Giọng & Nghe Hợp Âm)',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (int i = 0; i < _circleOfFifthsKeys.length; i++)
                        ChoiceChip(
                          key: Key(
                              'chip_circle_key_${_circleOfFifthsKeys[i].$1}'),
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${_circleOfFifthsKeys[i].$1} / ${_circleOfFifthsKeys[i].$2}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: _selectedCircleKeyIndex == i
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight),
                            ),
                          ),
                          selected: _selectedCircleKeyIndex == i,
                          onSelected: (_) =>
                              setState(() => _selectedCircleKeyIndex = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Giọng ${currentKey.$1} Trưởng / ${currentKey.$2} Thứ • Hóa biểu: ${currentKey.$3}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.secondary : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (int cIdx = 0;
                          cIdx < currentKey.$4.length;
                          cIdx++) ...[
                        if (cIdx > 0) const SizedBox(width: 6),
                        Expanded(
                          child: InkWell(
                            key: Key('btn_circle_chord_${currentKey.$4[cIdx]}'),
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              _playCircleChord(
                                currentKey.$4[cIdx],
                                currentKey.$5[cIdx],
                                audio,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.35),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    const ['I', 'ii', 'iii', 'IV', 'V', 'vi']
                                        [cIdx],
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? const Color(0xFF93C5FD)
                                          : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      currentKey.$4[cIdx],
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.primaryDark,
                                      ),
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
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Máy Dịch Giọng & Gợi ý Kẹp Capo
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn
                        ? '2. Smart Chord Transposer & Capo Calculator'
                        : '2. Máy Dịch Giọng Hợp Âm & Gợi Ý Kẹp Capo Thông Minh',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (pId, pLbl) in const [
                        ('canon', 'Vòng Canon in D'),
                        ('pop', 'Vòng Pop C-G-Am-F'),
                        ('ballad_fsharp', 'Vòng Ballad F#m-D-A-E'),
                      ])
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            pLbl,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: _selectedProgressionPresetId == pId
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight),
                            ),
                          ),
                          selected: _selectedProgressionPresetId == pId,
                          onSelected: (_) => setState(
                            () => _selectedProgressionPresetId = pId,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEn ? 'Transpose:' : 'Dịch nửa cung:',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        key: const Key('btn_transpose_down'),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => setState(
                          () => _transposeSemitones =
                              (_transposeSemitones - 1).clamp(-6, 6),
                        ),
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          size: 22,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isEn
                              ? (_transposeSemitones > 0
                                  ? '+$_transposeSemitones st'
                                  : '$_transposeSemitones st')
                              : (_transposeSemitones > 0
                                  ? '+$_transposeSemitones bán âm'
                                  : '$_transposeSemitones bán âm'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('btn_transpose_up'),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => setState(
                          () => _transposeSemitones =
                              (_transposeSemitones + 1).clamp(-6, 6),
                        ),
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kết quả dịch giọng: ${transposedChords.join('  →  ')}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (recommendedCapoFret > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            '💡 Gợi ý Kẹp Capo Ngăn $recommendedCapoFret: Bấm thế hợp âm mở (${[for (final c in baseProgression) _transposeChordSymbol(c, -recommendedCapoFret)].join(' - ')}) để giảm hợp âm chặn!',
                            style: const TextStyle(
                              fontSize: 11.8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.correct,
                            ),
                          ),
                        ],
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

/// Máy Đo Cao Độ Chuẩn Hz (A4 = 432/440/442 Hz), Đồng Hồ Kim Cents (±50c) & Thử Thách Cân Chỉnh Dây Đàn
class ChromaticCentsTunerChallengeCard extends ConsumerStatefulWidget {
  final int activeStringNumber; // 1..6
  final ValueChanged<int>? onSelectString;

  const ChromaticCentsTunerChallengeCard({
    super.key,
    required this.activeStringNumber,
    this.onSelectString,
  });

  @override
  ConsumerState<ChromaticCentsTunerChallengeCard> createState() =>
      _ChromaticCentsTunerChallengeCardState();
}

class _ChromaticCentsTunerChallengeCardState
    extends ConsumerState<ChromaticCentsTunerChallengeCard> {
  int _referenceA4Hz = 440; // 432 | 440 | 442
  int _centsOffset = 0; // -50 .. +50 cents
  bool _isChallengeActive = false;
  int _challengeSolvedCount = 0;

  static const Map<int, (String note, double baseHz440, String asset)>
      _standardStringData = {
    6: ('E2 (Mi trầm)', 82.4, 'assets/audio/notes/e2.wav'),
    5: ('A2 (La)', 110.0, 'assets/audio/notes/a2.wav'),
    4: ('D3 (Rê)', 146.8, 'assets/audio/notes/d3.wav'),
    3: ('G3 (Sol)', 196.0, 'assets/audio/notes/g3.wav'),
    2: ('B3 (Si)', 246.9, 'assets/audio/notes/b3.wav'),
    1: ('E4 (Mi cao)', 329.6, 'assets/audio/notes/e4.wav'),
  };

  void _startTuningChallenge(AudioService audio) {
    final rng = math.Random();
    final randomOffset = (rng.nextBool() ? 1 : -1) * (15 + rng.nextInt(30));
    setState(() {
      _isChallengeActive = true;
      _centsOffset = randomOffset;
    });
    final info = _standardStringData[widget.activeStringNumber]!;
    audio.playGuitarAsset(info.$3);
  }

  void _adjustTuningPeg(int deltaCents, AudioService audio) {
    final next = (_centsOffset + deltaCents).clamp(-50, 50);
    setState(() {
      _centsOffset = next;
      if (_isChallengeActive && next.abs() <= 3) {
        _centsOffset = 0;
        _isChallengeActive = false;
        _challengeSolvedCount++;
      }
    });
    final info = _standardStringData[widget.activeStringNumber]!;
    audio.playGuitarAsset(info.$3);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final audio = ref.watch(audioServiceProvider);
    final info = _standardStringData[widget.activeStringNumber] ??
        _standardStringData[6]!;
    final targetHz = info.$2 * (_referenceA4Hz / 440.0);
    final currentHz = targetHz * math.pow(2.0, _centsOffset / 1200.0);
    final isInTune = _centsOffset.abs() <= 3;

    return Container(
      key: const Key('card_chromatic_cents_tuner'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isInTune
              ? AppColors.correct.withOpacity(0.55)
              : const Color(0xFFF59E0B).withOpacity(0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Máy Đo Tần Số (A4 = $_referenceA4Hz Hz) • Chuẩn: $_challengeSolvedCount dây',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final hz in const [432, 440, 442]) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: InkWell(
                    key: Key('btn_ref_a4_$hz'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => setState(() => _referenceA4Hz = hz),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _referenceA4Hz == hz
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        '${hz}Hz',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _referenceA4Hz == hz ? Colors.white : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                '♭ -50c',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final normalized =
                        ((_centsOffset + 50) / 100.0).clamp(0.0, 1.0);
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 3,
                            height: 14,
                            color: AppColors.correct,
                          ),
                        ),
                        Positioned(
                          left: (constraints.maxWidth - 14) * normalized,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isInTune
                                  ? AppColors.correct
                                  : const Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '+50c ♯',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dây ${widget.activeStringNumber} (${info.$1}): ${currentHz.toStringAsFixed(1)} Hz (${_centsOffset > 0 ? '+$_centsOffset' : '$_centsOffset'}c)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color:
                        isInTune ? AppColors.correct : const Color(0xFFF59E0B),
                  ),
                ),
              ),
              if (!_isChallengeActive)
                TextButton.icon(
                  key: const Key('btn_start_ear_tuning_challenge'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _startTuningChallenge(audio),
                  icon: const Icon(Icons.hearing_rounded, size: 14),
                  label: const Text(
                    'Vặn Khóa Đàn',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final step in const [-10, -2, 2, 10])
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: InkWell(
                          key: Key('btn_tune_peg_$step'),
                          onTap: () => _adjustTuningPeg(step, audio),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              step > 0 ? '+${step}c' : '${step}c',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
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
