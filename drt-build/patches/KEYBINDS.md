# Audacity 3.7.9-style keybinds on Audacity 4

## Why this exists

Audacity 4 renamed a large set of UI actions. The default `shortcuts.xml`
shipped with 4.x still listed many of the **old** action keys, so chords
that worked in 3.7.9 were bound to names the new app never listens for.
From the user’s point of view the keys simply “did nothing.”

DRT rewires those bindings onto the **live** Audacity 4 action names and
puts back a few AU3-default sequences that 4.x left empty. The goal is
muscle memory for Desert Road Trips editing, not a full redesign of the
keymap.

Patch: `0002-restore-audacity-3.7.9-default-shortcuts.patch`  
Full file: `../configs/shortcuts.xml` (drop-in copy of the modified defaults)  
Upstream path: `src/app/configs/data/shortcuts.xml`

## Action-key remaps

| AU3 / stale key in 4.x XML | Live AU4 key |
|----------------------------|--------------|
| `contrast-analyser` | `contrast-analyzer` |
| `sel-prev-clip` | `select-previous-clip` |
| `sel-next-clip` | `select-next-clip` |
| `split-new` | `split-into-new-track` |
| `preferences` | `preference-dialog` |
| `track-close` | `track-delete` |
| `skip-sel-start` | `skip-to-selection-start` |
| `skip-sel-end` | `skip-to-selection-end` |

## Sequences restored or reassigned

| Chord | Action |
|-------|--------|
| `Ctrl+Y` | redo (also keeps `Ctrl+Shift+Z`) |
| `Ctrl+K` | delete |
| `Ctrl+P` | preferences (also keeps `Ctrl+,`) |
| `F11` | fullscreen |
| `Ctrl+M` | add-label-playing (also keeps `Ctrl+.`) |
| `Ctrl+Alt+X` | cut-leave-gap |
| `Ctrl+Alt+K` | delete-leave-gap |
| `Shift+R` | record-on-new-track |
| `Ctrl+Shift+X` | expand-all-tracks (no longer on cut-per-track-ripple) |

`Ctrl+F2` was removed from `accessibility-dev-show-tree` and placed on
its AU4 counterpart (see the patch diff).

## Applying

Patch (preferred when you want a reviewable delta):

```bash
cd /path/to/audacity   # clean upstream 4.x tree
git apply /path/to/drt-build/patches/0002-restore-audacity-3.7.9-default-shortcuts.patch
```

Or replace the shipped file wholesale:

```bash
cp /path/to/drt-build/configs/shortcuts.xml \
   /path/to/audacity/src/app/configs/data/shortcuts.xml
```

Existing user shortcut customizations in the profile may still override
these defaults; reset shortcuts in Preferences if an old binding sticks.

## Scope

Linux / Fedora DRT builds only. No claim that every AU3 chord is
recreated—only the ones that were dead because of renamed action keys,
plus a short list of everyday AU3 defaults used in show production.
