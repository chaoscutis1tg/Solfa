import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vector Diamond Gem Icon representing Solfa's virtual Gem currency.
class SolfaGemIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const SolfaGemIcon({
    super.key,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DiamondGemPainter(baseColor: color),
      ),
    );
  }
}

class _DiamondGemPainter extends CustomPainter {
  final Color? baseColor;

  const _DiamondGemPainter({this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final topLeft = Offset(w * 0.24, h * 0.14);
    final topRight = Offset(w * 0.76, h * 0.14);
    final midLeft = Offset(w * 0.06, h * 0.38);
    final midRight = Offset(w * 0.94, h * 0.38);
    final midInnerLeft = Offset(w * 0.34, h * 0.38);
    final midInnerRight = Offset(w * 0.66, h * 0.38);
    final bottomTip = Offset(w * 0.50, h * 0.90);

    final outerPath = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(midRight.dx, midRight.dy)
      ..lineTo(bottomTip.dx, bottomTip.dy)
      ..lineTo(midLeft.dx, midLeft.dy)
      ..close();

    final fillShader = const LinearGradient(
      colors: [
        Color(0xFF38BDF8), // Bright Sky Cyan
        Color(0xFF2563EB), // Royal Blue
        Color(0xFF6366F1), // Indigo facet
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final mainPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = baseColor == null ? fillShader : null
      ..color = baseColor ?? const Color(0xFF38BDF8);

    canvas.drawPath(outerPath, mainPaint);

    // Top crown highlight facet
    final crownPath = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(midInnerRight.dx, midInnerRight.dy)
      ..lineTo(midInnerLeft.dx, midInnerLeft.dy)
      ..close();
    canvas.drawPath(
      crownPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(0.38),
    );

    // Center lower facet
    final centerFacet = Path()
      ..moveTo(midInnerLeft.dx, midInnerLeft.dy)
      ..lineTo(midInnerRight.dx, midInnerRight.dy)
      ..lineTo(bottomTip.dx, bottomTip.dy)
      ..close();
    canvas.drawPath(
      centerFacet,
      Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(0.18),
    );

    // Crisp facet lines & border
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.06).clamp(0.8, 1.5)
      ..color = Colors.white.withOpacity(0.75);

    canvas.drawPath(outerPath, linePaint);
    canvas.drawLine(midLeft, midRight, linePaint);
    canvas.drawLine(topLeft, midInnerLeft, linePaint);
    canvas.drawLine(topRight, midInnerRight, linePaint);
    canvas.drawLine(midInnerLeft, bottomTip, linePaint);
    canvas.drawLine(midInnerRight, bottomTip, linePaint);
  }

  @override
  bool shouldRepaint(covariant _DiamondGemPainter oldDelegate) =>
      oldDelegate.baseColor != baseColor;
}

/// Displays a smooth, non-blocking floating Gem reward celebration overlay animation.
/// Automatically skips creating timers when [isTestMode] is true so automated widget tests remain fast and deterministic.
void showGemRewardAnimation(
  BuildContext context, {
  required int gemsAdded,
  String? subtitle,
  bool isTestMode = false,
}) {
  if (isTestMode || !context.mounted) return;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _GemRewardCelebrationWidget(
      gemsAdded: gemsAdded,
      subtitle: subtitle,
      onComplete: () {
        try {
          entry.remove();
        } catch (_) {}
      },
    ),
  );

  overlay.insert(entry);
}

class _GemRewardCelebrationWidget extends StatefulWidget {
  final int gemsAdded;
  final String? subtitle;
  final VoidCallback onComplete;

  const _GemRewardCelebrationWidget({
    required this.gemsAdded,
    this.subtitle,
    required this.onComplete,
  });

  @override
  State<_GemRewardCelebrationWidget> createState() =>
      _GemRewardCelebrationWidgetState();
}

class _GemRewardCelebrationWidgetState
    extends State<_GemRewardCelebrationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..forward();
    _dismissTimer = Timer(const Duration(milliseconds: 1300), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Align(
            alignment: const Alignment(0.0, -0.65),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                final scale = t < 0.22
                    ? Curves.easeOutBack.transform(t / 0.22)
                    : (t > 0.78 ? (1.0 - (t - 0.78) / 0.22) : 1.0);
                final opacity = t < 0.15
                    ? (t / 0.15)
                    : (t > 0.75 ? (1.0 - (t - 0.75) / 0.25) : 1.0);
                final dy = -28.0 * Curves.easeOutCubic.transform(t);

                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(
                      scale: scale.clamp(0.6, 1.15),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Radiating sparkle particles
                          for (int i = 0; i < 8; i++)
                            Builder(
                              builder: (_) {
                                final angle = (i * math.pi / 4);
                                final radius = 42.0 + 36.0 * t;
                                return Transform.translate(
                                  offset: Offset(
                                    math.cos(angle) * radius,
                                    math.sin(angle) * radius * 0.65,
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 13 * (1.0 - t * 0.5),
                                    color: const Color(0xFF38BDF8)
                                        .withOpacity((1.0 - t).clamp(0.0, 1.0)),
                                  ),
                                );
                              },
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withOpacity(0.94),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: const Color(0xFF38BDF8).withOpacity(0.65),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF38BDF8).withOpacity(0.28),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SolfaGemIcon(size: 24),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '+${widget.gemsAdded} Gem',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF38BDF8),
                                      ),
                                    ),
                                    if (widget.subtitle != null)
                                      Text(
                                        widget.subtitle!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white70,
                                        ),
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
              },
            ),
          ),
        ),
      ),
    );
  }
}

