import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';
import 'package:pptx_monsters/game/combat/projectiles.dart';
import 'package:pptx_monsters/game/components/arena_floor.dart';
import 'package:pptx_monsters/game/components/player.dart';
import 'package:pptx_monsters/game/components/pptx_actor.dart';
import 'package:pptx_monsters/game/input/gamepad_input.dart';
import 'package:pptx_monsters/game/pptx_monsters_game.dart';
import 'package:pptx_monsters/game/save/save_data.dart';

import 'arena_harness.dart';

void main() {
  group('controller', () {
    test('pushing a stick up comes out as up the screen', () {
      final pad = GamepadInput()
        ..handle(stickEvent(GamepadAxis.leftStickY, 1))
        ..handle(stickEvent(GamepadAxis.rightStickY, 1));

      // Normalized sticks report up as +1; screen y grows downwards.
      expect(pad.move.y, closeTo(-1, 1e-9));
      expect(pad.aim.y, closeTo(-1, 1e-9));
    });

    test('ignores a resting stick that has drifted off centre', () {
      final pad = GamepadInput()
        ..handle(stickEvent(GamepadAxis.leftStickX, 0.12))
        ..handle(stickEvent(GamepadAxis.rightStickY, -0.15));

      expect(pad.move.isZero(), isTrue);
      expect(pad.aim.isZero(), isTrue);
    });

    test('aims at full strength the moment the stick leaves the deadzone', () {
      final pad = GamepadInput()
        ..handle(stickEvent(GamepadAxis.rightStickX, Settings.defaultDeadzone + 0.01));

      expect(pad.aim, closeToVector(Vector2(1, 0), 1e-9));
    });

    test('moves gradually from the edge of the deadzone up to full speed', () {
      final pad = GamepadInput()
        ..handle(stickEvent(GamepadAxis.leftStickX, Settings.defaultDeadzone + 0.08));
      expect(pad.move.x, closeTo(0.1, 1e-6));

      pad.handle(stickEvent(GamepadAxis.leftStickX, 1));
      expect(pad.move.x, closeTo(1, 1e-9));
    });

    testWithGame<PptxMonstersGame>(
      'right stick aims and fires in the arena',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);

        game.gamepad.handle(stickEvent(GamepadAxis.rightStickX, -1));
        game.update(1 / 60);
        await game.ready();

        final shot = arena.floor.children.whereType<BulletPoint>().single;
        expect(shot.velocity.x, lessThan(0));
        expect(shot.velocity.y, closeTo(0, 1e-6));
      },
    );
  });

  group('touch aim stick', () {
    testWithGame<FlameGame>(
      'fires as soon as it is pushed, with no fire button',
      FlameGame.new,
      (game) async {
        final aim = StubStick();
        final (player, floor) = await _playerOnFloor(game, aimStick: aim);

        aim.push = Vector2(0.5, 0);
        game.update(1 / 60);
        await game.ready();

        final shot = floor.children.whereType<BulletPoint>().single;
        expect(shot.velocity.x, greaterThan(0));
        expect(player.isAiming, isTrue);
      },
    );

    testWithGame<FlameGame>(
      'does not fire under a thumb that is merely resting on it',
      FlameGame.new,
      (game) async {
        final aim = StubStick();
        final (player, floor) = await _playerOnFloor(game, aimStick: aim);

        aim.push = Vector2(Player.aimThreshold * 0.5, 0);
        game.update(1 / 60);
        await game.ready();

        expect(player.isAiming, isFalse);
        expect(floor.children.whereType<BulletPoint>(), isEmpty);
      },
    );

    testWithGame<FlameGame>(
      'keeps firing on cooldown while held, and stops when let go',
      FlameGame.new,
      (game) async {
        final aim = StubStick();
        final (_, floor) = await _playerOnFloor(game, aimStick: aim);

        aim.push = Vector2(0, -1);
        advance(game, 1);
        await game.ready();
        final whileHeld = _shotsFired(floor);
        expect(whileHeld, greaterThan(1));

        aim.push = Vector2.zero();
        advance(game, 1);
        await game.ready();
        expect(_shotsFired(floor), whileHeld);
      },
    );
  });

  group('aiming', () {
    testWithGame<FlameGame>(
      'shoots one way while walking the other',
      FlameGame.new,
      (game) async {
        final move = StubStick();
        final aim = StubStick();
        final (player, floor) = await _playerOnFloor(
          game,
          moveStick: move,
          aimStick: aim,
        );
        final start = player.position.clone();

        move.push = Vector2(1, 0);
        aim.push = Vector2(-1, 0);
        game.update(0.1);
        await game.ready();

        expect(player.position.x, greaterThan(start.x), reason: 'walks east');
        final shot = floor.children.whereType<BulletPoint>().single;
        expect(shot.velocity.x, lessThan(0), reason: 'fires west');
      },
    );

    testWithGame<FlameGame>(
      'turns the player to face the aim rather than its feet',
      FlameGame.new,
      (game) async {
        final move = StubStick();
        final aim = StubStick();
        final (player, _) = await _playerOnFloor(
          game,
          moveStick: move,
          aimStick: aim,
        );
        final art = player.children.whereType<PptxActor>().single;

        move.push = Vector2(1, 0);
        aim.push = Vector2(-1, 0);
        game.update(1 / 60);

        expect(player.facing, Facing.west);
        expect(art.scale.x, -1);
      },
    );

    testWithGame<FlameGame>(
      'hands facing and aim back to the feet once the aim is released',
      FlameGame.new,
      (game) async {
        final move = StubStick();
        final aim = StubStick();
        final (player, _) = await _playerOnFloor(
          game,
          moveStick: move,
          aimStick: aim,
        );

        move.push = Vector2(0, 1);
        aim.push = Vector2(-1, 0);
        game.update(1 / 60);
        expect(player.facing, Facing.west);

        aim.push = Vector2.zero();
        game.update(1 / 60);

        expect(player.facing, Facing.south);
        expect(player.aimDirection, closeToVector(Vector2(0, 1), 1e-9));
      },
    );

    testWithGame<FlameGame>(
      'still fires along the walking direction with Space and no aim',
      FlameGame.new,
      (game) async {
        final (player, floor) = await _playerOnFloor(game);

        hold(player, {LogicalKeyboardKey.keyD, LogicalKeyboardKey.space});
        game.update(1 / 60);
        await game.ready();

        final shot = floor.children.whereType<BulletPoint>().single;
        expect(shot.velocity.x, greaterThan(0));
        expect(player.isAiming, isFalse);
      },
    );
  });

  group('shots', () {
    testWithGame<FlameGame>(
      'point the way they fly',
      FlameGame.new,
      (game) async {
        final aim = StubStick();
        final (_, floor) = await _playerOnFloor(game, aimStick: aim);

        aim.push = Vector2(-1, -1);
        game.update(1 / 60);
        await game.ready();

        final shot = floor.children.whereType<BulletPoint>().single;
        // Up and to the left: -135 degrees, with screen y growing downwards.
        expect(shot.angle, closeTo(-3 * math.pi / 4, 1e-6));
      },
    );
  });

  group('keyboard', () {
    testWithGame<FlameGame>(
      'arrow keys aim and fire without Space',
      FlameGame.new,
      (game) async {
        final (player, floor) = await _playerOnFloor(game);

        hold(player, {LogicalKeyboardKey.arrowLeft});
        game.update(1 / 60);
        await game.ready();

        final shot = floor.children.whereType<BulletPoint>().single;
        expect(shot.velocity.x, lessThan(0));
      },
    );

    testWithGame<FlameGame>(
      'arrow keys no longer move the player',
      FlameGame.new,
      (game) async {
        final (player, _) = await _playerOnFloor(game);
        final start = player.position.clone();

        hold(player, {LogicalKeyboardKey.arrowRight});
        game.update(0.5);

        expect(player.position, closeToVector(start, 1e-9));
      },
    );

    testWithGame<FlameGame>(
      'WASD moves while the arrows aim, independently',
      FlameGame.new,
      (game) async {
        final (player, floor) = await _playerOnFloor(game);
        final start = player.position.clone();

        hold(player, {LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowUp});
        game.update(0.1);
        await game.ready();

        expect(player.position.y, greaterThan(start.y), reason: 'walks down');
        final shot = floor.children.whereType<BulletPoint>().single;
        expect(shot.velocity.y, lessThan(0), reason: 'fires up');
      },
    );
  });
}

int _shotsFired(ArenaFloor floor) =>
    floor.children.whereType<BulletPoint>().length;

/// A lone player in the middle of a floor, with no boss and no arena page, so
/// a test can drive exactly one input at a time.
///
/// The floor is far larger than any real arena: at bullet speed nothing fired
/// in a test can reach its edge, so every shot stays on the board and "how
/// many were fired" is simply how many are there.
Future<(Player, ArenaFloor)> _playerOnFloor(
  FlameGame game, {
  StubStick? moveStick,
  StubStick? aimStick,
  GamepadInput? gamepad,
}) async {
  final floor = ArenaFloor(
    position: Vector2.zero(),
    size: Vector2(4000, 4000),
  );
  final player = Player(
    position: floor.size / 2,
    size: 100,
    moveStick: moveStick,
    aimStick: aimStick,
    gamepad: gamepad,
  );
  floor.add(player);
  await game.add(floor);
  await game.ready();
  return (player, floor);
}
