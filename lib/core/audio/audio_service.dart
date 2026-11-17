import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static const int kPolyphonyPoolSize = 4;

  AudioPlayer? _lessonPlayer;
  AudioPlayer? _sfxPlayer;
  final List<AudioPlayer> _polyPool = [];
  int _polyCursor = 0;
  final bool isTestMode;
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  double _lessonVolume = 0.9;
  bool _sfxEnabled = true;
  bool _isDisposed = false;
  int _playSerial = 0;

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
    if (isTestMode || _isDisposed) return;
    if (_lessonPlayer == null) {
      _lessonPlayer = AudioPlayer();
      _lessonPlayer!.onPlayerStateChanged.listen((state) {
        if (!_isDisposed) {
          isPlayingNotifier.value = (state == PlayerState.playing);
        }
      });
      _lessonPlayer!.onPlayerComplete.listen((_) {
        if (!_isDisposed) {
          isPlayingNotifier.value = false;
        }
      });
    }
    _sfxPlayer ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
    if (_polyPool.isEmpty) {
      for (int i = 0; i < kPolyphonyPoolSize; i++) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        _polyPool.add(p);
      }
    }
  }

  /// Plays the specified lesson audio asset, stopping any currently playing lesson sound first.
  /// Used in Quiz & Battle rooms so each new question is heard clearly without overlap.
  Future<bool> playAsset(String assetPath) async {
    if (_isDisposed || assetPath.trim().isEmpty) return false;
    final currentOp = ++_playSerial;
    if (isTestMode) {
      isPlayingNotifier.value = true;
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!_isDisposed && currentOp == _playSerial) {
          isPlayingNotifier.value = false;
        }
      });
      return true;
    }
    try {
      await _ensurePlayers();
      if (_isDisposed || currentOp != _playSerial) return false;
      await _lessonPlayer!.stop();
      if (_isDisposed || currentOp != _playSerial) return false;
      await _lessonPlayer!.setVolume(_lessonVolume);
      final normalized = _normalizeAssetSourcePath(assetPath);
      isPlayingNotifier.value = true;
      await _lessonPlayer!.play(AssetSource(normalized));
      return true;
    } catch (_) {
      if (!_isDisposed && currentOp == _playSerial) {
        isPlayingNotifier.value = false;
      }
      return false;
    }
  }

  /// Plays a note using the 4-voice polyphonic pool so rapid Piano keys or Guitar arpeggios/strums
  /// sustain and blend naturally without cutting off previous notes.
  Future<bool> playPolyphonicAsset(String assetPath) async {
    if (_isDisposed || assetPath.trim().isEmpty) return false;
    if (isTestMode) {
      return playAsset(assetPath);
    }
    try {
      await _ensurePlayers();
      if (_isDisposed || _polyPool.isEmpty) return false;
      final voice = _polyPool[_polyCursor % _polyPool.length];
      _polyCursor = (_polyCursor + 1) % _polyPool.length;
      await voice.stop();
      await voice.setVolume(_lessonVolume);
      final normalized = _normalizeAssetSourcePath(assetPath);
      await voice.play(AssetSource(normalized));
      return true;
    } catch (_) {
      return playAsset(assetPath);
    }
  }

  /// Plays the reference pitch C4 (Đô chuẩn 261.6Hz) for Basic & Intermediate levels.
  Future<bool> playReferenceC4() async {
    return playAsset('assets/audio/notes/c4.wav');
  }

  /// Plays a specific piano note by key code (e.g. 'C4', 'F#4', 'G3_SOL', 'C6') with 4-voice polyphony.
  Future<bool> playPianoKey(String keyCode) async {
    final normalizedKey = keyCode
        .toLowerCase()
        .replaceAll('_sol', '')
        .replaceAll('_fa', '')
        .replaceAll('_treble', '')
        .replaceAll('_bass', '')
        .replaceAll('#', 'sharp');
    return playPolyphonicAsset('assets/audio/notes/$normalizedKey.wav');
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
    _playSerial++;
    if (!_isDisposed) {
      isPlayingNotifier.value = false;
    }
    if (isTestMode || _isDisposed) return;
    try {
      await _lessonPlayer?.stop();
      for (final p in _polyPool) {
        await p.stop();
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _playSerial++;
    isPlayingNotifier.value = false;
    if (isTestMode) return;
    try {
      await _lessonPlayer?.dispose();
      await _sfxPlayer?.dispose();
      for (final p in _polyPool) {
        await p.dispose();
      }
    } catch (_) {}
  }
}
