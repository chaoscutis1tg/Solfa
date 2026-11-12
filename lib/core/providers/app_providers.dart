import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/asset_validator.dart';
import '../audio/audio_service.dart';
import '../database/app_database.dart';
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
  final bool isLoaded;

  const AppSettingsState({
    this.themeMode = ThemeMode.light,
    this.autoPlayQuestionAudio = false,
    this.lessonVolume = 0.9,
    this.feedbackSoundEnabled = true,
    this.hapticFeedbackEnabled = true,
    this.defaultMetronomeSound = 'click',
    this.keepScreenAwakeOnMetronome = true,
    this.unlockAllLevels = false,
    this.isLoaded = false,
  });

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    bool? autoPlayQuestionAudio,
    double? lessonVolume,
    bool? feedbackSoundEnabled,
    bool? hapticFeedbackEnabled,
    String? defaultMetronomeSound,
    bool? keepScreenAwakeOnMetronome,
    bool? unlockAllLevels,
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
    final metroSound = map['default_metronome_sound'] ?? 'click';
    final keepAwake = (map['keep_screen_awake'] ?? 'true') == 'true';
    final unlockAll = (map['unlock_all_levels'] ?? 'false') == 'true';

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
    await _db.setSetting('theme_mode', str);
  }

  Future<void> setAutoPlayAudio(bool value) async {
    state = state.copyWith(autoPlayQuestionAudio: value);
    await _db.setSetting('auto_play_audio', value.toString());
  }

  Future<void> setLessonVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    state = state.copyWith(lessonVolume: clamped);
    _audioService.updateConfig(lessonVolume: clamped);
    await _db.setSetting('lesson_volume', clamped.toStringAsFixed(2));
  }

  Future<void> setFeedbackSound(bool value) async {
    state = state.copyWith(feedbackSoundEnabled: value);
    _audioService.updateConfig(sfxEnabled: value);
    await _db.setSetting('feedback_sound', value.toString());
  }

  Future<void> setHapticFeedback(bool value) async {
    state = state.copyWith(hapticFeedbackEnabled: value);
    await _db.setSetting('haptic_feedback', value.toString());
  }

  Future<void> setDefaultMetronomeSound(String sound) async {
    state = state.copyWith(defaultMetronomeSound: sound);
    await _db.setSetting('default_metronome_sound', sound);
  }

  Future<void> setKeepScreenAwake(bool value) async {
    state = state.copyWith(keepScreenAwakeOnMetronome: value);
    await _db.setSetting('keep_screen_awake', value.toString());
  }

  Future<void> setUnlockAllLevels(bool value) async {
    state = state.copyWith(unlockAllLevels: value);
    await _db.setSetting('unlock_all_levels', value.toString());
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

