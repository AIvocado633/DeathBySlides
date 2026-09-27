import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:gamepads/gamepads.dart';

import '../save/save_data.dart';

/// The latest stick positions and buttons from a connected controller, in
/// screen terms.
///
/// Fed from `Gamepads.normalizedEvents`, which already maps every platform's
/// raw key names onto a standard Xbox-style layout, so the left stick is the
/// left stick whether the pad is on Windows, Android or iOS. This class only
/// has to do two things on top of that:
///
///  * **Flip the vertical axis.** Normalized sticks report up as +1, but screen
///    y grows downwards, so pushing up must come out as negative y.
///  * **Ignore stick drift.** A resting analogue stick rarely reads exactly
///    zero, and a twin-stick shooter fires the moment the aim stick leaves the
///    centre, so anything inside [deadzone] is treated as centred.
///
/// It holds no stream subscription of its own; the game owns that, which keeps
/// this class free of platform channels and trivially testable.
class GamepadInput {
  /// How far a stick has to travel, as a fraction of full tilt, before it
  /// counts as pushed. Set from Design Ideas.
  double deadzone = Settings.defaultDeadzone;

  final Vector2 _left = Vector2.zero();
  final Vector2 _right = Vector2.zero();

  /// The movement stick, deadzoned and rescaled, at most unit length.
  Vector2 get move => _deadzoned(_left);

  /// The aiming stick: zero while centred, and a full-length direction the
  /// moment it leaves the deadzone.
  ///
  /// Unlike [move] this is deliberately not rescaled. Only the direction of a
  /// shot matters, and a twin-stick shooter should fire as soon as the stick
  /// picks a direction -- not wait until it has been pushed past some further
  /// threshold on top of the deadzone.
  Vector2 get aim =>
      _right.length < deadzone ? Vector2.zero() : _right.normalized();

  /// The left stick as it is, with no deadzone: what menus read to step
  /// through focus, with their own, larger threshold.
  Vector2 get leftStick => _left.clone();

  final Set<GamepadButton> _held = {};
  final List<GamepadButton> _presses = [];

  /// Whether [button] is down right now.
  bool isHeld(GamepadButton button) => _held.contains(button);

  /// The buttons pressed since the last call, oldest first. A button held
  /// down counts once, however long it is held.
  List<GamepadButton> takePresses() {
    final presses = List.of(_presses);
    _presses.clear();
    return presses;
  }

  /// Folds one normalized event into the current stick and button state.
  /// Triggers are ignored for now.
  void handle(NormalizedGamepadEvent event) {
    final button = event.button;
    if (button != null) {
      // Analogue buttons report how far they are pressed; past halfway is down.
      if (event.value > 0.5) {
        if (_held.add(button)) {
          _presses.add(button);
        }
      } else {
        _held.remove(button);
      }
      return;
    }
    switch (event.axis) {
      case GamepadAxis.leftStickX:
        _left.x = event.value;
      case GamepadAxis.leftStickY:
        _left.y = -event.value;
      case GamepadAxis.rightStickX:
        _right.x = event.value;
      case GamepadAxis.rightStickY:
        _right.y = -event.value;
      case GamepadAxis.leftTrigger:
      case GamepadAxis.rightTrigger:
      case null:
        break;
    }
  }

  /// Returns [raw] with the deadzone cut out and the remaining travel stretched
  /// back over 0..1, so a push starts slow just outside the deadzone instead
  /// of jumping straight to a fifth of full speed.
  Vector2 _deadzoned(Vector2 raw) {
    final length = raw.length;
    if (length < deadzone) {
      return Vector2.zero();
    }
    final stretched = math.min((length - deadzone) / (1 - deadzone), 1.0);
    return raw.normalized()..scale(stretched);
  }
}
