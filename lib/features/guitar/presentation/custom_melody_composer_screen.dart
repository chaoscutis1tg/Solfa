import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../core/audio/audio_service.dart';
import '../../../core/providers/app_providers.dart';
import 'guitar_studio_sheet.dart';
import 'interactive_songbook_and_theory_sheet.dart';

const String _kCustomSongsPrefsKey = 'solfa_custom_user_songs_v1';

/// Provider lưu danh sách các Bản Nhạc / Riff Cá Nhân do người dùng tự sáng tác (100% Offline).
final customUserSongsProvider = StateProvider<List<InteractiveSongItem>>(
  (ref) => const <InteractiveSongItem>[],
);

Map<String, dynamic> _encodeSongNote(SongTabNote n) => {
      's': n.stringNumber,
      'f': n.fret,
      'pk': n.pitchKey,
      'lbl': n.noteLabel,
      'wav': n.audioAsset,
    };

SongTabNote _decodeSongNote(Map<String, dynamic> m) => SongTabNote(
      stringNumber: (m['s'] as num?)?.toInt() ?? 1,
      fret: (m['f'] as num?)?.toInt() ?? 0,
      pitchKey: (m['pk'] as String?) ?? 'E4',
      noteLabel: (m['lbl'] as String?) ?? 'Mi (E4)',
      audioAsset: (m['wav'] as String?) ?? 'assets/audio/notes/e4.wav',
    );

Map<String, dynamic> _encodeCustomSong(InteractiveSongItem s) => {
      'id': s.id,
      'titleVi': s.titleVi,
      'titleEn': s.titleEn,
      'bpm': s.defaultBpm,
      'notes': s.notes.map(_encodeSongNote).toList(),
    };

InteractiveSongItem? _decodeCustomSong(Map<String, dynamic> m) {
  final rawNotes = m['notes'];
  if (rawNotes is! List || rawNotes.isEmpty) return null;
  final notes = rawNotes
      .whereType<Map>()
      .map((e) => _decodeSongNote(Map<String, dynamic>.from(e)))
      .toList();
  if (notes.isEmpty) return null;
  final title = (m['titleVi'] as String?) ?? 'Giai điệu của tôi';
  return InteractiveSongItem(
    id: (m['id'] as String?) ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
    category: 'custom',
    titleVi: title,
    titleEn: (m['titleEn'] as String?) ?? title,
    composer: 'Bản nhạc tự soạn • ChaoNote Studio',
    genreBadge: 'Bài của tôi',
    defaultBpm: ((m['bpm'] as num?)?.toInt() ?? 100).clamp(60, 200),
    gemCost: 0,
    chordProgression: const ['C', 'G', 'Am', 'F'],
    notes: notes,
  );
}

Future<void> loadCustomUserSongs(WidgetRef ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCustomSongsPrefsKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    final items = <InteractiveSongItem>[];
    for (final entry in decoded) {
      if (entry is Map) {
        final item = _decodeCustomSong(Map<String, dynamic>.from(entry));
        if (item != null) items.add(item);
      }
    }
    ref.read(customUserSongsProvider.notifier).state = items;
  } catch (_) {}
}

Future<void> _persistCustomSongsList(List<InteractiveSongItem> songs) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(songs.map(_encodeCustomSong).toList());
    await prefs.setString(_kCustomSongsPrefsKey, encoded);
  } catch (_) {}
}

Future<void> saveNewCustomUserSong(
  WidgetRef ref,
  InteractiveSongItem song,
) async {
  final current = ref.read(customUserSongsProvider);
  final updated = [song, ...current.where((s) => s.id != song.id)];
  ref.read(customUserSongsProvider.notifier).state = updated;
  await _persistCustomSongsList(updated);
}

Future<void> deleteCustomUserSong(WidgetRef ref, String id) async {
  final current = ref.read(customUserSongsProvider);
  final updated = current.where((s) => s.id != id).toList();
  ref.read(customUserSongsProvider.notifier).state = updated;
  await _persistCustomSongsList(updated);
}

/// Ánh xạ 1 phím Piano (vd 'C4', 'F#4', 'E5') sang vị trí Dây & Ngăn tối ưu trên Guitar 6 dây
/// để mọi bài tự soạn bằng Piano đều chơi lại được trên cả Guitar lẫn Piano!
(int stringNum, int fretNum) mapPitchKeyToGuitarPosition(String pitchKey) {
  for (int s = 1; s <= 6; s++) {
    for (int f = 0; f <= 15; f++) {
      final info = GuitarFretboardData.noteAt(stringNumber: s, fret: f);
      final octaveMatch = RegExp(r'\(([A-G]#?[0-9])\)').firstMatch(info.fullLabel);
      if (octaveMatch != null && octaveMatch.group(1) == pitchKey) {
        return (s, f);
      }
    }
  }
  return (1, 0);
}

Future<InteractiveSongItem?> openCustomMelodyComposerScreen(
  BuildContext context,
) {
  return Navigator.of(context).push<InteractiveSongItem>(
    MaterialPageRoute<InteractiveSongItem>(
      builder: (_) => const CustomMelodyComposerScreen(),
    ),
  );
}

class CustomMelodyComposerScreen extends ConsumerStatefulWidget {
  const CustomMelodyComposerScreen({super.key});

  @override
  ConsumerState<CustomMelodyComposerScreen> createState() =>
      _CustomMelodyComposerScreenState();
}

class _CustomMelodyComposerScreenState
    extends ConsumerState<CustomMelodyComposerScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _titleController;
  bool _isPianoMode = false;
  int _selectedPianoOctave = 4; // 3 | 4 | 5
  int _selectedBpm = 100;
  final List<SongTabNote> _composedNotes = [];
  bool _isPreviewPlaying = false;
  int _previewStep = -1;
  Timer? _previewTimer;
  AudioService? _audioRef;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final nextNum = ref.read(customUserSongsProvider).length + 1;
    _titleController = TextEditingController(text: 'Giai điệu của tôi #$nextNum');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audioRef = ref.read(audioServiceProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _previewTimer?.cancel();
    _audioRef?.stop(includePolyphony: true);
    _titleController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopPreview();
    }
  }

  void _stopPreview() {
    _previewTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPreviewPlaying = false;
        _previewStep = -1;
      });
    }
  }

  void _playNote(SongTabNote note, AudioService audio) {
    if (_isPianoMode) {
      audio.playPolyphonicAsset(note.audioAsset);
    } else {
      audio.playGuitarAsset(note.audioAsset);
    }
  }

  void _appendNote(SongTabNote note, AudioService audio, bool isEn) {
    _stopPreview();
    _playNote(note, audio);
    if (_composedNotes.length >= 32) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            isEn
                ? 'Maximum 32 notes per custom riff reached.'
                : 'Đã đạt tối đa 32 nốt cho một đoạn giai điệu cá nhân.',
          ),
        ),
      );
      return;
    }
    if (ref.read(appSettingsProvider).hapticFeedbackEnabled &&
        !audio.isTestMode) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }
    setState(() => _composedNotes.add(note));
  }

  void _togglePreview(AudioService audio) {
    if (_composedNotes.isEmpty) return;
    if (_isPreviewPlaying) {
      _stopPreview();
      return;
    }
    final intervalMs = (60000 / _selectedBpm).round().clamp(240, 1200);
    setState(() {
      _isPreviewPlaying = true;
      _previewStep = 0;
    });
    _playNote(_composedNotes[0], audio);

    int idx = 0;
    _previewTimer?.cancel();
    _previewTimer = Timer.periodic(Duration(milliseconds: intervalMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      idx++;
      if (idx >= _composedNotes.length) {
        t.cancel();
        setState(() {
          _isPreviewPlaying = false;
          _previewStep = -1;
        });
        return;
      }
      setState(() => _previewStep = idx);
      _playNote(_composedNotes[idx], audio);
    });
  }

  Future<void> _saveAndFinish(bool isEn) async {
    _stopPreview();
    if (_composedNotes.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          content: Text(
            isEn
                ? 'Please tap at least 3 notes before saving!'
                : 'Hãy bấm ít nhất 3 nốt nhạc trên đàn trước khi lưu bài nhé!',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
      return;
    }
    final rawTitle = _titleController.text.trim();
    final finalTitle = rawTitle.isEmpty
        ? (isEn ? 'My Custom Melody' : 'Giai điệu của tôi')
        : rawTitle;
    final newSong = InteractiveSongItem(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      category: 'custom',
      titleVi: finalTitle,
      titleEn: finalTitle,
      composer: isEn
          ? 'Custom Composition • ChaoNote Studio'
          : 'Bản nhạc tự soạn • ChaoNote Studio',
      genreBadge: isEn ? 'My Riff' : 'Bài của tôi',
      defaultBpm: _selectedBpm,
      gemCost: 0,
      chordProgression: const ['C', 'G', 'Am', 'F'],
      notes: List<SongTabNote>.unmodifiable(_composedNotes),
    );
    await saveNewCustomUserSong(ref, newSong);
    if (!mounted) return;
    Navigator.of(context).pop(newSong);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = ref.watch(appSettingsProvider).isEnglish;
    final audio = ref.watch(audioServiceProvider);
    audio.setGuitarType(ref.watch(selectedGuitarTypeProvider));

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          titleSpacing: 0,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isEn ? 'Compose Custom Melody' : 'Tự Soạn Giai Điệu Cá Nhân',
              maxLines: 1,
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            key: const Key('screen_custom_melody_composer'),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            children: [
              // 1. Đặt tên bài & chọn tốc độ BPM
              Container(
                padding: const EdgeInsets.all(13),
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
                    TextField(
                      key: const Key('input_composer_title'),
                      controller: _titleController,
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: isEn ? 'Track Title' : 'Tên giai điệu / câu Riff',
                        prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'BPM:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        for (final bpm in const [80, 100, 120, 140]) ...[
                          if (bpm != 80) const SizedBox(width: 6),
                          Expanded(
                            child: InkWell(
                              key: Key('chip_composer_bpm_$bpm'),
                              borderRadius: BorderRadius.circular(9),
                              onTap: () => setState(() => _selectedBpm = bpm),
                              child: Container(
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _selectedBpm == bpm
                                      ? AppColors.primary
                                      : AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  '$bpm',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _selectedBpm == bpm
                                        ? Colors.white
                                        : null,
                                  ),
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

              // 2. Dải nốt đã ghi (0..32 nốt) + Nghe thử / Xóa
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            isEn
                                ? 'Recorded Notes (${_composedNotes.length}/32)'
                                : 'Dải nốt đã ghi (${_composedNotes.length}/32 nốt)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: const Key('btn_composer_preview_play'),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: isEn ? 'Preview' : 'Nghe thử',
                              onPressed: _composedNotes.isEmpty
                                  ? null
                                  : () => _togglePreview(audio),
                              icon: Icon(
                                _isPreviewPlaying
                                    ? Icons.stop_circle_rounded
                                    : Icons.play_circle_fill_rounded,
                                color: _composedNotes.isEmpty
                                    ? Colors.white24
                                    : const Color(0xFF4ADE80),
                                size: 22,
                              ),
                            ),
                            IconButton(
                              key: const Key('btn_composer_undo_note'),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: isEn ? 'Undo' : 'Xóa nốt cuối',
                              onPressed: _composedNotes.isEmpty
                                  ? null
                                  : () => setState(
                                        () => _composedNotes.removeLast(),
                                      ),
                              icon: Icon(
                                Icons.backspace_outlined,
                                color: _composedNotes.isEmpty
                                    ? Colors.white24
                                    : Colors.white70,
                                size: 18,
                              ),
                            ),
                            IconButton(
                              key: const Key('btn_composer_clear_all'),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: isEn ? 'Clear' : 'Xóa tất cả',
                              onPressed: _composedNotes.isEmpty
                                  ? null
                                  : () {
                                      _stopPreview();
                                      setState(() => _composedNotes.clear());
                                    },
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: _composedNotes.isEmpty
                                    ? Colors.white24
                                    : AppColors.wrong,
                                size: 19,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_composedNotes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          isEn
                              ? 'Tap Guitar frets or Piano keys below to record your melody...'
                              : 'Chạm vào ngăn đàn Guitar hoặc phím Piano bên dưới để bắt đầu ghi nốt...',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.white60,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (int i = 0; i < _composedNotes.length; i++)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _previewStep == i
                                    ? AppColors.correct
                                    : AppColors.primary.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _previewStep == i
                                      ? Colors.white
                                      : const Color(0xFF38BDF8).withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                '${i + 1}. ${_composedNotes[i].pitchKey}',
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
              ),
              const SizedBox(height: 10),

              // 3. Chuyển đổi Nhạc cụ Soạn Nhạc: Cần đàn Guitar <-> Đàn Piano
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      key: const Key('chip_composer_guitar'),
                      visualDensity: VisualDensity.compact,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn ? '🎸 Guitar Fretboard' : '🎸 Soạn bằng Guitar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: !_isPianoMode ? Colors.white : null,
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
                      key: const Key('chip_composer_piano'),
                      visualDensity: VisualDensity.compact,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn ? '🎹 Piano Keys' : '🎹 Soạn bằng Piano',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _isPianoMode ? Colors.white : null,
                          ),
                        ),
                      ),
                      selected: _isPianoMode,
                      onSelected: (_) => setState(() => _isPianoMode = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (!_isPianoMode)
                _buildComposerGuitarBoard(audio, isEn)
              else
                _buildComposerPianoBoard(audio, isEn),

              const SizedBox(height: 14),
              ElevatedButton.icon(
                key: const Key('btn_composer_save_song'),
                onPressed: () => _saveAndFinish(isEn),
                icon: const Icon(Icons.save_rounded, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isEn
                        ? 'Save to Songbook & Play Now'
                        : 'Lưu Vào Kho Bản Nhạc & Chơi Ngay',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposerGuitarBoard(AudioService audio, bool isEn) {
    const stringLabels = ['d1', 'd2', 'd3', 'd4', 'd5', 'd6'];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF231811),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD97706).withOpacity(0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 30),
              for (int f = 0; f <= 5; f++)
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        f == 0 ? (isEn ? 'Open' : 'Buông') : 'Ng.$f',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (int s = 1; s <= 6; s++)
            SizedBox(
              height: 38,
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      stringLabels[s - 1],
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFDE68A),
                      ),
                    ),
                  ),
                  for (int f = 0; f <= 5; f++)
                    Expanded(
                      child: Builder(
                        builder: (_) {
                          final info = GuitarFretboardData.noteAt(
                            stringNumber: s,
                            fret: f,
                          );
                          final m = RegExp(r'\(([A-G]#?[0-9])\)')
                              .firstMatch(info.fullLabel);
                          final pk = m?.group(1) ?? info.noteCode;
                          return InkWell(
                            key: Key('composer_gtr_s${s}_f$f'),
                            onTap: () {
                              _appendNote(
                                SongTabNote(
                                  stringNumber: s,
                                  fret: f,
                                  pitchKey: pk,
                                  noteLabel: info.fullLabel,
                                  audioAsset: info.audioAsset,
                                ),
                                audio,
                                isEn,
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: f == 0
                                      ? const Color(0xFFFDE68A).withOpacity(0.6)
                                      : Colors.white24,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  pk,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
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
        ],
      ),
    );
  }

  Widget _buildComposerPianoBoard(AudioService audio, bool isEn) {
    final oct = _selectedPianoOctave;
    final whiteNotes = [
      ('C$oct', 'Đô', 'assets/audio/notes/c$oct.wav'),
      ('D$oct', 'Rê', 'assets/audio/notes/d$oct.wav'),
      ('E$oct', 'Mi', 'assets/audio/notes/e$oct.wav'),
      ('F$oct', 'Fa', 'assets/audio/notes/f$oct.wav'),
      ('G$oct', 'Sol', 'assets/audio/notes/g$oct.wav'),
      ('A$oct', 'La', 'assets/audio/notes/a$oct.wav'),
      ('B$oct', 'Si', 'assets/audio/notes/b$oct.wav'),
    ];
    final blackNotes = [
      (0, 'C#$oct', 'Đô#', 'assets/audio/notes/csharp$oct.wav'),
      (1, 'D#$oct', 'Rê#', 'assets/audio/notes/dsharp$oct.wav'),
      (3, 'F#$oct', 'Fa#', 'assets/audio/notes/fsharp$oct.wav'),
      (4, 'G#$oct', 'Sol#', 'assets/audio/notes/gsharp$oct.wav'),
      (5, 'A#$oct', 'La#', 'assets/audio/notes/asharp$oct.wav'),
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final o in const [3, 4, 5]) ...[
                if (o != 3) const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    key: Key('chip_composer_octave_$o'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _selectedPianoOctave = o),
                    child: Container(
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedPianoOctave == o
                            ? AppColors.primary
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn ? 'Octave $o' : 'Quãng $o (C$o–B$o)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 155,
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final whiteW = constraints.maxWidth / whiteNotes.length;
                final blackW = whiteW * 0.62;
                return Stack(
                  children: [
                    Row(
                      children: [
                        for (final (pk, vn, wav) in whiteNotes)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1.5),
                              child: InkWell(
                                key: Key('composer_piano_$pk'),
                                onTap: () {
                                  final pos = mapPitchKeyToGuitarPosition(pk);
                                  _appendNote(
                                    SongTabNote(
                                      stringNumber: pos.$1,
                                      fret: pos.$2,
                                      pitchKey: pk,
                                      noteLabel: '$vn ($pk)',
                                      audioAsset: wav,
                                    ),
                                    audio,
                                    isEn,
                                  );
                                },
                                child: Container(
                                  alignment: Alignment.bottomCenter,
                                  padding: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(9),
                                    ),
                                    border: Border.all(color: Colors.black26),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        vn,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        pk,
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black54,
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
                    for (final (slot, pk, vn, wav) in blackNotes)
                      Positioned(
                        left: (slot + 1) * whiteW - (blackW / 2),
                        top: 0,
                        width: blackW,
                        height: 92,
                        child: InkWell(
                          key: Key('composer_piano_$pk'),
                          onTap: () {
                            final pos = mapPitchKeyToGuitarPosition(pk);
                            _appendNote(
                              SongTabNote(
                                stringNumber: pos.$1,
                                fret: pos.$2,
                                pitchKey: pk,
                                noteLabel: '$vn ($pk)',
                                audioAsset: wav,
                              ),
                              audio,
                              isEn,
                            );
                          },
                          child: Container(
                            alignment: Alignment.bottomCenter,
                            padding: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2937),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(7),
                              ),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                vn,
                                style: const TextStyle(
                                  fontSize: 9.5,
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

