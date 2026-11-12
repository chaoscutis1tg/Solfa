import 'package:flutter/material.dart';

/// Zero-jank container wrapper (replaces heavy multi-layer Opacity animations
/// so scrolling and tab transitions run at a locked 60 FPS on mobile devices).
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Offset beginOffset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 200),
    this.beginOffset = Offset.zero,
  });

  @override
  Widget build(BuildContext context) => child;
}

/// Lightweight tap wrapper that never blocks native button ripples or scrolling.
class ScaleTap extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final BorderRadius? borderRadius;

  const ScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 1.0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}

/// Fixed-layout soundwave bar indicator inside a RepaintBoundary
/// (zero layout shifts when audio starts or stops).
class AnimatedSoundWave extends StatelessWidget {
  final bool isPlaying;
  final Color color;
  final int barCount;
  final double maxHeight;

  const AnimatedSoundWave({
    super.key,
    required this.isPlaying,
    required this.color,
    this.barCount = 9,
    this.maxHeight = 24,
  });

  static const List<double> _idleFactors = [
    0.32,
    0.48,
    0.38,
    0.60,
    0.45,
    0.60,
    0.38,
    0.48,
    0.32,
  ];

  static const List<double> _activeFactors = [
    0.55,
    0.88,
    0.68,
    1.00,
    0.80,
    0.95,
    0.72,
    0.85,
    0.52,
  ];

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: maxHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(barCount, (index) {
            final factor = isPlaying
                ? _activeFactors[index % _activeFactors.length]
                : _idleFactors[index % _idleFactors.length];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 4.0,
              height: (maxHeight * factor).clamp(6.0, maxHeight),
              decoration: BoxDecoration(
                color: isPlaying ? color : color.withOpacity(0.40),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ),
    );
  }
}
