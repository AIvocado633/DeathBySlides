import 'dart:ui';

import 'package:flame/components.dart';

import '../theme/palette.dart';
import 'slide_painting.dart';

/// The dashed outline a slide editor draws around an empty content placeholder.
///
/// Used as the frame for the game title and for the side panel, so the start
/// menu reads as a half-finished deck.
class PlaceholderFrame extends PositionComponent {
  PlaceholderFrame({
    super.position,
    super.size,
    this.cornerRadius = 6,
    this.strokeColor = Palette.placeholderStroke,
    this.fillColor,
  });

  final double cornerRadius;
  final Color strokeColor;
  final Color? fillColor;

  late final Paint _strokePaint = Paint()
    ..color = strokeColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;

  @override
  void render(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(
      size.toRect(),
      Radius.circular(cornerRadius),
    );
    final fill = fillColor;
    if (fill != null) {
      canvas.drawRRect(rrect, Paint()..color = fill);
    }
    drawDashedRRect(canvas, rrect, _strokePaint);
  }
}

/// The eight white resize handles an editor puts around a selected shape.
class SelectionHandles extends PositionComponent {
  SelectionHandles({super.position, super.size, this.handleSize = 11});

  final double handleSize;

  @override
  void render(Canvas canvas) {
    drawSelection(
      canvas,
      size.toRect(),
      handleSize: handleSize,
      rotationHandle: true,
    );
  }
}

final Paint _handleFillPaint = Paint()..color = Palette.slide;
final Paint _handleStrokePaint = Paint()
  ..color = Palette.selection
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.6;
final Paint _selectionOutlinePaint = Paint()
  ..color = Palette.selection.withValues(alpha: 0.45)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.2;

/// Draws an editor's selection around [rect]: a thin outline with a resize
/// handle at each corner and edge, and optionally the rotation handle above.
///
/// Also how keyboard and controller focus is shown, since choosing something
/// on a slide means selecting it.
void drawSelection(
  Canvas canvas,
  Rect rect, {
  double handleSize = 11,
  bool rotationHandle = false,
}) {
  canvas.drawRect(rect, _selectionOutlinePaint);
  for (final dx in [0.0, 0.5, 1.0]) {
    for (final dy in [0.0, 0.5, 1.0]) {
      if (dx == 0.5 && dy == 0.5) {
        continue;
      }
      final handle = Rect.fromCenter(
        center: Offset(rect.left + rect.width * dx, rect.top + rect.height * dy),
        width: handleSize,
        height: handleSize,
      );
      canvas.drawRect(handle, _handleFillPaint);
      canvas.drawRect(handle, _handleStrokePaint);
    }
  }
  if (rotationHandle) {
    // Floating above the top edge.
    final top = Offset(rect.center.dx, rect.top);
    final rotate = top.translate(0, -26);
    canvas.drawLine(top, rotate, _selectionOutlinePaint);
    canvas.drawCircle(rotate, handleSize / 2, _handleFillPaint);
    canvas.drawCircle(rotate, handleSize / 2, _handleStrokePaint);
  }
}
