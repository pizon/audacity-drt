# DRT patches

Plain `git diff` patches that recreate DRT features on top of upstream Audacity 4.x.

| Patch | Summary |
|-------|---------|
| `0001-select-region-store-retrieve-selection.patch` | Select → Region Store/Retrieve; playhead parked at range start so paste inserts correctly |
| `0002-restore-audacity-3.7.9-default-shortcuts.patch` | Rewire default shortcuts onto live AU4 action names (see [KEYBINDS.md](KEYBINDS.md)) |

```bash
cd /path/to/audacity   # clean upstream 4.x tree
git apply /path/to/drt-build/patches/0001-select-region-store-retrieve-selection.patch
git apply /path/to/drt-build/patches/0002-restore-audacity-3.7.9-default-shortcuts.patch
```

Order does not matter; the patches touch different files.
