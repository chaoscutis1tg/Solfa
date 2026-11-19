import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../core/audio/audio_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../guitar/presentation/guitar_studio_sheet.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';

/// Mô hình 1 bài tập Dò Vòng Hợp Âm Đệm Hát 4 ô nhịp thực tế.
class ChordProgressionChallenge {
  final String id;
  final String keyGroup; // 'C_Am' | 'G_Em' | 'F_Dm'
  final String titleVi;
  final String titleEn;
  final String romanFormula; // e.g. 'I – V – vi – IV'
  final List<String> targetChords; // 4 chords, e.g. ['C', 'G', 'Am', 'F']
  final String tipVi;
  final String tipEn;

  const ChordProgressionChallenge({
    required this.id,
    required this.keyGroup,
    required this.titleVi,
    required this.titleEn,
    required this.romanFormula,
    required this.targetChords,
    required this.tipVi,
    required this.tipEn,
  });
}

/// 6 hợp âm trong từng giọng chuẩn (khớp 100% với file WAV thật trong assets/audio/keys/).
const Map<String, List<(String degree, String chord, String audioAsset)>>
    kDiatonicKeyFamilies = {
  'C_Am': [
    ('I', 'C', 'assets/audio/keys/chord_c_maj.wav'),
    ('ii', 'Dm', 'assets/audio/keys/chord_d_min.wav'),
    ('iii', 'Em', 'assets/audio/keys/chord_e_min.wav'),
    ('IV', 'F', 'assets/audio/keys/chord_f_maj.wav'),
    ('V', 'G', 'assets/audio/keys/chord_g_maj.wav'),
    ('vi', 'Am', 'assets/audio/keys/chord_a_min.wav'),
  ],
  'G_Em': [
    ('I', 'G', 'assets/audio/keys/chord_g_maj.wav'),
    ('ii', 'Am', 'assets/audio/keys/chord_a_min.wav'),
    ('iii', 'Bm', 'assets/audio/keys/chord_b_min.wav'),
    ('IV', 'C', 'assets/audio/keys/chord_c_maj.wav'),
    ('V', 'D', 'assets/audio/keys/chord_d_maj.wav'),
    ('vi', 'Em', 'assets/audio/keys/chord_e_min.wav'),
  ],
  'F_Dm': [
    ('I', 'F', 'assets/audio/keys/chord_f_maj.wav'),
    ('ii', 'Gm', 'assets/audio/keys/chord_g_min.wav'),
    ('iii', 'Am', 'assets/audio/keys/chord_a_min.wav'),
    ('IV', 'Bb', 'assets/audio/keys/chord_bb_maj.wav'),
    ('V', 'C', 'assets/audio/keys/chord_c_maj.wav'),
    ('vi', 'Dm', 'assets/audio/keys/chord_d_min.wav'),
  ],
};

const List<ChordProgressionChallenge> kChordProgressionChallenges = [
  // === GIỌNG ĐÔ TRƯỞNG / LA THỨ (C / Am) ===
  ChordProgressionChallenge(
    id: 'prog_c_1564',
    keyGroup: 'C_Am',
    titleVi: 'Vòng Canon / V-Pop Quốc Dân',
    titleEn: 'Pop Anthem Progression',
    romanFormula: 'I – V – vi – IV',
    targetChords: ['C', 'G', 'Am', 'F'],
    tipVi: 'Mở đầu sáng sủa ở Chủ âm C (I), đi qua Át G (V), lắng xuống Am (vi) rồi mở rộng ở F (IV).',
    tipEn: 'Bright tonic C (I), dominant G (V), emotional Am (vi), and warm subdominant F (IV).',
  ),
  ChordProgressionChallenge(
    id: 'prog_am_6415',
    keyGroup: 'C_Am',
    titleVi: 'Vòng Ballad Trữ Tình Sâu Lắng',
    titleEn: 'Emotional Minor Ballad',
    romanFormula: 'vi – IV – I – V',
    targetChords: ['Am', 'F', 'C', 'G'],
    tipVi: 'Mở đầu bằng hợp âm Thứ Am (vi) tạo màu tự sự buồn nhẹ, sau đó bừng sáng ở C (I) và G (V).',
    tipEn: 'Starts on minor vi (Am) for an introspective mood before lifting to C (I) and G (V).',
  ),
  ChordProgressionChallenge(
    id: 'prog_c_4536',
    keyGroup: 'C_Am',
    titleVi: 'Vòng V-Pop / J-Pop Hiện Đại (4–5–3–6)',
    titleEn: 'Modern Royal Road (IV–V–iii–vi)',
    romanFormula: 'IV – V – iii – vi',
    targetChords: ['F', 'G', 'Em', 'Am'],
    tipVi: 'Vòng hòa âm cực kỳ thịnh hành trong nhạc trẻ hiện đại & R&B: dâng trào từ F → G rồi kết dịu ở Em → Am.',
    tipEn: 'Iconic modern pop/R&B progression rising F → G and resolving gently through Em → Am.',
  ),
  ChordProgressionChallenge(
    id: 'prog_c_1625',
    keyGroup: 'C_Am',
    titleVi: 'Vòng Acoustic Chill & Retro (1–6–2–5)',
    titleEn: 'Acoustic Turnaround (I–vi–ii–V)',
    romanFormula: 'I – vi – ii – V',
    targetChords: ['C', 'Am', 'Dm', 'G'],
    tipVi: 'Chuyển động quãng 4 êm ái Dm (ii) hút mạnh về Át G (V), tạo lực đẩy quay lại đầu câu.',
    tipEn: 'Classic smooth turnaround where ii (Dm) pulls naturally into dominant V (G).',
  ),

  // === GIỌNG SOL TRƯỞNG / MI THỨ (G / Em) ===
  ChordProgressionChallenge(
    id: 'prog_g_1564',
    keyGroup: 'G_Em',
    titleVi: 'Vòng Đệm Guitar Acoustic Kinh Điển',
    titleEn: 'Acoustic Campfire Classic',
    romanFormula: 'I – V – vi – IV',
    targetChords: ['G', 'D', 'Em', 'C'],
    tipVi: 'Thế bấm mở vàng của Guitar thùng: G vang dày, D sáng rõ, Em sâu lắng và C êm dịu.',
    tipEn: 'Resonant open-string guitar favorite: G → D → Em → C.',
  ),
  ChordProgressionChallenge(
    id: 'prog_em_6415',
    keyGroup: 'G_Em',
    titleVi: 'Vòng Lo-Fi / Indie Đêm Khuya',
    titleEn: 'Midnight Indie / Lo-Fi Loop',
    romanFormula: 'vi – IV – I – V',
    targetChords: ['Em', 'C', 'G', 'D'],
    tipVi: 'Bắt đầu từ Mi Thứ (Em) trầm ấm rồi vươn lên Đô Trưởng (C) và Sol Trưởng (G).',
    tipEn: 'Opens on deep E minor before blooming into C major and G major.',
  ),
  ChordProgressionChallenge(
    id: 'prog_g_4536',
    keyGroup: 'G_Em',
    titleVi: 'Vòng Điệp Khúc Cao Trào (C–D–Bm–Em)',
    titleEn: 'Soaring Chorus Progression',
    romanFormula: 'IV – V – iii – vi',
    targetChords: ['C', 'D', 'Bm', 'Em'],
    tipVi: 'Hợp âm Bm (iii) tạo bước chuyển lãng mạn rất đặc trưng trước khi về Em (vi).',
    tipEn: 'B minor (iii) creates a lush, emotional bridge before landing on E minor (vi).',
  ),
  ChordProgressionChallenge(
    id: 'prog_g_2516',
    keyGroup: 'G_Em',
    titleVi: 'Vòng R&B / Jazz Pop (2–5–1–6)',
    titleEn: 'Smooth 2–5–1–6 Groove',
    romanFormula: 'ii – V – I – vi',
    targetChords: ['Am', 'D', 'G', 'Em'],
    tipVi: 'Cụm ii – V – I (Am → D → G) là xương sống của R&B và nhạc nhẹ hiện đại.',
    tipEn: 'The ii–V–I cadence (Am → D → G) is the backbone of R&B and jazz-pop.',
  ),

  // === GIỌNG FA TRƯỞNG / RÊ THỨ (F / Dm) ===
  ChordProgressionChallenge(
    id: 'prog_f_1564',
    keyGroup: 'F_Dm',
    titleVi: 'Vòng Ballad Piano Ấm Áp',
    titleEn: 'Warm Piano Ballad',
    romanFormula: 'I – V – vi – IV',
    targetChords: ['F', 'C', 'Dm', 'Bb'],
    tipVi: 'Giọng Fa Trưởng rất vừa tầm giọng hát nam & nữ Việt Nam khi đệm Piano và kẹp Capo.',
    tipEn: 'F Major sits comfortably in vocal range with warm Bb subdominant color.',
  ),
  ChordProgressionChallenge(
    id: 'prog_dm_6415',
    keyGroup: 'F_Dm',
    titleVi: 'Vòng Trữ Tình Rê Thứ (Dm–Bb–F–C)',
    titleEn: 'Dramatic D Minor Progression',
    romanFormula: 'vi – IV – I – V',
    targetChords: ['Dm', 'Bb', 'F', 'C'],
    tipVi: 'Dm xuống Bb tạo chiều sâu da diết, sau đó giải tỏa sáng rực tại F và C.',
    tipEn: 'Dm to Bb builds dramatic tension before resolving brightly to F and C.',
  ),
  ChordProgressionChallenge(
    id: 'prog_f_4536',
    keyGroup: 'F_Dm',
    titleVi: 'Vòng Điệp Khúc Hiện Đại (Bb–C–Am–Dm)',
    titleEn: 'Modern Pop Chorus in F/Dm',
    romanFormula: 'IV – V – iii – vi',
    targetChords: ['Bb', 'C', 'Am', 'Dm'],
    tipVi: 'Từ Bb bước lên C rồi lướt qua Am về Dm cực kỳ bắt tai trong các bản hit V-Pop.',
    tipEn: 'Steps up from Bb to C, gliding through Am into Dm.',
  ),
  ChordProgressionChallenge(
    id: 'prog_f_1625',
    keyGroup: 'F_Dm',
    titleVi: 'Vòng Soul / Acoustic (F–Dm–Gm–C)',
    titleEn: 'Soulful Acoustic Turnaround',
    romanFormula: 'I – vi – ii – V',
    targetChords: ['F', 'Dm', 'Gm', 'C'],
    tipVi: 'Hợp âm Gm (ii) mềm mại dẫn thẳng về Đô Trưởng (V) trước khi khép lại ở Fa Trưởng.',
    tipEn: 'Rich Gm (ii) leads smoothly into C dominant (V).',
  ),
];

Future<void> openChordProgressionEarScreen(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const ChordProgressionEarScreen(),
    ),
  );
}

class ChordProgressionEarScreen extends ConsumerStatefulWidget {
  const ChordProgressionEarScreen({super.key});

  @override
  ConsumerState<ChordProgressionEarScreen> createState() =>
      _ChordProgressionEarScreenState();
}

class _ChordProgressionEarScreenState
    extends ConsumerState<ChordProgressionEarScreen>
    with WidgetsBindingObserver {
  bool _useGuitarSound = true; // true = Guitar | false = Piano
  String _selectedKeyGroup = 'C_Am';
  late List<ChordProgressionChallenge> _activeQueue;
  int _currentIndex = 0;
  final List<String> _userGuesses = [];
  bool _isPlayingSequence = false;
  int _activePlayingSlot = -1; // 0..3 when playing sequence
  int _combo = 0;
  int _solvedCount = 0;
  Timer? _seqTimer;
  AudioService? _audioRef;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rebuildQueue(shuffle: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audioRef = ref.read(audioServiceProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _seqTimer?.cancel();
    _audioRef?.stop(includePolyphony: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopSequence();
    }
  }

  void _rebuildQueue({required bool shuffle}) {
    _stopSequence();
    final list = kChordProgressionChallenges
        .where((c) => c.keyGroup == _selectedKeyGroup)
        .toList();
    if (shuffle) {
      list.shuffle(math.Random());
    }
    setState(() {
      _activeQueue = list;
      _currentIndex = 0;
      _userGuesses.clear();
    });
  }

  void _stopSequence() {
    _seqTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPlayingSequence = false;
        _activePlayingSlot = -1;
      });
    }
  }

  String _assetForChord(String chord) {
    for (final entries in kDiatonicKeyFamilies.values) {
      for (final e in entries) {
        if (e.$2 == chord) return e.$3;
      }
    }
    return 'assets/audio/keys/chord_c_maj.wav';
  }

  void _playSingleChord(String chord, AudioService audio) {
    final asset = _assetForChord(chord);
    if (_useGuitarSound) {
      audio.playGuitarAsset(asset);
    } else {
      audio.playPolyphonicAsset(asset);
    }
  }

  void _playProgressionSequence(
    ChordProgressionChallenge challenge,
    AudioService audio,
  ) {
    if (_isPlayingSequence) {
      _stopSequence();
      return;
    }
    setState(() {
      _isPlayingSequence = true;
      _activePlayingSlot = 0;
    });
    _playSingleChord(challenge.targetChords[0], audio);

    int step = 0;
    _seqTimer?.cancel();
    _seqTimer = Timer.periodic(const Duration(milliseconds: 1150), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      step++;
      if (step >= challenge.targetChords.length) {
        t.cancel();
        setState(() {
          _isPlayingSequence = false;
          _activePlayingSlot = -1;
        });
        return;
      }
      setState(() => _activePlayingSlot = step);
      _playSingleChord(challenge.targetChords[step], audio);
    });
  }

  Future<void> _onTapChordPad(
    String chord,
    ChordProgressionChallenge challenge,
    AudioService audio,
    bool isEn,
  ) async {
    _playSingleChord(chord, audio);
    if (_userGuesses.length >= 4) return;

    if (ref.read(appSettingsProvider).hapticFeedbackEnabled &&
        !audio.isTestMode) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }

    setState(() {
      _userGuesses.add(chord);
    });

    if (_userGuesses.length == 4) {
      bool allMatch = true;
      for (int i = 0; i < 4; i++) {
        if (_userGuesses[i] != challenge.targetChords[i]) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) {
        audio.playFeedbackSfx(isCorrect: true);
        final nextCombo = _combo + 1;
        final nextSolved = _solvedCount + 1;
        setState(() {
          _combo = nextCombo;
          _solvedCount = nextSolved;
        });
        // Thưởng +25 Gem cho mỗi 4 vòng hợp âm giải đúng!
        if (nextSolved % 4 == 0) {
          await ref
              .read(rewardedAdProvider.notifier)
              .grantBonusPrestigePoints(
                25,
                customMessage: isEn
                    ? '+25 Gems for mastering 4 Chord Progressions!'
                    : 'Thưởng +25 Gem chinh phục 4 Vòng Hợp Âm đệm hát!',
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.correct,
                behavior: SnackBarBehavior.floating,
                content: Row(
                  children: [
                    const SolfaGemIcon(size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEn
                            ? 'Awesome ear! Earned +25 Bonus Gems!'
                            : 'Đôi tai xuất sắc! Bạn vừa nhận thưởng +25 Gem!',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }
      } else {
        audio.playFeedbackSfx(isCorrect: false);
        setState(() => _combo = 0);
      }
    }
  }

  void _nextChallenge(AudioService audio) {
    _stopSequence();
    setState(() {
      _currentIndex = (_currentIndex + 1) % _activeQueue.length;
      _userGuesses.clear();
    });
    if (!audio.isTestMode) {
      _playProgressionSequence(_activeQueue[_currentIndex], audio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = ref.watch(appSettingsProvider).isEnglish;
    final audio = ref.watch(audioServiceProvider);
    final guitarType = ref.watch(selectedGuitarTypeProvider);
    audio.setGuitarType(guitarType);

    final challenge = _activeQueue[_currentIndex];
    final palette = kDiatonicKeyFamilies[_selectedKeyGroup]!;
    final tonicChord = palette.first.$2;
    final isEvaluated = _userGuesses.length == 4;
    final isAllCorrect = isEvaluated &&
        List.generate(
          4,
          (i) => _userGuesses[i] == challenge.targetChords[i],
        ).every((v) => v);

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
                  ? 'Chord Progression Ear Studio'
                  : 'Luyện Dò Vòng Hợp Âm Đệm Hát',
              maxLines: 1,
            ),
          ),
          actions: [
            IconButton(
              key: const Key('btn_shuffle_chord_progs'),
              tooltip: isEn ? 'Shuffle' : 'Trộn ngẫu nhiên',
              onPressed: () => _rebuildQueue(shuffle: true),
              icon: const Icon(Icons.shuffle_rounded, size: 20),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            key: const Key('screen_chord_progression_ear'),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            children: [
              // 1. Chọn nhạc cụ đệm mẫu: Guitar <-> Piano
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      key: const Key('chip_prog_sound_guitar'),
                      visualDensity: VisualDensity.compact,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn ? '🎸 Guitar Chords' : '🎸 Nghe Đàn Guitar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _useGuitarSound ? Colors.white : null,
                          ),
                        ),
                      ),
                      selected: _useGuitarSound,
                      onSelected: (_) => setState(() => _useGuitarSound = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      key: const Key('chip_prog_sound_piano'),
                      visualDensity: VisualDensity.compact,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn ? '🎹 Piano Chords' : '🎹 Nghe Đàn Piano',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: !_useGuitarSound ? Colors.white : null,
                          ),
                        ),
                      ),
                      selected: !_useGuitarSound,
                      onSelected: (_) =>
                          setState(() => _useGuitarSound = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 2. Chọn bộ Giọng (C/Am | G/Em | F/Dm)
              Row(
                children: [
                  for (final (kId, kLbl) in const [
                    ('C_Am', 'Giọng C / Am'),
                    ('G_Em', 'Giọng G / Em'),
                    ('F_Dm', 'Giọng F / Dm'),
                  ]) ...[
                    if (kId != 'C_Am') const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        key: Key('chip_prog_key_$kId'),
                        visualDensity: VisualDensity.compact,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isEn ? kLbl.replaceFirst('Giọng ', 'Key ') : kLbl,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: _selectedKeyGroup == kId
                                  ? Colors.white
                                  : null,
                            ),
                          ),
                        ),
                        selected: _selectedKeyGroup == kId,
                        onSelected: (_) {
                          setState(() => _selectedKeyGroup = kId);
                          _rebuildQueue(shuffle: false);
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // 3. Thẻ phát Vòng 4 Hợp Âm & 4 Ô Đáp Án
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            isEn
                                ? 'Progression ${_currentIndex + 1}/${_activeQueue.length}'
                                : 'Vòng ${_currentIndex + 1}/${_activeQueue.length} • Đã giải: $_solvedCount',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.secondary
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentAmber.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Combo x$_combo',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            key: const Key('btn_play_chord_prog_question'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              backgroundColor: _isPlayingSequence
                                  ? AppColors.wrong
                                  : AppColors.primary,
                            ),
                            onPressed: () =>
                                _playProgressionSequence(challenge, audio),
                            icon: Icon(
                              _isPlayingSequence
                                  ? Icons.stop_rounded
                                  : Icons.play_circle_fill_rounded,
                              size: 20,
                            ),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _isPlayingSequence
                                    ? (isEn ? 'Stop' : 'Dừng phát')
                                    : (isEn
                                        ? 'Play 4-Chord Loop'
                                        : 'Nghe Vòng 4 Hợp Âm'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            key: const Key('btn_play_prog_tonic_ref'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () =>
                                _playSingleChord(tonicChord, audio),
                            icon: const Icon(Icons.music_note_rounded, size: 16),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isEn ? 'Root $tonicChord' : 'Gốc $tonicChord (I)',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 4 Ô nhịp điền hợp âm
                    Row(
                      children: [
                        for (int i = 0; i < 4; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: Builder(
                              builder: (_) {
                                final hasVal = i < _userGuesses.length;
                                final val = hasVal ? _userGuesses[i] : '?';
                                final isPlayingHere = _activePlayingSlot == i;
                                final isSlotCorrect = isEvaluated &&
                                    _userGuesses[i] ==
                                        challenge.targetChords[i];
                                Color bg = isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : AppColors.backgroundLight;
                                Color border = isPlayingHere
                                    ? const Color(0xFFF59E0B)
                                    : (hasVal
                                        ? AppColors.primary
                                        : (isDark
                                            ? AppColors.borderDark
                                            : AppColors.borderLight));
                                if (isEvaluated) {
                                  border = isSlotCorrect
                                      ? AppColors.correct
                                      : AppColors.wrong;
                                  bg = (isSlotCorrect
                                          ? AppColors.correct
                                          : AppColors.wrong)
                                      .withOpacity(0.14);
                                }
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  height: 64,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: bg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: border,
                                      width: isPlayingHere || isEvaluated
                                          ? 2.0
                                          : 1.2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          isEn ? 'Bar ${i + 1}' : 'Ô ${i + 1}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          val,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: hasVal
                                                ? (isEvaluated
                                                    ? (isSlotCorrect
                                                        ? AppColors.correct
                                                        : AppColors.wrong)
                                                    : (isDark
                                                        ? Colors.white
                                                        : AppColors.primaryDark))
                                                : Colors.grey,
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
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. Bàn 6 Hợp Âm trong Giọng + Nút Xóa 1 ô
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      isEn
                          ? 'Tap 4 chords in order:'
                          : 'Chạm chọn lần lượt 4 hợp âm bạn nghe được:',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('btn_prog_backspace'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _userGuesses.isEmpty
                        ? null
                        : () => setState(() => _userGuesses.removeLast()),
                    icon: const Icon(Icons.backspace_outlined, size: 15),
                    label: Text(
                      isEn ? 'Undo' : 'Xóa 1 ô',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (int row = 0; row < 2; row++) ...[
                if (row > 0) const SizedBox(height: 8),
                Row(
                  children: [
                    for (int col = 0; col < 3; col++) ...[
                      if (col > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Builder(
                          builder: (_) {
                            final item = palette[row * 3 + col];
                            return Material(
                              color: isDark
                                  ? AppColors.surfaceDark
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                key: Key('btn_prog_pad_${item.$2}'),
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _onTapChordPad(
                                  item.$2,
                                  challenge,
                                  audio,
                                  isEn,
                                ),
                                child: Container(
                                  height: 58,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.primary
                                          .withOpacity(isDark ? 0.35 : 0.25),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item.$1,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppColors.secondary
                                              : AppColors.primary,
                                        ),
                                      ),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          item.$2,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
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
              ],

              // 5. Giải thích chi tiết khi điền đủ 4 ô
              if (isEvaluated) ...[
                const SizedBox(height: 14),
                Container(
                  key: const Key('card_prog_evaluation_result'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (isAllCorrect ? AppColors.correct : AppColors.wrong)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          (isAllCorrect ? AppColors.correct : AppColors.wrong)
                              .withOpacity(0.55),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isAllCorrect
                            ? (isEn
                                ? '🎉 Exact Match! (${challenge.romanFormula})'
                                : '🎉 Chuẩn xác 100%! (${challenge.romanFormula})')
                            : (isEn
                                ? 'Correct answer: ${challenge.targetChords.join(' → ')} (${challenge.romanFormula})'
                                : 'Đáp án đúng: ${challenge.targetChords.join(' → ')} (${challenge.romanFormula})'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isAllCorrect
                              ? AppColors.correct
                              : AppColors.wrong,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEn ? challenge.titleEn : challenge.titleVi,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isEn ? challenge.tipEn : challenge.tipVi,
                        style: const TextStyle(fontSize: 12, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (!isAllCorrect) ...[
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('btn_retry_chord_prog'),
                                onPressed: () =>
                                    setState(() => _userGuesses.clear()),
                                child: Text(isEn ? 'Try Again' : 'Thử lại'),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: ElevatedButton.icon(
                              key: const Key('btn_next_chord_prog'),
                              onPressed: () => _nextChallenge(audio),
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: Text(
                                isEn ? 'Next Loop' : 'Vòng tiếp theo',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

