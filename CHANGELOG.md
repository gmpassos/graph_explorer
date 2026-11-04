## 1.2.0

Behaviour changes (results differ from 1.1.x where they were wrong):

- `GraphScanner` / `Graph.scanPathsFrom` / `scanPathsFromMany` / `scanPathsMatching` /
  `shortestPathsFrom` / `shortestPathsFromMany` / `shortestPathsMatching`:
  - **Behaviour change:** every returned path now starts at one of the `from` nodes and ends
    at a target. Before, paths were resolved backwards to the graph roots: scanning from a
    non-root node returned the path from the real root, and paths from other roots were
    included (e.g. with `x -> d` and `a -> d`, `scanPathsFrom('a', 'd')` returned `[x, d]`).
  - **Behaviour change:** `findAll: true` now returns all the simple paths. The default
    `maxExpansion` is now `null` (no cap); before, the default (`3`) silently dropped paths
    when many of them went through the same node (3 chained diamonds: 6 of 8 paths).
    `maxExpansion` is still available as an explicit cap (the maximum number of times a node
    is expanded while enumerating paths; with a cap only a subset may be returned).
    Note that the number of paths can grow exponentially with the graph size.
  - `findAll: true` paths are grouped by target (in `Graph.targets` order) and sorted by length.
  - **Behaviour change:** `findAll: false` (and `shortestPathsFrom` with the default
    `findAll: false`) now returns a truly shortest path: the scan is a BFS from `from`
    that stops at the 1st target, and the path is the one walked by the BFS. Before, it
    was `shortestPathToRoot` of the target (see below).
  - With an `outputsProvider` and a `graph`, paths follow the provided outputs.
  - When populating a new graph with an `outputsProvider`, the graph is now populated in BFS
    and each node's outputs are requested once (`maxExpansion` no longer applies to the walk).
- `Node`:
  - **Behaviour change:** `shortestPathToRoot` / `depth` are now truly the shortest
    (a BFS from the roots). Before, they followed each node's 1st input, which is only
    shortest when the inputs were added in BFS order (`a -> b -> c -> d` plus `a -> d`
    gave `depth` 4 instead of 2). Ties are resolved by the inputs order.
    - The distances are computed once per graph (a multi-source BFS, `O(nodes + edges)`)
      and cached until the graph changes (a new node or edge anywhere invalidates the cache,
      not only an edge of the node itself, which also fixes stale cached paths).
    - `depth` no longer builds the path.
  - **Behaviour change:** a `Node.root` (`Graph.root`) now reports `shortestPathToRoot`
    `[self]` and `depth` 1, like any other root. Before, it reported an empty path
    (`depth` 0) until it got an output, and then `depth` 1.
  - **Behaviour change:** `resolveAllPathsToRoot` now returns all the simple paths from a root
    (sorted by length). Its `maxExpansion` is now `int?`, default `null` (no cap; was `3`).
- `GraphWalker` (`walk`, `walkAsync`, `walkByNodes`, `walkByNodesAsync`, `walkOrder`) and so
  `Node.outputsInDepth` / `inputsInDepth` / `sideRoots` / `Graph.walk*From`:
  - **Behaviour change:** the `maxDepth` limit is now exact in a DFS too. A DFS can reach a node
    first at a deeper level (where its outputs beyond `maxDepth` are cut); it's now expanded
    again when reached at a shallower depth (without being processed again).
    `a -> b -> c -> d`, `a -> c`, `outputsInDepth(maxDepth: 2)` now returns `[b, c, d]`
    (was `[b, c]`). The DFS visit order is otherwise kept; a BFS is unchanged.
- `sortByInputDependency` (`GraphWalker`, `Graph.toTree` / `toJson` / `walk*OrderFrom`,
  `sortedByInputDependency` / `sortedByOutputDependency`):
  - **Behaviour change:** the sort is now stable: tied siblings keep their insertion order
    (`[a, b, c]`, was `[a, c, b]`: an ascending sort was reversed).
    This can change the order of `toTree(sortByInputDependency: true)` / ASCII art trees.
  - `sortedByOutputsDepth`, `sortedByInputDepth` and `sortedPathsByLength` are now stable too.
- Tests:
  - The property tests now compare against brute force without special cases: arbitrary random
    digraphs (any roots, rootless cycles, self-loops), every `(from, target)` pair, graphs
    populated in BFS and DFS, the default `maxExpansion`, DFS and BFS with `maxDepth`,
    `shortestPathToRoot` / `depth` / `resolveAllPathsToRoot`.
  - The pinned quirks of 1.1.2 are now regression tests of the fixed behaviour.

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
