import 'dart:math' as math;
import 'dart:ui';

/// Small canvas helpers shared by the slide chrome components.
///
/// Flutter's [Canvas] has no dashed-stroke API, and a slide editor's empty
/// placeholders are the most recognisable dashed rectangles in software, so we
/// roll our own.
void drawDashedRRect(
  Canvas canvas,
  RRect rrect,
  Paint paint, {
  double dash = 12,
  double gap = 8,
}) {
  final path = Path()..addRRect(rrect);
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = math.min(distance + dash, metric.length);
      canvas.drawPath(metric.extractPath(distance, end), paint);
      distance = end + gap;
    }
  }
}

/// A right-pointing triangle: the bullet glyph used throughout the menus.
Path trianglePath(Offset centre, double size) {
  final half = size / 2;
  return Path()
    ..moveTo(centre.dx - half * 0.7, centre.dy - half)
    ..lineTo(centre.dx + half * 0.9, centre.dy)
    ..lineTo(centre.dx - half * 0.7, centre.dy + half)
    ..close();
}

/// A classic five-pointed autoshape star.
Path starPath(Offset centre, double radius, {int points = 5}) {
  final path = Path();
  final innerRadius = radius * 0.42;
  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? radius : innerRadius;
    final angle = -math.pi / 2 + i * math.pi / points;
    final point = Offset(
      centre.dx + r * math.cos(angle),
      centre.dy + r * math.sin(angle),
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

/// A block arrow autoshape pointing right.
Path blockArrowPath(Offset centre, double size) {
  final w = size;
  final h = size * 0.62;
  final left = centre.dx - w / 2;
  final top = centre.dy - h / 2;
  final shaftTop = top + h * 0.28;
  final shaftBottom = top + h * 0.72;
  final headLeft = left + w * 0.58;
  return Path()
    ..moveTo(left, shaftTop)
    ..lineTo(headLeft, shaftTop)
    ..lineTo(headLeft, top)
    ..lineTo(left + w, centre.dy)
    ..lineTo(headLeft, top + h)
    ..lineTo(headLeft, shaftBottom)
    ..lineTo(left, shaftBottom)
    ..close();
}

/// A lightning bolt autoshape: the universal symbol for "this animation was set
/// to On Click and nobody knows why".
Path boltPath(Offset centre, double size) {
  final w = size * 0.6;
  final h = size;
  final left = centre.dx - w / 2;
  final top = centre.dy - h / 2;
  return Path()
    ..moveTo(left + w * 0.55, top)
    ..lineTo(left, top + h * 0.58)
    ..lineTo(left + w * 0.42, top + h * 0.58)
    ..lineTo(left + w * 0.30, top + h)
    ..lineTo(left + w, top + h * 0.38)
    ..lineTo(left + w * 0.55, top + h * 0.38)
    ..close();
}
