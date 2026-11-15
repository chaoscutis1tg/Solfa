import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/note_formatter.dart';
import '../../../support_developer/application/rewarded_ad_controller.dart';
import 'musical_staff_widget.dart';
import 'piano_keyboard_widget.dart';

/// Opens the interactive "Đàn Piano & Tra cứu Khuông nhạc tự do (C3–C5)" modal bottom sheet.
Future<void> showFreePianoExplorerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const FreePianoExplorerSheet(),
  );
}

class FreePianoExplorerSheet extends ConsumerStatefulWidget {
  const FreePianoExplorerSheet({super.key});

  @override
  ConsumerState<FreePianoExplorerSheet> createState() =>
      _FreePianoExplorerSheetState();
}

class _FreePianoExplorerSheetState
    extends ConsumerState<FreePianoExplorerSheet> {
  int _selectedOctave = 4; // 3, 4, or 5
  String _selectedPitchClass = 'C'; // 'C', 'C#', 'D', ..., 'B'
  String? _activeHarmonyCode;
  String? _activeHarmonyTitle;
  String? _activeHarmonyFormula;
  String? _activeHarmonyAsset;
  List<String>? _activeHarmonyKeys;

  // Melodic Dictation (Chép nhạc giai điệu 3–4 nốt) state
  bool _isDictationMode = false;
  int _dictationIndex = 0;
  List<String> _userTappedNotes = [];
  bool _dictationCompleted = false;
  String? _dictationFeedback;
  bool _dictationFeedbackIsError = false;

  static const List<(String title, String hint, List<String> notes)>
      _dictationMelodies = [
    (
      'Giai điệu #1: Hợp âm Đô Trưởng rải lên',
      'Bắt đầu từ Đô (C4), đi lên theo quãng 3 Trưởng và quãng 5 Đúng',
      ['C4', 'E4', 'G4'],
    ),
    (
      'Giai điệu #2: Bước đi liền bậc Đô – Rê – Mi',
      'Bắt đầu từ Đô (C4), đi lên liền bậc từng cung',
      ['C4', 'D4', 'E4'],
    ),
    (
      'Giai điệu #3: Giai điệu kết về chủ âm',
      'Bắt đầu từ Sol (G4), đi xuống Mi (E4) rồi về Đô (C4)',
      ['G4', 'E4', 'C4'],
    ),
    (
      'Giai điệu #4: Âm hưởng La Thứ trữ tình',
      'Bắt đầu từ La (A4), xuống Mi (E4) và quay lại La (A4)',
      ['A4', 'E4', 'A4'],
    ),
    (
      'Giai điệu #5: Khúc ca 4 nốt tươi sáng',
      'Bắt đầu từ Đô (C4): Đô – Rê – Mi – Đô',
      ['C4', 'D4', 'E4', 'C4'],
    ),
    (
      'Giai điệu #6: Hợp âm Fa Trưởng ấm áp',
      'Bắt đầu từ Fa (F4), đi lên La (A4) và Sol (G4)',
      ['F4', 'A4', 'G4'],
    ),
  ];

  String get _activeNoteKey => '$_selectedPitchClass$_selectedOctave';

  static const List<(
    String code,
    String chipLabel,
    String title,
    String formula,
    String asset,
    List<String> keys,
  )> _harmonySamples = [
    (
      'C_maj',
      'Đô Trưởng (C)',
      'Hợp âm Đô Trưởng (C – E – G)',
      'Cấu tạo: Đô (C4) + Mi (E4, +4 bán âm) + Sol (G4, +7 bán âm). Âm sắc tươi sáng, vững chãi.',
      'assets/audio/keys/chord_c_maj.wav',
      ['C4', 'E4', 'G4'],
    ),
    (
      'A_min',
      'La Thứ (Am)',
      'Hợp âm La Thứ (A – C – E)',
      'Cấu tạo: La (A) + Đô (C, +3 bán âm) + Mi (E, +7 bán âm). Âm sắc trữ tình, sâu lắng.',
      'assets/audio/keys/chord_a_min.wav',
      ['A4', 'C4', 'E4'],
    ),
    (
      'F_maj',
      'Fa Trưởng (F)',
      'Hợp âm Fa Trưởng (F – A – C)',
      'Cấu tạo: Fa (F) + La (A, +4 bán âm) + Đô (C, +7 bán âm). Bậc IV ấm áp trong giọng Đô trưởng.',
      'assets/audio/keys/chord_f_maj.wav',
      ['F4', 'A4', 'C4'],
    ),
    (
      'G_dom7',
      'Sol Bảy (G7)',
      'Hợp âm Bảy Át Sol 7 (G – B – D – F)',
      'Cấu tạo 4 nốt: Sol (G) + Si (B) + Rê (D) + Fa (F). Tạo lực hút mạnh về hợp âm chủ Đô Trưởng.',
      'assets/audio/keys/chord_g_dom7.wav',
      ['G4', 'B4', 'D4', 'F4'],
    ),
    (
      'C_aug',
      'Đô Tăng (Caug)',
      'Hợp âm Đô Tăng (C – E – G♯)',
      'Cấu tạo: Đô (C4) + Mi (E4, +4 bán âm) + Sol thăng (G♯4, +8 bán âm). Màu sắc lơ lửng, kịch tính.',
      'assets/audio/keys/chord_c_aug.wav',
      ['C4', 'E4', 'G#4'],
    ),
    (
      'C_dim',
      'Đô Giảm (Cdim)',
      'Hợp âm Đô Giảm (C – D♯ – F♯)',
      'Cấu tạo: Đô (C4) + Rê thăng (D♯4, +3 bán âm) + Fa thăng (F♯4, +6 bán âm). Quãng 5 giảm căng thẳng, giàu kịch tính.',
      'assets/audio/keys/chord_c_dim.wav',
      ['C4', 'D#4', 'F#4'],
    ),
    (
      'M3',
      'Quãng 3 Trưởng',
      'Quãng 3 Trưởng (Đô C4 → Mi E4)',
      'Khoảng cách 2 cung (4 bán âm) từ Đô (C4) lên Mi (E4) — nền tảng của hợp âm Trưởng.',
      'assets/audio/intervals/c4_maj3_harm.wav',
      ['C4', 'E4'],
    ),
    (
      'P5',
      'Quãng 5 Đúng',
      'Quãng 5 Đúng (Đô C4 → Sol G4)',
      'Khoảng cách 3.5 cung (7 bán âm) từ Đô (C4) lên Sol (G4) — âm thanh hòa hợp hoàn hảo.',
      'assets/audio/intervals/c4_p5_harm.wav',
      ['C4', 'G4'],
    ),
  ];

  static const Map<String, int> _semitoneOffsets = {
    'C': 0,
    'C#': 1,
    'D': 2,
    'D#': 3,
    'E': 4,
    'F': 5,
    'F#': 6,
    'G': 7,
    'G#': 8,
    'A': 9,
    'A#': 10,
    'B': 11,
  };

  double _frequencyHz(String pitchClass, int octave) {
    final semi = _semitoneOffsets[pitchClass] ?? 0;
    final midi = (octave + 1) * 12 + semi;
    return 440.0 * math.pow(2.0, (midi - 69) / 12.0);
  }

  String _staffPositionDescription(String pitchClass, int octave) {
    final baseLetter = pitchClass.replaceAll('#', '');
    final hasSharp = pitchClass.contains('#');
    final sharpSuffix = hasSharp ? ' (kèm dấu thăng ♯)' : '';

    if (octave == 3) {
      switch (baseLetter) {
        case 'C':
          return 'Khóa Fa (𝄢): Nằm trong khe thứ 2 (từ dưới lên)$sharpSuffix.';
        case 'D':
          return 'Khóa Fa (𝄢): Nằm chính giữa dòng kẻ thứ 3 (dòng giữa)$sharpSuffix.';
        case 'E':
          return 'Khóa Fa (𝄢): Nằm trong khe thứ 3$sharpSuffix.';
        case 'F':
          return 'Khóa Fa (𝄢): Nằm trên dòng kẻ thứ 4 (giữa 2 chấm Khóa Fa)$sharpSuffix.';
        case 'G':
          return 'Khóa Fa (𝄢): Nằm trong khe thứ 4 (giữa dòng 4 & 5)$sharpSuffix.';
        case 'A':
          return 'Khóa Fa (𝄢): Nằm trên dòng kẻ thứ 5 (dòng trên cùng)$sharpSuffix.';
        case 'B':
          return 'Khóa Fa (𝄢): Nằm sát ngay phía trên dòng kẻ thứ 5$sharpSuffix.';
      }
    } else if (octave == 4) {
      switch (baseLetter) {
        case 'C':
          return 'Khóa Sol (𝄞): Nằm trên 1 dòng kẻ phụ ngay dưới khuông nhạc$sharpSuffix.';
        case 'D':
          return 'Khóa Sol (𝄞): Nằm sát ngay bên dưới dòng kẻ thứ 1$sharpSuffix.';
        case 'E':
          return 'Khóa Sol (𝄞): Nằm trên dòng kẻ thứ 1 (dưới cùng)$sharpSuffix.';
        case 'F':
          return 'Khóa Sol (𝄞): Nằm trong khe thứ 1 (giữa dòng 1 & 2)$sharpSuffix.';
        case 'G':
          return 'Khóa Sol (𝄞): Nằm trên dòng kẻ thứ 2 (tâm vòng xoắn Khóa Sol)$sharpSuffix.';
        case 'A':
          return 'Khóa Sol (𝄞): Nằm trong khe thứ 2 (chuẩn quốc tế 440 Hz)$sharpSuffix.';
        case 'B':
          return 'Khóa Sol (𝄞): Nằm chính giữa dòng kẻ thứ 3 (dòng giữa)$sharpSuffix.';
      }
    } else {
      switch (baseLetter) {
        case 'C':
          return 'Khóa Sol (𝄞): Nằm trong khe thứ 3 (giữa dòng 3 & 4)$sharpSuffix.';
        case 'D':
          return 'Khóa Sol (𝄞): Nằm trên dòng kẻ thứ 4$sharpSuffix.';
        case 'E':
          return 'Khóa Sol (𝄞): Nằm trong khe thứ 4 (khe trên cùng)$sharpSuffix.';
        case 'F':
          return 'Khóa Sol (𝄞): Nằm trên dòng kẻ thứ 5 (dòng trên cùng)$sharpSuffix.';
        case 'G':
          return 'Khóa Sol (𝄞): Nằm sát phía trên dòng kẻ thứ 5$sharpSuffix.';
        case 'A':
          return 'Khóa Sol (𝄞): Nằm trên 1 dòng kẻ phụ phía trên khuông nhạc$sharpSuffix.';
        case 'B':
          return 'Khóa Sol (𝄞): Nằm sát trên dòng kẻ phụ thứ 1 phía trên$sharpSuffix.';
      }
    }
    return 'Khuông nhạc 5 dòng kẻ';
  }

  void _selectAndPlay(String pitchClass, int octave, {bool fromPianoTap = false}) {
    final tappedNoteKey = '$pitchClass$octave';
    setState(() {
      _selectedPitchClass = pitchClass;
      _selectedOctave = octave;
      _activeHarmonyCode = null;
      _activeHarmonyTitle = null;
      _activeHarmonyFormula = null;
      _activeHarmonyAsset = null;
      _activeHarmonyKeys = null;
    });
    ref.read(audioServiceProvider).playPianoKey(tappedNoteKey);

    if (fromPianoTap && _isDictationMode && !_dictationCompleted) {
      final melody = _dictationMelodies[_dictationIndex];
      final targetNotes = melody.$3;
      final nextSlot = _userTappedNotes.length;
      if (nextSlot < targetNotes.length) {
        final expectedNote = targetNotes[nextSlot];
        if (tappedNoteKey == expectedNote) {
          final updated = [..._userTappedNotes, tappedNoteKey];
          final isDone = updated.length >= targetNotes.length;
          setState(() {
            _userTappedNotes = updated;
            _dictationCompleted = isDone;
            _dictationFeedbackIsError = false;
            _dictationFeedback = isDone
                ? 'Xuất sắc! Bạn đã chép chính xác toàn bộ giai điệu. Đã ghi nhận hoàn thành Nhiệm Vụ Chép Nhạc hôm nay!'
                : 'Chính xác nốt thứ ${updated.length}! Hãy bấm tiếp nốt thứ ${updated.length + 1}...';
          });
          if (isDone) {
            unawaited(
              ref.read(audioServiceProvider).playSessionCompleteFanfare(),
            );
            unawaited(
              ref
                  .read(rewardedAdProvider.notifier)
                  .recordMelodicDictationCompleted(),
            );
          }
        } else {
          setState(() {
            _dictationFeedbackIsError = true;
            _dictationFeedback =
                'Chưa đúng cao độ nốt thứ ${nextSlot + 1}! Hãy bấm "Nghe giai điệu" để cảm nhận lại hướng đi của nốt.';
          });
        }
      }
    }
  }

  Future<void> _playCurrentDictationMelody() async {
    final melody = _dictationMelodies[_dictationIndex];
    final audio = ref.read(audioServiceProvider);
    if (audio.isTestMode) {
      await audio.playPianoKey(melody.$3.first);
      return;
    }
    for (int i = 0; i < melody.$3.length; i++) {
      if (!mounted || !_isDictationMode) return;
      await audio.playPianoKey(melody.$3[i]);
      if (i < melody.$3.length - 1) {
        await Future.delayed(const Duration(milliseconds: 380));
      }
    }
  }

  void _toggleMelodicDictation() {
    final nextMode = !_isDictationMode;
    setState(() {
      _isDictationMode = nextMode;
      _selectedOctave = 4;
      _userTappedNotes = [];
      _dictationCompleted = false;
      _dictationFeedbackIsError = false;
      _dictationFeedback = nextMode
          ? 'Nghe giai điệu và chạm lần lượt các phím trên đàn Piano theo đúng thứ tự.'
          : null;
    });
    if (nextMode) {
      unawaited(_playCurrentDictationMelody());
    }
  }

  void _nextDictationMelody() {
    setState(() {
      _dictationIndex = (_dictationIndex + 1) % _dictationMelodies.length;
      _selectedOctave = 4;
      _userTappedNotes = [];
      _dictationCompleted = false;
      _dictationFeedbackIsError = false;
      _dictationFeedback =
          'Đã chuyển sang câu giai điệu mới! Hãy nghe và bấm lại từng nốt trên đàn.';
    });
    unawaited(_playCurrentDictationMelody());
  }

  void _selectHarmonySample((
    String code,
    String chipLabel,
    String title,
    String formula,
    String asset,
    List<String> keys,
  ) sample) {
    final firstKey = sample.$6.first;
    final pc = firstKey.replaceAll(RegExp(r'[0-9]'), '').toUpperCase();
    setState(() {
      _selectedPitchClass = pc;
      _selectedOctave = 4;
      _activeHarmonyCode = sample.$1;
      _activeHarmonyTitle = sample.$3;
      _activeHarmonyFormula = sample.$4;
      _activeHarmonyAsset = sample.$5;
      _activeHarmonyKeys = sample.$6;
    });
    ref.read(audioServiceProvider).playAsset(sample.$5);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final freq = _frequencyHz(_selectedPitchClass, _selectedOctave);
    final vnName = NoteFormatter.toVietnameseLabel(_activeNoteKey);
    final staffDesc =
        _staffPositionDescription(_selectedPitchClass, _selectedOctave);

    return Container(
      key: const Key('free_piano_explorer_sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.28),
          width: 1.2,
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
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

              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.piano_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đàn Piano & Tra cứu Khuông nhạc',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Chạm phím bất kỳ (C3–C5) để nghe cao độ & xem vị trí dòng/khe',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('btn_close_free_piano_explorer'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Octave Switcher (C3 Khóa Fa | C4 Khóa Sol | C5 Khóa Sol)
              Row(
                children: [
                  _OctaveTabButton(
                    key: const Key('explorer_octave_3'),
                    title: 'Quãng 3 (C3–B3)',
                    sub: 'Khóa Fa 𝄢 • Trầm',
                    isSelected: _selectedOctave == 3,
                    isDark: isDark,
                    onTap: () => _selectAndPlay(_selectedPitchClass, 3),
                  ),
                  const SizedBox(width: 6),
                  _OctaveTabButton(
                    key: const Key('explorer_octave_4'),
                    title: 'Quãng 4 (C4–B4)',
                    sub: 'Khóa Sol 𝄞 • Chuẩn',
                    isSelected: _selectedOctave == 4,
                    isDark: isDark,
                    onTap: () => _selectAndPlay(_selectedPitchClass, 4),
                  ),
                  const SizedBox(width: 6),
                  _OctaveTabButton(
                    key: const Key('explorer_octave_5'),
                    title: 'Quãng 5 (C5–B5)',
                    sub: 'Khóa Sol 𝄞 • Cao',
                    isSelected: _selectedOctave == 5,
                    isDark: isDark,
                    onTap: () => _selectAndPlay(_selectedPitchClass, 5),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 5-Line Musical Staff Preview
              MusicalStaffWidget(
                targetNoteKey: _activeNoteKey,
                selectedNoteKey: _activeNoteKey,
                showNote: true,
                isSightReading: false,
              ),
              const SizedBox(height: 10),

              // Active Note Details Card (Name + Hz + Staff line/space explanation + Replay button)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(isDark ? 0.14 : 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              _activeHarmonyTitle ?? vnName,
                              key: const Key('explorer_active_note_label'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (_activeHarmonyKeys == null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentAmber.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${freq.toStringAsFixed(1)} Hz',
                              style: const TextStyle(
                                color: AppColors.accentAmber,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        TextButton.icon(
                          key: const Key('btn_explorer_replay_note'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor:
                                AppColors.primary.withOpacity(0.14),
                          ),
                          onPressed: () {
                            if (_activeHarmonyAsset != null) {
                              ref
                                  .read(audioServiceProvider)
                                  .playAsset(_activeHarmonyAsset!);
                            } else {
                              _selectAndPlay(
                                  _selectedPitchClass, _selectedOctave);
                            }
                          },
                          icon: const Icon(Icons.volume_up_rounded, size: 15),
                          label: const Text(
                            'Nghe',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _activeHarmonyFormula ?? staffDesc,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Quick Chord & Interval Multi-Key Explorer Strip
              const Row(
                children: [
                  Icon(
                    Icons.library_music_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Bấm thử Hợp âm & Quãng chuẩn (Tô sáng các phím cấu thành):',
                      style: TextStyle(
                        fontSize: 11.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final sample in _harmonySamples)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          key: Key('explorer_harmony_${sample.$1}'),
                          label: Text(
                            sample.$2,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          selected: _activeHarmonyCode == sample.$1,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => _selectHarmonySample(sample),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Melodic Dictation Mini-Game (Chép nhạc giai điệu 3–4 nốt)
              _buildMelodicDictationSection(isDark),
              const SizedBox(height: 8),

              // Interactive Piano Keyboard
              PianoKeyboardWidget(
                highlightedNoteKey: _activeNoteKey,
                highlightedNoteKeys: _activeHarmonyKeys,
                selectedNoteKey: _activeNoteKey,
                showHighlight: true,
                enableBlackKeys: true,
                onKeyTap: (rawKey) {
                  final pc =
                      rawKey.replaceAll(RegExp(r'[0-9]'), '').toUpperCase();
                  _selectAndPlay(pc, _selectedOctave, fromPianoTap: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMelodicDictationSection(bool isDark) {
    final melody = _dictationMelodies[_dictationIndex];
    final targetNotes = melody.$3;
    final firstNoteLabel = NoteFormatter.toVietnameseLabel(targetNotes.first);

    return Container(
      key: const Key('card_melodic_dictation'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDictationMode
            ? AppColors.accentAmber.withOpacity(isDark ? 0.14 : 0.09)
            : (isDark
                ? Colors.white.withOpacity(0.04)
                : AppColors.primary.withOpacity(0.04)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDictationMode
              ? AppColors.accentAmber.withOpacity(0.55)
              : AppColors.primary.withOpacity(0.22),
          width: _isDictationMode ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hearing_rounded,
                size: 18,
                color: AppColors.accentAmber,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Thử thách Chép Nhạc Giai Điệu (3–4 nốt)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                key: const Key('btn_toggle_melodic_dictation'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: _isDictationMode
                      ? AppColors.accentAmber
                      : AppColors.primary,
                  foregroundColor:
                      _isDictationMode ? Colors.black87 : Colors.white,
                ),
                onPressed: _toggleMelodicDictation,
                icon: Icon(
                  _isDictationMode
                      ? Icons.close_rounded
                      : Icons.play_arrow_rounded,
                  size: 15,
                ),
                label: Text(
                  _isDictationMode ? 'Đóng thử thách' : 'Bắt đầu chép nhạc',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (_isDictationMode) ...[
            const SizedBox(height: 8),
            Text(
              '${melody.$1} • Nốt mở đầu gợi ý: $firstNoteLabel',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              melody.$2,
              style: const TextStyle(fontSize: 11.5),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(targetNotes.length, (idx) {
                final isSolved = idx < _userTappedNotes.length;
                final isCurrent = idx == _userTappedNotes.length;
                final slotLabel = isSolved
                    ? NoteFormatter.toVietnameseLabel(_userTappedNotes[idx])
                    : (idx == 0
                        ? '1. $firstNoteLabel'
                        : 'Nốt #${idx + 1}: ?');
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSolved
                        ? AppColors.correct.withOpacity(0.18)
                        : (isCurrent
                            ? AppColors.accentAmber.withOpacity(0.20)
                            : Colors.grey.withOpacity(0.12)),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: isSolved
                          ? AppColors.correct
                          : (isCurrent
                              ? AppColors.accentAmber
                              : Colors.grey.withOpacity(0.35)),
                      width: isCurrent ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSolved
                            ? Icons.check_circle_rounded
                            : (isCurrent
                                ? Icons.touch_app_rounded
                                : Icons.music_note_rounded),
                        size: 13,
                        color: isSolved
                            ? AppColors.correct
                            : (isCurrent ? AppColors.accentAmber : Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        slotLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isSolved ? AppColors.correct : null,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            if (_dictationFeedback != null) ...[
              const SizedBox(height: 7),
              Text(
                _dictationFeedback!,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _dictationCompleted
                      ? AppColors.correct
                      : (_dictationFeedbackIsError
                          ? AppColors.wrong
                          : AppColors.primary),
                ),
              ),
            ],
            if (_dictationCompleted &&
                !ref.watch(rewardedAdProvider).questDictationClaimedToday) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('btn_dictation_claim_quest'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.correct,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 34),
                  ),
                  onPressed: () async {
                    final pts = await ref
                        .read(rewardedAdProvider.notifier)
                        .claimDailyQuest('dictation');
                    if (pts > 0 && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.correct,
                          content: Text(
                            'Đã nhận +$pts Điểm Uy Tín từ nhiệm vụ Chép Nhạc Giai Điệu!',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.workspace_premium_rounded, size: 16),
                  label: const Text(
                    'Nhận thưởng Nhiệm vụ Chép Nhạc (+30 Điểm Uy Tín)',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  key: const Key('btn_replay_melodic_dictation'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _playCurrentDictationMelody,
                  icon: const Icon(Icons.volume_up_rounded, size: 15),
                  label: const Text(
                    'Nghe giai điệu',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const Key('btn_next_melodic_dictation'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _nextDictationMelody,
                  icon: const Icon(Icons.skip_next_rounded, size: 15),
                  label: const Text(
                    'Câu giai điệu khác',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OctaveTabButton extends StatelessWidget {
  final String title;
  final String sub;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _OctaveTabButton({
    super.key,
    required this.title,
    required this.sub,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected
            ? AppColors.primary
            : (isDark
                ? Colors.white.withOpacity(0.06)
                : AppColors.primary.withOpacity(0.06)),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.secondary
                    : AppColors.primary.withOpacity(0.22),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    sub,
                    style: TextStyle(
                      fontSize: 9.8,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white.withOpacity(0.92)
                          : Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
