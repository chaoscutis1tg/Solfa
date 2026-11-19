import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/app_providers.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';

/// Cấu hình Khiên Bảo Vệ Chuỗi (Streak Freeze) & Nhắc giờ luyện tập hằng ngày (100% Offline SQLite).
class StreakShieldReminderState {
  static const int kShieldGemCost = 150;
  static const int kMaxShields = 3;

  final int shieldCount; // 0..3
  final bool reminderEnabled;
  final String reminderTime; // '07:30' | '12:30' | '19:30' | '20:30' | '21:30'

  const StreakShieldReminderState({
    this.shieldCount = 0,
    this.reminderEnabled = false,
    this.reminderTime = '20:30',
  });

  StreakShieldReminderState copyWith({
    int? shieldCount,
    bool? reminderEnabled,
    String? reminderTime,
  }) {
    return StreakShieldReminderState(
      shieldCount: shieldCount ?? this.shieldCount,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  /// Trả về true nếu đã tới hoặc qua khung giờ nhắc học hôm nay mà chưa hoàn thành mục tiêu.
  bool isReminderDueNow({required bool isDailyGoalReached, DateTime? nowOverride}) {
    if (!reminderEnabled || isDailyGoalReached) return false;
    final now = nowOverride ?? DateTime.now();
    final parts = reminderTime.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0]) ?? 20;
    final m = int.tryParse(parts[1]) ?? 30;
    final nowMinutes = now.hour * 60 + now.minute;
    final targetMinutes = h * 60 + m;
    return nowMinutes >= targetMinutes;
  }
}

class StreakShieldReminderNotifier
    extends StateNotifier<StreakShieldReminderState> {
  final AppDatabase _db;
  final Ref _ref;

  StreakShieldReminderNotifier(this._db, this._ref)
      : super(const StreakShieldReminderState()) {
    loadFromDb();
  }

  Future<void> _persistInRoot(Future<void> Function() task) async {
    if (Zone.current == Zone.root) {
      await task();
    } else {
      unawaited(Zone.root.run(task));
    }
  }

  Future<void> loadFromDb() async {
    await _persistInRoot(() async {
      try {
        final map = await _db.getAllSettings();
        if (!mounted) return;
        final shields =
            (int.tryParse(map['streak_freeze_shields'] ?? '0') ?? 0).clamp(
          0,
          StreakShieldReminderState.kMaxShields,
        );
        final enabled = map['study_reminder_enabled'] == '1';
        final time = map['study_reminder_time'] ?? '20:30';
        if (state.shieldCount > shields || state.reminderEnabled) return;
        state = StreakShieldReminderState(
          shieldCount: shields,
          reminderEnabled: enabled,
          reminderTime: time,
        );
      } catch (_) {}
    });
  }

  Future<void> setReminderEnabled(bool enabled) async {
    state = state.copyWith(reminderEnabled: enabled);
    await _persistInRoot(() async {
      try {
        await _db.setSetting('study_reminder_enabled', enabled ? '1' : '0');
      } catch (_) {}
    });
  }

  Future<void> setReminderTime(String time) async {
    state = state.copyWith(reminderTime: time, reminderEnabled: true);
    await _persistInRoot(() async {
      try {
        await _db.setSetting('study_reminder_time', time);
        await _db.setSetting('study_reminder_enabled', '1');
      } catch (_) {}
    });
  }

  /// Mua +1 Khiên Bảo Vệ Chuỗi bằng 150 Gem (Tối đa tích trữ 3 khiên).
  Future<bool> purchaseStreakShield() async {
    if (state.shieldCount >= StreakShieldReminderState.kMaxShields) {
      return false;
    }
    final adState = _ref.read(rewardedAdProvider);
    if (adState.prestigePoints < StreakShieldReminderState.kShieldGemCost) {
      return false;
    }
    final isRootZone = Zone.current == Zone.root;
    final nextShields =
        (state.shieldCount + 1).clamp(0, StreakShieldReminderState.kMaxShields);
    state = state.copyWith(shieldCount: nextShields);

    await _persistInRoot(() async {
      await _ref.read(rewardedAdProvider.notifier).spendGemsForOneHourSession(
            gemCost: StreakShieldReminderState.kShieldGemCost,
          );
      try {
        await _db.setSetting('streak_freeze_shields', nextShields.toString());
        if (isRootZone && mounted) {
          _ref.invalidate(overallProgressProvider);
        }
      } catch (_) {}
    });
    return true;
  }
}

final streakShieldReminderProvider = StateNotifierProvider<
    StreakShieldReminderNotifier, StreakShieldReminderState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return StreakShieldReminderNotifier(db, ref);
});

Future<void> showStreakShieldAndReminderSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _StreakShieldAndReminderModal(),
  );
}

class _StreakShieldAndReminderModal extends ConsumerWidget {
  const _StreakShieldAndReminderModal();

  static const List<String> _presetTimes = [
    '07:30',
    '12:30',
    '19:30',
    '20:30',
    '21:30',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = ref.watch(appSettingsProvider).isEnglish;
    final shieldState = ref.watch(streakShieldReminderProvider);
    final notifier = ref.read(streakShieldReminderProvider.notifier);
    final adState = ref.watch(rewardedAdProvider);
    final streak =
        ref.watch(overallProgressProvider).valueOrNull?.currentStreakDays ?? 0;

    final isFull =
        shieldState.shieldCount >= StreakShieldReminderState.kMaxShields;
    final canAfford =
        adState.prestigePoints >= StreakShieldReminderState.kShieldGemCost;

    return Container(
      key: const Key('modal_streak_shield_reminder'),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Color(0xFF0EA5E9),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn
                              ? 'Streak Shield & Study Reminder'
                              : 'Khiên Giữ Chuỗi & Giờ Nhắc Học',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          isEn
                              ? 'Current Streak: $streak days • Shields: ${shieldState.shieldCount}/${StreakShieldReminderState.kMaxShields}'
                              : 'Chuỗi hiện tại: $streak ngày • Khiên đang có: ${shieldState.shieldCount}/${StreakShieldReminderState.kMaxShields}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 1. Khiên Bảo Vệ Chuỗi (Streak Freeze — 150 Gem)
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(isDark ? 0.12 : 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF0EA5E9).withOpacity(0.35),
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
                                ? '🛡️ Streak Freeze Shield'
                                : '🛡️ Khiên Bảo Vệ Chuỗi (Tối đa 3)',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            StreakShieldReminderState.kMaxShields,
                            (idx) => Padding(
                              padding: const EdgeInsets.only(left: 3),
                              child: Icon(
                                Icons.shield_rounded,
                                size: 18,
                                color: idx < shieldState.shieldCount
                                    ? const Color(0xFF0EA5E9)
                                    : Colors.grey.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEn
                          ? 'Automatically protects your daily streak if you miss 1 busy day.'
                          : 'Tự động bảo toàn chuỗi ngày học của bạn nếu lỡ bận nghỉ 1 ngày.',
                      style: TextStyle(
                        fontSize: 11.8,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      key: const Key('btn_buy_streak_shield'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 42),
                        backgroundColor: isFull
                            ? Colors.grey
                            : (canAfford
                                ? const Color(0xFF0284C7)
                                : AppColors.accentAmber),
                      ),
                      onPressed: isFull
                          ? null
                          : () async {
                              if (!canAfford) {
                                Navigator.of(context).pop();
                                context.push('/support-developer');
                                return;
                              }
                              final ok = await notifier.purchaseStreakShield();
                              if (ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.correct,
                                    behavior: SnackBarBehavior.floating,
                                    content: Text(
                                      isEn
                                          ? 'Equipped +1 Streak Shield! (${shieldState.shieldCount + 1}/3)'
                                          : 'Đã trang bị +1 Khiên Bảo Vệ Chuỗi! (${shieldState.shieldCount + 1}/3)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const SolfaGemIcon(size: 15),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isFull
                              ? (isEn
                                  ? 'Max Shields Equipped (3/3)'
                                  : 'Đã trang bị tối đa 3/3 Khiên')
                              : (canAfford
                                  ? (isEn
                                      ? 'Equip +1 Shield (${StreakShieldReminderState.kShieldGemCost} Gems)'
                                      : 'Đổi ${StreakShieldReminderState.kShieldGemCost} Gem → +1 Khiên Bảo Vệ')
                                  : (isEn
                                      ? 'Need ${StreakShieldReminderState.kShieldGemCost} Gems • Get Free Gems'
                                      : 'Cần ${StreakShieldReminderState.kShieldGemCost} Gem • Tới Trạm Nhận Gem')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Hẹn giờ nhắc luyện tập hằng ngày
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isEn
                                ? 'Daily Practice Reminder'
                                : 'Nhắc Giờ Luyện Tập Hằng Ngày',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          key: const Key('switch_study_reminder'),
                          value: shieldState.reminderEnabled,
                          activeColor: AppColors.primary,
                          onChanged: (v) => notifier.setReminderEnabled(v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in _presetTimes)
                          ChoiceChip(
                            key: Key('chip_reminder_time_$t'),
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              t,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: shieldState.reminderTime == t &&
                                        shieldState.reminderEnabled
                                    ? Colors.white
                                    : null,
                              ),
                            ),
                            selected: shieldState.reminderTime == t &&
                                shieldState.reminderEnabled,
                            onSelected: (_) => notifier.setReminderTime(t),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
