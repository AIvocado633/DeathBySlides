import 'dart:ui' show Color;

import 'package:death_by_slides/game/combat/master_template_boss.dart';
import 'package:death_by_slides/game/combat/projectiles.dart';
import 'package:death_by_slides/game/components/arena_floor.dart';
import 'package:death_by_slides/game/components/result_panel.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/pages/arena_page.dart';
import 'package:death_by_slides/game/save/save_data.dart';
import 'package:death_by_slides/game/save/save_store.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arena_harness.dart';

const int _masterTemplateLevel = 3;

DeathBySlidesGame _game() => DeathBySlidesGame(unlockAll: true);

Future<(ArenaPage, MasterTemplateBoss)> _open(DeathBySlidesGame game) async {
  final arena = await openArena(game, level: _masterTemplateLevel);
  return (arena, arena.boss as MasterTemplateBoss);
}

/// A shot of each side, parked in the middle of the board, standing still
/// apart from the rules the test puts on them.
Future<(BulletPoint, SwatchShot)> _shotsInFlight(
  DeathBySlidesGame game,
  ArenaPage arena,
) async {
  final mine = BulletPoint(
    position: arena.floor.centre.clone(),
    velocity: Vector2(0, -BulletPoint.speed),
  );
  final theirs = SwatchShot(
    position: arena.floor.centre.clone(),
    velocity: Vector2(0, SwatchShot.speed),
    colour: const Color(0xFF000000),
  );
  arena.floor.addAll([mine, theirs]);
  await game.ready();
  return (mine, theirs);
}

void main() {
  group('Master Template boss', () {
    testWithGame<DeathBySlidesGame>(
      'starts plain, with five layouts under a locked master',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);

        expect(boss.theme, SlideTheme.plain);
        expect(boss.readout, '5 layouts');
        expect(boss.master.isExposed, isFalse);
        expect(boss.master.isTargetable, isFalse);
        expect(arena.floor.look, same(FloorLook.standard));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'warns, then changes theme on its timer, in turn',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        const warnAt =
            MasterTemplateBoss.themeInterval -
            MasterTemplateBoss.warningDuration;

        advance(game, warnAt - 0.1);
        await game.ready();
        expect(boss.warning, isNull);

        advance(game, 0.2);
        await game.ready();
        expect(boss.warning, isNotNull);
        expect(boss.warning!.theme, SlideTheme.rebound);
        expect(boss.theme, SlideTheme.plain, reason: 'not yet');

        advance(game, MasterTemplateBoss.warningDuration);
        await game.ready();
        expect(boss.theme, SlideTheme.rebound);
        expect(boss.warning, isNull);
        expect(arena.floor.look, same(SlideTheme.rebound.floor));

        advance(game, MasterTemplateBoss.themeInterval);
        expect(boss.theme, SlideTheme.sleek);
        advance(game, MasterTemplateBoss.themeInterval);
        expect(boss.theme, SlideTheme.chunky);
        advance(game, MasterTemplateBoss.themeInterval);
        expect(boss.theme, SlideTheme.plain, reason: 'and round again');
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a theme change converts shots already in flight, on both sides',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        final (mine, theirs) = await _shotsInFlight(game, arena);

        boss.applyTheme(SlideTheme.chunky);
        expect(mine.velocity.length, closeTo(BulletPoint.speed * 0.6, 1e-3));
        expect(mine.scale.x, closeTo(1.6, 1e-6));
        expect(theirs.velocity.length, closeTo(SwatchShot.speed * 0.6, 1e-3));
        expect(theirs.scale.x, closeTo(1.6, 1e-6));

        // Relative to each shot's own speed, not stacked on the last theme.
        boss.applyTheme(SlideTheme.sleek);
        expect(mine.velocity.length, closeTo(BulletPoint.speed * 1.4, 1e-3));
        expect(mine.scale.x, closeTo(0.6, 1e-6));
        expect(theirs.velocity.length, closeTo(SwatchShot.speed, 1e-3));
        expect(theirs.rules.curve, isNot(0));
        expect(mine.rules.curve, 0, reason: 'only its shots curve');
      },
    );

    testWithGame<DeathBySlidesGame>(
      "the player's new shots follow the theme",
      _game,
      (game) async {
        final (arena, boss) = await _open(game);

        boss.applyTheme(SlideTheme.sleek);
        arena.player.fire();
        await game.ready();
        final shot = arena.floor.children.whereType<BulletPoint>().last;

        expect(shot.velocity.length, closeTo(BulletPoint.speed * 1.4, 1e-3));
        expect(shot.scale.x, closeTo(0.6, 1e-6));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'under Rebound a shot bounces off one wall, then leaves at the next',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        boss.applyTheme(SlideTheme.rebound);
        final shot = BulletPoint(
          position: Vector2(arena.floor.size.x - 2, 300),
          velocity: Vector2(BulletPoint.speed, 0),
        )..applyRules(SlideTheme.rebound.player);
        arena.floor.add(shot);
        await game.ready();

        shot.update(1 / 60);
        expect(shot.isMounted, isTrue, reason: 'bounced');
        expect(shot.velocity.x, lessThan(0));

        shot.position.x = 1;
        shot.update(1 / 60);
        await game.ready();
        expect(shot.isMounted, isFalse, reason: 'no bounce left');
      },
    );

    testWithGame<DeathBySlidesGame>(
      'under Sleek its shots curve as they fly',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        final (_, theirs) = await _shotsInFlight(game, arena);
        boss.applyTheme(SlideTheme.sleek);
        final heading = theirs.velocity.normalized();

        theirs.update(0.2);
        expect(theirs.velocity.normalized().dot(heading), lessThan(0.999));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'the readout counts layouts, and the master is locked until they go',
      _game,
      (game) async {
        final (_, boss) = await _open(game);

        for (var left = 4; left >= 1; left--) {
          boss.takeHit(MasterTemplateBoss.hitsPerLayout);
          expect(boss.readout, left == 1 ? '1 layout' : '$left layouts');
          expect(boss.master.isExposed, isFalse);
        }
        // A stray shot at the master while it is locked flies straight past.
        final stray = BulletPoint(
          position: Vector2.zero(),
          velocity: Vector2(0, -1),
        );
        boss.master.onCollisionStart({}, stray);
        expect(boss.master.health.current, MasterTemplateBoss.masterHits);

        boss.takeHit(MasterTemplateBoss.hitsPerLayout);
        expect(boss.readout, 'master only');
        expect(boss.master.isExposed, isTrue);
        expect(boss.remainingHits, MasterTemplateBoss.masterHits);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'closing the master puts the slide back to plain and wins it',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        boss.applyTheme(SlideTheme.chunky);

        boss.takeHit(boss.remainingHits);
        expect(boss.isDefeated, isTrue);
        expect(boss.theme, SlideTheme.plain);
        expect(arena.player.shotRules, same(ShotRules.standard));
        expect(arena.floor.look, same(FloorLook.standard));

        advance(game, 1);
        await game.ready();
        expect(arena.isResolved, isTrue);
        expect(arena.children.whereType<ResultPanel>(), hasLength(1));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'the warning waits with a paused fight',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        advance(
          game,
          MasterTemplateBoss.themeInterval -
              MasterTemplateBoss.warningDuration +
              0.2,
        );
        await game.ready();
        final progress = boss.warning!.progress;

        arena.pause();
        advance(game, 5);
        expect(boss.warning!.progress, progress);
        expect(boss.theme, SlideTheme.plain);
      },
    );

    testWithGame<DeathBySlidesGame>(
      "Pep Talk's slower shots hold under every theme",
      () => DeathBySlidesGame(
        unlockAll: true,
        saveStore: InMemorySaveStore(
          SaveData(
            settings: const Settings(pepTalk: PepTalk(slowerShots: true)),
          ).encode(),
        ),
      ),
      (game) async {
        final (arena, boss) = await _open(game);
        final (_, theirs) = await _shotsInFlight(game, arena);
        expect(theirs.velocity.length, closeTo(SwatchShot.speed * 0.7, 1e-3));

        boss.applyTheme(SlideTheme.chunky);
        expect(
          theirs.velocity.length,
          closeTo(SwatchShot.speed * 0.7 * 0.6, 1e-3),
        );
      },
    );
  });
}
