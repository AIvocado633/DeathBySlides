import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:death_by_slides/game/combat/projectiles.dart';
import 'package:death_by_slides/game/combat/diagram_wizard_boss.dart';
import 'package:death_by_slides/game/components/result_panel.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';

import 'arena_harness.dart';

const int _diagramWizardLevel = 2;

void main() {
  group('layouts', () {
    test('keep every shape inside the diagram, at any shape count', () {
      final box = Vector2(460, 230);
      const half = DiagramWizardBoss.nodeSize / 2;

      for (final layout in DiagramLayout.values) {
        for (var count = 1; count <= 6; count++) {
          final places = DiagramWizardBoss.positionsFor(layout, count, box);

          expect(places.length, count, reason: '$layout with $count shapes');
          for (final place in places) {
            expect(
              place.x,
              inInclusiveRange(half, box.x - half),
              reason: '$layout with $count shapes spills sideways',
            );
            expect(
              place.y,
              inInclusiveRange(half, box.y - half),
              reason: '$layout with $count shapes spills vertically',
            );
          }
        }
      }
    });

    test('never stack two shapes on the same spot', () {
      final box = Vector2(460, 230);

      for (final layout in DiagramLayout.values) {
        for (var count = 2; count <= 6; count++) {
          final places = DiagramWizardBoss.positionsFor(layout, count, box);
          for (var i = 0; i < places.length; i++) {
            for (var j = i + 1; j < places.length; j++) {
              expect(
                places[i].distanceTo(places[j]),
                greaterThan(1),
                reason: '$layout with $count shapes overlaps $i and $j',
              );
            }
          }
        }
      }
    });
  });

  group('Diagram Wizard boss', () {
    testWithGame<DeathBySlidesGame>(
      'opens as a six-shape cycle',
      DeathBySlidesGame.new,
      (game) async {
        final boss =
            (await openArena(game, level: _diagramWizardLevel)).boss as DiagramWizardBoss;

        expect(boss.livingShapes.length, 6);
        expect(boss.layout, DiagramLayout.cycle);
        expect(boss.readout, '6 shapes');
        expect(boss.remainingHits, boss.totalHits);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'takes two hits to break one shape',
      DeathBySlidesGame.new,
      (game) async {
        final boss =
            (await openArena(game, level: _diagramWizardLevel)).boss as DiagramWizardBoss;

        boss.takeHit();
        expect(boss.livingShapes.length, 6, reason: 'one hit only dents it');

        boss.takeHit();
        expect(boss.livingShapes.length, 5);
        expect(boss.readout, '5 shapes');
      },
    );

    testWithGame<DeathBySlidesGame>(
      'rearranges itself the moment a shape is broken',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game, level: _diagramWizardLevel);
        final boss = arena.boss as DiagramWizardBoss;
        final before = boss.livingShapes.map((s) => s.position.clone()).toList();

        boss.takeHit(DiagramWizardBoss.hitsPerShape);
        expect(boss.layout, DiagramLayout.process, reason: 'next layout');

        advance(game, 0.8);
        await game.ready();

        final after = boss.livingShapes.map((s) => s.position).toList();
        expect(after.length, 5);
        // The survivors have gone somewhere else entirely, which is the fight.
        for (var i = 0; i < after.length; i++) {
          expect(after[i].distanceTo(before[i + 1]), greaterThan(1));
        }
        expect(
          after,
          pairwiseCompare<Vector2, Vector2>(
            DiagramWizardBoss.positionsFor(
              DiagramLayout.process,
              5,
              boss.size,
            ),
            (actual, expected) => actual.distanceTo(expected) < 0.5,
            'settled into the process layout',
          ),
        );
      },
    );

    testWithGame<DeathBySlidesGame>(
      'walks on through the layouts as it is dismantled',
      DeathBySlidesGame.new,
      (game) async {
        final boss =
            (await openArena(game, level: _diagramWizardLevel)).boss as DiagramWizardBoss;

        boss.takeHit(DiagramWizardBoss.hitsPerShape);
        expect(boss.layout, DiagramLayout.process);
        boss.takeHit(DiagramWizardBoss.hitsPerShape);
        expect(boss.layout, DiagramLayout.hierarchy);
        boss.takeHit(DiagramWizardBoss.hitsPerShape);
        expect(boss.layout, DiagramLayout.pyramid);
        boss.takeHit(DiagramWizardBoss.hitsPerShape);
        expect(boss.layout, DiagramLayout.cycle, reason: 'wraps around');
      },
    );

    testWithGame<DeathBySlidesGame>(
      'throws connector arrows at the player',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game, level: _diagramWizardLevel);
        expect(arena.floor.children.whereType<ConnectorArrow>(), isEmpty);

        advance(game, 1.3);
        await game.ready();

        final arrows = arena.floor.children.whereType<ConnectorArrow>();
        expect(arrows, isNotEmpty);
        // Thrown downwards, because the player stands below the diagram.
        expect(arrows.first.velocity.y, greaterThan(0));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'running out of shapes wins the slide',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game, level: _diagramWizardLevel);

        arena.boss.takeHit(arena.boss.totalHits);
        expect(arena.boss.isDefeated, isTrue);

        advance(game, 0.7);
        await game.ready();

        expect(arena.isResolved, isTrue);
        final panel = arena.children.whereType<ResultPanel>().single;
        expect(panel.won, isTrue);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a bullet point that reaches a shape breaks it down',
      DeathBySlidesGame.new,
      (game) async {
        final arena = await openArena(game, level: _diagramWizardLevel);
        final before = arena.boss.remainingHits;

        arena.player.fire();
        advance(game, 0.8);
        await game.ready();

        expect(arena.boss.remainingHits, lessThan(before));
        expect(arena.floor.children.whereType<BulletPoint>(), isEmpty);
      },
    );
  });
}
