import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

export 'package:flutter_animate/flutter_animate.dart';

class MotionTokens {
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration page = Duration(milliseconds: 320);
  static const Duration complex = Duration(milliseconds: 420);

  static const Curve fastOut = Curves.easeOutCubic;
  static const Curve standardCurve = Curves.easeInOut;
  static const Curve inCurve = Curves.easeIn;
}

bool motionAllowed(BuildContext context) {
  return !MediaQuery.disableAnimationsOf(context);
}

Widget motionEntrance(
  BuildContext context,
  Widget child, {
  Duration duration = MotionTokens.medium,
  Curve curve = MotionTokens.fastOut,
  double slideY = 0.04,
  double scaleBegin = 0.98,
  bool includeScale = true,
}) {
  if (!motionAllowed(context)) {
    return child;
  }

  var animated = child.animate().fadeIn(duration: duration, curve: curve);
  if (slideY != 0) {
    animated = animated.slide(
      begin: Offset(0, slideY),
      end: Offset.zero,
      duration: duration,
      curve: curve,
    );
  }
  if (includeScale) {
    animated = animated.scale(
      begin: Offset(scaleBegin, scaleBegin),
      end: const Offset(1, 1),
      duration: duration,
      curve: curve,
    );
  }
  return animated;
}
