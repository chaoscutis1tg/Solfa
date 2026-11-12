import 'package:flutter/material.dart';

/// Vibrant crimson-red heart color used across Solfa's developer support UI.
const Color kHeartRedColor = Color(0xFFFF244C);
const Color kHeartRedDarkColor = Color(0xFFD91438);

/// A GPU-isolated (`RepaintBoundary`) pulsing red heart icon that never triggers
/// parent layout shifts and automatically disables infinite repeat under `flutter test`.
class PulsingRedHeart extends StatefulWidget {
  final double size;
  final bool enablePulse;
  final bool showGlowBadge;

  const PulsingRedHeart({
    super.key,
    this.size = 22,
    this.enablePulse = true,
    this.showGlowBadge = false,
  });

  @override
  State<PulsingRedHeart> createState() => _PulsingRedHeartState();
}

class _PulsingRedHeartState extends State<PulsingRedHeart>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _scaleAnimation;

  bool get _isInWidgetTest {
    final bindingType = WidgetsBinding.instance.runtimeType.toString();
    return bindingType.contains('TestWidgetsFlutterBinding') ||
        bindingType.contains('AutomatedTestWidgetsFlutterBinding');
  }

  @override
  void initState() {
    super.initState();
    if (widget.enablePulse && !_isInWidgetTest) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 950),
      )..repeat(reverse: true);
      _scaleAnimation = Tween<double>(begin: 0.94, end: 1.14).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
    } else {
      _scaleAnimation = const AlwaysStoppedAnimation<double>(1.0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heartIcon = RepaintBoundary(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Icon(
          Icons.favorite_rounded,
          color: kHeartRedColor,
          size: widget.size,
          shadows: [
            Shadow(
              color: kHeartRedColor.withOpacity(0.55),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );

    if (!widget.showGlowBadge) {
      return heartIcon;
    }

    final boxSize = widget.size + 22;
    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kHeartRedColor.withOpacity(0.22),
            kHeartRedDarkColor.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: kHeartRedColor.withOpacity(0.45),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: heartIcon,
    );
  }
}

