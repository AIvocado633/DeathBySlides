import 'dart:ui' as ui;

import 'package:death_by_slides/game/art/actor_art.dart';
import 'package:death_by_slides/game/art/shape_art.dart';
import 'package:death_by_slides/game/components/shape_actor.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arena_harness.dart';

/// Which prefix, and mirrored or not, [state] facing [facing] resolves to.
(String, bool)? _pick(Set<String> available, ActorState state, Facing facing) {
  final found = ActorFrames.resolve('hero', available, state, facing);
  return found == null ? null : (found.prefix, found.mirrored);
}

/// Makes the bundle hold [frames] (`prefix` -> frame count) for real, with
/// one-pixel images, so an actor loads them as it would exported art.
Future<void> _fakeFrames(Map<String, int> frames) async {
  final assets = <String>{};
  for (final MapEntry(key: prefix, value: count) in frames.entries) {
    for (var i = 0; i < count; i++) {
      final file = '$prefix${i.toString().padLeft(3, '0')}.png';
      assets.add('assets/images/$file');
      // One image each: the cache disposes every entry it holds.
      Flame.images.add(file, await _pixel());
    }
  }
  ShapeArt.debugUseManifest(assets);
}

Future<ui.Image> _pixel() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), ui.Paint());
  return recorder.endRecording().toImage(1, 1);
}

Future<ShapeActor> _actorIn(FlameGame game) async {
  final actor = ShapeActor(actor: 'hero', size: Vector2.all(100));
  await game.ensureAdd(actor);
  return actor;
}

SpriteAnimation? _animationOf(ShapeActor actor) =>
    actor.children.whereType<SpriteAnimationComponent>().single.animation;

void main() {
  tearDown(() {
    ShapeArt.resetManifestCache();
    Flame.images.clearCache();
  });

  group('which frames an actor shows', () {
    test('only idle frames: idle for everything, as before states', () {
      const idle = {'hero_idle_'};
      for (final state in ActorState.values) {
        for (final facing in Facing.values) {
          expect(
            _pick(idle, state, facing),
            ('hero_idle_', facing.isWestward),
            reason: '$state facing $facing',
          );
        }
      }
    });

    test('falls back: state and direction, state, idle and direction, idle', () {
      final available = {
        'hero_walk_e_',
        'hero_walk_',
        'hero_idle_e_',
        'hero_idle_',
      };
      final order = [...available];
      for (final expected in order) {
        expect(
          _pick(available, ActorState.walk, Facing.east)?.$1,
          expected,
        );
        available.remove(expected);
      }
      expect(_pick(available, ActorState.walk, Facing.east), isNull);
    });

    test('art drawn for another direction does not count', () {
      final available = {'hero_walk_e_', 'hero_idle_'};
      expect(_pick(available, ActorState.walk, Facing.south)?.$1, 'hero_idle_');
      expect(_pick(available, ActorState.walk, Facing.north)?.$1, 'hero_idle_');
    });

    test('west-facing directions mirror the eastern art', () {
      final available = {
        'hero_idle_',
        'hero_walk_s_',
        'hero_walk_se_',
        'hero_walk_e_',
        'hero_walk_ne_',
        'hero_walk_n_',
      };
      final expected = {
        Facing.south: ('hero_walk_s_', false),
        Facing.southEast: ('hero_walk_se_', false),
        Facing.east: ('hero_walk_e_', false),
        Facing.northEast: ('hero_walk_ne_', false),
        Facing.north: ('hero_walk_n_', false),
        Facing.southWest: ('hero_walk_se_', true),
        Facing.west: ('hero_walk_e_', true),
        Facing.northWest: ('hero_walk_ne_', true),
      };
      for (final MapEntry(key: facing, value: pick) in expected.entries) {
        expect(
          _pick(available, ActorState.walk, facing),
          pick,
          reason: '$facing',
        );
      }
    });

    test('no idle frames at all: nothing, so the stand-in is drawn', () {
      expect(_pick({'hero_walk_'}, ActorState.idle, Facing.south), isNull);
      expect(ActorFrames('hero', const {}).hasArtwork, isFalse);
    });
  });

  group('states, on the stand-in', () {
    testWithGame<FlameGame>('walks while walking, idles when not', FlameGame.new,
        (game) async {
      final actor = await _actorIn(game);
      expect(actor.hasArtwork, isFalse);
      expect(actor.state, ActorState.idle);

      actor.walking = true;
      expect(actor.state, ActorState.walk);
      actor.walking = false;
      expect(actor.state, ActorState.idle);
    });

    testWithGame<FlameGame>('hit plays once, then returns to what was playing',
        FlameGame.new, (game) async {
      final actor = await _actorIn(game);
      actor
        ..walking = true
        ..hit();
      expect(actor.state, ActorState.hit);

      game.update(ShapeActor.defaultHitDuration * 0.9);
      expect(actor.state, ActorState.hit);
      game.update(ShapeActor.defaultHitDuration * 0.2);
      expect(actor.state, ActorState.walk);
    });

    testWithGame<FlameGame>(
        'stopping during a hit lands once the hit is over', FlameGame.new,
        (game) async {
      final actor = await _actorIn(game);
      actor
        ..walking = true
        ..hit()
        ..walking = false;
      expect(actor.state, ActorState.hit);

      game.update(ShapeActor.defaultHitDuration + 0.01);
      expect(actor.state, ActorState.idle);
    });

    testWithGame<FlameGame>('a second hit starts the hit again', FlameGame.new,
        (game) async {
      final actor = await _actorIn(game)
        ..hit();
      game.update(ShapeActor.defaultHitDuration * 0.8);
      actor.hit();
      game.update(ShapeActor.defaultHitDuration * 0.8);
      expect(actor.state, ActorState.hit);
    });

    testWithGame<FlameGame>('die holds, and nothing interrupts it',
        FlameGame.new, (game) async {
      final actor = await _actorIn(game)..die();
      game.update(10);
      expect(actor.state, ActorState.die);

      actor
        ..hit()
        ..walking = true;
      game.update(1);
      expect(actor.state, ActorState.die);
    });

    testWithGame<FlameGame>('facing west mirrors the actor', FlameGame.new,
        (game) async {
      final actor = await _actorIn(game)..facing = Facing.west;
      expect(actor.scale.x, -1);
      actor.facing = Facing.northEast;
      expect(actor.scale.x, 1);
    });
  });

  group('states, with frames', () {
    testWithGame<FlameGame>(
        'hit plays its own frames once, then goes back to idle',
        FlameGame.new, (game) async {
      await _fakeFrames({'hero_idle_': 2, 'hero_hit_': 3});
      final actor = await _actorIn(game);
      expect(actor.hasArtwork, isTrue);
      final idle = _animationOf(actor);
      expect(idle!.loop, isTrue);

      actor.hit();
      final hit = _animationOf(actor)!;
      expect(hit, isNot(same(idle)));
      expect(hit.loop, isFalse);
      expect(hit.frames, hasLength(3));

      final length = 3 * actor.stepTime;
      game.update(length * 0.9);
      expect(actor.state, ActorState.hit);
      game.update(length * 0.2);
      expect(actor.state, ActorState.idle);
      expect(_animationOf(actor), same(idle));
    });

    testWithGame<FlameGame>('die holds its last frame', FlameGame.new,
        (game) async {
      await _fakeFrames({'hero_idle_': 1, 'hero_die_': 4});
      final actor = await _actorIn(game)..die();
      game.update(5);
      final view = actor.children.whereType<SpriteAnimationComponent>().single;
      expect(view.animation!.loop, isFalse);
      expect(view.animationTicker!.currentIndex, 3);
      expect(view.animationTicker!.done(), isTrue);
    });

    testWithGame<FlameGame>(
        'only idle frames: a hit leaves the idle loop running, untouched',
        FlameGame.new, (game) async {
      await _fakeFrames({'hero_idle_': 2});
      final actor = await _actorIn(game);
      final view = actor.children.whereType<SpriteAnimationComponent>().single;
      final idle = view.animation;
      final ticker = view.animationTicker;

      actor
        ..walking = true
        ..hit();
      expect(view.animation, same(idle));
      expect(view.animationTicker, same(ticker), reason: 'not restarted');
    });

    testWithGame<FlameGame>('walking west shows the eastern walk, mirrored',
        FlameGame.new, (game) async {
      await _fakeFrames({'hero_idle_': 1, 'hero_walk_e_': 4});
      final actor = await _actorIn(game)
        ..walking = true
        ..facing = Facing.west;
      expect(_animationOf(actor)!.frames, hasLength(4));
      expect(actor.scale.x, -1);
    });

    testWithGame<FlameGame>(
        'frames load once per actor and are shared by every copy',
        FlameGame.new, (game) async {
      await _fakeFrames({'hero_idle_': 1, 'hero_walk_': 2});
      final first = ShapeArt.loadActor('hero');
      expect(ShapeArt.loadActor('hero'), same(first));

      final a = await _actorIn(game);
      final b = await _actorIn(game);
      a.walking = true;
      b.walking = true;
      expect(_animationOf(a), same(_animationOf(b)));
    });
  });

  group('in a fight', () {
    testWithGame<DeathBySlidesGame>(
      'the player walks while moving and idles when still',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        final art = arena.player.children.whereType<ShapeActor>().single;
        expect(art.state, ActorState.idle);

        hold(arena.player, {LogicalKeyboardKey.keyD});
        game.update(1 / 60);
        expect(art.state, ActorState.walk);

        hold(arena.player, {});
        game.update(1 / 60);
        expect(art.state, ActorState.idle);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'the player flinches when shrunk and dies when shrunk away',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        final art = arena.player.children.whereType<ShapeActor>().single;

        arena.player.takeHit();
        expect(art.state, ActorState.hit);

        arena.player.takeHit(arena.player.health.current);
        expect(art.state, ActorState.die);
      },
    );

    for (final level in [1, 2]) {
      testWithGame<DeathBySlidesGame>(
        'slide $level\'s boss flinches, and dies when beaten',
        DeathBySlidesGame.new,
        (game) async {
          final arena = await openArena(game, level: level);
          final art = arena.boss.descendants().whereType<ShapeActor>().first;

          arena.boss.takeHit();
          expect(art.state, ActorState.hit);

          arena.boss.takeHit(arena.boss.remainingHits);
          expect(art.state, ActorState.die);
        },
      );
    }
  });
}
