import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:death_by_slides/game/components/control_stick.dart';
import 'package:death_by_slides/game/components/player.dart';
import 'package:death_by_slides/game/components/shape_actor.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'arena_harness.dart';

void main() {
  group('player', () {
    testWithGame<DeathBySlidesGame>(
      'starts centred below the boss',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);

        expect(arena.player.position.x, closeTo(arena.floor.size.x / 2, 0.01));
        expect(arena.player.position.y, greaterThan(arena.boss.position.y));
        expect(arena.player.position.y, lessThan(arena.floor.size.y));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'walks in the direction the keys are held',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        final start = arena.player.position.clone();

        hold(arena.player, {LogicalKeyboardKey.keyD});
        game.update(0.5);

        expect(arena.player.position.x, closeTo(start.x + 160, 0.01));
        expect(arena.player.position.y, closeTo(start.y, 0.01));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'stops when the keys are released',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        hold(arena.player, {LogicalKeyboardKey.keyD});
        game.update(0.2);
        final moved = arena.player.position.clone();

        hold(arena.player, const {});
        game.update(0.2);

        expect(arena.player.position, closeToVector(moved, 0.01));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'does not travel faster diagonally',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        final start = arena.player.position.clone();

        hold(arena.player, {LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyD});
        game.update(0.5);

        final travelled = arena.player.position - start;
        expect(travelled.length, closeTo(160, 0.01));
        expect(travelled.x, greaterThan(0));
        expect(travelled.y, lessThan(0));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'cancels out opposite keys',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        final start = arena.player.position.clone();

        hold(arena.player, {LogicalKeyboardKey.keyA, LogicalKeyboardKey.keyD});
        game.update(0.5);

        expect(arena.player.position, closeToVector(start, 0.01));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'cannot walk out of the arena',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        // Take the boss off the board: a hit would shrink the player and move
        // the wall it can reach, which is tested separately in combat_test.
        arena.boss.removeFromParent();
        await game.ready();
        final half = arena.player.scaledSize / 2;

        hold(arena.player, {LogicalKeyboardKey.keyD, LogicalKeyboardKey.keyS});
        advance(game, 5);

        expect(
          arena.player.position.x,
          closeTo(arena.floor.size.x - half.x, 0.01),
        );
        expect(
          arena.player.position.y,
          closeTo(arena.floor.size.y - half.y, 0.01),
        );

        hold(arena.player, {LogicalKeyboardKey.keyA, LogicalKeyboardKey.keyW});
        advance(game, 5);

        expect(arena.player.position.x, closeTo(half.x, 0.01));
        expect(arena.player.position.y, closeTo(half.y, 0.01));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'faces the way it is walking and mirrors the art going west',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        final art = arena.player.children.whereType<ShapeActor>().single;

        hold(arena.player, {LogicalKeyboardKey.keyD});
        game.update(1 / 60);
        expect(arena.player.facing, Facing.east);
        expect(art.scale.x, 1);

        hold(arena.player, {LogicalKeyboardKey.keyA});
        game.update(1 / 60);
        expect(arena.player.facing, Facing.west);
        expect(art.scale.x, -1);

        hold(arena.player, {LogicalKeyboardKey.keyW});
        game.update(1 / 60);
        expect(arena.player.facing, Facing.north);
        expect(art.scale.x, 1);
      },
    );
  });

  group('move stick', () {
    test('adds its push to the keyboard and stays capped at full tilt', () {
      final stick = StubStick();
      final player = Player(
        position: Vector2.zero(),
        size: 100,
        moveStick: stick,
      );

      // Half tilt east.
      stick.push = Vector2(0.5, 0);
      player.update(1);
      expect(player.direction.length, closeTo(0.5, 1e-9));

      // Full tilt east plus the D key must not stack into double speed.
      stick.push = Vector2(1, 0);
      hold(player, {LogicalKeyboardKey.keyD});
      player.update(1);
      expect(player.direction.length, closeTo(1, 1e-9));
    });

    testWithGame<DeathBySlidesGame>(
      'sits on the arena page beside the aim stick, both wired to the player',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);

        expect(arena.children.whereType<ControlStick>().length, 2);
        expect(arena.player.moveStick, same(arena.moveStick));
        expect(arena.player.aimStick, same(arena.aimStick));
        expect(arena.player.gamepad, same(game.gamepad));
      },
    );
  });
}
