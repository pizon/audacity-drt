# DRT build tooling

Podman-based Fedora 44 build and packaging for this fork.

Kept under `drt-build/` so Containerfiles, scripts, and local patches stay out of Audacity’s own `src/` tree while still living in the fork repository.

Release notes for DRT features and AppImage builds: [CHANGELOG.md](CHANGELOG.md).

## Layout

| Path | Purpose |
|------|---------|
| `Containerfile` | Fedora 44 image with Qt 6, cmake, ninja, AppImage tools deps |
| `build-image.sh` | Build / tag the Podman image |
| `configure-build.sh` | Configure, build, install into `../build/` |
| `package-appimage.sh` | Portable AppImage → `../dist/audacity-linux-4.0.2-drt-N.AppImage` |
| `run.sh` / `run-podman.sh` | Run the installed binary on the host or in the container |
| `shell.sh` | Interactive shell in the build container |
| `patches/` | DRT feature patches that can be applied to upstream |
| `configs/shortcuts.xml` | Full copy of the DRT default keymap (see `patches/KEYBINDS.md`) |

## Quick start

```bash
cd drt-build
./build-image.sh
./configure-build.sh
./package-appimage.sh
```

Default source tree: the fork root (`..`). Override with `SRC_DIR=` if needed.

If you already have the older `localhost/audacity4-build:fedora44` image:

```bash
podman tag localhost/audacity4-build:fedora44 localhost/audacity-drt-build:fedora44
```

## Applying DRT patches to upstream

From a clean Audacity 4.x checkout:

```bash
git apply /path/to/audacity-drt/drt-build/patches/0001-select-region-store-retrieve-selection.patch
git apply /path/to/audacity-drt/drt-build/patches/0002-restore-audacity-3.7.9-default-shortcuts.patch
git apply /path/to/audacity-drt/drt-build/patches/0003-paste-at-selection-start.patch
```

These are plain `git diff` patches; use `git apply` (not `git am`). Details for each patch live under `patches/`, including [patches/KEYBINDS.md](patches/KEYBINDS.md) for the shortcut remaps.
