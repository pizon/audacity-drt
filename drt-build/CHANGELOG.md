# Changelog

All notable DRT changes for this fork and its redistributable patches.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
AppImage builds are named `audacity-linux-4.0.2-drt-N.AppImage` (`N` from `.appimage-build-number`).

## [Unreleased]

### Added

- This changelog under `drt-build/`.

## [drt-3] - 2026-11-05

Based on Audacity `release-4.0.2` / fork `master`.

### Added

- **Select → Region Store / Retrieve** — bookmark the time selection; Retrieve restores the range and parks the playhead at the selection start so Paste inserts at the left edge (AU4 paste follows the playhead, not the selection alone).
- **AU3-style default shortcuts** — rewire bindings onto live Audacity 4 action names and restore a short set of everyday 3.7.9 chords (`Ctrl+Y` redo, `Ctrl+K` delete, `F11` fullscreen, etc.). See `patches/KEYBINDS.md`.
- **`drt-build/` Podman tooling** — Fedora 44 Containerfile, configure/build/package scripts, AppImage packaging with host patchelf 0.18 and strip skipped to avoid RELR corruption.
- **Redistributable patches** (plain `git apply`):
  - `patches/0001-select-region-store-retrieve-selection.patch`
  - `patches/0002-restore-audacity-3.7.9-default-shortcuts.patch`
- **`configs/shortcuts.xml`** — full copy of the DRT default keymap for drop-in use.
- Fork README preamble documenting DRT intent, AI-assisted history, patch-first distribution, Fedora 44 / Linux-only scope.

### Fixed

- Region Retrieve no longer restores an independent mid-selection cursor; that left Paste inserting inside the restored range instead of at its start.

### Changed

- Force-track `drt-build/build-image.sh` despite the repo root `build-*` gitignore pattern.
