## 1.1.2

- `GraphWalker`:
  - Fix `maxDepth`: a step beyond `maxDepth` was counted as processed, so a DFS
    walk could skip a node reached first beyond `maxDepth` and then again within it.
    Affects `walk`, `walkAsync`, `walkByNodes`, `walkByNodesAsync` and `walkOrder`,
    and so `Node.outputsInDepth` / `inputsInDepth` / `sideRoots` with `maxDepth`
    (e.g. `outputsInDepth(maxDepth: 1)` now returns every direct output).
    A DFS with `maxDepth >= 2` can still miss a node whose ancestor was reached first
    at a deeper level; use `bfs: true` for an exact depth limit.
- New tests: coverage 98.4% -> 99.4%.
  - Property tests over seeded random graphs (DAGs, cycles, self-loops, diamonds,
    long chains, disconnected components): scanner paths vs. brute-force path
    enumeration, shortest/longest path invariants, reachability, BFS/DFS walk
    orders, `toJson`/`fromJson` round-trips (`String` and `int` nodes),
    sync vs. async APIs.
  - Integration test querying a package dependency graph loaded from JSON.
  - Pins of current behaviour: tied siblings reversed with `sortByInputDependency`,
    `Node.root` depth, scan paths resolved back to the graph roots,
    `shortestPathToRoot` following the 1st input, DFS `maxDepth >= 2`.

## 1.1.1

- `Graph`:
  - Fix `toTree` / `toTreeFrom`: the `keyCast` argument was silently ignored (it was not
    forwarded to `GraphWalker.toTreeFrom`).
  - Fix `Graph.fromJson` for non-`String` node types (e.g. `Graph<int>.fromJson` with a
    `nodeValueMapper`): JSON nodes were looked up by node value instead of by their `String`
    key, so only the roots were created. JSON keys are now tracked per parent.
    A string reference is also accepted when it maps to the same node value.
- Tests for `keyCast` and for `fromJson` with `int` nodes (merged definitions, references).

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
