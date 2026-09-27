import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../art/pptx_art.dart';
import '../slide/motion.dart';
import '../theme/palette.dart';

/// A character in the game -- the player, or one of the PowerPoint features
/// they are trying to defeat.
///
/// Artwork comes from PNG frames exported out of PowerPoint (see
/// [PptxArt]). Until those frames exist, the actor draws a procedural
/// stand-in built from the same autoshapes the real art will be made of, so
/// layout and animation timing can be developed before the deck is finished.
class PptxActor extends PositionComponent {
  PptxActor({
    required this.artPrefix,
    this.tint = Palette.brand,
    this.stepTime = 0.14,
    this.bobbing = true,
    super.position,
    super.size,
    super.anchor,
  });

  /// File-name prefix of the exported frames, e.g. `hero_idle_`.
  final String artPrefix;

  /// Colour used by the placeholder stand-in.
  final Color tint;

  final double stepTime;

  /// Whether the actor bobs gently while idle. Decoration, so it stops with
  /// [Motion.reduced] -- and starts again if that is turned back off.
  final bool bobbing;

  PositionComponent? _art;
  MoveEffect? _bob;

  /// True once real PowerPoint artwork was found and mounted.
  bool get hasArtwork => _hasArtwork;
  bool _hasArtwork = false;

  @override
  Future<void> onLoad() async {
    final animation = await PptxArt.loadAnimation(
      artPrefix,
      stepTime: stepTime,
    );
    final Component art;
    if (animation != null) {
      _hasArtwork = true;
      art = SpriteAnimationComponent(
        animation: animation,
        size: size.clone(),
        position: size / 2,
        anchor: Anchor.center,
      );
    } else {
      art = _PlaceholderCreature(size: size.clone(), tint: tint)
        ..position = size / 2
        ..anchor = Anchor.center;
    }
    await add(art);
    if (art is PositionComponent) {
      _art = art;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final art = _art;
    if (!bobbing || art == null) {
      return;
    }
    final bob = _bob;
    if (Motion.reduced && bob != null) {
      bob.removeFromParent();
      _bob = null;
      art.position = size / 2;
    } else if (!Motion.reduced && bob == null) {
      art.add(
        _bob = MoveEffect.by(
          Vector2(0, -10),
          EffectController(
            duration: 1.3,
            alternate: true,
            infinite: true,
            curve: Curves.easeInOut,
          ),
        ),
      );
    }
  }
}

Color _darken(Color colour, [double amount = 0.16]) {
  final hsl = HSLColor.fromColor(colour);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

/// A monster assembled from PowerPoint autoshapes: an oval body, two circle
/// eyes and a bullet point for an antenna.
class _PlaceholderCreature extends PositionComponent {
  _PlaceholderCreature({required Vector2 size, required this.tint})
    : super(size: size);

  final Color tint;

  late final Paint _bodyPaint = Paint()..color = tint;
  late final Paint _bodyHighlight = Paint()..color = const Color(0x33FFFFFF);
  late final Color _shade = _darken(tint);
  late final Paint _outlinePaint = Paint()
    ..color = _shade
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  final Paint _eyeWhitePaint = Paint()..color = Palette.slide;
  final Paint _pupilPaint = Paint()..color = Palette.ink;
  final Paint _shadowPaint = Paint()..color = const Color(0x1A000000);
  late final Paint _mouthPaint = Paint()
    ..color = _shade
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round;

  @override
  void render(Canvas canvas) {
    final unit = math.min(width, height) / 100;
    final centre = Offset(width / 2, height / 2 + 6 * unit);

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centre.dx, height - 6 * unit),
        width: 56 * unit,
        height: 12 * unit,
      ),
      _shadowPaint,
    );

    // Antenna: a line topped with a bullet point.
    canvas.drawLine(
      Offset(centre.dx, centre.dy - 34 * unit),
      Offset(centre.dx, centre.dy - 50 * unit),
      _outlinePaint,
    );
    canvas.drawCircle(
      Offset(centre.dx, centre.dy - 54 * unit),
      6 * unit,
      _bodyPaint,
    );

    // Body.
    final body = Rect.fromCenter(
      center: centre,
      width: 70 * unit,
      height: 72 * unit,
    );
    final bodyRRect = RRect.fromRectAndRadius(body, Radius.circular(26 * unit));
    canvas.drawRRect(bodyRRect, _bodyPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(body.left, body.top, body.width, body.height * 0.42),
        Radius.circular(26 * unit),
      ),
      _bodyHighlight,
    );
    canvas.drawRRect(bodyRRect, _outlinePaint);

    // Eyes.
    for (final dx in [-16.0, 16.0]) {
      final eye = Offset(centre.dx + dx * unit, centre.dy - 12 * unit);
      canvas.drawCircle(eye, 11 * unit, _eyeWhitePaint);
      canvas.drawCircle(eye, 11 * unit, _outlinePaint);
      canvas.drawCircle(
        Offset(eye.dx + 2 * unit, eye.dy + 1 * unit),
        5 * unit,
        _pupilPaint,
      );
    }

    // A flat, unimpressed mouth.
    canvas.drawLine(
      Offset(centre.dx - 14 * unit, centre.dy + 16 * unit),
      Offset(centre.dx + 14 * unit, centre.dy + 16 * unit),
      _mouthPaint,
    );
  }
}
