import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/rendering.dart';
import 'package:flutter/animation.dart';

import '../slide/motion.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';

/// Everything a hit does beyond changing a number: the tint, the squash, the
/// shake and the damage that floats off.
///
/// One place on purpose. With [Motion.reduced] every flash and shake in the
/// game stops at once, rather than each fight having to remember to ask.
/// Damage numbers stay: they are what happened, not decoration.
abstract final class Impact {
  /// How long a hit tint lasts. Short, and never repeated faster than three
  /// times a second, which is the photosensitivity guideline.
  static const double flashDuration = 0.14;

  /// Marks [visual] as hit: a brief tint, and a squash that springs back.
  ///
  /// Give it the thing that is drawn -- an actor, a shape -- rather than
  /// anything whose scale or position the fight is already driving, so the
  /// reaction cannot fight the fight for control of them.
  static void hit(PositionComponent visual, {Color colour = Palette.slide}) {
    if (Motion.reduced) {
      return;
    }
    visual.decorator.addLast(
      PaintDecorator.tint(colour.withValues(alpha: 0.7)),
    );
    visual.addAll([
      TimerComponent(
        period: flashDuration,
        removeOnFinish: true,
        onTick: visual.decorator.removeLast,
      ),
      ScaleEffect.by(
        Vector2(1.16, 0.84),
        EffectController(duration: 0.07, alternate: true),
      ),
    ]);
  }

  /// Shakes [board] briefly, for a hit the player felt themselves.
  static void shake(PositionComponent board, {double distance = 7}) {
    if (Motion.reduced) {
      return;
    }
    board.add(
      MoveEffect.by(
        Vector2(distance, distance * 0.4),
        RepeatedEffectController(ZigzagEffectController(period: 0.09), 2),
      ),
    );
  }

  /// Floats [text] up from [position] on [board]: what the hit cost, in the
  /// units that side of the fight reports -- `-4 pt`, `-1 shape`.
  ///
  /// Kept inside the board, so a number off something fighting at the top of
  /// the arena does not float out over the slide behind it.
  static void damage(
    Component board,
    Vector2 position,
    String text, {
    Color colour = Palette.slide,
  }) {
    final at = position.clone();
    if (board is PositionComponent) {
      at.y = at.y.clamp(_edge, board.size.y - _edge);
      at.x = at.x.clamp(_edge, board.size.x - _edge);
    }
    board.add(DamageNumber(text: text, position: at, colour: colour));
  }

  /// How far a damage number starts from the board's edge. At least its own
  /// rise, so it is still on the board when it fades.
  static const double _edge = DamageNumber.rise + 14;
}

/// A number rising off something that was just hit, and fading as it goes.
class DamageNumber extends TextComponent {
  DamageNumber({
    required String text,
    required Vector2 position,
    Color colour = Palette.slide,
  }) : super(
         text: text,
         textRenderer: SlideText.damage(colour),
         position: position,
         anchor: Anchor.center,
         priority: 10,
       );

  static const double _duration = 0.7;

  /// How far it climbs before it is gone.
  static const double rise = 40;

  @override
  Future<void> onLoad() async {
    await addAll([
      MoveEffect.by(
        Vector2(0, -rise),
        EffectController(duration: _duration, curve: Curves.easeOut),
      ),
      OpacityEffect.fadeOut(EffectController(duration: _duration)),
      RemoveEffect(delay: _duration),
    ]);
  }
}
