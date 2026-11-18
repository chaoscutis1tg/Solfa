import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';
import '../../support_developer/presentation/support_developer_screen.dart';
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Hủy'),
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
                      ),
                      onPressed: () {
                        final val = int.tryParse(controller.text.trim());
                        Navigator.of(ctx).pop(val);
                      },
                      child: const Text('Áp dụng'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Hủy'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      key: const Key('btn_confirm_save_preset'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                      ),
                      onPressed: () {
                        final text = controller.text.trim();
                        Navigator.of(ctx).pop(
                          text.isNotEmpty ? text : defaultName,
                        );
                      },
                      child: const Text('Lưu mẫu'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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

  String _tempoMarking(int bpm, bool isEn) {
    if (bpm < 60) return isEn ? 'Largo (Very Slow)' : 'Largo (Rất chậm)';
    if (bpm < 76) return isEn ? 'Adagio (Slow)' : 'Adagio (Chậm)';
    if (bpm < 108) return isEn ? 'Andante (Walking)' : 'Andante (Vừa phải)';
    if (bpm < 120) return isEn ? 'Moderato (Moderate)' : 'Moderato (Trung bình)';
    if (bpm < 156) return isEn ? 'Allegro (Fast)' : 'Allegro (Nhanh)';
    if (bpm < 200) return isEn ? 'Vivace (Lively)' : 'Vivace (Sôi nổi)';
    return isEn ? 'Presto (Very Fast)' : 'Presto (Rất nhanh)';
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
    final isEn = ref.watch(appSettingsProvider).isEnglish;

    final soundTypes = [
      ('tempo', 'Tempo Lite'),
      ('click', isEn ? 'Mechanical' : 'Cơ học'),
      ('woodblock', isEn ? 'Woodblock' : 'Gỗ trầm'),
      ('bell', isEn ? 'Bell' : 'Chuông'),
    ];
    final subdivisions = [
      (1, isEn ? 'Quarter (1x)' : 'Đơn (1x)'),
      (2, isEn ? 'Eighth (2x)' : 'Đôi (2x)'),
      (3, isEn ? 'Triplet (3x)' : 'Liên 3 (3x)'),
      (4, isEn ? '16th (4x)' : 'Kép (4x)'),
    ];

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
                          isEn
                              ? '${_tempoMarking(cfg.bpm, true)} • ${cfg.intervalMs.toStringAsFixed(0)} ms/beat'
                              : '${_tempoMarking(cfg.bpm, false)} • ${cfg.intervalMs.toStringAsFixed(0)} ms/phách',
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
                            cfg.isRunning
                                ? (isEn ? 'Stop' : 'Dừng nhịp')
                                : (isEn ? 'Start' : 'Bắt đầu'),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isEn ? 'Time Signature' : 'Loại nhịp (Time Signature)',
                    style: const TextStyle(
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isEn ? 'Beat Subdivision' : 'Chia nhỏ phách (Subdivision)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (int i = 0; i < subdivisions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _CompactSelectButton(
                          key: Key('chip_sub_${subdivisions[i].$1}'),
                          label: subdivisions[i].$2,
                          isSelected: cfg.subdivision == subdivisions[i].$1,
                          isDark: isDark,
                          onTap: () =>
                              notifier.setSubdivision(subdivisions[i].$1),
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
                    Expanded(
                      child: Text(
                        isEn ? 'Advanced Settings' : 'Cài đặt nâng cao',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
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
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.bookmark_add_outlined,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      isEn ? '+ Save Preset' : '+ Lưu nhịp',
                                      style: const TextStyle(
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
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.tune_rounded,
                                              size: 15,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isEn ? 'Presets' : 'Mẫu tốc độ',
                                              style: const TextStyle(
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
                Text(
                  isEn ? 'Click Timbre' : 'Âm sắc nhịp',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (int i = 0; i < soundTypes.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _CompactSelectButton(
                          key: Key('chip_sound_${soundTypes[i].$1}'),
                          label: soundTypes[i].$2,
                          isSelected: cfg.soundType == soundTypes[i].$1,
                          isDark: isDark,
                          onTap: () =>
                              notifier.setSoundType(soundTypes[i].$1),
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
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    isEn ? 'Accent Beat 1' : 'Nhấn phách 1',
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
                                        ? (isEn
                                            ? 'Count-in: Off'
                                            : 'Đếm trước: Tắt')
                                        : (isEn
                                            ? 'Count-in: ${cfg.countInBars} bar'
                                            : 'Đếm trước: ${cfg.countInBars} nhịp'),
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
                                  ? (isEn
                                      ? 'Speed Trainer: +${cfg.speedUpIncrementBpm} BPM / ${cfg.speedUpEveryBars} bars (Bars: ${cfg.completedBarsCount})'
                                      : 'Tự động tăng tốc: +${cfg.speedUpIncrementBpm} BPM / ${cfg.speedUpEveryBars} ô nhịp (Đã chạy: ${cfg.completedBarsCount} ô)')
                                  : (isEn
                                      ? 'Auto Speed Trainer'
                                      : 'Tự động tăng tốc (Speed Trainer)'),
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

        const SizedBox(height: 14),

        // 3. Máy Đánh Trống (Drum Loops) & Bộ Gõ Tiết Tấu (Rhythm Tap Accuracy Pad)
        _RhythmTapAndDrumLoopsCard(
          bpm: cfg.bpm,
          isRunning: cfg.isRunning,
          isDark: isDark,
          isEn: isEn,
        ),
      ],
    );
  }
}

class _RhythmTapAndDrumLoopsCard extends ConsumerStatefulWidget {
  final int bpm;
  final bool isRunning;
  final bool isDark;
  final bool isEn;

  const _RhythmTapAndDrumLoopsCard({
    required this.bpm,
    required this.isRunning,
    required this.isDark,
    required this.isEn,
  });

  @override
  ConsumerState<_RhythmTapAndDrumLoopsCard> createState() =>
      _RhythmTapAndDrumLoopsCardState();
}

class _RhythmTapAndDrumLoopsCardState
    extends ConsumerState<_RhythmTapAndDrumLoopsCard> {
  static const String _kUnlockedDrumGroovesPrefsKey =
      'solfa_unlocked_vip_drum_grooves_v1';

  String _selectedGrooveId = 'pop_8beat';
  final Set<String> _unlockedVipGrooves = <String>{};
  int? _lastTapEpochMs;
  String _tapGradeLabel = 'Chạm Pad theo nhịp phách để đo độ chuẩn xác (ms)';
  Color _tapGradeColor = AppColors.primary;
  int _tapCombo = 0;
  int _perfectHits = 0;
  int _totalTaps = 0;

  @override
  void initState() {
    super.initState();
    _loadUnlockedDrumGrooves();
  }

  Future<void> _loadUnlockedDrumGrooves() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kUnlockedDrumGroovesPrefsKey) ??
          const <String>[];
      if (mounted && list.isNotEmpty) {
        setState(() {
          _unlockedVipGrooves.addAll(list);
        });
      }
    } catch (_) {}
  }

  Future<void> _persistUnlockedDrumGrooves() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kUnlockedDrumGroovesPrefsKey,
        _unlockedVipGrooves.toList(),
      );
    } catch (_) {}
  }

  static const List<(String id, String labelVi, String labelEn, int num, int den, int sub, int gemCost, List<String> pattern)>
      _drumGrooves = [
    ('pop_8beat', 'Pop 8-Beat', 'Pop 8-Beat', 4, 4, 2, 0, ['KICK', 'HAT', 'SNARE', 'HAT']),
    ('ballad_44', 'Ballad 4/4', 'Ballad 4/4', 4, 4, 1, 0, ['KICK', 'HAT', 'RIM', 'HAT']),
    ('waltz_34', 'Waltz 3/4', 'Waltz 3/4', 3, 4, 1, 0, ['KICK', 'HAT', 'HAT']),
    ('bolero_vn', 'Bolero / Rumba', 'Bolero Groove', 4, 4, 2, 300, ['KICK', 'SNARE', 'HAT', 'SNARE']),
    ('rock_drive', 'Canon Rock 16B', 'Canon Rock 16B', 4, 4, 2, 350, ['KICK', 'SNARE', 'KICK', 'SNARE']),
    ('funk_shuffle', 'Funk Shuffle', 'Funk Shuffle', 4, 4, 3, 400, ['KICK', 'GHOST', 'SNARE', 'HAT']),
  ];

  Future<void> _onSelectGroove(
    (String, String, String, int, int, int, int, List<String>) g,
  ) async {
    final id = g.$1;
    final cost = g.$7;
    if (cost > 0 && !_unlockedVipGrooves.contains(id)) {
      final ok = await ref
          .read(rewardedAdProvider.notifier)
          .spendGemsForOneHourSession(gemCost: cost);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.warning,
            content: Text(
              'Điệu trống VIP "${g.$2}" cần $cost Gem. Xem video ngắn để nhận ngay +100 Gem!',
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
      setState(() {
        _unlockedVipGrooves.add(id);
      });
      await _persistUnlockedDrumGrooves();
    }

    final metro = ref.read(metronomeProvider.notifier);
    metro.setTimeSignature(g.$4, g.$5);
    metro.setSubdivision(g.$6);
    setState(() {
      _selectedGrooveId = id;
    });
  }

  void _onTapRhythmPad() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final targetIntervalMs = (60000.0 / widget.bpm).round();

    if (ref.read(appSettingsProvider).hapticFeedbackEnabled) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }

    if (_lastTapEpochMs == null || (now - _lastTapEpochMs!) > targetIntervalMs * 2.4) {
      setState(() {
        _lastTapEpochMs = now;
        _tapCombo = 1;
        _totalTaps = 1;
        _perfectHits = 1;
        _tapGradeLabel = 'Bắt đầu nhịp #1 • Gõ tiếp nhịp sau (${targetIntervalMs}ms/phách)!';
        _tapGradeColor = AppColors.primary;
      });
      return;
    }

    final actualInterval = now - _lastTapEpochMs!;
    final diff = actualInterval - targetIntervalMs;
    final absDiff = diff.abs();

    setState(() {
      _lastTapEpochMs = now;
      _totalTaps++;
      if (absDiff <= 28) {
        _tapCombo++;
        _perfectHits++;
        _tapGradeLabel = 'PERFECT! (Lệch ${diff >= 0 ? '+$diff' : '$diff'} ms)';
        _tapGradeColor = AppColors.correct;
      } else if (absDiff <= 65) {
        _tapCombo++;
        _perfectHits++;
        _tapGradeLabel = 'GREAT! (Lệch ${diff >= 0 ? '+$diff' : '$diff'} ms)';
        _tapGradeColor = AppColors.primary;
      } else {
        _tapCombo = 0;
        _tapGradeLabel = diff < 0
            ? 'Hơi SỚM ($diff ms so với chuẩn ${targetIntervalMs}ms)'
            : 'Hơi TRỄ (+$diff ms so với chuẩn ${targetIntervalMs}ms)';
        _tapGradeColor = const Color(0xFFF59E0B);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentBeat =
        ref.watch(metronomeProvider.select((s) => s.currentBeat));
    final currentGroove = _drumGrooves.firstWhere(
      (g) => g.$1 == _selectedGrooveId,
      orElse: () => _drumGrooves.first,
    );
    final accuracyPct = _totalTaps > 0
        ? ((_perfectHits / _totalTaps) * 100).round()
        : 100;

    return Card(
      key: const Key('card_metronome_drum_and_rhythm_pad'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Máy Đánh Trống Đệm Đàn (Drum Groove Loops)
            Row(
              children: [
                const Icon(
                  Icons.album_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.isEn
                        ? 'Drum Groove Loops & Rhythm Tap Trainer'
                        : 'Máy Đánh Trống Đệm Đàn & Bộ Gõ Tiết Tấu (ms)',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
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
                  for (int i = 0; i < _drumGrooves.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Builder(
                      builder: (_) {
                        final g = _drumGrooves[i];
                        final isSelected = g.$1 == _selectedGrooveId;
                        final isLocked =
                            g.$7 > 0 && !_unlockedVipGrooves.contains(g.$1);
                        return ChoiceChip(
                          key: Key('chip_drum_groove_${g.$1}'),
                          visualDensity: VisualDensity.compact,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isLocked) ...[
                                const SolfaGemIcon(size: 11),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                isLocked
                                    ? '${widget.isEn ? g.$3 : g.$2} (${g.$7}G)'
                                    : (widget.isEn ? g.$3 : g.$2),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? Colors.white
                                      : (widget.isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight),
                                ),
                              ),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (_) => _onSelectGroove(g),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Visual Drum Step Matrix (Kick / Snare / Hi-Hat) isolated with RepaintBoundary for 60fps
            RepaintBoundary(
              child: Row(
                children: [
                  for (int b = 0; b < currentGroove.$8.length; b++) ...[
                    if (b > 0) const SizedBox(width: 6),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: (widget.isRunning && currentBeat == (b + 1))
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: (widget.isRunning && currentBeat == (b + 1))
                                ? AppColors.secondary
                                : AppColors.primary.withOpacity(0.25),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Phách ${b + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: (widget.isRunning &&
                                        currentBeat == (b + 1))
                                    ? Colors.white70
                                    : (widget.isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
                              ),
                            ),
                            Text(
                              currentGroove.$8[b],
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: (widget.isRunning &&
                                        currentBeat == (b + 1))
                                    ? Colors.white
                                    : (widget.isDark
                                        ? const Color(0xFF93C5FD)
                                        : AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // 2. Bộ Gõ Tiết Tấu Chấm Độ Lệch Mili-giây (Rhythm Tap Accuracy Pad)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isEn
                      ? 'Rhythm Tap Accuracy Pad'
                      : 'Bộ Gõ Luyện Phản Xạ Tiết Tấu (${widget.bpm} BPM)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.correct.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Combo x$_tapCombo • Chuẩn $accuracyPct%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.correct,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _tapGradeLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: _tapGradeColor,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                key: const Key('btn_rhythm_tap_accuracy_pad'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _tapGradeColor.withOpacity(0.10),
                  side: BorderSide(color: _tapGradeColor.withOpacity(0.55)),
                ),
                onPressed: _onTapRhythmPad,
                icon: Icon(
                  Icons.pan_tool_alt_rounded,
                  size: 18,
                  color: _tapGradeColor,
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.isEn
                        ? 'TAP BEAT PAD HERE (±25ms = PERFECT)'
                        : 'GÕ NHỊP VÀO ĐÂY THEO PHÁCH (±25ms = PERFECT)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: _tapGradeColor,
                    ),
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
    final isEn = ref.watch(appSettingsProvider).isEnglish;
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
                    isEn
                        ? 'Count-in: ${beatData.remainingCountInBeats + 1} beats left'
                        : 'Đếm vào nhịp: còn ${beatData.remainingCountInBeats + 1} phách',
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
                          ? (isEn
                              ? 'Beat ${beatData.currentBeat} / ${beatData.numerator}'
                              : 'Phách ${beatData.currentBeat} / ${beatData.numerator}')
                          : (isEn
                              ? 'Tap beat circles: Accent • Normal • Mute'
                              : 'Chạm số phách để đổi: Nhấn • Thường • Tắt'),
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
