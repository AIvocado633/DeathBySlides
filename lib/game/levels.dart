import 'combat/shrink_to_fit_boss.dart';
import 'combat/boss.dart';
import 'combat/diagram_wizard_boss.dart';

/// The deck the player has to get through.
///
/// Each level is one slide, and each boss is a presentation-software feature
/// that has personally wronged someone.
class LevelDefinition {
  const LevelDefinition({
    required this.number,
    required this.boss,
    required this.tagline,
    required this.winLine,
    required this.lossLine,
    this.buildBoss,
  });

  final int number;

  /// The feature's name, as the light table and the arena show it.
  final String boss;

  /// One line on the light table thumbnail.
  final String tagline;

  /// How the feature goes out, shown when the slide is won.
  final String winLine;

  /// How the feature got you, shown when the slide is lost.
  final String lossLine;

  /// Builds the feature standing in the way, or null while its fight has not
  /// been written yet.
  final BossBuilder? buildBoss;

  /// Whether this slide's fight exists in this build of the game. Whether the
  /// player has earned it yet is a separate question.
  bool get isBuilt => buildBoss != null;
}

/// The level with this [LevelDefinition.number].
LevelDefinition levelNumbered(int number) =>
    kLevels.firstWhere((level) => level.number == number);

const List<LevelDefinition> kLevels = [
  LevelDefinition(
    number: 1,
    boss: 'Shrink-to-Fit',
    tagline: 'Shrinks your text on sight',
    winLine: 'Shrink-to-Fit shrank itself out of the deck. One feature down.',
    lossLine: 'Shrink-to-Fit shrank you until you no longer fit on the slide.',
    buildBoss: ShrinkToFitBoss.new,
  ),
  LevelDefinition(
    number: 2,
    boss: 'Diagram Wizard',
    tagline: 'No diagram, no wizardry',
    winLine: 'The Diagram Wizard ran out of shapes to shuffle. Two down.',
    lossLine: 'The Diagram Wizard rearranged you right off the slide.',
    buildBoss: DiagramWizardBoss.new,
  ),
  LevelDefinition(
    number: 3,
    boss: 'Master Template',
    tagline: 'Changes everything at once',
    winLine: 'The Master Template has been overruled.',
    lossLine: 'The Master Template changed you, along with everything else.',
  ),
  LevelDefinition(
    number: 4,
    boss: 'Build Order',
    tagline: 'Seventeen triggers, no order',
    winLine: 'The Build Order is finally empty.',
    lossLine: 'Your exit animation was set to On Click. Someone clicked.',
  ),
  LevelDefinition(
    number: 5,
    boss: 'Snap to Grid',
    tagline: 'Almost where you wanted it',
    winLine: 'Snap to Grid has been switched off. Nothing lines up. It is fine.',
    lossLine: 'You were snapped to the nearest gridline and left there.',
  ),
  LevelDefinition(
    number: 6,
    boss: 'Legacy Format',
    tagline: 'Last saved in 2003',
    winLine: 'Saved in a format from this century at last.',
    lossLine: 'The old file format could not keep you. Nothing personal.',
  ),
];
