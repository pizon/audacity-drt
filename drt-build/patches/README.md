# DRT patches

Plain `git diff` patches that recreate DRT features on top of upstream Audacity 4.x.

| Patch | Summary |
|-------|---------|
| `0001-select-region-store-retrieve-selection.patch` | Select → Region Store/Retrieve; parks playhead at range start on retrieve |
| `0002-restore-audacity-3.7.9-default-shortcuts.patch` | Rewire default shortcuts onto live AU4 action names (see [KEYBINDS.md](KEYBINDS.md)) |
| `0003-paste-at-selection-start.patch` | Paste inserts at selection start, not the playhead |

```bash
cd /path/to/audacity   # clean upstream 4.x tree
git apply /path/to/drt-build/patches/0001-select-region-store-retrieve-selection.patch
git apply /path/to/drt-build/patches/0002-restore-audacity-3.7.9-default-shortcuts.patch
git apply /path/to/drt-build/patches/0003-paste-at-selection-start.patch
```

`0001` and `0002` may be applied in either order. Apply `0003` after `0001` if both are used (both touch `trackeditactionscontroller.cpp`).
