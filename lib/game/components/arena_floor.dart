import 'dart:ui';

import 'package:flame/components.dart';

import '../theme/palette.dart';

/// The pattern drawn on the floor.
enum FloorPattern { grid, stripes, dots, checks }

/// What the floor looks like: its colour, and the pattern drawn over it.
class FloorLook {
  const FloorLook({
    required this.floor,
    required this.pattern,
    required this.patternColour,
  });

  /// The floor every fight starts on.
  static const standard = FloorLook(
    floor: Color(0xFF161D2B),
    pattern: FloorPattern.grid,
    patternColour: Color(0xFF263048),
  );

  final Color floor;
  final FloorPattern pattern;
  final Color patternColour;
}

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

  /// What the floor looks like. A feature that re-themes the slide changes
  /// it; every other fight keeps [FloorLook.standard].
  FloorLook get look => _look;
  FloorLook _look = FloorLook.standard;
  set look(FloorLook look) {
    _look = look;
    _floorPaint.color = look.floor;
    _patternPaint.color = look.patternColour;
  }

  final Paint _floorPaint = Paint()..color = FloorLook.standard.floor;
  final Paint _patternPaint = Paint()
    ..color = FloorLook.standard.patternColour
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
    canvas.save();
    canvas.clipRect(rect);
    switch (_look.pattern) {
      case FloorPattern.grid:
        for (var x = _tile; x < width; x += _tile) {
          canvas.drawLine(Offset(x, 0), Offset(x, height), _patternPaint);
        }
        for (var y = _tile; y < height; y += _tile) {
          canvas.drawLine(Offset(0, y), Offset(width, y), _patternPaint);
        }
      case FloorPattern.stripes:
        for (var x = -height; x < width; x += _tile / 2) {
          canvas.drawLine(Offset(x, height), Offset(x + height, 0), _patternPaint);
        }
      case FloorPattern.dots:
        final dot = Paint()..color = _look.patternColour;
        for (var x = _tile / 2; x < width; x += _tile / 2) {
          for (var y = _tile / 2; y < height; y += _tile / 2) {
            canvas.drawCircle(Offset(x, y), 2.5, dot);
          }
        }
      case FloorPattern.checks:
        final check = Paint()..color = _look.patternColour;
        const big = _tile * 1.5;
        for (var x = 0.0; x < width; x += big) {
          for (var y = 0.0; y < height; y += big) {
            if (((x + y) / big).round().isEven) {
              canvas.drawRect(Rect.fromLTWH(x, y, big, big), check);
            }
          }
        }
    }
    canvas.restore();
    canvas.drawRect(rect, _borderPaint);
  }
}
