import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../slide/focusable.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';
import 'placeholder_frame.dart';

/// A checkbox like the ones in PowerPoint's dialogs, with its label beside it.
///
/// The whole row is the hit target, as in Office, where clicking the label
/// ticks the box.
class SettingCheckbox extends PositionComponent
    with TapCallbacks, HoverCallbacks, Focusable {
  SettingCheckbox({
    required this.label,
    required bool checked,
    required this.onChanged,
    super.position,
    double width = 400,
  }) : _checked = checked,
       super(size: Vector2(width, rowHeight));

  static const double rowHeight = 48;
  static const double _box = 24;

  final String label;
  final void Function(bool checked) onChanged;

  bool get checked => _checked;
  bool _checked;

  final Paint _boxPaint = Paint();
  final Paint _edgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;
  final Paint _tickPaint = Paint()
    ..color = Palette.slide
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _washPaint = Paint()..color = Palette.brandWash;

  @override
  Future<void> onLoad() async {
    await add(
      TextComponent(
        text: label,
        textRenderer: SlideText.settingLabel,
        position: Vector2(_box + 18, height / 2),
        anchor: Anchor.centerLeft,
      ),
    );
  }

  @override
  void activate() {
    _checked = !_checked;
    onChanged(_checked);
  }

  @override
  void onTapUp(TapUpEvent event) => activate();

  @override
  void render(Canvas canvas) {
    if (isHighlighted) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(6)),
        _washPaint,
      );
      drawSelection(canvas, size.toRect().inflate(3), handleSize: 9);
    }
    final box = Rect.fromLTWH(6, (height - _box) / 2, _box, _box);
    final rbox = RRect.fromRectAndRadius(box, const Radius.circular(3));
    _boxPaint.color = _checked ? Palette.brand : Palette.slide;
    _edgePaint.color = _checked ? Palette.brand : Palette.inkSoft;
    canvas.drawRRect(rbox, _boxPaint);
    canvas.drawRRect(rbox, _edgePaint);
    if (_checked) {
      canvas.drawPath(
        Path()
          ..moveTo(box.left + 5, box.center.dy + 1)
          ..lineTo(box.left + 10, box.bottom - 6)
          ..lineTo(box.right - 5, box.top + 6),
        _tickPaint,
      );
    }
  }
}

/// A slider modelled on the zoom slider in PowerPoint's status bar -- minus,
/// track, knob, plus -- which finally gets to do something.
///
/// Tap the minus or plus to step, tap or drag along the track to jump, or
/// focus it and press left and right.
class SettingSlider extends PositionComponent
    with TapCallbacks, DragCallbacks, HoverCallbacks, Focusable {
  SettingSlider({
    required this.label,
    required double value,
    required this.min,
    required this.max,
    required this.step,
    required this.format,
    required this.onChanged,
    this.mark,
    super.position,
    double width = 580,
  }) : assert(min < max && step > 0),
       _value = value.clamp(min, max),
       super(size: Vector2(width, rowHeight));

  static const double rowHeight = 48;

  final String label;
  final double min;
  final double max;
  final double step;

  /// Where to draw the notch the zoom slider has at 100%: here, the default.
  final double? mark;

  /// How [value] reads beside the slider, e.g. `20%`.
  final String Function(double value) format;

  final void Function(double value) onChanged;

  double get value => _value;
  double _value;

  late final TextComponent _readout;

  /// The track takes the right-hand part of the row, with room for the minus
  /// before it and the plus and readout after it.
  double get _trackLeft => width - 290;
  double get _trackRight => width - 110;
  double get _minusX => _trackLeft - 24;
  double get _plusX => _trackRight + 24;

  static const double _buttonReach = 18;

  final Paint _trackPaint = Paint()
    ..color = Palette.inkFaint
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;
  final Paint _knobPaint = Paint()..color = Palette.inkSoft;
  final Paint _knobActivePaint = Paint()..color = Palette.brand;
  final Paint _washPaint = Paint()..color = Palette.brandWash;

  bool _dragging = false;

  @override
  Future<void> onLoad() async {
    await addAll([
      TextComponent(
        text: label,
        textRenderer: SlideText.settingLabel,
        position: Vector2(6, height / 2),
        anchor: Anchor.centerLeft,
      ),
      _readout = TextComponent(
        text: format(_value),
        textRenderer: SlideText.caption,
        position: Vector2(width - 6, height / 2),
        anchor: Anchor.centerRight,
      ),
    ]);
  }

  /// Moves the value by [steps] steps, stopping at either end.
  void nudge(int steps) => _set(_value + steps * step);

  void _set(double value) {
    final steps = ((value - min) / step).round();
    // Rounded, so 0.15 is saved as 0.15 rather than 0.15000000000000002.
    final snapped = ((min + steps * step).clamp(min, max) * 1e6).round() / 1e6;
    if ((snapped - _value).abs() < 1e-9) {
      return;
    }
    _value = snapped;
    _readout.text = format(snapped);
    onChanged(snapped);
  }

  double _valueAt(double x) {
    final t = ((x - _trackLeft) / (_trackRight - _trackLeft)).clamp(0.0, 1.0);
    return min + t * (max - min);
  }

  double _xOf(double value) =>
      _trackLeft + (value - min) / (max - min) * (_trackRight - _trackLeft);

  /// Nothing to press: a slider is changed with left and right.
  @override
  void activate() {}

  @override
  void onTapDown(TapDownEvent event) {
    final x = event.localPosition.x;
    if ((x - _minusX).abs() <= _buttonReach) {
      nudge(-1);
    } else if ((x - _plusX).abs() <= _buttonReach) {
      nudge(1);
    } else if (_onTrack(x)) {
      _set(_valueAt(x));
    }
  }

  bool _onTrack(double x) => x >= _trackLeft - 8 && x <= _trackRight + 8;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final x = event.localPosition.x;
    _dragging = _onTrack(x);
    // The knob jumps to the finger as the drag starts, rather than waiting
    // for it to move.
    if (_dragging) {
      _set(_valueAt(x));
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_dragging) {
      _set(_valueAt(event.localEndPosition.x));
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _dragging = false;
  }

  @override
  void render(Canvas canvas) {
    if (isHighlighted) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(6)),
        _washPaint,
      );
      drawSelection(canvas, size.toRect().inflate(3), handleSize: 9);
    }
    final y = height / 2;
    // Minus.
    canvas.drawLine(
      Offset(_minusX - 7, y),
      Offset(_minusX + 7, y),
      _trackPaint,
    );
    // Track, with a notch at the mark.
    canvas.drawLine(Offset(_trackLeft, y), Offset(_trackRight, y), _trackPaint);
    final notch = mark;
    if (notch != null) {
      final x = _xOf(notch);
      canvas.drawLine(Offset(x, y - 7), Offset(x, y + 7), _trackPaint);
    }
    // Plus.
    canvas.drawLine(Offset(_plusX - 7, y), Offset(_plusX + 7, y), _trackPaint);
    canvas.drawLine(Offset(_plusX, y - 7), Offset(_plusX, y + 7), _trackPaint);
    canvas.drawCircle(
      Offset(_xOf(_value), y),
      9,
      isHighlighted || _dragging ? _knobActivePaint : _knobPaint,
    );
  }
}
