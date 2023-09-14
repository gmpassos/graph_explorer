## 1.0.1

- Added `AnyNode` and `NoneNode`.
- `Graph`:
  - Added `populate` and `populateAsync`.
  - Added `walkOutputsFrom` and `walkInputsFrom`.
  - Added `rootValues`, `valuesToNodes`.
- `Node`:
  - Added field `attachment`.
- New `GraphWalker`.

- Removed `ascii_art_tree` dependency:
  - Package `ascii_art_tree 1.0.6` now uses `graph_explorer` internally (avoid dependency loop).
      - The `Graph` integration was moved to package `ascii_art_tree` as an extension.

## 1.0.0

- Initial version.
