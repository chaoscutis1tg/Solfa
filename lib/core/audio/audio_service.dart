import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  AudioPlayer? _lessonPlayer;
  AudioPlayer? _sfxPlayer;
  final bool isTestMode;
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  double _lessonVolume = 0.9;
  bool _sfxEnabled = true;

  AudioService({this.isTestMode = false});

  void updateConfig({double? lessonVolume, bool? sfxEnabled}) {
    if (lessonVolume != null) {
      _lessonVolume = lessonVolume.clamp(0.0, 1.0);
    }
    if (sfxEnabled != null) {
      _sfxEnabled = sfxEnabled;
    }
  }

  String _normalizeAssetSourcePath(String assetPath) {
    if (assetPath.startsWith('assets/')) {
      return assetPath.substring('assets/'.length);
    }
    return assetPath;
  }

  Future<void> _ensurePlayers() async {
    if (isTestMode) return;
    if (_lessonPlayer == null) {
      _lessonPlayer = AudioPlayer();
      _lessonPlayer!.onPlayerStateChanged.listen((state) {
        isPlayingNotifier.value = (state == PlayerState.playing);
      });
      _lessonPlayer!.onPlayerComplete.listen((_) {
        isPlayingNotifier.value = false;
      });
    }
    _sfxPlayer ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  }

  /// Plays the specified lesson audio asset, stopping any currently playing lesson sound first.
  Future<bool> playAsset(String assetPath) async {
    if (assetPath.trim().isEmpty) return false;
    if (isTestMode) {
      isPlayingNotifier.value = true;
      Future.delayed(const Duration(milliseconds: 50), () {
        isPlayingNotifier.value = false;
      });
      return true;
    }
    try {
      await _ensurePlayers();
      await _lessonPlayer!.stop();
      await _lessonPlayer!.setVolume(_lessonVolume);
      final normalized = _normalizeAssetSourcePath(assetPath);
      isPlayingNotifier.value = true;
      await _lessonPlayer!.play(AssetSource(normalized));
      return true;
    } catch (_) {
      isPlayingNotifier.value = false;
      return false;
    }
  }

  /// Plays the reference pitch C4 (Đô chuẩn 261.6Hz) for Basic & Intermediate levels.
  Future<bool> playReferenceC4() async {
    return playAsset('assets/audio/notes/c4.wav');
  }

  /// Plays a specific piano note by key code (e.g. 'C4', 'F#4') for interactive keyboard preview.
  Future<bool> playPianoKey(String keyCode) async {
    final normalizedKey =
        keyCode.toLowerCase().replaceAll('#', 'sharp');
    return playAsset('assets/audio/notes/$normalizedKey.wav');
  }

  /// Plays the upgraded sparkling celesta chime (Correct) or soft wooden marimba (Wrong) SFX.
  Future<void> playFeedbackSfx({required bool isCorrect}) async {
    if (!_sfxEnabled || isTestMode) return;
    try {
      await _ensurePlayers();
      await _sfxPlayer!.stop();
      await _sfxPlayer!.setVolume((_lessonVolume * 0.90).clamp(0.2, 1.0));
      final path = isCorrect ? 'audio/sfx/correct.wav' : 'audio/sfx/wrong.wav';
      await _sfxPlayer!.play(AssetSource(path));
    } catch (_) {}
  }

  /// Plays celebratory Major 9th fanfare chime when finishing a session.
  Future<void> playSessionCompleteFanfare() async {
    if (!_sfxEnabled || isTestMode) return;
    try {
      await _ensurePlayers();
      await _sfxPlayer!.stop();
      await _sfxPlayer!.setVolume((_lessonVolume * 0.90).clamp(0.2, 1.0));
      await _sfxPlayer!.play(AssetSource('audio/sfx/complete.wav'));
    } catch (_) {}
  }

  Future<void> stop() async {
    isPlayingNotifier.value = false;
    if (isTestMode) return;
    try {
      await _lessonPlayer?.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    isPlayingNotifier.value = false;
    if (isTestMode) return;
    try {
      await _lessonPlayer?.dispose();
      await _sfxPlayer?.dispose();
    } catch (_) {}
  }
}
