## 1.0.2

- `GraphWalker`:
  - Added `extractAllEntries`.
- `Graph.fromJson`:
  - `maxExpansion` computed from `GraphWalker.extractAllEntries`.

## 1.0.1

- Added `AnyNode` and `NoneNode`.
- `Graph`:
  - Added `populate` and `populateAsync`.
  - Added `walkOutputsFrom` and `walkInputsFrom`.
  - Added `walkOutputsOrderFrom` and `walkInputsOrderFrom`.
  - Added `rootValues`, `valuesToNodes`.
  - Added `getNodes` and `getNodesNullable`.
- `Node`:
  - Added field `attachment`.
  - Added `roots`, `sideRoots`, `dependencies`, `missingDependencies`.
- `IterableNodeExtension`:
  - Added `merge` and `complement`.
  - Added `inputsInDepthIntersection`, `sortedByOutputDependency` and `sortedByInputDependency`.
- New `GraphWalker`.

- Removed `ascii_art_tree` dependency:
  - Package `ascii_art_tree 1.0.6` now uses `graph_explorer` internally (avoid dependency loop).
      - The `Graph` integration was moved to package `ascii_art_tree` as an extension.

- Improved tests coverage (80%+).

## 1.0.0

- Initial version.
