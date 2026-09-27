import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';
import 'package:death_by_slides/game/components/control_stick.dart';
import 'package:death_by_slides/game/components/player.dart';
import 'package:death_by_slides/game/pages/arena_page.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/routes.dart';

/// Opens a level's arena and returns its page, ready to be driven frame by
/// frame. Defaults to slide 1, the Shrink-to-Fit fight.
Future<ArenaPage> openArena(DeathBySlidesGame game, {int level = 1}) async {
  await game.ready();
  game.router.pushNamed(Routes.slideShowFor(level));
  await game.ready();
  return game.router.currentRoute.children.whereType<ArenaPage>().single;
}

/// Tells [player] which keys are currently down.
void hold(Player player, Set<LogicalKeyboardKey> keys) {
  player.onKeyEvent(
    const KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyW,
      logicalKey: LogicalKeyboardKey.keyW,
      timeStamp: Duration.zero,
    ),
    keys,
  );
}

/// Runs the game forward for [seconds] at a steady 60 fps.
///
/// Steps with `update`, which is what the real loop calls on the root game:
/// it delegates to `updateTree` for the lifecycle queue and children, and
/// then runs collision detection. Calling `updateTree` directly skips the
/// collision pass, so nothing would ever be hit.
///
/// Components spawned during a frame mount at the start of the next one, so
/// await `game.ready()` before inspecting `children`.
void advance(FlameGame game, double seconds) {
  final frames = (seconds * 60).round();
  for (var frame = 0; frame < frames; frame++) {
    game.update(1 / 60);
  }
}

/// A thumb stick whose push can be set directly, so the player's handling
/// of touch input can be tested without synthesising drag gestures.
class StubStick extends ControlStick {
  StubStick() : super(position: Vector2.zero());

  Vector2 push = Vector2.zero();

  @override
  Vector2 get relativeDelta => push;
}

/// A normalized controller event pressing, or releasing, [button].
NormalizedGamepadEvent buttonEvent(GamepadButton button, {bool down = true}) {
  final value = down ? 1.0 : 0.0;
  return NormalizedGamepadEvent(
    gamepadId: 'pad',
    timestamp: 0,
    value: value,
    button: button,
    rawEvent: GamepadEvent(
      gamepadId: 'pad',
      timestamp: 0,
      type: KeyType.button,
      key: button.name,
      value: value,
    ),
  );
}

/// A normalized controller event moving one stick axis to [value].
NormalizedGamepadEvent stickEvent(GamepadAxis axis, double value) {
  return NormalizedGamepadEvent(
    gamepadId: 'pad',
    timestamp: 0,
    value: value,
    axis: axis,
    rawEvent: GamepadEvent(
      gamepadId: 'pad',
      timestamp: 0,
      type: KeyType.analog,
      key: axis.name,
      value: value,
    ),
  );
}
