import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pptx_monsters/game/combat/autofit_boss.dart';
import 'package:pptx_monsters/game/combat/impact.dart';
import 'package:pptx_monsters/game/combat/projectiles.dart';
import 'package:pptx_monsters/game/combat/smartart_boss.dart';
import 'package:pptx_monsters/game/components/player.dart';
import 'package:pptx_monsters/game/components/result_panel.dart';
import 'package:pptx_monsters/game/pages/arena_page.dart';
import 'package:pptx_monsters/game/pptx_monsters_game.dart';
import 'package:pptx_monsters/game/slide/motion.dart';

import 'arena_harness.dart';

void main() {
  tearDown(() => Motion.reduced = false);

  group('invulnerability', () {
    testWithGame<PptxMonstersGame>(
      'two shots arriving together cost one size, not two',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);
        final full = arena.player.health.current;

        _shootAtPlayer(arena);
        // A frame to mount the shot, and a frame for it to be felt.
        advance(game, 3 / 60);
        await game.ready();
        expect(arena.player.health.current, full - 1);
        expect(arena.player.isInvulnerable, isTrue);

        // A second shot, well inside the window.
        _shootAtPlayer(arena);
        advance(game, 3 / 60);
        await game.ready();
        expect(
          arena.player.health.current,
          full - 1,
          reason: 'shrugged off while flashing',
        );

        // And one after it, which lands.
        advance(game, Player.invulnerableFor);
        expect(arena.player.isInvulnerable, isFalse);
        _shootAtPlayer(arena);
        advance(game, 3 / 60);
        await game.ready();
        expect(arena.player.health.current, full - 2);
      },
    );

    testWithGame<PptxMonstersGame>(
      'blinks while it lasts, no faster than three times a second',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);
        _shootAtPlayer(arena);
        advance(game, 3 / 60);
        await game.ready();
        expect(arena.player.isInvulnerable, isTrue);

        expect(
          1 / Player.blinkPeriod,
          lessThanOrEqualTo(3),
          reason: 'one blink is on and off: the photosensitivity guideline',
        );
        expect(
          Player.invulnerableFor,
          greaterThanOrEqualTo(0.6),
          reason: 'long enough to get out of a stream of shots',
        );
      },
    );

    testWithGame<PptxMonstersGame>(
      'a direct hit still lands, so fights can be driven from tests',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);

        arena.player.takeHit();
        arena.player.takeHit();

        expect(arena.player.health.current, arena.player.health.max - 2);
      },
    );

    testWithGame<PptxMonstersGame>(
      'bosses get no such mercy: every bullet point counts',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);
        final before = arena.boss.remainingHits;

        for (var i = 0; i < 2; i++) {
          arena.floor.add(
            BulletPoint(
              position:
                  arena.boss.position + Vector2(0, arena.boss.scaledSize.y / 2),
              velocity: Vector2.zero(),
            ),
          );
        }
        advance(game, 3 / 60);
        await game.ready();

        expect(arena.boss.remainingHits, before - 2);
      },
    );
  });

  group('damage numbers', () {
    testWithGame<PptxMonstersGame>(
      'report the cost in AutoFit\'s own units',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);
        final boss = arena.boss as AutoFitBoss;
        final before = boss.pointSize;

        boss.takeHit();
        await game.ready();

        final step = before - boss.pointSize;
        expect(_numbers(arena), ['−$step pt']);
      },
    );

    testWithGame<PptxMonstersGame>(
      'report a broken SmartArt shape as a shape',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game, level: 2);
        final boss = arena.boss as SmartArtBoss;

        boss.takeHit(SmartArtBoss.hitsPerShape);
        await game.ready();

        expect(_numbers(arena), contains('−1 shape'));
      },
    );

    testWithGame<PptxMonstersGame>(
      'report what the player lost, as the readout counts it',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);

        arena.player.takeHit();
        await game.ready();

        expect(_numbers(arena), ['−13%']);
      },
    );
  });

  group('reduce motion', () {
    testWithGame<PptxMonstersGame>(
      'turns off every flash and shake from one switch',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);
        Motion.reduced = true;

        arena.player.takeHit();
        (arena.boss as AutoFitBoss).takeHit();
        await game.ready();

        expect(
          arena.floor.children.whereType<MoveEffect>(),
          isEmpty,
          reason: 'no screen shake',
        );
        expect(
          arena.floor.descendants().whereType<TimerComponent>(),
          isEmpty,
          reason: 'no tint waiting to be taken off again',
        );
        expect(
          _numbers(arena),
          hasLength(2),
          reason: 'the numbers are information, and stay',
        );
      },
    );
  });

  group('balance', () {
    test('every boss fires slower than the player shrugs off a hit', () {
      // The mercy window only ever swallows shots that arrive together, so
      // the fights are as hard as they were. A boss firing faster than this
      // would be quietly halved by it.
      for (final interval in [
        AutoFitBoss.fireInterval,
        SmartArtBoss.fireInterval,
      ]) {
        expect(interval, greaterThan(Player.invulnerableFor));
      }
    });
  });

  group('the player leaving the slide', () {
    testWithGame<PptxMonstersGame>(
      'plays an exit animation before the slide is lost',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);

        arena.player.takeHit(arena.player.health.max);
        advance(game, Player.exitDuration * 0.8);
        await game.ready();

        expect(arena.isResolved, isFalse);
        expect(arena.player.isMounted, isTrue);
        expect(
          arena.player.scale.x,
          lessThan(arena.player.health.scale),
          reason: 'shrinking away, on top of the size it had left',
        );
        expect(arena.player.angle, isNot(0), reason: 'and turning');

        advance(game, Player.exitDuration);
        await game.ready();
        expect(arena.isResolved, isTrue);
      },
    );

    testWithGame<PptxMonstersGame>(
      'does not let the boss steal the win on the way out',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);

        arena.player.takeHit(arena.player.health.max);
        arena.boss.takeHit(arena.boss.totalHits);
        advance(game, Player.exitDuration + 0.6);
        await game.ready();

        final panel = arena.children.whereType<ResultPanel>().single;
        expect(panel.won, isFalse);
      },
    );
  });
}

/// Drops a resize handle on the player's edge, where it cannot miss.
///
/// On the edge rather than the middle: a small hitbox sitting entirely inside
/// a big one never crosses it, and a collision is a crossing.
void _shootAtPlayer(ArenaPage arena) {
  arena.floor.add(
    ResizeHandle(
      position:
          arena.player.position + Vector2(arena.player.scaledSize.x / 2, 0),
      velocity: Vector2.zero(),
    ),
  );
}

List<String> _numbers(ArenaPage arena) => arena.floor
    .descendants()
    .whereType<DamageNumber>()
    .map((number) => number.text)
    .toList();
