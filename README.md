# Death by Slides

[![CI](https://github.com/AIvocado633/DeathBySlides/actions/workflows/ci.yml/badge.svg)](https://github.com/AIvocado633/DeathBySlides/actions/workflows/ci.yml)

A 2D mobile game about defeating the presentation-software features that
defeated you.

Each level is a slide. Each boss is a feature — Shrink-to-Fit, the Diagram
Wizard, the Master Template, the Build Order. You fight them from a top-down
view inside the slide, with a character built out of autoshapes.

The game takes place inside a made-up slide editor with a look of its own —
ink-navy chrome, warm paper slides, a teal accent, and the Braille Institute's
[Atkinson Hyperlegible](https://www.brailleinstitute.org/freefont/) typeface
(SIL Open Font License, see `assets/fonts/OFL.txt`) — so it is about slideware in
general, not a homage to any one product. It is not affiliated with or endorsed
by the makers of any presentation software.

Built with Flutter and the [Flame](https://flame-engine.org) engine.

## Status

Slides 1 and 2 are playable end to end. The other four bosses are named but
not built.

- **Start menu** — a title slide in the editor's normal view, with toolbar,
  status bar, dashed placeholders and staggered fly-in entrances.
- **Light Table** — level select, showing all six slides (see *Progression*
  below).
- **Slide show** — two fights so far, Shrink-to-Fit and the Diagram Wizard,
  with twin-stick controls (see below).
- **Tweaks** — settings for controls and motion (see below). Sound settings
  follow once the game has sound.

### Progression

The deck is played in order. Slide 1 is always open; every other slide opens
once the one before it is won, and stays open, because wins are saved on the
device. Any slide you have opened can be replayed.

- **Light Table** — each thumbnail shows where its slide stands: a star
  under a slide you have beaten (the mark slide editors give slides with
  animations), a plain slide when it is open, a greyed-out slide with a bolt
  when it is locked, and a faded *hidden slide*, number struck through, when
  its boss has not been built yet.
- **Winning** a slide offers **Next Slide** first, then Retry Slide and Walk
  Off. Beating the last slide that has been built ends on the same dialog
  without Next Slide, until the rest of the deck exists.
- **Start menu** — *Start Presenting* (F5) on a fresh deck. Once you have won
  something it becomes *Carry On* (Shift+F5) and opens the first
  slide you have not won yet, which is also the slide the status bar shows.
  The footer counts down the features still in the way.

### Controls

Twin-stick: one input moves, the other aims, and pushing the aim in any
direction fires that way immediately — there is no fire button.

|           | Touch             | Keyboard                         | Controller          |
| --------- | ----------------- | -------------------------------- | ------------------- |
| **Move**  | left thumb stick  | WASD                             | left stick          |
| **Aim**   | right thumb stick | arrow keys                       | right stick         |
| **Menus** | tap               | arrows, Enter or Space, Esc      | D-pad or left stick, A, B |
| **Pause** | Pause chip        | B or `.`                         | Start               |

All three work at once, so you can pick up a controller mid-fight.

Menus work without touching the screen. Arrows, the D-pad or the left stick
move focus, drawn as a shape selection; the light table moves across its
grid. Enter, Space or A chooses, and Esc or B goes back. On the start menu,
F5 starts the show from the beginning and Shift+F5 from the current slide, as
in most presenting software. Mid-fight, Esc or B opens the pause menu (see below). On
Android the back gesture goes back a step — during a fight it pauses instead —
and only leaves the app from the title slide.

### Pausing

During a real presentation, **B** blanks the screen until you press it again, so
that is what pausing looks like: the fight freezes behind a black slide
offering Resume, Retry Slide and Walk Off. `.`, controller **Start** and the
**Pause** chip do the same.

Nothing advances while paused — movement, shot cooldowns, boss timers and
shots already in the air all stop together, because the whole board is one
frozen time scale — and resuming never fires a shot queued behind the menu.

Leaving a fight takes two steps now: Esc, back or the **Walk Off** chip opens
the pause menu with Walk Off already chosen, so one stray tap or key press
cannot lose a fight. Pressing Esc again ends it, as in any slide show.

The fight also pauses itself when the app goes away — a notification, a call,
another app, or a desktop window losing focus — and stays paused on the way
back, so nobody returns mid-dodge. Space still
fires along the way you are walking, for anyone who would rather not aim.
Controllers come through the Flame team's
[`gamepads`](https://pub.dev/packages/gamepads) package, whose normalized
events map every platform's pad onto the same Xbox-style layout.

Each fight is built out of the feature's own behaviour rather than out of a
health bar with a new sprite on it.

### Tweaks

Settings live in the editor's Tweaks panel, built from its own controls:
dialog checkboxes, and sliders borrowed from the status bar's zoom slider,
which finally does something. Everything can be reached with arrows, the D-pad
or the left stick — left and right move a focused slider — and every change is
saved and applied the moment it is made.

- **Swap sticks** moves on the right thumb and aims on the left, for
  left-handed players. Touch only: keys and controller sticks stay put.
- **Controller dead zone**, 5–40%, 20% by default: how far a stick must travel
  before it counts. Raise it if a worn stick walks the player on its own.
- **Thumb stick size**, 80–125%, for small phones or big thumbs.
- **Reduce Motion** stills everything that is only decoration: fly-in
  entrances (things simply appear), the drifting autoshapes on the title
  slide, the actors' idle bob, and every hit flash, squash and shake. The
  fight itself — walking, shots, bosses moving — is untouched. Until the
  player chooses, it follows the device's own setting (Android's *Remove
  animations*), checked again whenever the app comes back.

### Slide 1 — Shrink-to-Fit

Shrink-to-Fit shrinks whatever does not fit, so the fight turns that on both
sides. Every hit the boss lands makes the player smaller; every bullet point
that lands steps the boss down a ladder of point sizes, the way text shrinks
when it overflows its box, from 54 pt to nothing. Whoever runs out of size first loses
the slide.

Shrinking is not purely a punishment. A smaller player is quicker and a
narrower target, and can squeeze closer to the walls — the trade is that you
have less room left to lose.

### Slide 2 — Diagram Wizard

The Diagram Wizard is not one target but six connected shapes. Break one and the
survivors immediately re-lay themselves out into the next layout — cycle,
process, hierarchy, pyramid — closing ranks and throwing your aim away, which
is exactly what an auto-diagram does to a slide the moment you add or remove a
line.
It fights back by throwing its connector arrows at you.

Where Shrink-to-Fit is one target that gets smaller, the Diagram Wizard is
many targets that
keep moving: same controls, a completely different problem.

### How a hit feels

A hit is never just a number going down. Whatever was hit flashes and squashes,
the board shakes when the player takes one, and what the hit cost floats off it
in that side's own units — `−6 pt` off Shrink-to-Fit, `−1 shape` off the Diagram Wizard, `−13%`
off the player. Health is never a bar in this game, so the numbers say what the
readouts say.

After a hit the player is briefly untouchable, blinking, so two shots arriving
together cost one size rather than two. Both bosses fire slower than that
window, so it only ever swallows shots that arrive at once; a test holds them
to that. Bosses get no such mercy: every bullet point in a stream counts.

Losing plays an *exit* animation — the player spins out — and the result
dialog waits for it to finish. A boss beaten during those last moments does
not steal the win.

Every flash, squash and shake goes through `lib/game/combat/impact.dart`, so
Reduce Motion turns them all off from one switch. Damage numbers stay:
they are what happened, not decoration.

## Running it

```bash
flutter run
```

On Windows there is also a script that builds a standalone copy and starts it,
the way a player would launch the game rather than a developer:

```bat
run-windows.bat
```

With no argument it makes a release build; pass `debug` or `profile` for the
other configurations. Double-clicking it works, and the game keeps running
after the console window closes. For a hot-reload loop use `flutter run -d
windows` instead.

Progress is saved on the device as soon as a slide is won. On Windows it lives
in `%APPDATA%\com.deathbyslides\Death by Slides\shared_preferences.json`; delete
that file to start the deck over.

To work on a boss without playing through the deck first, open every built
slide with a developer switch:

```bash
flutter run --dart-define=UNLOCK_ALL=true
```

It changes what is open, never what is saved. Tests set the same switch
through `DeathBySlidesGame(unlockAll: true)`.

Android, iOS and Windows are configured.

The game is **landscape only**. The layout is a 16:9 slide, letterboxed onto
whatever screen it gets, exactly the way a real deck behaves in slide show
mode. That is locked in three places, all of which are needed:

| Layer | Setting |
| --- | --- |
| Android | `android:screenOrientation="sensorLandscape"` on the activity, so even the launch theme cannot appear in portrait |
| iOS | `Info.plist` declares only the two landscape orientations, on phone and iPad |
| Dart | `Flame.device.setLandscape()` at startup, on mobile only |

`test/orientation_test.dart` guards all three, because re-running
`flutter create` regenerates the platform files from templates that allow
portrait.

On desktop the window stays freely resizable, as desktop windows should be; the
slide just letterboxes inside whatever shape it is given.

```bash
flutter test      # unit and layout tests
flutter analyze   # lints
```

CI runs both on every pull request, alongside debug builds for Android and
Windows — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml). The
workflow pins the Flutter version, so bump it together with `.metadata` when
upgrading the SDK.

To preview in a browser instead, add the web platform back with
`flutter create --platforms=web .`.

## How it is put together

```
lib/
  main.dart                  App shell; sets landscape, hosts the GameWidget
  game/
    death_by_slides_game.dart  FlameGame + RouterComponent; one route per screen
    routes.dart              Route names
    levels.dart              The six slides, and the boss each one builds
    combat/impact.dart       Hit flashes, shakes and damage numbers, in one place
    deck.dart                Which slides are open, given what has been won
    slide/
      slide_metrics.dart     The 1280x720 design canvas and its margins
      slide_page.dart        Base page: scales and letterboxes the slide
      fly_in.dart            The fly-in entrance animation, as an extension
      focusable.dart         What keyboard and controller focus can land on
      motion.dart            The one Reduce Motion switch decoration obeys
    input/                   Controller state, and keys and buttons as menu actions
    pages/                   One file per screen
    components/              Toolbar, status bar, placeholders, buttons, actors
    art/shape_art.dart        Loads exported PNG frames
    save/                    Progress and settings, kept as one JSON document
    theme/                   The made-up editor's colours and text styles
assets/images/               Exported artwork (see docs/)
assets/fonts/                Atkinson Hyperlegible, bundled, with its licence
```

Two conventions carry most of the weight:

**Everything is measured in slide units.** Layout code works against a fixed
1280×720 canvas and never sees device pixels; `SlidePage` handles the scaling
and centring. `test/slide_layout_test.dart` holds pages to that canvas.

**Artwork is optional.** `ShapeActor` draws a procedural stand-in when its PNG
frames are missing, so the game runs before the art exists.

## Drawing the monsters

Characters are built from plain autoshapes in any slide or vector editor and
exported as PNG — see
[docs/art-pipeline.md](docs/art-pipeline.md).
