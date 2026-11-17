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

  /// Danh sách 8 hợp âm Guitar thông dụng nhất (kèm vị trí bấm trên 6 dây: -1 = X bịt, 0 = buông, >0 = ngăn bấm)
  static const List<GuitarChordShape> commonChords = [
    GuitarChordShape(
      id: 'C',
      name: 'Đô Trưởng (C)',
      formula: 'X - 3 - 2 - 0 - 1 - 0',
      fretsByString1To6: [0, 1, 0, 2, 3, -1],
      fingersByString1To6: [0, 1, 0, 2, 3, 0],
      audioAsset: 'assets/audio/keys/chord_c_maj.wav',
      tip: 'Ngón 1 bấm Dây 2 ngăn 1 • Ngón 2 Dây 4 ngăn 2 • Ngón 3 Dây 5 ngăn 3 (Bỏ dây 6)',
    ),
    GuitarChordShape(
      id: 'G',
      name: 'Sol Trưởng (G)',
      formula: '3 - 2 - 0 - 0 - 0 - 3',
      fretsByString1To6: [3, 0, 0, 0, 2, 3],
      fingersByString1To6: [3, 0, 0, 0, 1, 2],
      audioAsset: 'assets/audio/keys/chord_g_maj.wav',
      tip: 'Ngón 1 Dây 5 ngăn 2 • Ngón 2 Dây 6 ngăn 3 • Ngón 3 Dây 1 ngăn 3 (Vang cả 6 dây)',
    ),
    GuitarChordShape(
      id: 'Am',
      name: 'La Thứ (Am)',
      formula: 'X - 0 - 2 - 2 - 1 - 0',
      fretsByString1To6: [0, 1, 2, 2, 0, -1],
      fingersByString1To6: [0, 1, 3, 2, 0, 0],
      audioAsset: 'assets/audio/keys/chord_a_min.wav',
      tip: 'Ngón 1 Dây 2 ngăn 1 • Ngón 2 Dây 4 ngăn 2 • Ngón 3 Dây 3 ngăn 2 (Bass dây 5 La)',
    ),
    GuitarChordShape(
      id: 'Em',
      name: 'Mi Thứ (Em)',
      formula: '0 - 2 - 2 - 0 - 0 - 0',
      fretsByString1To6: [0, 0, 0, 2, 2, 0],
      fingersByString1To6: [0, 0, 0, 3, 2, 0],
      audioAsset: 'assets/audio/keys/chord_e_min.wav',
      tip: 'Hợp âm dễ nhất: Chỉ cần 2 ngón (Ngón 2 Dây 5 ngăn 2 & Ngón 3 Dây 4 ngăn 2)',
    ),
    GuitarChordShape(
      id: 'Dm',
      name: 'Rê Thứ (Dm)',
      formula: 'X - X - 0 - 2 - 3 - 1',
      fretsByString1To6: [1, 3, 2, 0, -1, -1],
      fingersByString1To6: [1, 3, 2, 0, 0, 0],
      audioAsset: 'assets/audio/keys/chord_d_min.wav',
      tip: 'Ngón 1 Dây 1 ngăn 1 • Ngón 2 Dây 3 ngăn 2 • Ngón 3 Dây 2 ngăn 3 (Bass dây 4 Rê)',
    ),
    GuitarChordShape(
      id: 'F',
      name: 'Fa Trưởng (F)',
      formula: 'X - X - 3 - 2 - 1 - 1',
      fretsByString1To6: [1, 1, 2, 3, -1, -1],
      fingersByString1To6: [1, 1, 2, 3, 0, 0],
      audioAsset: 'assets/audio/keys/chord_f_maj.wav',
      tip: 'Ngón 1 chặn nhẹ Dây 1&2 ngăn 1 • Ngón 2 Dây 3 ngăn 2 • Ngón 3 Dây 4 ngăn 3',
    ),
    GuitarChordShape(
      id: 'D',
      name: 'Rê Trưởng (D)',
      formula: 'X - X - 0 - 2 - 3 - 2',
      fretsByString1To6: [2, 3, 2, 0, -1, -1],
      fingersByString1To6: [2, 3, 1, 0, 0, 0],
      audioAsset: 'assets/audio/keys/chord_d_maj.wav',
      tip: 'Hình tam giác ở 3 dây dưới: Ngón 1 Dây 3 ngăn 2 • Ngón 2 Dây 1 ngăn 2 • Ngón 3 Dây 2 ngăn 3',
    ),
    GuitarChordShape(
      id: 'E',
      name: 'Mi Trưởng (E)',
      formula: '0 - 2 - 2 - 1 - 0 - 0',
      fretsByString1To6: [0, 0, 1, 2, 2, 0],
      fingersByString1To6: [0, 0, 1, 3, 2, 0],
      audioAsset: 'assets/audio/keys/chord_e_maj.wav',
      tip: 'Giống thế bấm Am nhưng dịch toàn bộ lên 1 dây (Ngón 1 Dây 3 ngăn 1)',
    ),
  ];
}

class GuitarChordShape {
  final String id;
  final String name;
  final String formula;
  final List<int> fretsByString1To6;
  final List<int> fingersByString1To6;
  final String audioAsset;
  final String tip;

  const GuitarChordShape({
    required this.id,
    required this.name,
    required this.formula,
    required this.fretsByString1To6,
    required this.fingersByString1To6,
    required this.audioAsset,
    required this.tip,
  });
}

/// Mở Bảng Công Cụ & Bản Đồ Cần Đàn Guitar Tương Tác (Tách biệt hoàn toàn với Piano).
Future<void> showGuitarStudioSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const GuitarStudioSheet(),
  );
}

class GuitarStudioSheet extends ConsumerStatefulWidget {
  const GuitarStudioSheet({super.key});

  @override
  ConsumerState<GuitarStudioSheet> createState() => _GuitarStudioSheetState();
}

class _GuitarStudioSheetState extends ConsumerState<GuitarStudioSheet> {
  /// 0: Bản đồ Cần đàn (Fretboard Map)
  /// 1: Hợp âm Guitar (Chord Shapes)
  /// 2: Bản đồ Scale (Pentatonic & Trưởng/Thứ)
  /// 3: Đọc Tab & Luyện ngón (Spider 1-2-3-4)
  int _selectedTab = 0;

  int _activeString = 5; // Dây 5
  int _activeFret = 3; // Ngăn 3 (Đô C3)
  bool _showNaturalNotesOnly = true;
  bool _showOctaveJumpGuide = false;

  int _selectedChordIndex = 0;
  String _selectedScaleId = 'am_pentatonic';

  int _spiderStep = 0;
  Timer? _spiderTimer;
  bool _isSpiderPlaying = false;

  Timer? _strumTimer;
  int? _activeStrumString;
  int? _activeStrumFret;

  @override
  void dispose() {
    _spiderTimer?.cancel();
    _strumTimer?.cancel();
    super.dispose();
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
    _spiderTimer = Timer.periodic(const Duration(milliseconds: 520), (_) {
      if (!mounted) return;
      setState(() {
        _spiderStep = (_spiderStep + 1) % 8;
      });
      _playCurrentSpiderStep();
    });
  }

  void _playCurrentSpiderStep() {
    // 4 bước đầu: Bò nhện 1-2-3-4 trên dây 6; 4 bước sau: 1-2-3-4 trên dây 5
    final stringNum = _spiderStep < 4 ? 6 : 5;
    final fretNum = (_spiderStep % 4) + 1;
    final note = GuitarFretboardData.noteAt(
      stringNumber: stringNum,
      fret: fretNum,
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

    return Container(
      key: const Key('guitar_studio_sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Color(0xFFD97706),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn
                            ? 'Guitar Studio & Fretboard Map'
                            : 'Phòng Học Guitar & Bản Đồ Cần Đàn',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        isEn
                            ? '6 Strings (E–A–D–G–B–e) • Chords • Scales • Tab & Spider'
                            : '6 Dây (E–A–D–G–B–e) • Hợp âm • Scale • Đọc Tab & Luyện ngón',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('btn_close_guitar_studio'),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 4 Chế độ học Guitar tách biệt rõ ràng (Hiển thị gọn trên 1 hàng 4 cột, không tràn khung 360px)
            Row(
              children: [
                for (final (idx, label, icon) in [
                  (0, isEn ? 'Fretboard' : 'Map Cần', Icons.grid_on_rounded),
                  (1, isEn ? 'Chords' : 'Hợp âm', Icons.pan_tool_alt_rounded),
                  (2, 'Scale', Icons.timeline_rounded),
                  (3, isEn ? 'Tab & 1234' : 'Đọc Tab', Icons.queue_music_rounded),
                ]) ...[
                  if (idx > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Material(
                      color: _selectedTab == idx
                          ? const Color(0xFFD97706)
                          : (isDark
                              ? Colors.white.withOpacity(0.06)
                              : const Color(0xFFD97706).withOpacity(0.08)),
                      borderRadius: BorderRadius.circular(11),
                      child: InkWell(
                        key: Key('chip_guitar_tab_$idx'),
                        borderRadius: BorderRadius.circular(11),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 16,
                                color: _selectedTab == idx
                                    ? Colors.white
                                    : const Color(0xFFD97706),
                              ),
                              const SizedBox(height: 3),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11.5,
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

            if (_selectedTab == 0)
              _buildFretboardMapTab(audioService, isDark, isEn)
            else if (_selectedTab == 1)
              _buildChordShapesTab(audioService, isDark, isEn)
            else if (_selectedTab == 2)
              _buildScaleMapTab(
                context,
                audioService,
                adState,
                proUnlocked,
                isDark,
              )
            else
              _buildTabAndSpiderExerciseTab(audioService, isDark),
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

  /// TAB 2: Thư viện Thế bấm Hợp âm Guitar (Chord Shapes) + Rải từng dây sáng đèn
  Widget _buildChordShapesTab(dynamic audioService, bool isDark, bool isEn) {
    final chord = GuitarFretboardData.commonChords[_selectedChordIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(GuitarFretboardData.commonChords.length, (i) {
            final c = GuitarFretboardData.commonChords[i];
            final selected = _selectedChordIndex == i;
            return ChoiceChip(
              key: Key('chip_guitar_chord_${c.id}'),
              visualDensity: VisualDensity.compact,
              label: Text(
                c.id,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              selected: selected,
              onSelected: (_) {
                _strumTimer?.cancel();
                setState(() {
                  _selectedChordIndex = i;
                  _activeStrumString = null;
                  _activeStrumFret = null;
                });
                audioService.playAsset(c.audioAsset);
              },
            );
          }),
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
                    onPressed: () => audioService.playAsset(chord.audioAsset),
                    icon: const Icon(Icons.volume_up_rounded, size: 15),
                    label: Text(isEn ? 'Chord' : 'Gảy hợp âm'),
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
          maxFrets: 5,
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
          'Hướng dẫn đặt ngón: ${chord.tip} (Số 1: Ngón trỏ • Số 2: Ngón giữa • Số 3: Áp út • O: Dây buông • X: Không gảy)',
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
        'Full Map 12 ngăn (50 Gem)',
        true,
        {'E', 'G', 'A', 'B', 'D', 'F#'},
        'E',
        'Bản đồ Scale mở rộng toàn cần đàn 12 ngăn giúp nối các thế bấm CAGED từ ngăn 0 lên ngăn 12.'
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
            audioService.playAsset(info.audioAsset);
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

  /// TAB 4: Cách đọc Tab 6 dây & Bài luyện ngón Spider 1-2-3-4
  Widget _buildTabAndSpiderExerciseTab(dynamic audioService, bool isDark) {
    final activeString = _spiderStep < 4 ? 6 : 5;
    final activeFret = (_spiderStep % 4) + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cách đọc Tab Guitar trong 10 giây:',
                style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text(
                '• Khuông Tab gồm 6 dòng kẻ ngang đại diện cho 6 dây đàn (Dòng trên cùng là Dây 1 mỏng nhất e4, dòng dưới cùng là Dây 6 dày nhất E2).\n'
                '• Con số viết trên dòng nào = Bấm vào NGĂN ĐÓ của dây đó (Số 0 = Gảy dây buông không bấm; Số 1–2–3–4 = Bấm ngăn 1, 2, 3, 4).',
                style: TextStyle(fontSize: 11.8, height: 1.38),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Bài luyện ngón Spider (Bò nhện 1–2–3–4):',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
            ElevatedButton.icon(
              key: const Key('btn_toggle_spider_exercise'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isSpiderPlaying ? AppColors.wrong : AppColors.primary,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: _toggleSpiderExercise,
              icon: Icon(
                _isSpiderPlaying
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
                size: 18,
              ),
              label: Text(_isSpiderPlaying ? 'Dừng tập' : 'Chạy mẫu 1-2-3-4'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GuitarTabViewerWidget(
          activeStepIndex: _spiderStep,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        InteractiveGuitarFretboard(
          maxFrets: 5,
          activeString: activeString,
          activeFret: activeFret,
          showAllNotes: false,
          onTapFret: (s, f) {
            final info = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
            audioService.playAsset(info.audioAsset);
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

  const GuitarTabViewerWidget({
    super.key,
    this.activeStepIndex = 0,
    required this.isDark,
    this.highlightString,
    this.highlightFret,
  });

  @override
  Widget build(BuildContext context) {
    const tabStrings = ['e|', 'B|', 'G|', 'D|', 'A|', 'E|'];
    // 8 bước bài tập Spider 1-2-3-4 trên Dây 6 rồi sang Dây 5
    const steps = [
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
      final isAm = optionKey.contains('AM');
      return InteractiveGuitarFretboard(
        key: const Key('guitar_question_board'),
        maxFrets: 5,
        scalePitchSet:
            isAm ? const {'A', 'C', 'D', 'E', 'G'} : const {'C', 'D', 'E', 'F', 'G', 'A', 'B'},
        scaleRootPitch: isAm ? 'A' : 'C',
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
