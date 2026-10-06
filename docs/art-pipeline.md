# Drawing the monsters

Every character in this game — the player and the features they are fighting —
is built out of plain autoshapes in a slide editor and exported as PNG. That is
a hard constraint: if a sprite could not have been built out of rectangles,
ovals and arrows, it does not belong in the game.

Any slide or vector editor will do (LibreOffice Impress, Keynote, Inkscape, …).
The steps below happen to use PowerPoint, because that is what the first
sprites were drawn in; the game itself is not tied to any one editor.

This document is the contract between the deck and the code.

![The cast: the presenter, Shrink-to-Fit, the Diagram Wizard, the Master
Template and Snap to Grid, idle, blinking, hit and beaten](images/cast.png)

## Where things live

| What | Where |
| --- | --- |
| Source decks | `art/<actor>_<state>.pptx`, and `art/launcher_icon.pptx` |
| Exported frames | `assets/images/` |
| Export | [`tool/export_art.py`](../tool/export_art.py), or [`tool/export-art.ps1`](../tool/export-art.ps1) through PowerPoint |
| Loader | [`lib/game/art/shape_art.dart`](../lib/game/art/shape_art.dart) |
| Component that draws an actor | [`lib/game/components/shape_actor.dart`](../lib/game/components/shape_actor.dart) |

## Naming

Frames are a zero-padded sequence sharing a prefix:

```
assets/images/hero_idle_000.png
assets/images/hero_idle_001.png
assets/images/hero_idle_002.png
```

Each sequence loads `000`, `001`, … and stops at the first missing number. A
single still is just a one-frame sequence.

### States

The prefix is `<actor>_<state>_`, and every state is optional except `idle`:

| State | Plays | Used when |
| --- | --- | --- |
| `idle` | loops | standing still — the fallback for everything else |
| `walk` | loops | moving |
| `hit` | once, then back to `idle` or `walk` | taking a hit |
| `die` | once, holding the last frame | beaten; the exit effects run on top |
| `cheer` | loops | pleased with itself: the presenter on the title slide once the deck is done |

Which actors use which:

| Actor | Prefix | States it plays |
| --- | --- | --- |
| The presenter (menu and fights) | `hero` | `idle`, `walk`, `hit`, `die`, `cheer` |
| Shrink-to-Fit | `shrink_to_fit` | `idle`, `hit`, `die` |
| Diagram Wizard — one shape, repeated for every node | `diagram_wizard` | `idle`, `hit`, `die` |
| Master Template — the face on the master thumbnail | `master_template` | `idle`, `hit`, `die` |
| Snap to Grid — the face in the grid dialog | `snap_to_grid` | `idle`, `hit`, `die` |

### Directions

Art can also be drawn per direction, as `<actor>_<state>_<dir>_`, for the five
directions `s`, `se`, `e`, `ne` and `n`. The other three are the mirror image
of their eastern twin (`sw` of `se`, `w` of `e`, `nw` of `ne`), so they are
never drawn. Only the presenter turns, so only `hero` gains anything from
directional art; bosses always face the player (`s`).

```
assets/images/hero_walk_e_000.png   walking east, and mirrored for west
assets/images/hero_walk_n_000.png   walking north
```

### What is shown when art is missing

For a state and a facing, the first of these that exists is shown:

1. `<actor>_<state>_<dir>_` — that state, drawn for that direction
2. `<actor>_<state>_` — that state, drawn once for every direction
3. `<actor>_idle_<dir>_` — idle, drawn for that direction
4. `<actor>_idle_` — idle

An actor with only idle frames therefore looks exactly as it did before
states existed. When `hit` falls back to idle, idle keeps looping and the hit
simply lasts 0.3 seconds. Without any idle frames the actor draws its
procedural stand-in throughout (see below). Every actor's frames load once and
are shared, so switching state never touches the disk.

## Drawing rules

- **One pose per slide.** Slide 1 is frame `000`, slide 2 is frame `001`, and
  so on. Keep each animation in its own deck.
- **Keep the character the same size and in the same place on every slide**, or
  it will jitter when the frames play. Use *View ▸ Guides* and leave the
  character's feet on the same guide in every pose.
- **Draw at roughly 512×512.** Sprites are scaled down in game, so exporting
  larger than you need costs nothing but a few KB and keeps them crisp on
  high-DPI phones.
- **Draw on a square slide, 512 × 512 px** (5.33 in). The decks under `art/`
  already are.
- **Group each pose** (select everything on the slide, <kbd>Ctrl</kbd>+<kbd>G</kbd>).
  Export needs one shape per slide, and grouping also stops you nudging a leg
  out of place by accident. The export refuses a slide with anything else on
  it.
- **Keep the invisible frame in the group.** Every pose in `art/` holds a
  square with no fill and no line, named *Frame*, covering the whole slide.
  *Save as Picture* writes a group's bounds, so without it a raised arm would
  make that frame bigger and the animation would jump. Copy a slide to start
  a new pose, and the frame comes with it.

## Exporting

One command regenerates every PNG from the decks:

```bash
python tool/export_art.py                       # every deck
python tool/export_art.py art/hero_walk.pptx    # just one
```

It needs Python with `python-pptx`, `numpy` and `Pillow`, LibreOffice and
poppler (`pdftocairo`), all free and the same on every desktop. For each
`art/<actor>_<state>.pptx` it:

1. checks every deck against the drawing rules above, and stops with the deck
   and slide that breaks one before writing anything;
2. deletes that sequence's old frames, so a slide removed from the deck does
   not leave a stale `…_007.png` behind;
3. writes one `<actor>_<state>_NNN.png` per slide, 512 × 512, on a
   transparent background.

LibreOffice paints every page white when it exports, so each deck is
rendered twice, on white and on black. How far the two differ at each pixel
is how transparent it is, which recovers soft edges exactly.

`art/launcher_icon.pptx` becomes the app's launcher icons: Android's
mipmaps, the iOS app icon set and the Windows `.ico`, all from one 1024 px
render. App icons are opaque, so draw its background in.

### Through PowerPoint

On Windows with PowerPoint installed, the same export for the actor decks
can go through PowerPoint itself, with nothing else to install:

```powershell
powershell -ExecutionPolicy Bypass -File tool\export-art.ps1
powershell -ExecutionPolicy Bypass -File tool\export-art.ps1 art\hero_walk.pptx
```

It applies the same checks, deletes stale frames the same way, and exports
each slide's group with PowerPoint's own *Save as Picture*. It was written
without PowerPoint to hand: check the first few files it writes before
trusting a whole run. The launcher icon still goes through
`tool/export_art.py`.

### By hand

For a frame or two: select the group, right-click ▸ **Save as Picture…**,
choose **PNG**, and save it as `assets/images/<actor>_<state>_NNN.png`.
PowerPoint writes the shape's own bounds with a transparent background.

### Where the decks came from

The first decks were drawn by [`tool/draw_cast.py`](../tool/draw_cast.py),
which builds every pose out of autoshapes. The decks are the source now: edit
them in a slide editor and re-export. Running `draw_cast.py` again starts
over, and overwrites them.

## Using the art in game

Drop the PNGs into `assets/images/` and restart the app (a hot *reload* will not
pick up new assets; hot *restart* or a full run will). Nothing else is needed:
`assets/images/` is registered wholesale in `pubspec.yaml`, and `ShapeActor`
looks its frames up by prefix.

```dart
ShapeActor(
  actor: 'hero',
  size: Vector2.all(230),
)
```

The actor picks its frames itself from what it is doing: set `walking` and
`facing`, and call `hit()` and `die()`.

### Without art

`ShapeActor` falls back to a procedural stand-in — a monster made of the same
autoshapes the real art is made of — so a new actor can be put into the game
before its deck is drawn. The tests see it too: they run without Flutter's
test binding, so the asset bundle looks empty to them, except in
`test/art_test.dart`, which checks the shipped art itself. It acts out the states too: a waddle to
walk, a squash with screwed-shut eyes when hit, and crossed-out eyes when it
dies. You will see one line per missing actor in
the console:

```
ShapeArt: no frames named "hero_idle_000.png" in assets/images/ - falling back to placeholder art.
```

That message disappears on its own once the frames are in place.

## Adding a new monster

1. Draw it in a new deck, one pose per slide, one deck per state: copy an
   existing deck under `art/` and rename it `<actor>_<state>.pptx`, so the
   slide size and the invisible frame come with it.
2. Run `python tool/export_art.py`, and add the actor to the cast in
   `test/art_test.dart`.
3. Add a `ShapeActor(actor: '<actor>')` where you want it, and call `hit()` and
   `die()` on it where the boss takes a hit and is beaten.
4. If it is a boss, set its slide's `buildBoss` in `kLevels`, in
   [`lib/game/levels.dart`](../lib/game/levels.dart), to its constructor. The
   arena needs no changes.
