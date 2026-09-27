import 'dart:ui';

import 'package:flame/components.dart';

import '../theme/palette.dart';

/// The playfield: a tiled floor seen from directly above.
///
/// Actors are added as children of the floor rather than of the page, so their
/// positions are arena-local and staying inside the arena is a clamp against
/// [size] instead of arithmetic against the floor's offset on the slide.
///
/// It is also the handle for freezing the fight: [pause] scales time to zero
/// for every actor and projectile on the board at once.
class ArenaFloor extends PositionComponent with HasTimeScale {
  ArenaFloor({required Vector2 position, required Vector2 size})
    : super(position: position, size: size);

  static const double _tile = 60;

  final Paint _floorPaint = Paint()..color = const Color(0xFF161D2B);
  final Paint _gridPaint = Paint()
    ..color = const Color(0xFF263048)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _borderPaint = Paint()
    ..color = Palette.brand
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  /// The centre of the arena, in arena-local coordinates.
  Vector2 get centre => size / 2;

  /// Clamps [position] so that a body of [bodySize] stays fully inside the
  /// floor. Mutates and returns [position].
  Vector2 clampInside(Vector2 position, Vector2 bodySize) {
    final half = bodySize / 2;
    position.x = position.x.clamp(half.x, size.x - half.x);
    position.y = position.y.clamp(half.y, size.y - half.y);
    return position;
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    canvas.drawRect(rect, _floorPaint);
    for (var x = _tile; x < width; x += _tile) {
      canvas.drawLine(Offset(x, 0), Offset(x, height), _gridPaint);
    }
    for (var y = _tile; y < height; y += _tile) {
      canvas.drawLine(Offset(0, y), Offset(width, y), _gridPaint);
    }
    canvas.drawRect(rect, _borderPaint);
  }
}
