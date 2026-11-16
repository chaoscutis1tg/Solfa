import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Renders the custom Light (`bg_light.jpg`) and Dark (`bg_dark.jpg`)
/// musical backgrounds with GPU-cached ambient blur (`ImageFilter.blur`)
/// so the background is soft and atmospheric without distracting from content.
class SolfaBackground extends StatelessWidget {
  final Widget child;
  final bool showStaffWaves;

  const SolfaBackground({
    super.key,
    required this.child,
    this.showStaffWaves = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assetPath =
        isDark ? 'assets/images/bg_dark.jpg' : 'assets/images/bg_light.jpg';
    final overlayStyle =
        isDark ? AppTheme.darkOverlayStyle : AppTheme.lightOverlayStyle;

    SystemChrome.setSystemUIOverlayStyle(overlayStyle);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: 18.0,
                    sigmaY: 18.0,
                    tileMode: TileMode.decal,
                  ),
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    cacheWidth: 480,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (context, _, __) => ColoredBox(
                      color: isDark
                          ? const Color(0xFF040714)
                          : const Color(0xFFD8F2FF),
                    ),
                  ),
                ),
                ColoredBox(
                  color: isDark
                      ? const Color(0xFF050816).withOpacity(0.68)
                      : const Color(0xFFF5F8FF).withOpacity(0.62),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
