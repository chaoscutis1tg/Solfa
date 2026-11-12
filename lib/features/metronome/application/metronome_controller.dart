import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/providers/app_providers.dart';

enum MetronomeStatus {
  stopped,
  countIn,
  playing,
  paused,
  error,
}

/// Pure, testable Tap Tempo calculator implementing BR-11 & Section 12.3.
class TapTempoCalculator {
  static const int minValidIntervalMs = 190; // ~315 BPM max raw tap
  static const int maxValidIntervalMs = 2100; // ~28 BPM min raw tap
  static const int resetTimeoutMs = 2500;
  static const int maxSamples = 6;

  final List<int> _tapTimestampsMs = [];

  List<int> get tapTimestampsMs => List.unmodifiable(_tapTimestampsMs);

  /// Records a tap at [timestampMs] and returns the calculated BPM (clamped 30..300),
  /// or null if at least 2 valid taps haven't been collected yet.
  int? registerTap(int timestampMs) {
    if (_tapTimestampsMs.isNotEmpty) {
      final delta = timestampMs - _tapTimestampsMs.last;
      if (delta > resetTimeoutMs) {
        // Sequence expired -> start fresh measurement (Section 12.3)
        _tapTimestampsMs.clear();
      } else if (delta < minValidIntervalMs || delta > maxValidIntervalMs) {
        // Ignore outlier tap interval (BR-11)
        _tapTimestampsMs[_tapTimestampsMs.length - 1] = timestampMs;
        return null;
      }
    }

    _tapTimestampsMs.add(timestampMs);
    if (_tapTimestampsMs.length > maxSamples) {
      _tapTimestampsMs.removeAt(0);
    }

    if (_tapTimestampsMs.length < 2) return null;

    final List<int> intervals = [];
    for (int i = 1; i < _tapTimestampsMs.length; i++) {
      final d = _tapTimestampsMs[i] - _tapTimestampsMs[i - 1];
      if (d >= minValidIntervalMs && d <= maxValidIntervalMs) {
        intervals.add(d);
      }
    }
    if (intervals.isEmpty) return null;

    // Sort intervals and use median/trimmed average to reject jitter outliers
    intervals.sort();
    double avgMs;
    if (intervals.length >= 4) {
      final trimmed = intervals.sublist(1, intervals.length - 1);
      avgMs = trimmed.reduce((a, b) => a + b) / trimmed.length;
    } else {
      avgMs = intervals.reduce((a, b) => a + b) / intervals.length;
    }

    final rawBpm = (60000.0 / avgMs).round();
    return clampBpm(rawBpm);
  }

  void reset() => _tapTimestampsMs.clear();

  /// BR-10: Clamp BPM strictly within [30, 300].
  static int clampBpm(int bpm) => bpm.clamp(30, 300);

  /// Section 6.14.2: Ideal interval in milliseconds between beats = 60,000 / BPM.
  static double intervalMsForBpm(int bpm) {
    final safeBpm = clampBpm(bpm);
    return 60000.0 / safeBpm;
  }
}

class MetronomeState {
  final int bpm;
  final int numerator;
  final int denominator;
  final String soundType; // 'click', 'woodblock', 'bell'
  final bool accentFirstBeat;
  final int countInBars; // 0, 1, or 2
  final double volume;
  final MetronomeStatus status;
  final int currentBeat; // 1..numerator (or 0 when stopped)
  final int remainingCountInBeats;
  final String? errorMessage;

  const MetronomeState({
    this.bpm = 100,
    this.numerator = 4,
    this.denominator = 4,
    this.soundType = 'click',
    this.accentFirstBeat = true,
    this.countInBars = 0,
    this.volume = 0.9,
    this.status = MetronomeStatus.stopped,
    this.currentBeat = 0,
    this.remainingCountInBeats = 0,
    this.errorMessage,
  });

  bool get isRunning =>
      status == MetronomeStatus.playing || status == MetronomeStatus.countIn;

  String get timeSignature => '$numerator/$denominator';

  double get intervalMs => TapTempoCalculator.intervalMsForBpm(bpm);

  MetronomeState copyWith({
    int? bpm,
    int? numerator,
    int? denominator,
    String? soundType,
    bool? accentFirstBeat,
    int? countInBars,
    double? volume,
    MetronomeStatus? status,
    int? currentBeat,
    int? remainingCountInBeats,
    String? errorMessage,
  }) {
    return MetronomeState(
      bpm: bpm != null ? TapTempoCalculator.clampBpm(bpm) : this.bpm,
      numerator: numerator ?? this.numerator,
      denominator: denominator ?? this.denominator,
      soundType: soundType ?? this.soundType,
      accentFirstBeat: accentFirstBeat ?? this.accentFirstBeat,
      countInBars: countInBars ?? this.countInBars,
      volume: volume ?? this.volume,
      status: status ?? this.status,
      currentBeat: currentBeat ?? this.currentBeat,
      remainingCountInBeats:
          remainingCountInBeats ?? this.remainingCountInBeats,
      errorMessage: errorMessage,
    );
  }
}

class MetronomeNotifier extends StateNotifier<MetronomeState> {
  final Ref _ref;
  final bool isTestMode;
  final TapTempoCalculator _tapCalculator = TapTempoCalculator();

  Timer? _schedulerTimer;
  final Stopwatch _stopwatch = Stopwatch();
  int _nextBeatTargetMicros = 0;

  AudioPlayer? _accentPlayer;
  AudioPlayer? _normalPlayer;

  MetronomeNotifier(this._ref, {this.isTestMode = false})
      : super(const MetronomeState()) {
    final defaultSound = _ref.read(appSettingsProvider).defaultMetronomeSound;
    state = state.copyWith(soundType: defaultSound);
  }

  Future<void> _initAudioPlayers() async {
    if (isTestMode) return;
    try {
      if (_accentPlayer == null) {
        _accentPlayer = AudioPlayer();
        await _accentPlayer!.setPlayerMode(PlayerMode.lowLatency);
        await _accentPlayer!.setReleaseMode(ReleaseMode.stop);
      }
      if (_normalPlayer == null) {
        _normalPlayer = AudioPlayer();
        await _normalPlayer!.setPlayerMode(PlayerMode.lowLatency);
        await _normalPlayer!.setReleaseMode(ReleaseMode.stop);
      }
    } catch (_) {}
  }

  void setBpm(int newBpm) {
    final clamped = TapTempoCalculator.clampBpm(newBpm);
    if (clamped == state.bpm) return;
    state = state.copyWith(bpm: clamped);
    if (state.isRunning) {
      _rescheduleRunningLoop();
    }
  }

  void incrementBpm(int delta) {
    setBpm(state.bpm + delta);
  }

  void setTimeSignature(int numerator, int denominator) {
    state = state.copyWith(
      numerator: numerator,
      denominator: denominator,
      currentBeat: state.isRunning ? 1 : 0,
    );
  }

  void setSoundType(String soundType) {
    state = state.copyWith(soundType: soundType);
  }

  void setAccentFirstBeat(bool value) {
    state = state.copyWith(accentFirstBeat: value);
  }

  void setCountInBars(int bars) {
    state = state.copyWith(countInBars: bars.clamp(0, 2));
  }

  void setVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: v);
    if (!isTestMode) {
      _accentPlayer?.setVolume(v);
      _normalPlayer?.setVolume(v);
    }
  }

  /// Registers a user tap for Tap Tempo (UC-14, BR-11, TC-10).
  int? registerTap({int? customTimestampMs}) {
    final nowMs = customTimestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final computedBpm = _tapCalculator.registerTap(nowMs);
    if (computedBpm != null) {
      setBpm(computedBpm);
    }
    return computedBpm;
  }

  Future<void> togglePlayPause() async {
    if (state.isRunning) {
      await pause();
    } else {
      await start();
    }
  }

  Future<void> start() async {
    await _initAudioPlayers();
    _schedulerTimer?.cancel();

    final keepAwake =
        _ref.read(appSettingsProvider).keepScreenAwakeOnMetronome;
    if (keepAwake && !isTestMode) {
      try {
        unawaited(WakelockPlus.enable());
      } catch (_) {}
    }

    final totalCountIn = state.countInBars * state.numerator;
    final initialStatus = totalCountIn > 0
        ? MetronomeStatus.countIn
        : MetronomeStatus.playing;

    state = state.copyWith(
      status: initialStatus,
      currentBeat: 1,
      remainingCountInBeats: totalCountIn > 0 ? totalCountIn - 1 : 0,
      errorMessage: null,
    );

    unawaited(_playBeatClick(isFirstBeat: true));

    _stopwatch
      ..reset()
      ..start();
    final intervalMicros = (60000000.0 / state.bpm).round();
    _nextBeatTargetMicros = intervalMicros;
    _scheduleNextTick();
  }

  void _rescheduleRunningLoop() {
    _schedulerTimer?.cancel();
    _stopwatch
      ..reset()
      ..start();
    final intervalMicros = (60000000.0 / state.bpm).round();
    _nextBeatTargetMicros = intervalMicros;
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    if (!state.isRunning) return;
    final nowMicros = _stopwatch.elapsedMicroseconds;
    final delayMicros =
        (_nextBeatTargetMicros - nowMicros).clamp(1000, 10000000);

    _schedulerTimer = Timer(Duration(microseconds: delayMicros), () {
      if (!state.isRunning) return;
      _onBeatTick();
      final intervalMicros = (60000000.0 / state.bpm).round();
      _nextBeatTargetMicros += intervalMicros;
      _scheduleNextTick();
    });
  }

  void _onBeatTick() {
    if (state.status == MetronomeStatus.countIn) {
      final nextBeat = (state.currentBeat % state.numerator) + 1;
      if (state.remainingCountInBeats <= 0) {
        // Transition from Count-in to Playing on beat 1
        state = state.copyWith(
          status: MetronomeStatus.playing,
          currentBeat: 1,
          remainingCountInBeats: 0,
        );
        unawaited(_playBeatClick(isFirstBeat: true));
      } else {
        state = state.copyWith(
          currentBeat: nextBeat,
          remainingCountInBeats: state.remainingCountInBeats - 1,
        );
        unawaited(_playBeatClick(isFirstBeat: nextBeat == 1));
      }
      return;
    }

    final nextBeat = (state.currentBeat % state.numerator) + 1;
    state = state.copyWith(currentBeat: nextBeat);
    unawaited(_playBeatClick(isFirstBeat: nextBeat == 1));
  }

  Future<void> _playBeatClick({required bool isFirstBeat}) async {
    if (isTestMode || state.volume <= 0.01) return;
    try {
      final useAccent = isFirstBeat && state.accentFirstBeat;
      final suffix = useAccent ? 'accent' : 'normal';
      final assetPath = 'audio/metronome/${state.soundType}_$suffix.wav';
      final player = useAccent ? _accentPlayer : _normalPlayer;
      if (player != null) {
        await player.stop();
        await player.play(AssetSource(assetPath), volume: state.volume);
      }
    } catch (_) {}
  }

  Future<void> pause() async {
    _schedulerTimer?.cancel();
    _stopwatch.stop();
    if (!isTestMode) {
      try {
        unawaited(WakelockPlus.disable());
      } catch (_) {}
    }
    state = state.copyWith(status: MetronomeStatus.paused);
  }

  Future<void> stop() async {
    _schedulerTimer?.cancel();
    _stopwatch.stop();
    if (!isTestMode) {
      try {
        unawaited(WakelockPlus.disable());
      } catch (_) {}
    }
    state = state.copyWith(
      status: MetronomeStatus.stopped,
      currentBeat: 0,
      remainingCountInBeats: 0,
    );
  }

  @override
  void dispose() {
    _schedulerTimer?.cancel();
    _stopwatch.stop();
    if (!isTestMode) {
      try {
        WakelockPlus.disable();
        _accentPlayer?.dispose();
        _normalPlayer?.dispose();
      } catch (_) {}
    }
    super.dispose();
  }
}

final metronomeProvider =
    StateNotifierProvider<MetronomeNotifier, MetronomeState>((ref) {
  return MetronomeNotifier(ref);
});
