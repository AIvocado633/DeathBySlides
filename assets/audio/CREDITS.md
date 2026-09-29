# Audio credits

Every sound in this folder is original to Death by Slides. None is sampled,
downloaded or taken from any other product: each one is synthesised from
oscillators and noise by [`tool/make_sounds.py`](../../tool/make_sounds.py),
which rebuilds them all:

```bash
python tool/make_sounds.py
```

They are released with the game's own code, and additionally dedicated to the
public domain under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/),
so anyone may reuse them.

The *idea* of a click per bullet, a whoosh, a drum roll and applause comes from
the stock animation sounds slide editors used to ship. Their recordings belong
to their makers and are not used here.

| File | What it is | Source | Licence |
| --- | --- | --- | --- |
| `click.wav` | A bullet point fired | `tool/make_sounds.py` | CC0 1.0 |
| `player_hit.wav` | The presenter shrinking a size | `tool/make_sounds.py` | CC0 1.0 |
| `player_lost.wav` | Deflating: a slide lost | `tool/make_sounds.py` | CC0 1.0 |
| `shrink_to_fit_hit.wav` | Shrink-to-Fit losing a point size | `tool/make_sounds.py` | CC0 1.0 |
| `shrink_to_fit_defeated.wav` | Shrink-to-Fit shrinking to nothing | `tool/make_sounds.py` | CC0 1.0 |
| `diagram_hit.wav` | A Diagram Wizard shape knocked | `tool/make_sounds.py` | CC0 1.0 |
| `diagram_break.wav` | A shape breaking off the diagram | `tool/make_sounds.py` | CC0 1.0 |
| `diagram_reflow.wav` | The diagram re-laying itself out | `tool/make_sounds.py` | CC0 1.0 |
| `diagram_defeated.wav` | The diagram collapsing | `tool/make_sounds.py` | CC0 1.0 |
| `whoosh.wav` | A page flying in | `tool/make_sounds.py` | CC0 1.0 |
| `drum_roll.wav` | Into a fight | `tool/make_sounds.py` | CC0 1.0 |
| `applause.wav` | A slide won | `tool/make_sounds.py` | CC0 1.0 |
| `template_hit.wav` | A Master Template layout knocked | `tool/make_sounds.py` | CC0 1.0 |
| `template_layout_off.wav` | A layout stripped off the master | `tool/make_sounds.py` | CC0 1.0 |
| `theme_warning.wav` | *Applying theme…* | `tool/make_sounds.py` | CC0 1.0 |
| `theme_applied.wav` | A new theme landing on everything | `tool/make_sounds.py` | CC0 1.0 |
| `template_closed.wav` | The Master Template closing | `tool/make_sounds.py` | CC0 1.0 |
| `build_tag_hit.wav` | A Build Order tag knocked | `tool/make_sounds.py` | CC0 1.0 |
| `build_step_deleted.wav` | A step deleted from the Build Order | `tool/make_sounds.py` | CC0 1.0 |
| `build_reorder.wav` | The Build Order reordering itself | `tool/make_sounds.py` | CC0 1.0 |
| `build_step_started.wav` | A build step starting | `tool/make_sounds.py` | CC0 1.0 |
| `build_emptied.wav` | The Build Order emptied | `tool/make_sounds.py` | CC0 1.0 |
| `menu_loop.wav` | Menu music: hold music for a template | `tool/make_sounds.py` | CC0 1.0 |
| `fight_loop.wav` | Fight music: the same template, at a deadline | `tool/make_sounds.py` | CC0 1.0 |

Adding a sound from anywhere else? List it here with its source and licence,
and only use it if that licence allows shipping it in the game (CC0 is
simplest).
