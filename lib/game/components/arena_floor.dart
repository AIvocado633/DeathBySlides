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

  /// The spacing of the grid every fight starts with.
  static const double standardGridSpacing = _tile;

  /// How far apart the grid lines are, and where one row and one column
  /// cross. A feature that snaps the player to the grid changes them, so the
  /// grid drawn is always the grid snapped to.
  double get gridSpacing => _gridSpacing;
  double _gridSpacing = _tile;
  Vector2 get gridOrigin => _gridOrigin.clone();
  Vector2 _gridOrigin = Vector2.zero();

  void setGrid({required double spacing, Vector2? origin}) {
    _gridSpacing = spacing;
    _gridOrigin = origin?.clone() ?? Vector2.zero();
  }

  /// The grid line nearest to [value] along one axis, among those that keep
  /// a body of [half] half-size inside [0, extent].
  double _nearestLine(double value, double origin, double half, double extent) {
    final s = _gridSpacing;
    final lowest = origin + ((half - origin) / s).ceil() * s;
    final highest = origin + ((extent - half - origin) / s).floor() * s;
    if (lowest > highest) {
      return extent / 2;
    }
    final nearest = origin + ((value - origin) / s).round() * s;
    return nearest.clamp(lowest, highest);
  }

  /// [position] moved to the nearest grid crossing a body of [bodySize] can
  /// stand on, so it lies on a row and a column at once.
  Vector2 snapToGrid(Vector2 position, Vector2 bodySize) => Vector2(
    _nearestLine(position.x, _gridOrigin.x, bodySize.x / 2, size.x),
    _nearestLine(position.y, _gridOrigin.y, bodySize.y / 2, size.y),
  );

  /// Every grid line along one axis that lies on the floor.
  List<double> gridLines({required bool rows}) {
    final extent = rows ? size.y : size.x;
    final origin = rows ? _gridOrigin.y : _gridOrigin.x;
    final s = _gridSpacing;
    return [
      for (var v = origin - ((origin) / s).floor() * s; v <= extent; v += s)
        if (v > 0 && v < extent) v,
    ];
  }

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
        for (final x in gridLines(rows: false)) {
          canvas.drawLine(Offset(x, 0), Offset(x, height), _patternPaint);
        }
        for (final y in gridLines(rows: true)) {
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
