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
      final queue = _queue(BuildQueue.opening())..update(0.1, clicked: true);
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
        expect(boss.tags.map((tag) => tag.number).toSet(), {
          for (var i = 1; i <= 17; i++) i,
        });
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

  group('every attack can be dodged', () {
    final arena = Vector2(900, 420);
    // A full-size player, which is the hardest to fit through anything.
    const player = ArenaPage.playerSize;
    final shot = BuildShot(
      position: Vector2.zero(),
      velocity: Vector2(1, 0),
      kind: EffectKind.entrance,
    ).size.x;

    test('the lane every attack leaves fits a full-size player and a shot', () {
      expect(BuildAttack.lane, greaterThanOrEqualTo(player + shot));
    });

    /// Plays [effect] to the end on a stage of [arena]'s size with the player
    /// at [at], and returns every shot it threw, with when it was thrown.
    List<({double at, Vector2 from, Vector2 velocity})> play(
      BuildEffect effect, {
      required int seed,
      Vector2? at,
    }) {
      final stage = _RecordingStage(arena, at ?? Vector2(450, 330));
      final attack = BuildAttack.of(
        effect,
        stage: stage,
        random: math.Random(seed),
      );
      for (var t = 0.0; t < effect.duration + 0.1; t += 1 / 60) {
        stage.now = t;
        attack.update(1 / 60);
      }
      return stage.shots;
    }

    /// The widest clear stretch a wall of shots at [positions] leaves along
    /// an edge [extent] long, and where its middle is.
    ({double width, double middle}) widestLane(
      Iterable<double> positions,
      double extent,
    ) {
      final edges = [
        -shot / 2,
        ...positions.toList()..sort(),
        extent + shot / 2,
      ];
      var best = (width: 0.0, middle: 0.0);
      for (var i = 1; i < edges.length; i++) {
        final width = edges[i] - edges[i - 1] - shot;
        if (width > best.width) {
          best = (width: width, middle: (edges[i] + edges[i - 1]) / 2);
        }
      }
      return best;
    }

    test('Wipe always leaves a lane a full-size player fits through', () {
      for (var seed = 0; seed < 60; seed++) {
        final shots = play(BuildEffect.wipe, seed: seed);
        final lane = widestLane(shots.map((s) => s.from.y), arena.y);
        expect(lane.width, greaterThan(player + 20), reason: 'seed $seed');
      }
    });

    test('Fly In leaves a lane in both walls, the second within reach', () {
      // How far a full-size player walks between the two walls.
      const reach = 320 * 0.6;
      for (var seed = 0; seed < 60; seed++) {
        final shots = play(BuildEffect.flyIn, seed: seed);
        final fromTop = shots.first.velocity.y > 0;
        final extent = fromTop ? arena.x : arena.y;
        double along(Vector2 from) => fromTop ? from.x : from.y;
        final first = shots.where((s) => s.at < 0.3).map((s) => along(s.from));
        final second = shots
            .where((s) => s.at >= 0.3)
            .map((s) => along(s.from));
        final a = widestLane(first, extent);
        final b = widestLane(second, extent);
        expect(a.width, greaterThan(player + 20), reason: 'seed $seed, wall 1');
        expect(b.width, greaterThan(player + 20), reason: 'seed $seed, wall 2');
        expect(
          (a.middle - b.middle).abs(),
          lessThanOrEqualTo(reach),
          reason: 'seed $seed: the second lane is out of reach',
        );
      }
    });

    test('Pulse opens its gap towards the player, wherever they stand', () {
      for (final at in [
        Vector2(450, 330),
        Vector2(100, 40),
        Vector2(800, 400),
      ]) {
        for (var seed = 0; seed < 30; seed++) {
          final shots = play(BuildEffect.pulse, seed: seed, at: at);
          final centre = shots.first.from;
          expect((at - centre).length, closeTo(170, 1e-6));
          final facing = math.atan2(at.y - centre.y, at.x - centre.x);
          for (final s in shots) {
            final off = math.atan2(s.velocity.y, s.velocity.x) - facing;
            final angle = math.atan2(math.sin(off), math.cos(off)).abs();
            if (angle >= math.pi / 2) {
              continue;
            }
            // How far the shot passes from the player's centre.
            final miss = 170 * math.sin(angle) - shot / 2;
            expect(
              miss,
              greaterThan(player / 2),
              reason: 'player at $at, seed $seed',
            );
          }
        }
      }
    });
  });
}

/// A stage that only records what an attack throws.
class _RecordingStage implements BuildStage {
  _RecordingStage(this.arena, this.player);

  @override
  final Vector2 arena;
  final Vector2 player;

  double now = 0;
  final shots = <({double at, Vector2 from, Vector2 velocity})>[];

  @override
  Vector2 aimAt() => player.clone();

  @override
  void throwShot(
    Vector2 from,
    Vector2 velocity,
    EffectKind kind, {
    ShotRules rules = ShotRules.standard,
  }) => shots.add((at: now, from: from.clone(), velocity: velocity.clone()));
}
