# Changelog

All notable DRT changes for this fork and its redistributable patches.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
AppImage builds are named `audacity-linux-4.0.2-drt-N.AppImage` (`N` from `.appimage-build-number`).

## [Unreleased]

## [drt-6] - 2026-11-11

Based on Audacity `release-4.0.2` / fork `master`.

### Added

- **Analyze → Plot Spectrum** — Qt/QML port of the Audacity 3.7.9 frequency analysis dialog, reusing `PlotSpectrumBase` + `SpectrumAnalyst`. Supports spectrum / autocorrelation / cepstrum, FFT size, window function, lin/log axis, grid, zoom/pan, cursor/peak readout, replot, and export. Patch: `patches/0005-plot-spectrum.patch`.

### Fixed

- **Paste inserts at the selection start**, not the playhead. Matches cut/delete and keeps L/R mono tracks aligned after a stereo split. Patch: `patches/0003-paste-at-selection-start.patch`.
- **Log-scale spectrogram ruler shows a usable scale.** Ticks fall on every decade (majors at 1, 2, 5 × 10ⁿ, minors at the other digits) instead of linear 5000 Hz steps, and label thinning keeps the roundest labels that fit, so short multi-view channels no longer drop to two or three labels. Patch: `patches/0004-log-scale-spectrogram-ruler-ticks.patch`.

## [drt-3] - 2026-11-05

Based on Audacity `release-4.0.2` / fork `master`.

### Added

- **Select → Region Store / Retrieve** — bookmark the time selection; Retrieve restores the range and parks the playhead at the selection start.
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
