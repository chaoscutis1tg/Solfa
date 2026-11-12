import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Displays the official Solfa brand logo (`assets/images/solfa_logo.png`).
class SolfaLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const SolfaLogo({
    super.key,
    this.size = 64,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showShadow
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: size * 0.24,
                  offset: Offset(0, size * 0.08),
                ),
              ],
            )
          : null,
      child: Image.asset(
        'assets/images/solfa_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, _, __) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(size * 0.26),
          ),
          child: Icon(
            Icons.music_note_rounded,
            color: Colors.white,
            size: size * 0.56,
          ),
        ),
      ),
    );
  }
}
