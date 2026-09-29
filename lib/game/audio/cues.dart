/// Every sound effect in the game, and how often each may overlap itself.
///
/// The files live in `assets/audio/` and are synthesised by
/// `tool/make_sounds.py`; [length] is each file's duration, which is how the
/// game knows a voice has finished without asking the platform.
enum Cue {
  /// A bullet point leaving the presenter. The one cue a player can trigger
  /// several times a second, so it is the one most tightly capped.
  bulletPoint('click.wav', length: 0.05, maxVoices: 3),

  /// The presenter shrinking a size.
  playerHit('player_hit.wav', length: 0.22),

  /// The presenter spinning out: something deflating.
  playerLost('player_lost.wav', length: 1.1, maxVoices: 1),

  shrinkToFitHit('shrink_to_fit_hit.wav', length: 0.1, maxVoices: 3),
  shrinkToFitDefeated('shrink_to_fit_defeated.wav', length: 0.7, maxVoices: 1),

  diagramHit('diagram_hit.wav', length: 0.12, maxVoices: 3),
  diagramShapeBroken('diagram_break.wav', length: 0.35),
  diagramReflow('diagram_reflow.wav', length: 0.4, maxVoices: 1),
  diagramDefeated('diagram_defeated.wav', length: 1, maxVoices: 1),

  /// A layout knocked on the Master Template.
  templateHit('template_hit.wav', length: 0.12, maxVoices: 3),

  /// A layout stripped off the master.
  templateLayoutOff('template_layout_off.wav', length: 0.45),

  /// "Applying theme…": the warning before the rules change.
  themeWarning('theme_warning.wav', length: 1.2, maxVoices: 1),

  /// The new theme landing on everything at once.
  themeApplied('theme_applied.wav', length: 0.8, maxVoices: 1),

  /// The Master Template closed for good.
  templateClosed('template_closed.wav', length: 1.1, maxVoices: 1),

  /// A Build Order tag knocked.
  buildTagHit('build_tag_hit.wav', length: 0.1, maxVoices: 3),

  /// A step deleted from the Build Order.
  buildStepDeleted('build_step_deleted.wav', length: 0.4),

  /// The Build Order reordering itself.
  buildReorder('build_reorder.wav', length: 0.6, maxVoices: 1),

  /// A build step starting: its attack is coming.
  buildStepStarted('build_step_started.wav', length: 0.3),

  /// The Build Order emptied at last.
  buildEmptied('build_emptied.wav', length: 1.2, maxVoices: 1),

  /// A page's fly-in entrances. Several things fly in at once, so it plays
  /// once per page rather than once per thing.
  whoosh('whoosh.wav', length: 0.42, maxVoices: 1),

  /// Into a fight.
  drumRoll('drum_roll.wav', length: 2.2, maxVoices: 1),

  /// A slide won.
  applause('applause.wav', length: 2.6, maxVoices: 1);

  const Cue(this.file, {required this.length, this.maxVoices = 2});

  /// The file under `assets/audio/`.
  final String file;

  /// How long the file plays, in seconds.
  final double length;

  /// How many copies may sound at once. One more is dropped rather than
  /// piled on, so a stream of shots stays a rhythm rather than a roar.
  final int maxVoices;
}

/// The music loops.
enum Track {
  /// Hold music for the menus, the way a template sounds while you wait.
  menu('menu_loop.wav'),

  /// The same template, at a deadline.
  fight('fight_loop.wav');

  const Track(this.file);

  final String file;
}
