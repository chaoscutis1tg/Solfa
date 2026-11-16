import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Unified Design System for Solfa Studio (Modern Minimalist + Premium Music Education).
/// Enforces consistent spacing, radius, typography, and low-noise surface hierarchy.
class SolfaSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 22.0;
  static const double xxl = 28.0;

  static const EdgeInsets screenPadding =
      EdgeInsets.fromLTRB(16, 10, 16, 28);
}

class SolfaRadius {
  static const double sm = 10.0;
  static const double md = 14.0;
  static const double lg = 18.0;
  static const double pill = 999.0;
}

class SolfaTypography {
  static const TextStyle heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static const TextStyle numeric = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Clean section header without decorative clutter.
class SolfaSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const SolfaSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SolfaSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SolfaTypography.sectionTitle,
            ),
          ),
          if (actionLabel != null && onActionTap != null)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onActionTap,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Minimalist surface container using subtle contrast and 1px neutral borders
/// instead of competing gradients or heavy shadows.
class SolfaSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool isPrimaryHighlight;
  final Color? customBorderColor;

  const SolfaSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.isPrimaryHighlight = false,
    this.customBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isPrimaryHighlight
        ? (isDark ? const Color(0xFF172554) : AppColors.primary)
        : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);
    final borderColor = customBorderColor ??
        (isPrimaryHighlight
            ? AppColors.primary.withOpacity(isDark ? 0.65 : 1.0)
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)));

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(SolfaRadius.lg),
        border: Border.all(
          color: borderColor,
          width: isPrimaryHighlight ? 1.4 : 1.0,
        ),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(SolfaRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(SolfaRadius.lg),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

