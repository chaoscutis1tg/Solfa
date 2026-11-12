import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../application/metronome_controller.dart';

final metronomePresetsProvider =
    FutureProvider<List<MetronomePresetModel>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return db.getMetronomePresets();
});

/// UI-10: Máy đếm nhịp cơ học - Mechanical Metronome (UC-14 & Section 12)
/// - Gom gọn toàn bộ điều khiển chính vừa khít trong 1 màn hình duy nhất.
/// - Cố định kích thước đèn phách (`_BeatIndicatorHeader`) để không bao giờ giật giao diện theo nhịp.
/// - Bật `AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())` mượt mà.
class MetronomeScreen extends ConsumerStatefulWidget {
  const MetronomeScreen({super.key});

  @override
  ConsumerState<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends ConsumerState<MetronomeScreen>
    with WidgetsBindingObserver {
  static const List<(int num, int den)> _timeSignatures = [
    (1, 4),
    (2, 4),
    (3, 4),
    (4, 4),
    (6, 8),
  ];

  static const List<(String code, String label)> _soundTypes = [
    ('click', 'Cơ học'),
    ('woodblock', 'Gỗ trầm'),
    ('bell', 'Chuông'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(metronomeProvider.notifier).pause();
    }
  }

  Future<void> _showDirectBpmInputDialog(int currentBpm) async {
    final controller = TextEditingController(text: currentBpm.toString());
    final entered = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nhập tốc độ BPM (30 – 300)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ví dụ: 120',
            suffixText: 'BPM',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(96, 42)),
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              Navigator.of(ctx).pop(val);
            },
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
    if (entered != null) {
      ref.read(metronomeProvider.notifier).setBpm(entered);
    }
  }

  void _showPresetsSheet(List<MetronomePresetModel> presets) {
    final notifier = ref.read(metronomeProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mẫu tốc độ chuẩn (Presets)',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((p) {
                    return ActionChip(
                      avatar: const Icon(Icons.speed_rounded, size: 16),
                      label: Text(
                        '${p.name} (${p.bpm} BPM • ${p.timeSignatureLabel})',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      onPressed: () {
                        notifier.setBpm(p.bpm);
                        notifier.setTimeSignature(p.numerator, p.denominator);
                        notifier.setSoundType(p.soundType);
                        Navigator.of(ctx).pop();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _tempoMarking(int bpm) {
    if (bpm < 60) return 'Largo (Rất chậm)';
    if (bpm < 76) return 'Adagio (Chậm)';
    if (bpm < 108) return 'Andante (Vừa phải)';
    if (bpm < 120) return 'Moderato (Trung bình)';
    if (bpm < 156) return 'Allegro (Nhanh)';
    if (bpm < 200) return 'Vivace (Sôi nổi)';
    return 'Presto (Rất nhanh)';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(
      metronomeProvider.select(
        (s) => (
          bpm: s.bpm,
          numerator: s.numerator,
          denominator: s.denominator,
          soundType: s.soundType,
          accentFirstBeat: s.accentFirstBeat,
          countInBars: s.countInBars,
          volume: s.volume,
          isRunning: s.isRunning,
          intervalMs: s.intervalMs,
        ),
      ),
    );
    final notifier = ref.read(metronomeProvider.notifier);
    final presetsAsync = ref.watch(metronomePresetsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
      children: [
        // 1. Main Mechanical Metronome Console Card
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                // Isolated, Fixed-Height Beat Visualizer (ZERO layout shift on beats!)
                const RepaintBoundary(
                  child: _BeatIndicatorHeader(),
                ),
                const SizedBox(height: 6),

                // Compact Tap-to-Edit BPM Display
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showDirectBpmInputDialog(cfg.bpm),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${cfg.bpm}',
                              key: const Key('metronome_bpm_text'),
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                height: 1.0,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'BPM',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.edit_outlined,
                              size: 15,
                              color: AppColors.primary.withOpacity(0.75),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_tempoMarking(cfg.bpm)} • ${cfg.intervalMs.toStringAsFixed(0)} ms/phách',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Balanced 4-button Stepper Row (-5, -1, +1, +5)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('btn_bpm_minus_5'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => notifier.incrementBpm(-5),
                        child: const Text(
                          '-5',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('btn_bpm_minus_1'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => notifier.incrementBpm(-1),
                        child: const Icon(Icons.remove_rounded, size: 19),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('btn_bpm_plus_1'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => notifier.incrementBpm(1),
                        child: const Icon(Icons.add_rounded, size: 19),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('btn_bpm_plus_5'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => notifier.incrementBpm(5),
                        child: const Text(
                          '+5',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),

                // Compact BPM Slider (30 - 300)
                SizedBox(
                  height: 36,
                  child: Slider(
                    key: const Key('slider_bpm'),
                    value: cfg.bpm.toDouble(),
                    min: 30,
                    max: 300,
                    divisions: 270,
                    onChanged: (val) => notifier.setBpm(val.round()),
                  ),
                ),

                const SizedBox(height: 4),

                // Play/Stop & Tap Tempo Buttons (2 equal columns)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('btn_tap_tempo'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 46),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: notifier.registerTap,
                        icon: const Icon(Icons.touch_app_rounded, size: 19),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Tap Tempo'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const Key('btn_metronome_play_pause'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 46),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          backgroundColor: cfg.isRunning
                              ? AppColors.wrong
                              : AppColors.primary,
                        ),
                        onPressed: notifier.togglePlayPause,
                        icon: Icon(
                          cfg.isRunning
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 22,
                        ),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            cfg.isRunning ? 'Dừng nhịp' : 'Bắt đầu',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 2. All-in-One Compact Rhythm & Sound Card (Fits on the same screen!)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Signature Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Loại nhịp',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    presetsAsync.maybeWhen(
                      data: (presets) => presets.isNotEmpty
                          ? InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _showPresetsSheet(presets),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Mẫu tốc độ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (int i = 0; i < _timeSignatures.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _CompactSelectButton(
                          key: Key(
                            'chip_sig_${_timeSignatures[i].$1}_${_timeSignatures[i].$2}',
                          ),
                          label:
                              '${_timeSignatures[i].$1}/${_timeSignatures[i].$2}',
                          isSelected: cfg.numerator == _timeSignatures[i].$1 &&
                              cfg.denominator == _timeSignatures[i].$2,
                          isDark: isDark,
                          onTap: () => notifier.setTimeSignature(
                            _timeSignatures[i].$1,
                            _timeSignatures[i].$2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),
                const Text(
                  'Âm sắc máy đếm nhịp cơ',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (int i = 0; i < _soundTypes.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _CompactSelectButton(
                          key: Key('chip_sound_${_soundTypes[i].$1}'),
                          label: _soundTypes[i].$2,
                          isSelected: cfg.soundType == _soundTypes[i].$1,
                          isDark: isDark,
                          onTap: () =>
                              notifier.setSoundType(_soundTypes[i].$1),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),
                // Compact Accent + Count-in + Volume Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () =>
                            notifier.setAccentFirstBeat(!cfg.accentFirstBeat),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: cfg.accentFirstBeat
                                ? AppColors.accentAmber.withOpacity(0.16)
                                : AppColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: cfg.accentFirstBeat
                                  ? AppColors.accentAmber
                                  : AppColors.primary.withOpacity(0.18),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cfg.accentFirstBeat
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_off_outlined,
                                size: 16,
                                color: cfg.accentFirstBeat
                                    ? AppColors.accentAmber
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 5),
                              const Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Nhấn phách 1',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          final nextBars = (cfg.countInBars + 1) % 3;
                          notifier.setCountInBars(nextBars);
                        },
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: cfg.countInBars > 0
                                ? AppColors.primary.withOpacity(0.14)
                                : AppColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.22),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size: 15,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    cfg.countInBars == 0
                                        ? 'Đếm trước: Tắt'
                                        : 'Đếm trước: ${cfg.countInBars} nhịp',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactSelectButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _CompactSelectButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primary
          : (isDark
              ? Colors.white.withOpacity(0.06)
              : AppColors.primary.withOpacity(0.06)),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.secondary
                  : AppColors.primary.withOpacity(0.18),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Strictly fixed-height (`62px`) beat visualizer widget.
/// Repaints ONLY itself when `currentBeat` ticks, with CONSTANT `38x38` circle sizes
/// so there is ZERO layout shift or screen jumping on beats!
class _BeatIndicatorHeader extends ConsumerWidget {
  const _BeatIndicatorHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beatData = ref.watch(
      metronomeProvider.select(
        (s) => (
          numerator: s.numerator,
          currentBeat: s.currentBeat,
          isRunning: s.isRunning,
          accentFirstBeat: s.accentFirstBeat,
          status: s.status,
          remainingCountInBeats: s.remainingCountInBeats,
        ),
      ),
    );

    return SizedBox(
      height: 62,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 18,
            child: beatData.status == MetronomeStatus.countIn
                ? Text(
                    'Đếm vào nhịp: còn ${beatData.remainingCountInBeats + 1} phách',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentAmber,
                      fontSize: 11.5,
                    ),
                  )
                : Text(
                    beatData.isRunning
                        ? 'Phách hiện tại: ${beatData.currentBeat} / ${beatData.numerator}'
                        : 'Nhịp ${beatData.numerator} phách • Sẵn sàng',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(beatData.numerator, (index) {
                final beatNumber = index + 1;
                final isActive = beatData.isRunning &&
                    beatData.currentBeat == beatNumber;
                final isAccentBeat =
                    beatNumber == 1 && beatData.accentFirstBeat;

                final activeColor = isAccentBeat
                    ? AppColors.accentAmber
                    : AppColors.primary;

                return Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? activeColor
                        : AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isAccentBeat
                          ? AppColors.accentAmber
                          : AppColors.primary.withOpacity(0.35),
                      width: isAccentBeat ? 2.0 : 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$beatNumber',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: isActive
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
