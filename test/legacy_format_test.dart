import 'dart:math' as math;

import 'package:death_by_slides/game/combat/boss.dart';
import 'package:death_by_slides/game/combat/build_order_boss.dart';
import 'package:death_by_slides/game/combat/diagram_wizard_boss.dart';
import 'package:death_by_slides/game/combat/legacy_format_boss.dart';
import 'package:death_by_slides/game/combat/master_template_boss.dart';
import 'package:death_by_slides/game/combat/projectiles.dart';
import 'package:death_by_slides/game/combat/snap_to_grid_boss.dart';
import 'package:death_by_slides/game/components/arena_floor.dart';
import 'package:death_by_slides/game/components/chip_button.dart';
import 'package:death_by_slides/game/components/result_panel.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/pages/arena_page.dart';
import 'package:death_by_slides/game/save/save_data.dart';
import 'package:death_by_slides/game/save/save_store.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arena_harness.dart';

const int _legacyFormatLevel = 6;

DeathBySlidesGame _game() => DeathBySlidesGame(unlockAll: true);

Future<(ArenaPage, LegacyFormatBoss)> _open(DeathBySlidesGame game) async {
  final arena = await openArena(game, level: _legacyFormatLevel);
  advance(game, 1 / 60);
  await game.ready();
  return (arena, arena.boss as LegacyFormatBoss);
}

/// Beats every stage before [stage] and reads the checker, so [stage] is
/// being fought.
Future<void> _reach(
  DeathBySlidesGame game,
  LegacyFormatBoss boss,
  LegacyStage stage,
) async {
  while (boss.stage != stage || boss.phase == null) {
    final phase = boss.phase;
    if (phase == null) {
      boss.checker!.skipReading();
    } else {
      boss.takeHit(phase.window.health.current);
    }
    await game.ready();
  }
  advance(game, 1 / 60);
  await game.ready();
}

/// Runs the fight for [seconds], keeping the player in it however much lands,
/// so a long test is not cut short by losing the slide.
void _survive(DeathBySlidesGame game, ArenaPage arena, double seconds) {
  for (var done = 0.0; done < seconds - 1e-9; done += 1) {
    arena.player.health.restore();
    advance(game, math.min(1, seconds - done));
  }
}

Iterable<T> _onFloor<T>(ArenaPage arena) => arena.floor.children.whereType<T>();

void main() {
  group('Legacy Format boss', () {
    testWithGame<DeathBySlidesGame>(
      'opens at 97-2003 on the old floor, throwing in eight directions only',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        expect(boss.readout, '97-2003');
        expect(boss.phase, isA<ShrinkPhase>());
        expect(arena.floor.look, LegacyFormatBoss.floorLook);

        // Off the eight ways, so a faithful aim would show.
        arena.player.position.setValues(130, 380);
        _survive(game, arena, ShrinkPhase.fireInterval * 3);
        await game.ready();
        final handles = _onFloor<ResizeHandle>(arena).toList();
        expect(handles, isNotEmpty);
        for (final handle in handles) {
          final angle = math.atan2(handle.velocity.y, handle.velocity.x);
          final eighths = angle / (math.pi / 4);
          expect(eighths, closeTo(eighths.roundToDouble(), 1e-6));
        }
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a stage beaten saves it a format forward, with the checker up first',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);

        boss.takeHit(LegacyStage.shrinkToFit.hits);
        await game.ready();
        expect(boss.readout, '2007');
        expect(boss.phase, isNull);
        expect(boss.checker!.isReading, isTrue);
        expect(
          arena.player.has(PlayerFeature.independentAim),
          isTrue,
          reason: 'nothing is taken while the checker is being read',
        );

        _onFloor<EnemyShot>(arena).forEach((shot) => shot.removeFromParent());
        advance(game, LegacyFormatBoss.checkerReadTime - 0.1);
        await game.ready();
        expect(_onFloor<EnemyShot>(arena), isEmpty, reason: 'it holds fire');
        expect(boss.phase, isNull);

        advance(game, 0.2);
        await game.ready();
        expect(boss.phase, isA<PicturePhase>());
        expect(boss.checker!.isFeatureOff, isTrue);
        expect(arena.player.has(PlayerFeature.independentAim), isFalse);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'the checker gives the feature back once its time is up',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        await _reach(game, boss, LegacyStage.diagramWizard);
        expect(arena.player.has(PlayerFeature.independentAim), isFalse);

        _survive(game, arena, LegacyFormatBoss.featureOffFor - 0.2);
        expect(arena.player.has(PlayerFeature.independentAim), isFalse);
        advance(game, 0.3);
        await game.ready();
        expect(arena.player.has(PlayerFeature.independentAim), isTrue);
        expect(boss.checker, isNull);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'the checker takes aiming and diagonal movement in turn',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        final taken = <PlayerFeature>[];
        for (final stage in LegacyStage.values.skip(1)) {
          await _reach(game, boss, stage);
          taken.add(boss.checker!.feature);
          expect(arena.player.has(boss.checker!.feature), isFalse);
          final other = PlayerFeature.values.where(
            (feature) => feature != boss.checker!.feature,
          );
          expect(
            other.every(arena.player.has),
            isTrue,
            reason: 'one at a time',
          );
        }
        expect(taken, [
          PlayerFeature.independentAim,
          PlayerFeature.diagonalMovement,
          PlayerFeature.independentAim,
          PlayerFeature.diagonalMovement,
          PlayerFeature.independentAim,
        ]);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'the Diagram Wizard arrives as a picture: one target that never moves',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        await _reach(game, boss, LegacyStage.diagramWizard);
        final picture = boss.phase!.window;
        final at = picture.position.clone();

        _survive(game, arena, PicturePhase.fireInterval * 2 + 0.1);
        await game.ready();
        final targets = arena.floor
            .descendants()
            .whereType<BulletTarget>()
            .where((target) => target.isTargetable);
        expect(targets.single, picture);
        expect(arena.floor.descendants().whereType<DiagramNode>(), isEmpty);
        expect(picture.position, at);
        expect(_onFloor<ConnectorArrow>(arena), isNotEmpty);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'the Master Template keeps to the themes the old format can store',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        await _reach(game, boss, LegacyStage.masterTemplate);
        final phase = boss.phase! as ThemePhase;

        // A little past each change, so frame rounding never lands a check
        // a frame short of one.
        final seen = <SlideTheme>[];
        for (var i = 0; i < 4; i++) {
          _survive(game, arena, ThemePhase.themeInterval - 0.5);
          await game.ready();
          expect(phase.warning, isNotNull, reason: 'a warning comes first');
          expect(_onFloor<SwatchShot>(arena), isNotEmpty);
          advance(game, 0.6);
          await game.ready();
          seen.add(phase.theme);
          expect(arena.player.shotRules, phase.theme.player);
        }
        expect(seen, [
          SlideTheme.rebound,
          SlideTheme.chunky,
          SlideTheme.plain,
          SlideTheme.rebound,
        ]);

        boss.takeHit(phase.window.health.current);
        await game.ready();
        expect(arena.player.shotRules, ShotRules.standard);
        expect(arena.floor.look, LegacyFormatBoss.floorLook);
        expect(_onFloor<ThemeWarning>(arena), isEmpty);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'the Build Order only knows After Last, and plays its attacks',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        await _reach(game, boss, LegacyStage.buildOrder);
        final phase = boss.phase! as BuildPhase;

        expect(
          phase.queue.steps.map((step) => step.trigger),
          everyElement(Trigger.afterLast),
        );
        expect(
          phase.queue.steps.map((step) => step.effect),
          isNot(anyElement(isIn([BuildEffect.spin, BuildEffect.wobble]))),
          reason: 'nothing curves in the old format',
        );
        advance(game, 1.5);
        await game.ready();
        expect(phase.children.whereType<BuildAttack>(), isNotEmpty);
        expect(_onFloor<BuildShot>(arena), isNotEmpty);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'guides strike near their line and not a tile away; nobody snaps',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        await _reach(game, boss, LegacyStage.snapToGrid);
        final phase = boss.phase! as GuidePhase;
        final player = arena.player;
        expect(player.positionFilter, isNull);
        _onFloor<EnemyShot>(arena).forEach((shot) => shot.removeFromParent());
        final full = player.health.current;

        phase.markGuide(horizontal: true, line: player.position.y + 60);
        await game.ready();
        advance(game, SnapToGridBoss.warning + 0.1);
        await game.ready();
        expect(player.health.current, full, reason: 'a tile away');

        phase.markGuide(
          horizontal: false,
          line: player.position.x + GuidePhase.strikeReach / 2,
        );
        await game.ready();
        advance(game, SnapToGridBoss.warning + 0.1);
        expect(player.health.current, full - 1);

        boss.takeHit(phase.window.health.current);
        await game.ready();
        expect(_onFloor<AlignmentGuide>(arena), isEmpty);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'File ▸ Info ▸ Convert: the last blow gives everything back and wins',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        await _reach(game, boss, LegacyStage.convert);
        expect(boss.readout, '2019');
        expect(arena.player.has(PlayerFeature.independentAim), isFalse);
        advance(game, ConvertPhase.fireInterval + 0.05);
        await game.ready();
        expect(
          _onFloor<ResizeHandle>(arena).length,
          greaterThanOrEqualTo(ConvertPhase.ringSize),
        );

        boss.takeHit(boss.remainingHits);
        expect(boss.isDefeated, isTrue);
        expect(boss.readout, 'converted');
        expect(PlayerFeature.values.every(arena.player.has), isTrue);
        expect(arena.floor.look, FloorLook.standard);

        advance(game, 0.6);
        await game.ready();
        expect(arena.isResolved, isTrue);
        final panel = arena.children.whereType<ResultPanel>().single;
        expect(panel.won, isTrue);
        expect(
          panel.children.whereType<ChipButton>().map((b) => b.label),
          isNot(contains('Next Slide')),
          reason: 'the last slide of the deck',
        );
      },
    );

    testWithGame<DeathBySlidesGame>(
      'its health is the whole conversion',
      _game,
      (game) async {
        final (_, boss) = await _open(game);
        expect(boss.totalHits, 34);
        expect(boss.remainingHits, boss.totalHits);

        boss.takeHit(LegacyStage.shrinkToFit.hits + 2);
        expect(boss.remainingHits, boss.totalHits - 8);
        expect(boss.readout, '2007');
      },
    );

    testWithGame<DeathBySlidesGame>(
      "Pep Talk's slower shots slow everything it throws",
      () => DeathBySlidesGame(
        unlockAll: true,
        saveStore: InMemorySaveStore(
          SaveData(
            settings: const Settings(pepTalk: PepTalk(slowerShots: true)),
          ).encode(),
        ),
      ),
      (game) async {
        final (arena, _) = await _open(game);
        advance(game, ShrinkPhase.fireInterval + 0.05);
        await game.ready();
        expect(
          _onFloor<ResizeHandle>(arena).first.velocity.length,
          closeTo(ResizeHandle.speed * 0.7, 1e-3),
        );
      },
    );
  });

  group('player features', () {
    testWithGame<DeathBySlidesGame>(
      'without independent aiming, shots go the way the player walks',
      _game,
      (game) async {
        final (arena, _) = await _open(game);
        final player = arena.player;
        player.setFeature(PlayerFeature.independentAim, on: false);

        hold(player, {LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowUp});
        advance(game, 0.1);
        await game.ready();
        final shots = _onFloor<BulletPoint>(arena).toList();
        expect(shots, isNotEmpty, reason: 'aiming still fires');
        for (final shot in shots) {
          expect(shot.velocity.y, closeTo(0, 1e-6));
          expect(shot.velocity.x, greaterThan(0));
        }

        player.setFeature(PlayerFeature.independentAim, on: true);
        advance(game, 0.4);
        expect(player.aimDirection, Vector2(0, -1));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'without diagonal movement, the player walks four ways',
      _game,
      (game) async {
        final (arena, _) = await _open(game);
        final player = arena.player;
        player.setFeature(PlayerFeature.diagonalMovement, on: false);
        final start = player.position.clone();

        hold(player, {LogicalKeyboardKey.keyD, LogicalKeyboardKey.keyW});
        advance(game, 0.2);
        final moved = player.position - start;
        expect(moved.length, greaterThan(0));
        expect(moved.x == 0 || moved.y == 0, isTrue);

        player.setFeature(PlayerFeature.diagonalMovement, on: true);
        final before = player.position.clone();
        advance(game, 0.2);
        final diagonal = player.position - before;
        expect(diagonal.x, greaterThan(0));
        expect(diagonal.y, lessThan(0));
      },
    );
  });
}
