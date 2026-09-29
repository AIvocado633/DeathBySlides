import 'dart:math' as math;

import 'package:death_by_slides/game/combat/boss.dart';
import 'package:death_by_slides/game/combat/build_order_boss.dart';
import 'package:death_by_slides/game/combat/projectiles.dart';
import 'package:death_by_slides/game/components/result_panel.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/pages/arena_page.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arena_harness.dart';

const int _buildOrderLevel = 4;

BuildStep _step(int id, BuildEffect effect, Trigger trigger) =>
    BuildStep(id, effect, trigger);

/// A queue that starts at once, so tests count from zero.
BuildQueue _queue(List<BuildStep> steps) =>
    BuildQueue(steps, gap: 0.5, startDelay: 0);

List<int> _ids(List<BuildStep> steps) => [for (final s in steps) s.id];

Future<(ArenaPage, BuildOrderBoss)> _open(DeathBySlidesGame game) async {
  final arena = await openArena(game, level: _buildOrderLevel);
  return (arena, arena.boss as BuildOrderBoss);
}

int _shotsOnBoard(ArenaPage arena) =>
    arena.floor.children.whereType<BuildShot>().length;

void main() {
  group('the queue', () {
    test('After Last waits for everything before it, and a gap', () {
      final queue = _queue([
        _step(1, BuildEffect.pulse, Trigger.afterLast),
        _step(2, BuildEffect.spin, Trigger.afterLast),
      ]);

      expect(_ids(queue.update(0.5)), [1], reason: 'after the opening gap');
      final pulse = BuildEffect.pulse.duration;
      expect(queue.update(pulse - 0.1), isEmpty, reason: 'still playing');
      expect(queue.update(0.2), isEmpty, reason: 'finished, but no gap yet');
      expect(_ids(queue.update(0.5)), [2]);
    });

    test('With Last starts alongside the step before it', () {
      final queue = _queue([
        _step(1, BuildEffect.pulse, Trigger.afterLast),
        _step(2, BuildEffect.spin, Trigger.withLast),
        _step(3, BuildEffect.wipe, Trigger.withLast),
        _step(4, BuildEffect.bounce, Trigger.afterLast),
      ]);

      expect(_ids(queue.update(0.5)), [1, 2, 3]);
      expect(queue.running, hasLength(3));
    });

    test('On Click starts on a click, and only then', () {
      final queue = _queue([
        _step(1, BuildEffect.flyIn, Trigger.onClick),
        _step(2, BuildEffect.spin, Trigger.withLast),
        _step(3, BuildEffect.pulse, Trigger.onClick),
      ]);

      expect(queue.update(10), isEmpty, reason: 'nobody clicked');
      expect(_ids(queue.update(0.1, clicked: true)), [1, 2]);
      expect(queue.update(0.1), isEmpty);
      // One click starts one On Click step, even with another waiting.
      expect(_ids(queue.update(0.1, clicked: true)), [3]);
    });

    test('a click does nothing while an After Last step is next', () {
      final queue = _queue([
        _step(1, BuildEffect.pulse, Trigger.onClick),
        _step(2, BuildEffect.spin, Trigger.afterLast),
      ])..update(0.1, clicked: true);
      expect(queue.next?.trigger, Trigger.afterLast);

      expect(queue.update(0.1, clicked: true), isEmpty);
    });

    test('plays from the top again once it has run out', () {
      final queue = _queue([
        _step(1, BuildEffect.pulse, Trigger.onClick),
        _step(2, BuildEffect.spin, Trigger.onClick),
      ]);
      expect(_ids(queue.update(0.1, clicked: true)), [1]);
      expect(_ids(queue.update(0.1, clicked: true)), [2]);
      expect(_ids(queue.update(0.1, clicked: true)), [1]);
    });

    test('deleting a step takes it out, and the next one still comes next', () {
      final queue = _queue([
        _step(1, BuildEffect.pulse, Trigger.onClick),
        _step(2, BuildEffect.spin, Trigger.onClick),
        _step(3, BuildEffect.wipe, Trigger.onClick),
      ])..update(0.1, clicked: true);
      expect(queue.next?.id, 2);

      queue.remove(1);
      expect(_ids(queue.steps), [2, 3]);
      expect(queue.next?.id, 2);

      queue.remove(2);
      expect(queue.next?.id, 3);
      queue.remove(3);
      expect(queue.isEmpty, isTrue);
      expect(queue.update(1, clicked: true), isEmpty);
    });

    test('reordering shuffles the steps and reads from the top', () {
      final queue = _queue(BuildQueue.opening())
        ..update(0.1, clicked: true);
      final before = _ids(queue.steps);

      queue.reorder(math.Random(1));
      expect(_ids(queue.steps), isNot(before));
      expect(_ids(queue.steps)..sort(), [...before]..sort());
      expect(queue.cursor, 0);
    });

    test('opens with seventeen steps', () {
      expect(BuildQueue.opening(), hasLength(17));
    });
  });

  group('Build Order boss', () {
    testWithGame<DeathBySlidesGame>(
      'opens with seventeen animations, each with a tag',
      () => DeathBySlidesGame(unlockAll: true),
      (game) async {
        final (arena, boss) = await _open(game);

        expect(boss.readout, '17 animations');
        expect(boss.tags, hasLength(17));
        expect(
          boss.tags.map((tag) => tag.number).toSet(),
          {for (var i = 1; i <= 17; i++) i},
        );
        expect(arena.player.exit, PlayerExit.flyOut);
      },
    );

    testWithGame<DeathBySlidesGame>(
      "a bullet point is a click: On Click waits for the player's shot",
      () => DeathBySlidesGame(unlockAll: true),
      (game) async {
        final (arena, boss) = await _open(game);
        expect(boss.queue.next!.trigger, Trigger.onClick);

        advance(game, 3);
        await game.ready();
        expect(_shotsOnBoard(arena), 0, reason: 'nobody clicked');

        arena.player.fire();
        advance(game, 0.1);
        await game.ready();
        expect(_shotsOnBoard(arena), greaterThan(0));
        expect(boss.queue.cursor, greaterThan(0));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'shooting a tag down deletes its step',
      () => DeathBySlidesGame(unlockAll: true),
      (game) async {
        final (_, boss) = await _open(game);
        final tag = boss.tags.first;

        for (var i = 0; i < BuildOrderBoss.hitsPerTag; i++) {
          tag.onCollisionStart(
            {},
            BulletPoint(position: Vector2.zero(), velocity: Vector2(0, -1)),
          );
        }

        expect(boss.readout, '16 animations');
        expect(boss.queue.steps.map((s) => s.id), isNot(contains(tag.step.id)));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'reorders itself every few deletions, and renumbers the tags',
      () => DeathBySlidesGame(unlockAll: true),
      (game) async {
        final (_, boss) = await _open(game);

        for (final id in [3, 7]) {
          boss.deleteStep(id);
        }
        expect(boss.reorders, 0);
        boss.deleteStep(11);
        expect(boss.reorders, 1);

        final position = {
          for (final (i, step) in boss.queue.steps.indexed) step.id: i + 1,
        };
        for (final tag in boss.tags) {
          expect(tag.number, position[tag.step.id]);
        }
      },
    );

    testWithGame<DeathBySlidesGame>(
      'an empty Build Order wins the slide',
      () => DeathBySlidesGame(unlockAll: true),
      (game) async {
        final (arena, boss) = await _open(game);

        boss.takeHit(boss.totalHits);
        expect(boss.readout, '0 animations');
        expect(boss.isDefeated, isTrue);

        advance(game, 0.6);
        await game.ready();
        expect(arena.isResolved, isTrue);
        expect(arena.children.whereType<ResultPanel>().single.won, isTrue);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'losing flies the player up and off the slide',
      () => DeathBySlidesGame(unlockAll: true),
      (game) async {
        final (arena, _) = await _open(game);
        final start = arena.player.position.y;

        arena.player.takeHit(arena.player.health.current);
        advance(game, 0.3);
        await game.ready();
        expect(arena.player.position.y, lessThan(start));

        advance(game, 1);
        await game.ready();
        expect(arena.isResolved, isTrue);
        expect(arena.children.whereType<ResultPanel>().single.won, isFalse);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'tags stay in the upper part of the arena as they drift',
      () => DeathBySlidesGame(unlockAll: true),
      (game) async {
        final (_, boss) = await _open(game);
        for (var i = 0; i < 30; i++) {
          advance(game, 0.2);
        }
        for (final tag in boss.tags) {
          expect(
            boss.tagArea.inflate(1).contains(tag.position.toOffset()),
            isTrue,
          );
        }
      },
    );
  });
}
