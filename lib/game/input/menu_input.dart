import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

/// What the player asked a menu to do, whichever device they asked with.
///
/// Pages only ever see these, so a page handles the keyboard, a controller and
/// Android's back gesture with the same code.
enum MenuAction {
  up,
  down,
  left,
  right,

  /// Enter, Space, controller A.
  activate,

  /// Esc, controller B, Android back.
  back,

  /// B or `.`, controller Start: the usual blank-screen keys, which pause
  /// a fight and let it go again.
  pause,

  /// F5: start the show from the first slide.
  startFromBeginning,

  /// Shift+F5: start the show from the current slide.
  startFromCurrent;

  bool get isDirection =>
      this == up || this == down || this == left || this == right;
}

/// The menu action a key press stands for, or null for any other key.
///
/// Arrow keys also fire on key repeat, so holding one keeps moving focus;
/// everything else fires once per press.
MenuAction? menuActionForKey(
  KeyEvent event,
  Set<LogicalKeyboardKey> keysPressed,
) {
  if (event is KeyUpEvent) {
    return null;
  }
  final direction = switch (event.logicalKey) {
    LogicalKeyboardKey.arrowUp => MenuAction.up,
    LogicalKeyboardKey.arrowDown => MenuAction.down,
    LogicalKeyboardKey.arrowLeft => MenuAction.left,
    LogicalKeyboardKey.arrowRight => MenuAction.right,
    _ => null,
  };
  if (direction != null || event is KeyRepeatEvent) {
    return direction;
  }
  return switch (event.logicalKey) {
    LogicalKeyboardKey.enter ||
    LogicalKeyboardKey.numpadEnter ||
    LogicalKeyboardKey.space => MenuAction.activate,
    LogicalKeyboardKey.escape => MenuAction.back,
    // Presenting software blanks the screen on B, and on the period key beside it.
    LogicalKeyboardKey.keyB || LogicalKeyboardKey.period => MenuAction.pause,
    LogicalKeyboardKey.f5 =>
      keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
              keysPressed.contains(LogicalKeyboardKey.shiftRight)
          ? MenuAction.startFromCurrent
          : MenuAction.startFromBeginning,
    _ => null,
  };
}

/// The menu action a controller button stands for, or null for the rest.
MenuAction? menuActionForButton(GamepadButton button) => switch (button) {
  GamepadButton.a => MenuAction.activate,
  GamepadButton.b => MenuAction.back,
  GamepadButton.start => MenuAction.pause,
  GamepadButton.dpadUp => MenuAction.up,
  GamepadButton.dpadDown => MenuAction.down,
  GamepadButton.dpadLeft => MenuAction.left,
  GamepadButton.dpadRight => MenuAction.right,
  _ => null,
};

/// Turns an analogue stick into menu steps, the way a D-pad would give them.
///
/// A push steps once. Held, it waits [firstDelay], then steps every
/// [interval] until the stick comes back to the centre or changes direction.
/// Without this, a stick held for a quarter of a second would skip through a
/// menu at the frame rate.
class StickRepeat {
  /// How far the stick has to be pushed, as a fraction of full tilt, to step.
  /// Well past the gameplay deadzone, so a thumb resting on the stick never
  /// wanders through a menu.
  static const double threshold = 0.5;
  static const double firstDelay = 0.4;
  static const double interval = 0.15;

  MenuAction? _held;
  double _untilRepeat = 0;

  /// Advances by [dt] with the stick at [stick] (screen axes, y down), and
  /// returns the step to take this frame, if any.
  MenuAction? update(double dt, Vector2 stick) {
    final direction = _directionOf(stick);
    if (direction != _held) {
      _held = direction;
      _untilRepeat = firstDelay;
      return direction;
    }
    if (direction == null) {
      return null;
    }
    _untilRepeat -= dt;
    if (_untilRepeat > 0) {
      return null;
    }
    _untilRepeat += interval;
    return direction;
  }

  static MenuAction? _directionOf(Vector2 stick) {
    if (stick.length < threshold) {
      return null;
    }
    if (stick.x.abs() > stick.y.abs()) {
      return stick.x > 0 ? MenuAction.right : MenuAction.left;
    }
    return stick.y > 0 ? MenuAction.down : MenuAction.up;
  }
}
