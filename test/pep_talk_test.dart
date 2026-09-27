import 'dart:convert';
import 'dart:math' as math;

import 'package:death_by_slides/game/combat/projectiles.dart';
import 'package:death_by_slides/game/components/chip_button.dart';
import 'package:death_by_slides/game/components/player.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/pages/arena_page.dart';
import 'package:death_by_slides/game/pages/pep_talk_page.dart';
import 'package:death_by_slides/game/pages/tweaks_page.dart';
import 'package:death_by_slides/game/routes.dart';
import 'package:death_by_slides/game/save/save_data.dart';
import 'package:death_by_slides/game/save/save_store.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arena_harness.dart';

/// A game whose save already has [pepTalk] switched on.
DeathBySlidesGame Function() _gameWith(PepTalk pepTalk) =>
    () => DeathBySlidesGame(
      saveStore: InMemorySaveStore(
        SaveData(settings: Settings(pepTalk: pepTalk)).encode(),
      ),
    );

/// Runs the fight until the boss has something in the air, and returns it.
Future<EnemyShot> _firstShot(DeathBySlidesGame game, ArenaPage arena) async {
  for (var i = 0; i < 600; i++) {
    advance(game, 1 / 60);
    await game.ready();
    final shots = arena.floor.children.whereType<EnemyShot>();
    if (shots.isNotEmpty) {
      return shots.first;
    }
  }
  fail('the boss never threw anything');
}

/// Radians between [velocity] and the way from [from] to [to].
double _miss(Vector2 velocity, Vector2 from, Vector2 to) {
  final wanted = to - from;
  final off =
      math.atan2(velocity.y, velocity.x) - math.atan2(wanted.y, wanted.x);
  return math.atan2(math.sin(off), math.cos(off)).abs();
}

List<String> _texts(ArenaPage arena) =>
    arena.children.whereType<TextComponent>().map((t) => t.text).toList();

void main() {
  // Other tests build players and shots outside a game; never leave them an
  // assist switched on.
  tearDown(() => PepTalk.current = const PepTalk());

  group('each option changes its own value and nothing else', () {
    const off = PepTalk();

    ({int hits, double shots, double grace, bool assist}) values(PepTalk p) =>
        (
          hits: p.playerHits,
          shots: p.shotSpeedScale,
          grace: p.graceScale,
          assist: p.aimAssist,
        );

    test('all off is the game as tuned', () {
      expect(values(off), (hits: 8, shots: 1.0, grace: 1.0, assist: false));
      expect(off.isOn, isFalse);
    });

    test('more room to shrink', () {
      expect(
        values(off.copyWith(moreRoom: true)),
        (hits: 12, shots: 1.0, grace: 1.0, assist: false),
      );
    });

    test('slower shots', () {
      expect(
        values(off.copyWith(slowerShots: true)),
        (hits: 8, shots: 0.7, grace: 1.0, assist: false),
      );
    });

    test('longer grace', () {
      expect(
        values(off.copyWith(longerGrace: true)),
        (hits: 8, shots: 1.0, grace: 2.0, assist: false),
      );
    });

    test('aim assist', () {
      expect(
        values(off.copyWith(aimAssist: true)),
        (hits: 8, shots: 1.0, grace: 1.0, assist: true),
      );
    });
  });

  group('in a fight', () {
    testWithGame<DeathBySlidesGame>(
      'more room to shrink: 12 hits, same smallest size',
      _gameWith(const PepTalk(moreRoom: true)),
      (game) async {
        final arena = await openArena(game);
        final health = arena.player.health;

        expect(health.max, PepTalk.roomyHits);
        // Size to speed is unchanged: full health is full size, and the
        // smallest size is the same as without Pep Talk.
        expect(health.scale, 1);
        expect(health.minScale, 0.4);

        arena.player.takeHit(PepTalk.normalHits);
        expect(health.isDead, isFalse, reason: '8 hits no longer end it');
        arena.player.takeHit(PepTalk.roomyHits - PepTalk.normalHits);
        expect(health.isDead, isTrue);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'without Pep Talk the player still takes 8 hits',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        expect(arena.player.health.max, PepTalk.normalHits);
      },
    );

    for (final (level, speed) in [
      (1, ResizeHandle.speed),
      (2, ConnectorArrow.speed),
    ]) {
      testWithGame<DeathBySlidesGame>(
        'slower shots slow slide $level to 70%',
        _gameWith(const PepTalk(slowerShots: true)),
        (game) async {
          final arena = await openArena(game, level: level);
          final shot = await _firstShot(game, arena);
          expect(shot.velocity.length, closeTo(speed * 0.7, 1e-3));
        },
      );

      testWithGame<DeathBySlidesGame>(
        'without slower shots slide $level keeps its speed',
        DeathBySlidesGame.new,
        (game) async {
          final arena = await openArena(game, level: level);
          final shot = await _firstShot(game, arena);
          expect(shot.velocity.length, closeTo(speed, 1e-3));
        },
      );
    }

    testWithGame<DeathBySlidesGame>(
      'longer grace doubles the window after a hit',
      _gameWith(const PepTalk(longerGrace: true)),
      (game) async {
        final arena = await openArena(game);
        expect(Player.graceWindow, Player.invulnerableFor * 2);

        final shot = ResizeHandle(
          position: arena.player.position.clone(),
          velocity: Vector2.zero(),
        );
        arena.player.onCollisionStart({}, shot);
        expect(arena.player.isInvulnerable, isTrue);

        advance(game, Player.invulnerableFor + 0.1);
        expect(arena.player.isInvulnerable, isTrue, reason: 'still in grace');

        advance(game, Player.invulnerableFor);
        expect(arena.player.isInvulnerable, isFalse);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'without longer grace the window is as tuned',
      DeathBySlidesGame.new,
      (game) async {
        await openArena(game);
        expect(Player.graceWindow, Player.invulnerableFor);
      },
    );

    for (final assist in [true, false]) {
      testWithGame<DeathBySlidesGame>(
        assist
            ? 'aim assist bends a near miss towards the boss'
            : 'without aim assist a near miss flies straight',
        _gameWith(PepTalk(aimAssist: assist)),
        (game) async {
          final arena = await openArena(game);
          final from = arena.player.position.clone();
          final target = arena.boss.position.clone();
          // Twelve degrees off: a near miss.
          final heading = (target - from).normalized()..rotate(math.pi / 15);
          final shot = BulletPoint(
            position: from,
            velocity: heading * BulletPoint.speed,
          );
          arena.floor.add(shot);
          await game.ready();
          final before = _miss(shot.velocity, shot.position, target);

          // Only the shot moves, so the boss stays where it was aimed at.
          for (var i = 0; i < 6; i++) {
            shot.update(1 / 60);
          }
          final after = _miss(shot.velocity, shot.position, target);

          if (assist) {
            expect(after, lessThan(before * 0.8));
          } else {
            expect(
              shot.velocity.normalized().dot(heading),
              closeTo(1, 1e-6),
              reason: 'the heading never changed',
            );
          }
        },
      );
    }

    testWithGame<DeathBySlidesGame>(
      'aim assist leaves a shot alone when nothing is ahead of it',
      _gameWith(const PepTalk(aimAssist: true)),
      (game) async {
        final arena = await openArena(game);
        // Straight down, away from the boss.
        final heading = Vector2(0, 1);
        final shot = BulletPoint(
          position: arena.player.position.clone(),
          velocity: heading * BulletPoint.speed,
        );
        arena.floor.add(shot);
        await game.ready();

        shot.update(1 / 60);
        expect(shot.velocity.normalized().dot(heading), closeTo(1, 1e-6));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'the slide says when Pep Talk is on',
      _gameWith(const PepTalk(slowerShots: true)),
      (game) async {
        final arena = await openArena(game);
        expect(_texts(arena), contains('Pep Talk is on'));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'and says nothing when it is off',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game);
        expect(_texts(arena), isNot(contains('Pep Talk is on')));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a win still counts with every assist on',
      _gameWith(
        const PepTalk(
          moreRoom: true,
          slowerShots: true,
          longerGrace: true,
          aimAssist: true,
        ),
      ),
      (game) async {
        final arena = await openArena(game);
        arena.boss.takeHit(arena.boss.remainingHits);
        advance(game, 1);
        await game.ready();
        expect(arena.isResolved, isTrue);
        expect(game.deck.resumeSlide, isNot(1), reason: 'slide 1 is won');
      },
    );
  });

  group('the Pep Talk page', () {
    final store = InMemorySaveStore();

    testWithGame<DeathBySlidesGame>(
      'opens from Tweaks, and its switches save and take effect',
      () => DeathBySlidesGame(saveStore: store),
      (game) async {
        await game.ready();
        game.router.pushNamed(Routes.tweaks);
        await game.ready();
        final tweaks = game.router.currentRoute.children
            .whereType<TweaksPage>()
            .single;
        await game.ready();
        tweaks
            .descendants()
            .whereType<ChipButton>()
            .singleWhere((chip) => chip.label == 'Pep Talk…')
            .activate();
        await game.ready();
        final page = game.router.currentRoute.children
            .whereType<PepTalkPage>()
            .single;

        page.slowerShots.activate();
        page.aimAssist.activate();

        const chosen = PepTalk(slowerShots: true, aimAssist: true);
        expect(game.settings.pepTalk, chosen);
        expect(PepTalk.current, chosen, reason: 'in effect straight away');

        await Future<void>.delayed(Duration.zero);
        expect(SaveData.decode(store.document!).settings.pepTalk, chosen);
      },
    );
  });

  group('saving', () {
    test('survives a save', () {
      const pepTalk = PepTalk(moreRoom: true, longerGrace: true);
      final back = Settings.fromJson(
        jsonDecode(jsonEncode(const Settings(pepTalk: pepTalk).toJson())),
      );
      expect(back.pepTalk, pepTalk);
    });

    test('an older save, or anything unreadable, is all off', () {
      expect(Settings.fromJson({'swapSticks': true}).pepTalk, const PepTalk());
      expect(
        Settings.fromJson({
          'pepTalk': {'moreRoom': 'yes', 'aimAssist': 1},
        }).pepTalk,
        const PepTalk(),
      );
    });
  });
}
