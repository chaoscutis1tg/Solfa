import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Custom vector Guitar Icon (supports both Acoustic round-body with soundhole
/// and Electric double-cutaway body with lightning accent).
/// Rendered inside a [RepaintBoundary] for zero-cost GPU caching.
class SolfaGuitarIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool isElectric;

  const SolfaGuitarIcon({
    super.key,
    this.size = 20,
    this.color = const Color(0xFFD97706),
    this.isElectric = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _SolfaGuitarPainter(
            color: color,
            isElectric: isElectric,
          ),
        ),
      ),
    );
  }
}

class _SolfaGuitarPainter extends CustomPainter {
  final Color color;
  final bool isElectric;

  const _SolfaGuitarPainter({
    required this.color,
    required this.isElectric,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final cy = s / 2;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-math.pi / 4); // Iconic 45-degree diagonal guitar tilt

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.085).clamp(1.2, 2.2)
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // 1. Guitar Neck (extending upwards from body)
    final neckRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -s * 0.22),
        width: s * 0.11,
        height: s * 0.36,
      ),
      Radius.circular(s * 0.03),
    );
    canvas.drawRRect(neckRect, fillPaint);

    // 2. Headstock (top tip)
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -s * 0.43),
        width: s * 0.16,
        height: s * 0.11,
      ),
      Radius.circular(s * 0.035),
    );
    canvas.drawRRect(headRect, fillPaint);

    // 3. Guitar Body (Acoustic figure-8 vs Electric sharp double-horn)
    if (!isElectric) {
      // Upper bout + Lower bout figure-8 acoustic body
      canvas.drawCircle(Offset(0, s * 0.05), s * 0.19, fillPaint);
      canvas.drawCircle(Offset(0, s * 0.24), s * 0.25, fillPaint);
    } else {
      // Electric body with sharp horns
      final bodyPath = Path()
        ..moveTo(-s * 0.20, -s * 0.06) // Left horn tip
        ..quadraticBezierTo(-s * 0.08, s * 0.02, -s * 0.06, -s * 0.02)
        ..lineTo(s * 0.06, -s * 0.02)
        ..quadraticBezierTo(s * 0.08, s * 0.02, s * 0.19, -s * 0.04) // Right horn tip
        ..quadraticBezierTo(s * 0.26, s * 0.12, s * 0.24, s * 0.28)
        ..quadraticBezierTo(0, s * 0.44, -s * 0.24, s * 0.28)
        ..quadraticBezierTo(-s * 0.26, s * 0.12, -s * 0.20, -s * 0.06)
        ..close();
      canvas.drawPath(bodyPath, fillPaint);
    }

    // 4. Cutout details (Soundhole & Bridge in contrasting negative space)
    final detailPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.saveLayer(
      Rect.fromCenter(center: Offset.zero, width: s * 1.2, height: s * 1.2),
      Paint(),
    );
    // Re-draw body + neck inside layer so dstOut punches clean holes
    canvas.drawRRect(neckRect, fillPaint);
    canvas.drawRRect(headRect, fillPaint);
    if (!isElectric) {
      canvas.drawCircle(Offset(0, s * 0.05), s * 0.19, fillPaint);
      canvas.drawCircle(Offset(0, s * 0.24), s * 0.25, fillPaint);
      // Soundhole
      canvas.drawCircle(Offset(0, s * 0.09), s * 0.075, detailPaint);
      // Bridge bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, s * 0.26),
            width: s * 0.20,
            height: s * 0.045,
          ),
          Radius.circular(s * 0.02),
        ),
        detailPaint,
      );
    } else {
      final bodyPath = Path()
        ..moveTo(-s * 0.20, -s * 0.06)
        ..quadraticBezierTo(-s * 0.08, s * 0.02, -s * 0.06, -s * 0.02)
        ..lineTo(s * 0.06, -s * 0.02)
        ..quadraticBezierTo(s * 0.08, s * 0.02, s * 0.19, -s * 0.04)
        ..quadraticBezierTo(s * 0.26, s * 0.12, s * 0.24, s * 0.28)
        ..quadraticBezierTo(0, s * 0.44, -s * 0.24, s * 0.28)
        ..quadraticBezierTo(-s * 0.26, s * 0.12, -s * 0.20, -s * 0.06)
        ..close();
      canvas.drawPath(bodyPath, fillPaint);
      // Dual Humbucker Pickups
      for (final py in [s * 0.09, s * 0.21]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(0, py),
              width: s * 0.19,
              height: s * 0.045,
            ),
            Radius.circular(s * 0.02),
          ),
          detailPaint,
        );
      }
    }
    canvas.restore();
    // Draw subtle tuning pegs hint
    canvas.drawLine(
      Offset(-s * 0.11, -s * 0.43),
      Offset(s * 0.11, -s * 0.43),
      strokePaint..strokeWidth = (s * 0.05).clamp(0.8, 1.4),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SolfaGuitarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isElectric != isElectric;
  }
}

