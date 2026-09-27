import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:death_by_slides/game/components/player.dart';
import 'package:death_by_slides/game/combat/shrink_to_fit_boss.dart';
import 'package:death_by_slides/game/combat/health.dart';
import 'package:death_by_slides/game/combat/projectiles.dart';
import 'package:death_by_slides/game/components/result_panel.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';

import 'arena_harness.dart';

void main() {
  group('health', () {
    test('shrinks its owner as it drains, but never to nothing', () {
      final health = Health(max: 4, minScale: 0.4);

      expect(health.scale, 1);
      health.damage();
      expect(health.scale, closeTo(0.85, 1e-9));
      health.damage(3);
      expect(health.isDead, isTrue);
      expect(health.scale, 0.4);
    });

    test('cannot be damaged past death', () {
      final health = Health(max: 2);

      expect(health.damage(5), 2);
      expect(health.current, 0);
      expect(health.damage(), 0);
    });
  });

  group('Shrink-to-Fit boss', () {
    testWithGame<DeathBySlidesGame>(
      'counts down the point-size ladder, one step per hit',
      DeathBySlidesGame.new,
      (game) async {
        final boss = (await openArena(game)).boss as ShrinkToFitBoss;
        expect(boss.pointSize, ShrinkToFitBoss.pointLadder.first);

        boss.takeHit();
        expect(boss.pointSize, ShrinkToFitBoss.pointLadder[1]);

        boss.takeHit(ShrinkToFitBoss.pointLadder.length - 2);
        expect(boss.pointSize, ShrinkToFitBoss.pointLadder.last);

        boss.takeHit();
        expect(boss.pointSize, 0);
        expect(boss.isDefeated, isTrue);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'gets visibly smaller as it is worn down',
      DeathBySlidesGame.new,
      (game) async {
        final boss = (await openArena(game)).boss as ShrinkToFitBoss;
        final full = boss.scale.x;

        boss.takeHit(4);

        expect(boss.scale.x, lessThan(full));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'throws resize handles at the player',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        expect(arena.floor.children.whereType<ResizeHandle>(), isEmpty);

        advance(game, 1.6);
        await game.ready();

        final handles = arena.floor.children.whereType<ResizeHandle>();
        expect(handles, isNotEmpty);
        // Thrown downwards, because the player stands below the boss.
        expect(handles.first.velocity.y, greaterThan(0));
      },
    );
  });

  group('shooting', () {
    testWithGame<DeathBySlidesGame>(
      'sends a bullet point up the slide by default',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        arena.player.fire();
        await game.ready();

        final shot = arena.floor.children.whereType<BulletPoint>().single;
        expect(shot.velocity.y, lessThan(0));
        expect(shot.velocity.x, closeTo(0, 1e-9));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a bullet point that reaches the boss damages it and is spent',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        final before = arena.boss.remainingHits;

        arena.player.fire();
        advance(game, 0.8);
        await game.ready();

        expect(arena.boss.remainingHits, lessThan(before));
        expect(arena.floor.children.whereType<BulletPoint>(), isEmpty);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a bullet point that hits nothing leaves the board',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        // Aim along the floor, away from the boss.
        arena.floor.add(
          BulletPoint(
            position: Vector2(40, arena.floor.size.y - 40),
            velocity: Vector2(-BulletPoint.speed, 0),
          ),
        );
        await game.ready();
        expect(arena.floor.children.whereType<BulletPoint>(), isNotEmpty);

        advance(game, 0.5);
        await game.ready();

        expect(arena.floor.children.whereType<BulletPoint>(), isEmpty);
      },
    );
  });

  group('being shrunk', () {
    testWithGame<DeathBySlidesGame>(
      'lets the player squeeze closer to the wall and move quicker',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        arena.boss.removeFromParent();
        await game.ready();

        hold(arena.player, {LogicalKeyboardKey.keyD});
        advance(game, 5);
        final wallAtFullSize = arena.player.position.x;

        arena.player.takeHit(4);
        advance(game, 5);

        expect(arena.player.position.x, greaterThan(wallAtFullSize));
        expect(
          arena.player.position.x,
          closeTo(arena.floor.size.x - arena.player.scaledSize.x / 2, 0.01),
        );
      },
    );

    testWithGame<DeathBySlidesGame>(
      'trades presence for pace',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        arena.boss.removeFromParent();
        await game.ready();

        arena.player.position.setValues(100, arena.floor.size.y / 2);
        hold(arena.player, {LogicalKeyboardKey.keyD});
        game.update(0.2);
        final atFullSize = arena.player.position.x - 100;

        arena.player.takeHit(4);
        arena.player.position.setValues(100, arena.floor.size.y / 2);
        game.update(0.2);
        final whenShrunk = arena.player.position.x - 100;

        expect(whenShrunk, greaterThan(atFullSize));
      },
    );
  });

  group('resolving the slide', () {
    testWithGame<DeathBySlidesGame>(
      'beating the boss wins the slide and freezes the board',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);

        arena.boss.takeHit(ShrinkToFitBoss.pointLadder.length);
        // The boss shrinks away before the dialog appears.
        advance(game, 0.6);
        await game.ready();

        expect(arena.isResolved, isTrue);
        expect(arena.floor.timeScale, 0);
        final panel = arena.children.whereType<ResultPanel>().single;
        expect(panel.won, isTrue);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'being shrunk away loses the slide, once the exit animation ends',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);

        arena.player.takeHit(arena.player.health.max);
        await game.ready();
        expect(
          arena.isResolved,
          isFalse,
          reason: 'the player leaves the slide first',
        );

        advance(game, Player.exitDuration + 0.1);
        await game.ready();

        expect(arena.isResolved, isTrue);
        final panel = arena.children.whereType<ResultPanel>().single;
        expect(panel.won, isFalse);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'takes the controls away and only ever shows one dialog',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);

        arena.player.takeHit(arena.player.health.max);
        arena.boss.takeHit(ShrinkToFitBoss.pointLadder.length);
        advance(game, 0.6);
        await game.ready();

        expect(arena.children.whereType<ResultPanel>().length, 1);
        expect(arena.moveStick.isMounted, isFalse);
        expect(arena.aimStick.isMounted, isFalse);
      },
    );

    testWithGame<DeathBySlidesGame>(
      're-entering the level starts a fresh fight',
      DeathBySlidesGame.new,
      (game) async {
        final first = await openArena(game);
        first.boss.takeHit(3);
        expect(first.boss.remainingHits, lessThan(ShrinkToFitBoss.pointLadder.length));

        game.router.pop();
        await game.ready();
        final second = await openArena(game);

        expect(second, isNot(same(first)));
        expect(second.boss.remainingHits, ShrinkToFitBoss.pointLadder.length);
        expect(second.player.health.current, second.player.health.max);
      },
    );
  });
}
