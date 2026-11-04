# DRT patches

Plain `git diff` patches that recreate DRT features on top of upstream Audacity 4.x.

| Patch | Summary |
|-------|---------|
| `0001-select-region-store-retrieve-selection-and-playhead.patch` | Select → Region Store/Retrieve, including playhead |

```bash
cd /path/to/audacity   # clean upstream 4.x tree
git apply /path/to/drt-build/patches/0001-select-region-store-retrieve-selection-and-playhead.patch
```
