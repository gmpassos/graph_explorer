## 1.1.0

- sdk: ^3.13.0

- `Node`:
  - Fix `isAlwaysRoot`: now `true` only for nodes created with `Node.root` (`Graph.root`),
    even after outputs are added, and `false` for ordinary root nodes.
- `IterableOfListNodeExtension.longestPaths`:
  - Fix: was returning shorter paths too when more than one path was shorter than the longest.
- Replaced deprecated `whereNotNull` with `nonNulls`.
- Dart 3 lints and formatting (initializing formals for private named parameters;
  public parameter names are unchanged).

- New tests for the public API (`test/graph_explorer_api_test.dart`): coverage 84% -> 98%.

- GitHub Actions: `actions/checkout@v7`, `codecov/codecov-action@v7`.

- collection: ^1.19.1
- lints: ^6.1.0
- dependency_validator: ^5.1.0
- test: ^1.33.0
- coverage: ^1.16.0

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
