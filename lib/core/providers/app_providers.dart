import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/asset_validator.dart';
import '../audio/audio_service.dart';
import '../database/app_database.dart';
import '../localization/app_locale.dart';
import '../models/domain_models.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final assetValidatorProvider = Provider<AssetValidator>((ref) {
  return AssetValidator();
});

final audioServiceProvider = Provider<AudioService>((ref) {
  final svc = AudioService();
  ref.onDispose(() => svc.dispose());
  return svc;
});

class AppSettingsState {
  final ThemeMode themeMode;
  final bool autoPlayQuestionAudio;
  final double lessonVolume;
  final bool feedbackSoundEnabled;
  final bool hapticFeedbackEnabled;
  final String defaultMetronomeSound;
  final bool keepScreenAwakeOnMetronome;
  final bool unlockAllLevels;
  final int dailyGoalTarget;
  final String languageMode; // 'auto' | 'vi' | 'en'
  final String countryCodeOverride; // '' (auto) | 'VN' | 'US' | 'DE' | ...
  final bool isLoaded;

  const AppSettingsState({
    this.themeMode = ThemeMode.light,
    this.autoPlayQuestionAudio = false,
    this.lessonVolume = 0.9,
    this.feedbackSoundEnabled = true,
    this.hapticFeedbackEnabled = true,
    this.defaultMetronomeSound = 'tempo',
    this.keepScreenAwakeOnMetronome = true,
    this.unlockAllLevels = true,
    this.dailyGoalTarget = 20,
    this.languageMode = 'auto',
    this.countryCodeOverride = '',
    this.isLoaded = false,
  });

  DetectedCountryInfo get detectedCountry => AppLocale.detectCountry(
        overrideCountryCode:
            countryCodeOverride.isEmpty ? null : countryCodeOverride,
      );

  String get effectiveLanguageCode => AppLocale.resolveLanguageCode(
        languageMode: languageMode,
        countryCodeOverride:
            countryCodeOverride.isEmpty ? null : countryCodeOverride,
      );

  bool get isEnglish => effectiveLanguageCode == 'en';

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    bool? autoPlayQuestionAudio,
    double? lessonVolume,
    bool? feedbackSoundEnabled,
    bool? hapticFeedbackEnabled,
    String? defaultMetronomeSound,
    bool? keepScreenAwakeOnMetronome,
    bool? unlockAllLevels,
    int? dailyGoalTarget,
    String? languageMode,
    String? countryCodeOverride,
    bool? isLoaded,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      autoPlayQuestionAudio: autoPlayQuestionAudio ?? this.autoPlayQuestionAudio,
      lessonVolume: lessonVolume ?? this.lessonVolume,
      feedbackSoundEnabled: feedbackSoundEnabled ?? this.feedbackSoundEnabled,
      hapticFeedbackEnabled: hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      defaultMetronomeSound: defaultMetronomeSound ?? this.defaultMetronomeSound,
      keepScreenAwakeOnMetronome:
          keepScreenAwakeOnMetronome ?? this.keepScreenAwakeOnMetronome,
      unlockAllLevels: unlockAllLevels ?? this.unlockAllLevels,
      dailyGoalTarget: dailyGoalTarget ?? this.dailyGoalTarget,
      languageMode: languageMode ?? this.languageMode,
      countryCodeOverride: countryCodeOverride ?? this.countryCodeOverride,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  final AppDatabase _db;
  final AudioService _audioService;

  AppSettingsNotifier(this._db, this._audioService)
      : super(const AppSettingsState());

  Future<void> loadSettings() async {
    final map = await _db.getAllSettings();
    final themeStr = map['theme_mode'] ?? 'light';
    final ThemeMode mode;
    if (themeStr == 'dark') {
      mode = ThemeMode.dark;
    } else if (themeStr == 'system') {
      mode = ThemeMode.system;
    } else {
      mode = ThemeMode.light;
    }

    final autoPlay = map['auto_play_audio'] == 'true';
    final volume = double.tryParse(map['lesson_volume'] ?? '') ?? 0.9;
    final sfx = (map['feedback_sound'] ?? 'true') == 'true';
    final haptic = (map['haptic_feedback'] ?? 'true') == 'true';
    final metroSound = map['default_metronome_sound'] ?? 'tempo';
    final keepAwake = (map['keep_screen_awake'] ?? 'true') == 'true';
    final unlockAll = (map['unlock_all_levels'] ?? 'true') == 'true';
    final dailyGoal =
        (int.tryParse(map['daily_goal_target'] ?? '') ?? 20).clamp(5, 200);
    final rawLang = map['language_mode'] ?? 'auto';
    final langMode =
        (rawLang == 'vi' || rawLang == 'en') ? rawLang : 'auto';
    final countryOverride = map['country_code_override'] ?? '';

    _audioService.updateConfig(lessonVolume: volume, sfxEnabled: sfx);

    state = AppSettingsState(
      themeMode: mode,
      autoPlayQuestionAudio: autoPlay,
      lessonVolume: volume,
      feedbackSoundEnabled: sfx,
      hapticFeedbackEnabled: haptic,
      defaultMetronomeSound: metroSound,
      keepScreenAwakeOnMetronome: keepAwake,
      unlockAllLevels: unlockAll,
      dailyGoalTarget: dailyGoal,
      languageMode: langMode,
      countryCodeOverride: countryOverride,
      isLoaded: true,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final str = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.system
            ? 'system'
            : 'light';
    try {
      await _db.setSetting('theme_mode', str);
    } catch (_) {}
  }

  Future<void> setAutoPlayAudio(bool value) async {
    state = state.copyWith(autoPlayQuestionAudio: value);
    try {
      await _db.setSetting('auto_play_audio', value.toString());
    } catch (_) {}
  }

  Future<void> setLessonVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    state = state.copyWith(lessonVolume: clamped);
    _audioService.updateConfig(lessonVolume: clamped);
    try {
      await _db.setSetting('lesson_volume', clamped.toStringAsFixed(2));
    } catch (_) {}
  }

  Future<void> setFeedbackSound(bool value) async {
    state = state.copyWith(feedbackSoundEnabled: value);
    _audioService.updateConfig(sfxEnabled: value);
    try {
      await _db.setSetting('feedback_sound', value.toString());
    } catch (_) {}
  }

  Future<void> setHapticFeedback(bool value) async {
    state = state.copyWith(hapticFeedbackEnabled: value);
    try {
      await _db.setSetting('haptic_feedback', value.toString());
    } catch (_) {}
  }

  Future<void> setDefaultMetronomeSound(String sound) async {
    state = state.copyWith(defaultMetronomeSound: sound);
    try {
      await _db.setSetting('default_metronome_sound', sound);
    } catch (_) {}
  }

  Future<void> setKeepScreenAwake(bool value) async {
    state = state.copyWith(keepScreenAwakeOnMetronome: value);
    try {
      await _db.setSetting('keep_screen_awake', value.toString());
    } catch (_) {}
  }

  Future<void> setUnlockAllLevels(bool value) async {
    state = state.copyWith(unlockAllLevels: value);
    try {
      await _db.setSetting('unlock_all_levels', value.toString());
    } catch (_) {}
  }

  Future<void> setDailyGoalTarget(int value) async {
    final clamped = value.clamp(5, 200);
    state = state.copyWith(dailyGoalTarget: clamped);
    try {
      await _db.setSetting('daily_goal_target', clamped.toString());
    } catch (_) {}
  }

  Future<void> setLanguageMode(String mode) async {
    final normalized = (mode == 'vi' || mode == 'en') ? mode : 'auto';
    state = state.copyWith(languageMode: normalized);
    try {
      await _db.setSetting('language_mode', normalized);
    } catch (_) {}
  }

  Future<void> setCountryCodeOverride(String code) async {
    final normalized = code.trim().toUpperCase();
    state = state.copyWith(countryCodeOverride: normalized);
    try {
      await _db.setSetting('country_code_override', normalized);
    } catch (_) {}
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audio = ref.watch(audioServiceProvider);
  return AppSettingsNotifier(db, audio);
});

final topicsListProvider = FutureProvider<List<TopicModel>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return db.getTopics(onlyEnabled: false);
});

final overallProgressProvider = FutureProvider<OverallProgressStats>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return db.getOverallProgressStats();
});

final pendingReviewItemsProvider =
    FutureProvider.family<List<ReviewItemModel>, String?>((ref, topicId) async {
  final db = ref.watch(appDatabaseProvider);
  return db.getPendingReviewItems(topicId: topicId);
});

