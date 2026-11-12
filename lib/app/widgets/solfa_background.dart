import 'package:flutter/material.dart';

/// Renders the custom Light (`bg_light.jpg`) and Dark (`bg_dark.jpg`)
/// musical backgrounds with GPU-friendly resolution caching (`cacheWidth: 720`)
/// and `gaplessPlayback: true` for smooth 60 FPS scrolling.
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

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                assetPath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                cacheWidth: 720,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
                errorBuilder: (context, _, __) => ColoredBox(
                  color:
                      isDark ? const Color(0xFF070D30) : const Color(0xFFD8F2FF),
                ),
              ),
              ColoredBox(
                color: isDark
                    ? const Color(0xFF050A24).withOpacity(0.26)
                    : Colors.white.withOpacity(0.18),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}
