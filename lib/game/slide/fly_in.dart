import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import 'motion.dart';

/// PowerPoint's "Fly In" entrance animation, applied to any component.
///
/// Call this *after* the component's final position has been set: the helper
/// remembers that position, shifts the component out of frame and animates it
/// back. Staggering `delay` across a group reproduces the classic
/// one-bullet-at-a-time build.
///
/// With [Motion.reduced] the component simply appears where it belongs.
extension FlyIn on PositionComponent {
  void flyIn({
    Vector2? from,
    double delay = 0,
    double duration = 0.45,
  }) {
    if (Motion.reduced) {
      return;
    }
    final destination = position.clone();
    position = destination + (from ?? Vector2(-110, 0));
    add(
      MoveEffect.to(
        destination,
        EffectController(
          duration: duration,
          startDelay: delay,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }
}
