import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    ('tempo', 'Tempo Lite'),
    ('click', 'Cơ học'),
    ('woodblock', 'Gỗ trầm'),
    ('bell', 'Chuông'),
  ];

  static const List<(int sub, String label)> _subdivisions = [
    (1, 'Đơn (1x)'),
    (2, 'Đôi (2x)'),
    (3, 'Liên 3 (3x)'),
    (4, 'Kép (4x)'),
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
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ví dụ: 120',
            helperText: 'Giới hạn hợp lệ: 30 đến 300 BPM',
            suffixText: 'BPM',
          ),
          onSubmitted: (value) {
            final val = int.tryParse(value.trim());
            Navigator.of(ctx).pop(val);
          },
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
    controller.dispose();
    if (entered != null) {
      ref.read(metronomeProvider.notifier).setBpm(entered);
    }
  }

  Future<void> _showSaveCustomPresetDialog() async {
    final s = ref.read(metronomeProvider);
    final defaultName = 'Nhịp ${s.bpm} BPM (${s.timeSignature})';
    final controller = TextEditingController(text: defaultName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Lưu Preset cá nhân'),
        content: TextField(
          key: const Key('input_custom_preset_name'),
          controller: controller,
          inputFormatters: [
            LengthLimitingTextInputFormatter(36),
          ],
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên mẫu nhịp của bạn',
            hintText: 'Ví dụ: Luyện ngón Guitar 95 BPM',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            key: const Key('btn_confirm_save_preset'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(96, 42)),
            onPressed: () {
              final text = controller.text.trim();
              Navigator.of(ctx).pop(text.isNotEmpty ? text : defaultName);
            },
            child: const Text('Lưu mẫu'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name != null && name.isNotEmpty) {
      final db = ref.read(appDatabaseProvider);
      final preset = MetronomePresetModel(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        bpm: s.bpm,
        numerator: s.numerator,
        denominator: s.denominator,
        soundType: s.soundType,
      );
      await db.saveMetronomePreset(preset);
      ref.invalidate(metronomePresetsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã lưu mẫu "$name" (${s.bpm} BPM)')),
        );
      }
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Mẫu tốc độ (Presets & Cá nhân)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('btn_save_preset_in_sheet'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showSaveCustomPresetDialog();
                      },
                      icon: const Icon(Icons.bookmark_add_outlined, size: 17),
                      label: const Text('Lưu nhịp hiện tại'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((p) {
                    final isCustom = p.id.startsWith('custom_');
                    return InputChip(
                      avatar: Icon(
                        isCustom
                            ? Icons.bookmark_rounded
                            : Icons.speed_rounded,
                        size: 16,
                        color: isCustom
                            ? AppColors.accentAmber
                            : AppColors.primary,
                      ),
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
                      onDeleted: isCustom
                          ? () async {
                              await ref
                                  .read(appDatabaseProvider)
                                  .deleteMetronomePreset(p.id);
                              ref.invalidate(metronomePresetsProvider);
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                              }
                            }
                          : null,
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
          subdivision: s.subdivision,
          accentFirstBeat: s.accentFirstBeat,
          countInBars: s.countInBars,
          autoSpeedUpEnabled: s.autoSpeedUpEnabled,
          speedUpEveryBars: s.speedUpEveryBars,
          speedUpIncrementBpm: s.speedUpIncrementBpm,
          targetMaxBpm: s.targetMaxBpm,
          completedBarsCount: s.completedBarsCount,
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
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        // 1. Điều khiển chính (Primary Metronome Console)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              children: [
                // Isolated, Fixed-Height Beat Visualizer (ZERO layout shift on beats)
                const RepaintBoundary(
                  child: _BeatIndicatorHeader(),
                ),
                const SizedBox(height: 8),

                // Large BPM Display (Tap-to-Edit)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showDirectBpmInputDialog(cfg.bpm),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.16),
                      ),
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
                                fontSize: 52,
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
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: AppColors.primary.withOpacity(0.75),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_tempoMarking(cfg.bpm)} • ${cfg.intervalMs.toStringAsFixed(0)} ms/phách',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Balanced 4-button Stepper Row (-5, -1, +1, +5)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('btn_bpm_minus_5'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
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
                          minimumSize: const Size(0, 40),
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
                          minimumSize: const Size(0, 40),
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
                          minimumSize: const Size(0, 40),
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
                  height: 38,
                  child: Slider(
                    key: const Key('slider_bpm'),
                    value: cfg.bpm.toDouble(),
                    min: 30,
                    max: 300,
                    divisions: 270,
                    onChanged: (val) => notifier.setBpm(val.round()),
                  ),
                ),

                const SizedBox(height: 6),

                // Play/Stop & Tap Tempo Buttons (One Primary Action: Bắt đầu / Dừng nhịp)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('btn_tap_tempo'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
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
                          minimumSize: const Size(double.infinity, 48),
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

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Time Signature & Subdivision (Core Rhythm Controls)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Loại nhịp (Time Signature)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Chia nhỏ phách (Subdivision)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (int i = 0; i < _subdivisions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _CompactSelectButton(
                          key: Key('chip_sub_${_subdivisions[i].$1}'),
                          label: _subdivisions[i].$2,
                          isSelected: cfg.subdivision == _subdivisions[i].$1,
                          isDark: isDark,
                          onTap: () =>
                              notifier.setSubdivision(_subdivisions[i].$1),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 2. Cài đặt nâng cao & Mẫu nhịp (Separated Advanced Section)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Cài đặt nâng cao',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              key: const Key('btn_save_custom_preset'),
                              borderRadius: BorderRadius.circular(8),
                              onTap: _showSaveCustomPresetDialog,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bookmark_add_outlined,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      '+ Lưu nhịp',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            presetsAsync.maybeWhen(
                              data: (presets) => presets.isNotEmpty
                                  ? InkWell(
                                      key: const Key('btn_open_presets_sheet'),
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _showPresetsSheet(presets),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
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
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                const Text(
                  'Âm sắc nhịp',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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
                // Compact Accent + Count-in Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () =>
                            notifier.setAccentFirstBeat(!cfg.accentFirstBeat),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: cfg.accentFirstBeat
                                ? AppColors.primary.withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: cfg.accentFirstBeat
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.borderDark
                                      : AppColors.borderLight),
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
                                    ? AppColors.primary
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
                                      fontWeight: FontWeight.w700,
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
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: cfg.countInBars > 0
                                ? AppColors.primary.withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: cfg.countInBars > 0
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.borderDark
                                      : AppColors.borderLight),
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
                                      fontWeight: FontWeight.w700,
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

                const SizedBox(height: 10),
                // Speed Trainer / Automator
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cfg.autoSpeedUpEnabled
                        ? AppColors.correct.withOpacity(0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cfg.autoSpeedUpEnabled
                          ? AppColors.correct.withOpacity(0.45)
                          : (isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            size: 17,
                            color: cfg.autoSpeedUpEnabled
                                ? AppColors.correct
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              cfg.autoSpeedUpEnabled
                                  ? 'Tự động tăng tốc: +${cfg.speedUpIncrementBpm} BPM / ${cfg.speedUpEveryBars} ô nhịp (Đã chạy: ${cfg.completedBarsCount} ô)'
                                  : 'Tự động tăng tốc (Speed Trainer)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 28,
                            child: Transform.scale(
                              scale: 0.82,
                              child: Switch(
                                key: const Key('switch_speed_trainer'),
                                value: cfg.autoSpeedUpEnabled,
                                onChanged: (v) =>
                                    notifier.setAutoSpeedUp(enabled: v),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (cfg.autoSpeedUpEnabled) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final preset in const [
                              (2, 4, '+2 BPM / 4 nhịp'),
                              (5, 4, '+5 BPM / 4 nhịp'),
                              (5, 8, '+5 BPM / 8 nhịp'),
                            ]) ...[
                              if (preset.$1 != 2 || preset.$2 != 4)
                                const SizedBox(width: 6),
                              Expanded(
                                child: _CompactSelectButton(
                                  key: Key(
                                    'speed_step_${preset.$1}_${preset.$2}',
                                  ),
                                  label: preset.$3,
                                  isSelected: cfg.speedUpIncrementBpm ==
                                          preset.$1 &&
                                      cfg.speedUpEveryBars == preset.$2,
                                  isDark: isDark,
                                  onTap: () => notifier.setAutoSpeedUp(
                                    enabled: true,
                                    incrementBpm: preset.$1,
                                    everyBars: preset.$2,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
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
          beatStates: s.beatStates,
          status: s.status,
          remainingCountInBeats: s.remainingCountInBeats,
        ),
      ),
    );

    return SizedBox(
      height: 64,
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
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      beatData.isRunning
                          ? 'Phách ${beatData.currentBeat} / ${beatData.numerator}'
                          : 'Chạm số phách để đổi: Nhấn • Thường • Tắt',
                      maxLines: 1,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
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
                final beatMode = index < beatData.beatStates.length
                    ? beatData.beatStates[index]
                    : (beatNumber == 1 && beatData.accentFirstBeat ? 2 : 1);
                final isAccentBeat = beatMode == 2;
                final isMutedBeat = beatMode == 0;

                final Color activeColor = isMutedBeat
                    ? Colors.grey.withOpacity(0.45)
                    : (isAccentBeat
                        ? AppColors.accentAmber
                        : AppColors.primary);

                final Color idleBgColor = isMutedBeat
                    ? Colors.grey.withOpacity(0.08)
                    : (isAccentBeat
                        ? AppColors.accentAmber.withOpacity(0.14)
                        : AppColors.primary.withOpacity(0.12));

                final Color borderColor = isMutedBeat
                    ? Colors.grey.withOpacity(0.40)
                    : (isAccentBeat
                        ? AppColors.accentAmber
                        : AppColors.primary.withOpacity(0.42));

                return GestureDetector(
                  key: Key('beat_circle_$beatNumber'),
                  onTap: () => ref
                      .read(metronomeProvider.notifier)
                      .cycleBeatState(index),
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isActive ? activeColor : idleBgColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: borderColor,
                        width: isAccentBeat ? 2.0 : 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isMutedBeat ? '×' : '$beatNumber',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: isActive
                            ? Colors.white
                            : (isMutedBeat
                                ? Colors.grey
                                : Theme.of(context).textTheme.bodyLarge?.color),
                      ),
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
