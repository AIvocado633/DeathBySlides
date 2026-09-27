import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../slide/motion.dart';
import '../slide/slide_metrics.dart';
import '../theme/palette.dart';
import 'slide_painting.dart';

/// The autoshapes everyone has dropped onto a slide at 2am.
enum Autoshape { star, arrow, bolt, roundedRect, oval }

/// A single decorative shape drifting slowly across the slide, or holding
/// still with [Motion.reduced].
class FloatingAutoshape extends PositionComponent {
  FloatingAutoshape({
    required this.shape,
    required this.velocity,
    required this.spin,
    required Color tint,
    required double radius,
    required Vector2 super.position,
  }) : _paint = Paint()..color = tint,
       super(size: Vector2.all(radius * 2), anchor: Anchor.center);

  final Autoshape shape;
  final Vector2 velocity;
  final double spin;
  final Paint _paint;

  static const double _topBound = kContentTop + 20;
  static const double _bottomBound = kContentBottom - 20;

  @override
  void update(double dt) {
    super.update(dt);
    if (Motion.reduced) {
      return;
    }
    position += velocity * dt;
    angle += spin * dt;

    final half = width / 2;
    if (position.x < half || position.x > kSlideWidth - half) {
      velocity.x = -velocity.x;
      position.x = position.x.clamp(half, kSlideWidth - half);
    }
    if (position.y < _topBound + half || position.y > _bottomBound - half) {
      velocity.y = -velocity.y;
      position.y = position.y.clamp(_topBound + half, _bottomBound - half);
    }
  }

  @override
  void render(Canvas canvas) {
    final centre = Offset(width / 2, height / 2);
    final radius = width / 2;
    switch (shape) {
      case Autoshape.star:
        canvas.drawPath(starPath(centre, radius), _paint);
      case Autoshape.arrow:
        canvas.drawPath(blockArrowPath(centre, width), _paint);
      case Autoshape.bolt:
        canvas.drawPath(boltPath(centre, height), _paint);
      case Autoshape.roundedRect:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: centre, width: width, height: height * 0.7),
            Radius.circular(radius * 0.3),
          ),
          _paint,
        );
      case Autoshape.oval:
        canvas.drawOval(
          Rect.fromCenter(center: centre, width: width, height: height * 0.78),
          _paint,
        );
    }
  }
}

/// Spawns a drifting field of autoshapes behind the slide content.
class AutoshapeBackdrop extends Component {
  AutoshapeBackdrop({this.count = 9, int? seed}) : _random = math.Random(seed);

  final int count;
  final math.Random _random;

  static const List<Color> _tints = [
    Palette.brandWash,
    Color(0x12000000),
    Color(0x140563C1),
  ];

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < count; i++) {
      final radius = 30 + _random.nextDouble() * 46;
      addAll([
        FloatingAutoshape(
          shape: Autoshape.values[_random.nextInt(Autoshape.values.length)],
          radius: radius,
          tint: _tints[_random.nextInt(_tints.length)],
          spin: (_random.nextDouble() - 0.5) * 0.5,
          velocity: Vector2(
            (_random.nextDouble() - 0.5) * 34,
            (_random.nextDouble() - 0.5) * 34,
          ),
          position: Vector2(
            radius + _random.nextDouble() * (kSlideWidth - radius * 2),
            kContentTop +
                radius +
                _random.nextDouble() *
                    (kContentBottom - kContentTop - radius * 2),
          ),
        ),
      ]);
    }
  }
}
