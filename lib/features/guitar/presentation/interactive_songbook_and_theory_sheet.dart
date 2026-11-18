import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../core/audio/audio_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';
import '../../support_developer/presentation/support_developer_screen.dart';

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

/// Một nốt trong bản nhạc Tab chạy tương tác (6 dây Guitar & Cao độ Piano tương ứng).
class SongTabNote {
  final int stringNumber; // 1 (e4) .. 6 (E2)
  final int fret; // 0..15
  final String noteLabel; // e.g., 'F#4 (Fa#)'
  final String audioAsset;
  final String? chordSymbol;

  const SongTabNote({
    required this.stringNumber,
    required this.fret,
    required this.noteLabel,
    required this.audioAsset,
    this.chordSymbol,
  });
}

/// Mô hình Bản Nhạc Tương Tác (Public Domain Classics & Rock Arrangements).
class InteractiveSongItem {
  final String id;
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
}

const List<InteractiveSongItem> kInteractiveSongbookCatalog = [
  InteractiveSongItem(
    id: 'song_ode_to_joy',
    titleVi: 'Ode to Joy (Khúc Hoan Ca)',
    titleEn: 'Ode to Joy (Symphony No. 9)',
    composer: 'L. van Beethoven (1824 • Public Domain)',
    genreBadge: 'Cổ điển • Dễ',
    defaultBpm: 96,
    gemCost: 0,
    chordProgression: ['C', 'G', 'Am', 'F', 'C', 'G', 'C'],
    notes: [
      SongTabNote(stringNumber: 1, fret: 0, noteLabel: 'Mi (E4)', audioAsset: 'audio/notes/E4.wav', chordSymbol: 'C'),
      SongTabNote(stringNumber: 1, fret: 0, noteLabel: 'Mi (E4)', audioAsset: 'audio/notes/E4.wav'),
      SongTabNote(stringNumber: 1, fret: 1, noteLabel: 'Fa (F4)', audioAsset: 'audio/notes/F4.wav'),
      SongTabNote(stringNumber: 1, fret: 3, noteLabel: 'Sol (G4)', audioAsset: 'audio/notes/G4.wav', chordSymbol: 'G'),
      SongTabNote(stringNumber: 1, fret: 3, noteLabel: 'Sol (G4)', audioAsset: 'audio/notes/G4.wav'),
      SongTabNote(stringNumber: 1, fret: 1, noteLabel: 'Fa (F4)', audioAsset: 'audio/notes/F4.wav'),
      SongTabNote(stringNumber: 1, fret: 0, noteLabel: 'Mi (E4)', audioAsset: 'audio/notes/E4.wav', chordSymbol: 'Am'),
      SongTabNote(stringNumber: 2, fret: 3, noteLabel: 'Rê (D4)', audioAsset: 'audio/notes/D4.wav'),
      SongTabNote(stringNumber: 2, fret: 1, noteLabel: 'Đô (C4)', audioAsset: 'audio/notes/C4.wav', chordSymbol: 'F'),
      SongTabNote(stringNumber: 2, fret: 1, noteLabel: 'Đô (C4)', audioAsset: 'audio/notes/C4.wav'),
      SongTabNote(stringNumber: 2, fret: 3, noteLabel: 'Rê (D4)', audioAsset: 'audio/notes/D4.wav', chordSymbol: 'G'),
      SongTabNote(stringNumber: 1, fret: 0, noteLabel: 'Mi (E4)', audioAsset: 'audio/notes/E4.wav'),
      SongTabNote(stringNumber: 2, fret: 3, noteLabel: 'Rê (D4)', audioAsset: 'audio/notes/D4.wav'),
      SongTabNote(stringNumber: 2, fret: 1, noteLabel: 'Đô (C4)', audioAsset: 'audio/notes/C4.wav', chordSymbol: 'C'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_greensleeves',
    titleVi: 'Greensleeves (Giai Điệu Hoàng Gia)',
    titleEn: 'Greensleeves (16th Century Folk)',
    composer: 'Dân ca Anh Thế kỷ 16 (Public Domain)',
    genreBadge: 'Ballad 3/4',
    defaultBpm: 100,
    gemCost: 0,
    chordProgression: ['Am', 'G', 'F', 'E7', 'Am', 'G', 'E7', 'Am'],
    notes: [
      SongTabNote(stringNumber: 3, fret: 2, noteLabel: 'La (A3)', audioAsset: 'audio/notes/A3.wav', chordSymbol: 'Am'),
      SongTabNote(stringNumber: 2, fret: 1, noteLabel: 'Đô (C4)', audioAsset: 'audio/notes/C4.wav'),
      SongTabNote(stringNumber: 2, fret: 3, noteLabel: 'Rê (D4)', audioAsset: 'audio/notes/D4.wav', chordSymbol: 'G'),
      SongTabNote(stringNumber: 1, fret: 0, noteLabel: 'Mi (E4)', audioAsset: 'audio/notes/E4.wav'),
      SongTabNote(stringNumber: 1, fret: 1, noteLabel: 'Fa (F4)', audioAsset: 'audio/notes/F4.wav', chordSymbol: 'F'),
      SongTabNote(stringNumber: 1, fret: 0, noteLabel: 'Mi (E4)', audioAsset: 'audio/notes/E4.wav'),
      SongTabNote(stringNumber: 2, fret: 3, noteLabel: 'Rê (D4)', audioAsset: 'audio/notes/D4.wav', chordSymbol: 'G'),
      SongTabNote(stringNumber: 2, fret: 0, noteLabel: 'Si (B3)', audioAsset: 'audio/notes/B3.wav'),
      SongTabNote(stringNumber: 3, fret: 0, noteLabel: 'Sol (G3)', audioAsset: 'audio/notes/G3.wav'),
      SongTabNote(stringNumber: 3, fret: 2, noteLabel: 'La (A3)', audioAsset: 'audio/notes/A3.wav', chordSymbol: 'Am'),
      SongTabNote(stringNumber: 2, fret: 0, noteLabel: 'Si (B3)', audioAsset: 'audio/notes/B3.wav', chordSymbol: 'E7'),
      SongTabNote(stringNumber: 2, fret: 1, noteLabel: 'Đô (C4)', audioAsset: 'audio/notes/C4.wav'),
      SongTabNote(stringNumber: 3, fret: 2, noteLabel: 'La (A3)', audioAsset: 'audio/notes/A3.wav', chordSymbol: 'Am'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_romance_damour',
    titleVi: 'Romance d\'Amour (Guitar Cổ Điển)',
    titleEn: 'Romance d\'Amour (Spanish Romance)',
    composer: 'Khuyết danh Thế kỷ 19 (Public Domain)',
    genreBadge: 'VIP • Rải hợp âm',
    defaultBpm: 108,
    gemCost: 300,
    chordProgression: ['Em', 'Am', 'B7', 'Em'],
    notes: [
      SongTabNote(stringNumber: 1, fret: 7, noteLabel: 'Si (B4)', audioAsset: 'audio/notes/B4.wav', chordSymbol: 'Em'),
      SongTabNote(stringNumber: 2, fret: 0, noteLabel: 'Si (B3)', audioAsset: 'audio/notes/B3.wav'),
      SongTabNote(stringNumber: 3, fret: 0, noteLabel: 'Sol (G3)', audioAsset: 'audio/notes/G3.wav'),
      SongTabNote(stringNumber: 1, fret: 7, noteLabel: 'Si (B4)', audioAsset: 'audio/notes/B4.wav'),
      SongTabNote(stringNumber: 1, fret: 5, noteLabel: 'La (A4)', audioAsset: 'audio/notes/A4.wav', chordSymbol: 'Am'),
      SongTabNote(stringNumber: 1, fret: 3, noteLabel: 'Sol (G4)', audioAsset: 'audio/notes/G4.wav'),
      SongTabNote(stringNumber: 1, fret: 2, noteLabel: 'Fa# (F#4)', audioAsset: 'audio/notes/Fs4.wav', chordSymbol: 'B7'),
      SongTabNote(stringNumber: 1, fret: 0, noteLabel: 'Mi (E4)', audioAsset: 'audio/notes/E4.wav'),
      SongTabNote(stringNumber: 1, fret: 3, noteLabel: 'Sol (G4)', audioAsset: 'audio/notes/G4.wav', chordSymbol: 'Em'),
      SongTabNote(stringNumber: 1, fret: 7, noteLabel: 'Si (B4)', audioAsset: 'audio/notes/B4.wav'),
      SongTabNote(stringNumber: 1, fret: 12, noteLabel: 'Mi (E5)', audioAsset: 'audio/notes/E5.wav'),
      SongTabNote(stringNumber: 1, fret: 7, noteLabel: 'Si (B4)', audioAsset: 'audio/notes/B4.wav', chordSymbol: 'Em'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_fur_elise_rock',
    titleVi: 'Für Elise Rock (Thư Gửi Elise)',
    titleEn: 'Für Elise Rock Lead (Beethoven)',
    composer: 'L. van Beethoven (1810 • Public Domain)',
    genreBadge: 'VIP • Lead Riff',
    defaultBpm: 124,
    gemCost: 350,
    chordProgression: ['Am', 'E7', 'Am', 'C', 'G', 'Am'],
    notes: [
      SongTabNote(stringNumber: 1, fret: 12, noteLabel: 'Mi (E5)', audioAsset: 'audio/notes/E5.wav', chordSymbol: 'Am'),
      SongTabNote(stringNumber: 1, fret: 11, noteLabel: 'Rê# (D#5)', audioAsset: 'audio/notes/Ds5.wav'),
      SongTabNote(stringNumber: 1, fret: 12, noteLabel: 'Mi (E5)', audioAsset: 'audio/notes/E5.wav'),
      SongTabNote(stringNumber: 1, fret: 11, noteLabel: 'Rê# (D#5)', audioAsset: 'audio/notes/Ds5.wav'),
      SongTabNote(stringNumber: 1, fret: 12, noteLabel: 'Mi (E5)', audioAsset: 'audio/notes/E5.wav'),
      SongTabNote(stringNumber: 2, fret: 12, noteLabel: 'Si (B4)', audioAsset: 'audio/notes/B4.wav', chordSymbol: 'E7'),
      SongTabNote(stringNumber: 1, fret: 10, noteLabel: 'Rê (D5)', audioAsset: 'audio/notes/D5.wav'),
      SongTabNote(stringNumber: 1, fret: 8, noteLabel: 'Đô (C5)', audioAsset: 'audio/notes/C5.wav'),
      SongTabNote(stringNumber: 2, fret: 10, noteLabel: 'La (A4)', audioAsset: 'audio/notes/A4.wav', chordSymbol: 'Am'),
      SongTabNote(stringNumber: 2, fret: 5, noteLabel: 'Mi (E4)', audioAsset: 'audio/notes/E4.wav'),
      SongTabNote(stringNumber: 2, fret: 9, noteLabel: 'Sol# (G#4)', audioAsset: 'audio/notes/Gs4.wav', chordSymbol: 'E7'),
      SongTabNote(stringNumber: 2, fret: 10, noteLabel: 'La (A4)', audioAsset: 'audio/notes/A4.wav', chordSymbol: 'Am'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_turkish_march_rock',
    titleVi: 'Turkish March Rock (Hành Khúc Thổ Nhĩ Kỳ)',
    titleEn: 'Turkish March Rock (Rondo Alla Turca)',
    composer: 'W. A. Mozart (1783 • Public Domain)',
    genreBadge: 'VIP • Tốc độ cao',
    defaultBpm: 138,
    gemCost: 400,
    chordProgression: ['Am', 'E7', 'Am', 'Dm', 'Am', 'E7', 'Am'],
    notes: [
      SongTabNote(stringNumber: 2, fret: 0, noteLabel: 'Si (B3)', audioAsset: 'audio/notes/B3.wav', chordSymbol: 'Am'),
      SongTabNote(stringNumber: 3, fret: 2, noteLabel: 'La (A3)', audioAsset: 'audio/notes/A3.wav'),
      SongTabNote(stringNumber: 3, fret: 1, noteLabel: 'Sol# (G#3)', audioAsset: 'audio/notes/Gs3.wav'),
      SongTabNote(stringNumber: 3, fret: 2, noteLabel: 'La (A3)', audioAsset: 'audio/notes/A3.wav'),
      SongTabNote(stringNumber: 2, fret: 1, noteLabel: 'Đô (C4)', audioAsset: 'audio/notes/C4.wav', chordSymbol: 'Am'),
      SongTabNote(stringNumber: 2, fret: 3, noteLabel: 'Rê (D4)', audioAsset: 'audio/notes/D4.wav'),
      SongTabNote(stringNumber: 2, fret: 1, noteLabel: 'Đô (C4)', audioAsset: 'audio/notes/C4.wav'),
      SongTabNote(stringNumber: 2, fret: 0, noteLabel: 'Si (B3)', audioAsset: 'audio/notes/B3.wav'),
      SongTabNote(stringNumber: 1, fret: 0, noteLabel: 'Mi (E4)', audioAsset: 'audio/notes/E4.wav', chordSymbol: 'E7'),
      SongTabNote(stringNumber: 1, fret: 1, noteLabel: 'Fa (F4)', audioAsset: 'audio/notes/F4.wav', chordSymbol: 'Dm'),
      SongTabNote(stringNumber: 1, fret: 0, noteLabel: 'Mi (E4)', audioAsset: 'audio/notes/E4.wav'),
      SongTabNote(stringNumber: 2, fret: 3, noteLabel: 'Rê (D4)', audioAsset: 'audio/notes/D4.wav'),
      SongTabNote(stringNumber: 2, fret: 1, noteLabel: 'Đô (C4)', audioAsset: 'audio/notes/C4.wav'),
      SongTabNote(stringNumber: 1, fret: 5, noteLabel: 'La (A4)', audioAsset: 'audio/notes/A4.wav', chordSymbol: 'Am'),
    ],
  ),
  InteractiveSongItem(
    id: 'song_canon_rock',
    titleVi: 'Canon Rock (Bản Solo Huyền Thoại)',
    titleEn: 'Canon Rock in D (Neo-Classical Lead)',
    composer: 'Johann Pachelbel (1680 • Public Domain Rock Arrangement)',
    genreBadge: 'BOSS VIP • 168 BPM',
    defaultBpm: 168,
    gemCost: 500,
    chordProgression: ['D5', 'A5', 'Bm', 'F#m', 'G5', 'D5', 'G5', 'A5'],
    notes: [
      SongTabNote(stringNumber: 1, fret: 14, noteLabel: 'Fa# (F#5)', audioAsset: 'audio/notes/Fs4.wav', chordSymbol: 'D5'),
      SongTabNote(stringNumber: 1, fret: 12, noteLabel: 'Mi (E5)', audioAsset: 'audio/notes/E5.wav', chordSymbol: 'A5'),
      SongTabNote(stringNumber: 1, fret: 10, noteLabel: 'Rê (D5)', audioAsset: 'audio/notes/D5.wav', chordSymbol: 'Bm'),
      SongTabNote(stringNumber: 1, fret: 9, noteLabel: 'Đô# (C#5)', audioAsset: 'audio/notes/Cs5.wav', chordSymbol: 'F#m'),
      SongTabNote(stringNumber: 2, fret: 12, noteLabel: 'Si (B4)', audioAsset: 'audio/notes/B4.wav', chordSymbol: 'G5'),
      SongTabNote(stringNumber: 2, fret: 10, noteLabel: 'La (A4)', audioAsset: 'audio/notes/A4.wav', chordSymbol: 'D5'),
      SongTabNote(stringNumber: 2, fret: 12, noteLabel: 'Si (B4)', audioAsset: 'audio/notes/B4.wav', chordSymbol: 'G5'),
      SongTabNote(stringNumber: 1, fret: 9, noteLabel: 'Đô# (C#5)', audioAsset: 'audio/notes/Cs5.wav', chordSymbol: 'A5'),
      SongTabNote(stringNumber: 1, fret: 10, noteLabel: 'Rê (D5)', audioAsset: 'audio/notes/D5.wav', chordSymbol: 'D5'),
      SongTabNote(stringNumber: 1, fret: 14, noteLabel: 'Fa# (F#5)', audioAsset: 'audio/notes/Fs4.wav'),
      SongTabNote(stringNumber: 1, fret: 15, noteLabel: 'Sol (G5)', audioAsset: 'audio/notes/G4.wav', chordSymbol: 'G5'),
      SongTabNote(stringNumber: 1, fret: 12, noteLabel: 'Mi (E5)', audioAsset: 'audio/notes/E5.wav', chordSymbol: 'A5'),
      SongTabNote(stringNumber: 1, fret: 14, noteLabel: 'Fa# (F#5)', audioAsset: 'audio/notes/Fs4.wav'),
      SongTabNote(stringNumber: 1, fret: 10, noteLabel: 'Rê (D5)', audioAsset: 'audio/notes/D5.wav', chordSymbol: 'D5'),
    ],
  ),
];

/// Widget tổng hợp "Kho Bản Nhạc & Tab Chạy Tương Tác" + "Vòng Tròn Bậc 5 & Máy Dịch Giọng Capo"
class InteractiveSongbookAndTheoryTab extends ConsumerStatefulWidget {
  const InteractiveSongbookAndTheoryTab({super.key});

  @override
  ConsumerState<InteractiveSongbookAndTheoryTab> createState() =>
      _InteractiveSongbookAndTheoryTabState();
}

class _InteractiveSongbookAndTheoryTabState
    extends ConsumerState<InteractiveSongbookAndTheoryTab>
    with WidgetsBindingObserver {
  int _subMode = 0; // 0: Kho Bản Nhạc & Tab Chạy, 1: Vòng Bậc 5 & Dịch Giọng Capo
  String _selectedSongId = kInteractiveSongbookCatalog.first.id;
  double _speedFactor = 1.0; // 0.5x | 0.75x | 1.0x
  bool _isAutoPlaying = false;
  int _currentNoteIndex = 0;
  int _hitCount = 0;
  int _attemptCount = 0;
  int _combo = 0;
  Timer? _playTimer;

  // Circle of Fifths & Capo Transposer state
  int _selectedCircleKeyIndex = 0; // 0 = C / Am .. 11 = F / Dm
  int _transposeSemitones = 0; // -6 .. +6
  String _selectedProgressionPresetId = 'canon';

  static const List<(String major, String minor, String sharpsFlats, List<String> diatonicChords, List<String> chordAudio)>
      _circleOfFifthsKeys = [
    ('C', 'Am', '0 dấu hóa', ['C', 'Dm', 'Em', 'F', 'G', 'Am'], ['audio/chords/C_maj.wav', 'audio/chords/D_min.wav', 'audio/chords/E_min.wav', 'audio/chords/F_maj.wav', 'audio/chords/G_maj.wav', 'audio/chords/A_min.wav']),
    ('G', 'Em', '1 dấu # (F#)', ['G', 'Am', 'Bm', 'C', 'D', 'Em'], ['audio/chords/G_maj.wav', 'audio/chords/A_min.wav', 'audio/chords/B_min.wav', 'audio/chords/C_maj.wav', 'audio/chords/D_maj.wav', 'audio/chords/E_min.wav']),
    ('D', 'Bm', '2 dấu # (F#, C#)', ['D', 'Em', 'F#m', 'G', 'A', 'Bm'], ['audio/chords/D_maj.wav', 'audio/chords/E_min.wav', 'audio/chords/Fs_min.wav', 'audio/chords/G_maj.wav', 'audio/chords/A_maj.wav', 'audio/chords/B_min.wav']),
    ('A', 'F#m', '3 dấu #', ['A', 'Bm', 'C#m', 'D', 'E', 'F#m'], ['audio/chords/A_maj.wav', 'audio/chords/B_min.wav', 'audio/chords/Cs_min.wav', 'audio/chords/D_maj.wav', 'audio/chords/E_maj.wav', 'audio/chords/Fs_min.wav']),
    ('E', 'C#m', '4 dấu #', ['E', 'F#m', 'G#m', 'A', 'B', 'C#m'], ['audio/chords/E_maj.wav', 'audio/chords/Fs_min.wav', 'audio/chords/Gs_min.wav', 'audio/chords/A_maj.wav', 'audio/chords/B_maj.wav', 'audio/chords/Cs_min.wav']),
    ('F', 'Dm', '1 dấu b (Bb)', ['F', 'Gm', 'Am', 'Bb', 'C', 'Dm'], ['audio/chords/F_maj.wav', 'audio/chords/G_min.wav', 'audio/chords/A_min.wav', 'audio/chords/Bb_maj.wav', 'audio/chords/C_maj.wav', 'audio/chords/D_min.wav']),
  ];

  static const List<String> _chromaticRoots = [
    'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        loadSongbookPreferences(ref);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopAutoPlay();
    }
  }

  InteractiveSongItem get _currentSong => kInteractiveSongbookCatalog.firstWhere(
        (s) => s.id == _selectedSongId,
        orElse: () => kInteractiveSongbookCatalog.first,
      );

  void _stopAutoPlay() {
    _playTimer?.cancel();
    if (mounted) {
      setState(() {
        _isAutoPlaying = false;
      });
    }
  }

  void _toggleAutoPlay(AudioService audio) {
    if (_isAutoPlaying) {
      _stopAutoPlay();
      return;
    }
    final song = _currentSong;
    final effectiveBpm = (song.defaultBpm * _speedFactor).round().clamp(35, 240);
    final intervalMs = (60000 / effectiveBpm).round();

    setState(() {
      _isAutoPlaying = true;
    });

    final firstNote = song.notes[_currentNoteIndex];
    audio.playAsset(firstNote.audioAsset);

    _playTimer?.cancel();
    _playTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!mounted) {
        _playTimer?.cancel();
        return;
      }
      final nextIdx = (_currentNoteIndex + 1) % song.notes.length;
      setState(() {
        _currentNoteIndex = nextIdx;
      });
      audio.playAsset(song.notes[nextIdx].audioAsset);
    });
  }

  Future<void> _onTapUnlockVipSong(InteractiveSongItem song) async {
    _stopAutoPlay();
    final adNotifier = ref.read(rewardedAdProvider.notifier);
    final ok = await adNotifier.spendGemsForOneHourSession(
      gemCost: song.gemCost,
    );
    if (!ok) {
      if (!mounted) return;
      final currentGems = ref.read(rewardedAdProvider).prestigePoints;
      final missing = (song.gemCost - currentGems).clamp(0, 9999);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          content: Text(
            'Bản nhạc VIP "${song.titleVi}" cần ${song.gemCost} Gem (còn thiếu $missing Gem). Xem video ngắn nhận +100 Gem ngay!',
          ),
          action: SnackBarAction(
            label: 'Nhận +100 Gem',
            textColor: Colors.white,
            onPressed: () {
              showRewardedVideoAdSimulationDialog(context, ref);
            },
          ),
        ),
      );
      return;
    }

    final updated = {
      ...ref.read(unlockedVipSongsProvider),
      song.id,
    };
    ref.read(unlockedVipSongsProvider.notifier).state = updated;
    unawaited(persistUnlockedVipSongs(updated));

    setState(() {
      _selectedSongId = song.id;
      _currentNoteIndex = 0;
      _hitCount = 0;
      _attemptCount = 0;
      _combo = 0;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.correct,
          content: Text('Đã mở khóa vĩnh viễn bản nhạc "${song.titleVi}"!'),
        ),
      );
    }
  }

  void _onPlayerTapHighwayNote(int tappedString, int tappedFret, AudioService audio) {
    final song = _currentSong;
    final target = song.notes[_currentNoteIndex];
    final isHit = target.stringNumber == tappedString && target.fret == tappedFret;

    if (ref.read(appSettingsProvider).hapticFeedbackEnabled && !audio.isTestMode) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }

    audio.playAsset(target.audioAsset);

    setState(() {
      _attemptCount++;
      if (isHit) {
        _hitCount++;
        _combo++;
        final isLastNote = _currentNoteIndex == song.notes.length - 1;
        _currentNoteIndex = (_currentNoteIndex + 1) % song.notes.length;

        if (isLastNote) {
          final acc = _attemptCount > 0 ? (_hitCount / _attemptCount) : 1.0;
          final earnedStars = acc >= 0.9 ? 3 : (acc >= 0.7 ? 2 : 1);
          final prevStars = ref.read(songbookStarsProvider)[song.id] ?? 0;
          if (earnedStars > prevStars) {
            final nextMap = {
              ...ref.read(songbookStarsProvider),
              song.id: earnedStars,
            };
            ref.read(songbookStarsProvider.notifier).state = nextMap;
            unawaited(persistSongbookStars(nextMap));
          }
        }
      } else {
        _combo = 0;
      }
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = ref.watch(appSettingsProvider).isEnglish;
    final audio = ref.watch(audioServiceProvider);
    final unlockedSongs = ref.watch(unlockedVipSongsProvider);
    final songStars = ref.watch(songbookStarsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-mode switcher: [1. Kho Bản Nhạc & Tab Chạy] | [2. Vòng Bậc 5 & Kẹp Capo]
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                key: const Key('chip_submode_songbook'),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isEn ? '🎵 Interactive Songbook' : '🎵 Bản Nhạc & Tab Chạy',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: _subMode == 0
                          ? Colors.white
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                    ),
                  ),
                ),
                selected: _subMode == 0,
                onSelected: (_) => setState(() => _subMode = 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                key: const Key('chip_submode_circle_capo'),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isEn ? '🧭 Circle of 5ths & Capo' : '🧭 Vòng Bậc 5 & Dịch Capo',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: _subMode == 1
                          ? Colors.white
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                    ),
                  ),
                ),
                selected: _subMode == 1,
                onSelected: (_) {
                  _stopAutoPlay();
                  setState(() => _subMode = 1);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_subMode == 0)
          _buildInteractiveSongbookView(
            context,
            isDark: isDark,
            isEn: isEn,
            audio: audio,
            unlockedSongs: unlockedSongs,
            songStars: songStars,
          )
        else
          _buildCircleOfFifthsAndCapoView(
            context,
            isDark: isDark,
            isEn: isEn,
            audio: audio,
          ),
      ],
    );
  }

  Widget _buildInteractiveSongbookView(
    BuildContext context, {
    required bool isDark,
    required bool isEn,
    required AudioService audio,
    required Set<String> unlockedSongs,
    required Map<String, int> songStars,
  }) {
    final song = _currentSong;
    final targetNote = song.notes[_currentNoteIndex];
    final starsEarned = songStars[song.id] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Horizontal Song Selector Carousel (Free + VIP Boss Tracks like Canon Rock)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < kInteractiveSongbookCatalog.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Builder(
                  builder: (_) {
                    final item = kInteractiveSongbookCatalog[i];
                    final isUnlocked = !item.isVip || unlockedSongs.contains(item.id);
                    final isSelected = item.id == song.id;
                    final itemStars = songStars[item.id] ?? 0;

                    return InkWell(
                      key: Key('card_song_${item.id}'),
                      borderRadius: BorderRadius.circular(13),
                      onTap: () {
                        if (!isUnlocked) {
                          _onTapUnlockVipSong(item);
                          return;
                        }
                        _stopAutoPlay();
                        setState(() {
                          _selectedSongId = item.id;
                          _currentNoteIndex = 0;
                          _hitCount = 0;
                          _attemptCount = 0;
                          _combo = 0;
                        });
                      },
                      child: Container(
                        width: 175,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.secondary
                                : (item.isVip && !isUnlocked
                                    ? const Color(0xFFF59E0B).withOpacity(0.55)
                                    : (isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight)),
                            width: isSelected ? 1.6 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.genreBadge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? Colors.white70
                                          : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                                if (!isUnlocked) ...[
                                  const SolfaGemIcon(size: 12),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${item.gemCost}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ] else
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (int s = 1; s <= 3; s++)
                                        Icon(
                                          Icons.star_rounded,
                                          size: 12,
                                          color: s <= itemStars
                                              ? const Color(0xFFFBBF24)
                                              : Colors.grey.withOpacity(0.35),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEn ? item.titleEn : item.titleVi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.defaultBpm} BPM • ${item.notes.length} nốt',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isSelected
                                    ? Colors.white70
                                    : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Speed Trainer (50% - 75% - 100%) + Auto-Play Button + Combo Badge
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
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
                          isEn ? song.titleEn : song.titleVi,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          song.composer,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.correct.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'Combo x$_combo • ⭐ $starsEarned/3',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.correct,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Speed Selector + Auto-Play Controls
              Row(
                children: [
                  const Text(
                    'Tốc độ:',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  for (final spd in const [0.5, 0.75, 1.0]) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: ChoiceChip(
                        key: Key('chip_song_speed_${(spd * 100).round()}'),
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${(spd * 100).round()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _speedFactor == spd
                                ? Colors.white
                                : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                          ),
                        ),
                        selected: _speedFactor == spd,
                        onSelected: (_) {
                          setState(() => _speedFactor = spd);
                          if (_isAutoPlaying) {
                            _stopAutoPlay();
                            _toggleAutoPlay(audio);
                          }
                        },
                      ),
                    ),
                  ],
                  const Spacer(),
                  ElevatedButton.icon(
                    key: const Key('btn_songbook_autoplay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isAutoPlaying ? AppColors.wrong : AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                    ),
                    onPressed: () => _toggleAutoPlay(audio),
                    icon: Icon(
                      _isAutoPlaying
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _isAutoPlaying ? 'Dừng' : 'Nghe mẫu',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 3. Scrolling 6-String Tab Highway isolated with RepaintBoundary for 60fps
              RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.45),
                    ),
                  ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nốt #${_currentNoteIndex + 1}/${song.notes.length}: Dây ${targetNote.stringNumber} • Ngăn ${targetNote.fret} (${targetNote.noteLabel})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                        if (targetNote.chordSymbol != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.22),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Hợp âm: ${targetNote.chordSymbol}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int idx = 0; idx < song.notes.length; idx++) ...[
                            if (idx > 0) const SizedBox(width: 6),
                            Builder(
                              builder: (_) {
                                final n = song.notes[idx];
                                final isCurrent = idx == _currentNoteIndex;
                                final isPassed = idx < _currentNoteIndex;
                                return InkWell(
                                  key: Key('highway_note_$idx'),
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => _onPlayerTapHighwayNote(
                                    n.stringNumber,
                                    n.fret,
                                    audio,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 56,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 7,
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? AppColors.primary
                                          : (isPassed
                                              ? AppColors.correct.withOpacity(0.22)
                                              : Colors.white.withOpacity(0.07)),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isCurrent
                                            ? const Color(0xFF38BDF8)
                                            : Colors.white24,
                                        width: isCurrent ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Dây ${n.stringNumber}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Ng.${n.fret}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          n.noteLabel.split(' ').first,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            color: Color(0xFF93C5FD),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
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
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: ElevatedButton.icon(
                        key: const Key('btn_tap_current_highway_note'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.correct,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _onPlayerTapHighwayNote(
                          targetNote.stringNumber,
                          targetNote.fret,
                          audio,
                        ),
                        icon: const Icon(Icons.touch_app_rounded, size: 17),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Gảy Nốt Đang Sáng: Dây ${targetNote.stringNumber} • Ngăn ${targetNote.fret} (${targetNote.noteLabel})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircleOfFifthsAndCapoView(
    BuildContext context, {
    required bool isDark,
    required bool isEn,
    required AudioService audio,
  }) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Vòng Tròn Hòa Âm Bậc 5 (Circle of Fifths)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
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
                    ? '1. Interactive Circle of Fifths (Tap Key & Hear Chords)'
                    : '1. Vòng Tròn Hòa Âm Bậc 5 (Chọn Giọng & Nghe 6 Hợp Âm Chủ Đạo)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (int i = 0; i < _circleOfFifthsKeys.length; i++)
                    ChoiceChip(
                      key: Key('chip_circle_key_${_circleOfFifthsKeys[i].$1}'),
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
              const SizedBox(height: 8),
              Text(
                'Giọng ${currentKey.$1} Trưởng / ${currentKey.$2} Thứ • Hóa biểu: ${currentKey.$3}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.secondary : AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (int cIdx = 0;
                      cIdx < currentKey.$4.length;
                      cIdx++) ...[
                    if (cIdx > 0) const SizedBox(width: 5),
                    Expanded(
                      child: InkWell(
                        key: Key('btn_circle_chord_${currentKey.$4[cIdx]}'),
                        borderRadius: BorderRadius.circular(9),
                        onTap: () {
                          audio.playAsset(currentKey.$5[cIdx]);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.35),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                const ['I', 'ii', 'iii', 'IV', 'V', 'vi'][cIdx],
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFF93C5FD)
                                      : AppColors.primary,
                                ),
                              ),
                              Text(
                                currentKey.$4[cIdx],
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.primaryDark,
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
        const SizedBox(height: 10),

        // 2. Máy Dịch Giọng Hợp Âm & Kẹp Capo Thông Minh
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
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
                    ? '2. Smart Chord Transposer & Capo Calculator'
                    : '2. Máy Dịch Giọng Hợp Âm & Gợi Ý Kẹp Capo Thông Minh',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
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
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _selectedProgressionPresetId == pId
                              ? Colors.white
                              : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight),
                        ),
                      ),
                      selected: _selectedProgressionPresetId == pId,
                      onSelected: (_) =>
                          setState(() => _selectedProgressionPresetId = pId),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Dịch nửa cung:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('btn_transpose_down'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(
                      () => _transposeSemitones = (_transposeSemitones - 1).clamp(-6, 6),
                    ),
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _transposeSemitones > 0
                          ? '+$_transposeSemitones nửa cung'
                          : '$_transposeSemitones nửa cung',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('btn_transpose_up'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(
                      () => _transposeSemitones = (_transposeSemitones + 1).clamp(-6, 6),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kết quả dịch giọng: ${transposedChords.join('  →  ')}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (recommendedCapoFret > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '💡 Gợi ý Kẹp Capo Ngăn $recommendedCapoFret: Bấm thế hợp âm mở (${[for (final c in baseProgression) _transposeChordSymbol(c, -recommendedCapoFret)].join(' - ')}) để giảm hợp âm chặn!',
                        style: const TextStyle(
                          fontSize: 11.2,
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
    6: ('E2 (Mi trầm)', 82.4, 'audio/guitar_acoustic/notes/E2.wav'),
    5: ('A2 (La)', 110.0, 'audio/guitar_acoustic/notes/A2.wav'),
    4: ('D3 (Rê)', 146.8, 'audio/guitar_acoustic/notes/D3.wav'),
    3: ('G3 (Sol)', 196.0, 'audio/guitar_acoustic/notes/G3.wav'),
    2: ('B3 (Si)', 246.9, 'audio/guitar_acoustic/notes/B3.wav'),
    1: ('E4 (Mi cao)', 329.6, 'audio/guitar_acoustic/notes/E4.wav'),
  };

  void _startTuningChallenge(AudioService audio) {
    final rng = math.Random();
    final randomOffset = (rng.nextBool() ? 1 : -1) * (15 + rng.nextInt(30));
    setState(() {
      _isChallengeActive = true;
      _centsOffset = randomOffset;
    });
    final info = _standardStringData[widget.activeStringNumber]!;
    audio.playAsset(info.$3);
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
    audio.playAsset(info.$3);
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
                  'Máy Đo Tần Số Chuẩn (A4 = $_referenceA4Hz Hz) • Đã chuẩn: $_challengeSolvedCount dây',
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
          // Visual Cents Bar (-50c .. 0c .. +50c)
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
                    final normalized = ((_centsOffset + 50) / 100.0).clamp(0.0, 1.0);
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
                  'Dây ${widget.activeStringNumber} (${info.$1}): ${currentHz.toStringAsFixed(1)} Hz / Chuẩn ${targetHz.toStringAsFixed(1)} Hz (${_centsOffset > 0 ? '+$_centsOffset' : '$_centsOffset'}c)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isInTune ? AppColors.correct : const Color(0xFFF59E0B),
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
                    'Thử thách Vặn Khóa Đàn',
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
