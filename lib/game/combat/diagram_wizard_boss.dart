import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import '../audio/game_audio.dart';
import '../components/shape_actor.dart';
import '../theme/palette.dart';
import 'boss.dart';
import 'health.dart';
import 'impact.dart';
import 'projectiles.dart';

/// The layouts the Diagram Wizard cycles through. Picking one has never been
/// the hard part; living with the one it picks for you is.
enum DiagramLayout { cycle, process, hierarchy, pyramid }

/// The second boss: the feature that turns your bullet list into a diagram and
/// then refuses to let you place anything in it.
///
/// It is not one target but six connected shapes. Break one and the survivors
/// immediately re-lay themselves out into the next layout, closing ranks and
/// throwing your aim away -- which is precisely what the Diagram Wizard does to
/// a slide the moment you add or remove a line.
class DiagramWizardBoss extends Boss {
  /// Spreads across the top of the arena, centred.
  DiagramWizardBoss(super.context, {this.shapeCount = 6, int? seed})
    : _random = math.Random(seed),
      super(
        position: Vector2(context.arenaSize.x / 2, 140),
        size: Vector2(460, 230),
      );

  /// How many shapes the diagram starts with.
  final int shapeCount;

  final math.Random _random;

  static const double nodeSize = 64;
  static const int hitsPerShape = 2;

  /// Seconds between thrown connector arrows. Longer than the player's mercy
  /// window, so a single stream of shots always lands.
  static const double fireInterval = 1.2;
  static const double _reflowDuration = 0.55;

  DiagramLayout get layout => _layout;
  DiagramLayout _layout = DiagramLayout.cycle;

  List<DiagramNode> get livingShapes => children
      .whereType<DiagramNode>()
      .where((node) => !node.isBroken)
      .toList();

  @override
  int get remainingHits =>
      livingShapes.fold(0, (sum, node) => sum + node.health.current);

  @override
  int get totalHits => shapeCount * hitsPerShape;

  @override
  String get readout {
    final count = livingShapes.length;
    return count == 1 ? '1 shape' : '$count shapes';
  }

  @override
  bool get isDefeated => _defeated;

  @override
  Iterable<Cue> get cues => const [
    Cue.diagramHit,
    Cue.diagramShapeBroken,
    Cue.diagramReflow,
    Cue.diagramDefeated,
  ];
  bool _defeated = false;

  double _sinceLastShot = 0;

  @override
  Future<void> onLoad() async {
    final places = positionsFor(_layout, shapeCount, size);
    await addAll([
      for (var i = 0; i < shapeCount; i++)
        DiagramNode(position: places[i], onBroken: _onShapeBroken),
    ]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_defeated) {
      return;
    }
    _sinceLastShot += dt;
    if (_sinceLastShot >= fireInterval) {
      _sinceLastShot = 0;
      _throwConnector();
    }
  }

  void _throwConnector() {
    final shapes = livingShapes;
    if (shapes.isEmpty) {
      return;
    }
    final origin = arenaPositionOf(shapes[_random.nextInt(shapes.length)]);
    final toTarget = aimAt() - origin;
    if (toTarget.isZero()) {
      return;
    }
    parent?.add(
      ConnectorArrow(
        position: origin,
        velocity: toTarget.normalized() * ConnectorArrow.speed,
      ),
    );
  }

  /// Where [node] sits in arena-local space. The diagram is anchored at its
  /// centre, so a child's own position is relative to the box's top-left.
  Vector2 arenaPositionOf(DiagramNode node) =>
      position + node.position - size / 2;

  void _onShapeBroken() {
    if (livingShapes.isEmpty) {
      _defeated = true;
      _collapse();
      return;
    }
    reflow();
  }

  /// Advances to the next layout and slides every surviving shape into its new
  /// place. This is the fight: the board you were aiming at is gone.
  void reflow() {
    audio.play(Cue.diagramReflow);
    _layout = DiagramLayout
        .values[(_layout.index + 1) % DiagramLayout.values.length];
    final shapes = livingShapes;
    final places = positionsFor(_layout, shapes.length, size);
    for (var i = 0; i < shapes.length; i++) {
      shapes[i].add(
        MoveEffect.to(
          places[i],
          EffectController(
            duration: _reflowDuration,
            curve: Curves.easeInOutCubic,
          ),
        ),
      );
    }
  }

  void _collapse() {
    audio.play(Cue.diagramDefeated);
    add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.5, curve: Curves.easeInBack),
        onComplete: () {
          removeFromParent();
          onDefeated();
        },
      ),
    );
  }

  @override
  void takeHit([int amount = 1]) {
    for (var i = 0; i < amount; i++) {
      final shapes = livingShapes;
      if (shapes.isEmpty) {
        return;
      }
      shapes.first.takeHit();
    }
  }

  @override
  void render(Canvas canvas) {
    final shapes = livingShapes;
    if (shapes.length < 2) {
      return;
    }
    // Connectors are derived from the shapes, so the diagram redraws itself
    // for free whenever a reflow moves them. Each layout wires up the way the
    // real one does: a ring, a chain, a parent fanning out to its children,
    // and a pyramid, which has no connectors at all.
    final paint = Paint()
      ..color = Palette.diagramWizardDark
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    switch (_layout) {
      case DiagramLayout.cycle:
        _chain(canvas, shapes, paint, closed: true);
      case DiagramLayout.process:
        _chain(canvas, shapes, paint);
      case DiagramLayout.hierarchy:
        for (final child in shapes.skip(1)) {
          canvas.drawLine(
            shapes.first.position.toOffset(),
            child.position.toOffset(),
            paint,
          );
        }
      case DiagramLayout.pyramid:
        break;
    }
  }

  static void _chain(
    Canvas canvas,
    List<DiagramNode> shapes,
    Paint paint, {
    bool closed = false,
  }) {
    for (var i = 0; i < shapes.length - 1; i++) {
      canvas.drawLine(
        shapes[i].position.toOffset(),
        shapes[i + 1].position.toOffset(),
        paint,
      );
    }
    if (closed) {
      canvas.drawLine(
        shapes.last.position.toOffset(),
        shapes.first.position.toOffset(),
        paint,
      );
    }
  }

  /// Node centres for [layout], in box-local coordinates.
  ///
  /// Every layout keeps whole shapes inside [box], so the diagram never spills
  /// out of its own frame however many shapes are left in it.
  static List<Vector2> positionsFor(
    DiagramLayout layout,
    int count,
    Vector2 box,
  ) {
    if (count <= 0) {
      return const [];
    }
    const inset = nodeSize / 2 + 10;
    final centre = box / 2;

    switch (layout) {
      case DiagramLayout.cycle:
        // An ellipse rather than a circle, so the shapes use the width of a
        // 16:9 slide instead of huddling in the middle of it.
        final rx = box.x / 2 - inset;
        final ry = box.y / 2 - inset;
        return [
          for (var i = 0; i < count; i++)
            Vector2(
              centre.x + rx * math.cos(-math.pi / 2 + i * 2 * math.pi / count),
              centre.y + ry * math.sin(-math.pi / 2 + i * 2 * math.pi / count),
            ),
        ];

      case DiagramLayout.process:
        return [
          for (var i = 0; i < count; i++)
            Vector2(_spread(i, count, box.x, inset), centre.y),
        ];

      case DiagramLayout.hierarchy:
        if (count == 1) {
          return [centre.clone()];
        }
        return [
          Vector2(centre.x, inset),
          for (var i = 0; i < count - 1; i++)
            Vector2(_spread(i, count - 1, box.x, inset), box.y - inset),
        ];

      case DiagramLayout.pyramid:
        final rows = <int>[];
        var placed = 0;
        while (placed < count) {
          final width = math.min(rows.length + 1, count - placed);
          rows.add(width);
          placed += width;
        }
        return [
          for (var r = 0; r < rows.length; r++)
            for (var i = 0; i < rows[r]; i++)
              Vector2(
                _spread(i, rows[r], box.x, inset),
                rows.length == 1
                    ? centre.y
                    : inset + (box.y - inset * 2) * r / (rows.length - 1),
              ),
        ];
    }
  }

  /// Spreads [count] shapes evenly across [extent], inset from both ends.
  static double _spread(int index, int count, double extent, double inset) {
    if (count == 1) {
      return extent / 2;
    }
    return inset + (extent - inset * 2) * index / (count - 1);
  }
}

/// One shape in the diagram: a rounded rectangle with something living in it.
class DiagramNode extends PositionComponent with CollisionCallbacks, HasAudio {
  DiagramNode({required Vector2 position, required this.onBroken})
    : super(
        position: position,
        size: Vector2.all(DiagramWizardBoss.nodeSize),
        anchor: Anchor.center,
        children: [RectangleHitbox()],
      );

  final void Function() onBroken;

  final Health health = Health(max: DiagramWizardBoss.hitsPerShape, minScale: 0.7);

  bool get isBroken => _broken;
  bool _broken = false;

  late final Paint _fillPaint = Paint()..color = Palette.diagramWizard;
  late final Paint _edgePaint = Paint()
    ..color = Palette.diagramWizardDark
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  late final ShapeActor _actor;

  @override
  Future<void> onLoad() async {
    await add(
      _actor = ShapeActor(
        artPrefix: 'diagram_wizard_idle_',
        tint: Palette.diagramWizard,
        position: size / 2,
        size: size * 0.72,
        anchor: Anchor.center,
        bobbing: false,
      ),
    );
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is! BulletPoint || _broken) {
      return;
    }
    other.removeFromParent();
    takeHit(other.damage);
  }

  void takeHit([int amount = 1]) {
    if (_broken) {
      return;
    }
    health.damage(amount);
    scale = Vector2.all(health.scale);
    Impact.hit(_actor);
    if (!health.isDead) {
      audio.play(Cue.diagramHit);
      return;
    }
    _broken = true;
    audio.play(Cue.diagramShapeBroken);
    // The Diagram Wizard counts itself in shapes, so that is what a break costs
    // it.
    final diagram = parent;
    if (diagram is DiagramWizardBoss) {
      final board = diagram.parent;
      if (board != null) {
        Impact.damage(
          board,
          diagram.arenaPositionOf(this) - Vector2(0, DiagramWizardBoss.nodeSize),
          '−1 shape',
        );
      }
    }
    // Out of the fight immediately, so the reflow it triggers already sees the
    // new shape count, but left on screen briefly so the break is visible.
    onBroken();
    add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.25, curve: Curves.easeInBack),
        onComplete: removeFromParent,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(10),
    );
    canvas.drawRRect(rrect, _fillPaint);
    canvas.drawRRect(rrect, _edgePaint);
  }
}
