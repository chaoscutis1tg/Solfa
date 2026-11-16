import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vector CustomPainter icon of Two Crossed Broadswords (Kiếm Chéo Đấu Trường)
/// designed for the central Diamond Navigation CTA and the 1v1 Battle Arena.
class CrossedSwordsIcon extends StatelessWidget {
  final double size;
  final Color color;
  final Color? guardColor;

  const CrossedSwordsIcon({
    super.key,
    this.size = 26,
    this.color = Colors.white,
    this.guardColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CrossedSwordsPainter(
          bladeColor: color,
          guardColor: guardColor ?? color,
        ),
      ),
    );
  }
}

class _CrossedSwordsPainter extends CustomPainter {
  final Color bladeColor;
  final Color guardColor;

  const _CrossedSwordsPainter({
    required this.bladeColor,
    required this.guardColor,
  });

  void _drawSingleSword(Canvas canvas, Size size, double angleRadians) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angleRadians);

    // 1. Sword Blade (pointing straight up in local coordinates: y from +0.16s to -0.44s)
    final bladePaint = Paint()
      ..color = bladeColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final bladePath = Path()
      ..moveTo(0, -s * 0.45) // Sharp tip
      ..lineTo(s * 0.085, -s * 0.28)
      ..lineTo(s * 0.068, s * 0.14)
      ..lineTo(-s * 0.068, s * 0.14)
      ..lineTo(-s * 0.085, -s * 0.28)
      ..close();
    canvas.drawPath(bladePath, bladePaint);

    // Subtle central fuller ridge for metallic depth
    final fullerPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..strokeWidth = s * 0.025
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, -s * 0.28),
      Offset(0, s * 0.11),
      fullerPaint,
    );

    // 2. Crossguard (flared horizontal guard at y = +0.14s..+0.21s)
    final guardPaint = Paint()
      ..color = guardColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final guardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, s * 0.175),
        width: s * 0.36,
        height: s * 0.075,
      ),
      Radius.circular(s * 0.035),
    );
    canvas.drawRRect(guardRect, guardPaint);

    // 3. Grip / Hilt (y = +0.21s..+0.36s)
    final gripRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, s * 0.285),
        width: s * 0.082,
        height: s * 0.16,
      ),
      Radius.circular(s * 0.025),
    );
    canvas.drawRRect(gripRect, guardPaint);

    // 4. Pommel (round jewel at bottom y = +0.40s)
    canvas.drawCircle(
      Offset(0, s * 0.395),
      s * 0.062,
      guardPaint,
    );

    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Left-to-right diagonal sword (+42 deg)
    _drawSingleSword(canvas, size, math.pi / 4.2);
    // Right-to-left diagonal sword (-42 deg)
    _drawSingleSword(canvas, size, -math.pi / 4.2);
  }

  @override
  bool shouldRepaint(covariant _CrossedSwordsPainter oldDelegate) {
    return oldDelegate.bladeColor != bladeColor ||
        oldDelegate.guardColor != guardColor;
  }
}

