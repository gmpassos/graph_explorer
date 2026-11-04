// Property-style tests over generated graphs.
//
// Every generator uses a seeded [Random], so each run explores exactly the
// same graphs. The library results are checked against brute-force
// reference implementations (simple path enumeration, reachability, BFS
// distances) written directly over the adjacency maps.

import 'dart:async';
import 'dart:math';

import 'package:graph_explorer/graph_explorer.dart';
import 'package:test/test.dart';

/// An adjacency map: node -> outputs (in insertion order).
typedef Adjacency = Map<int, List<int>>;

/// A random graph over `0..n-1` where `0` is the only root and every node is
/// reachable from `0`.
/// - [cycles]: adds back edges (never into `0`, so it stays a root).
/// - [selfLoops]: adds `i -> i` edges (which [Node.addOutput] ignores).
Adjacency _randomGraph(
  Random r,
  int n, {
  double p = 0.35,
  bool cycles = false,
  bool selfLoops = false,
  int offset = 0,
}) {
  var adj = <int, List<int>>{for (var i = 0; i < n; i++) i: <int>[]};

  for (var i = 0; i < n; i++) {
    if (selfLoops && r.nextDouble() < 0.2) adj[i]!.add(i);
    for (var j = 1; j < n; j++) {
      if (j == i) continue;
      if (j < i && !cycles) continue;
      if (r.nextDouble() < (j < i ? p / 3 : p)) adj[i]!.add(j);
    }
  }

  // Ensure that every node has an input from a lower node (reachable from 0):
  for (var j = 1; j < n; j++) {
    if (!adj.entries.any((e) => e.key < j && e.value.contains(j))) {
      adj[r.nextInt(j)]!.add(j);
    }
  }

  if (offset == 0) return adj;

  return adj.map(
    (k, l) => MapEntry(k + offset, l.map((e) => e + offset).toList()),
  );
}

/// An arbitrary random directed graph over `0..n-1`: any number of roots
/// (including none), cycles, self-loops and unreachable components.
Adjacency _randomDigraph(Random r, int n, {double p = 0.25}) => {
  for (var i = 0; i < n; i++)
    i: [
      for (var j = 0; j < n; j++)
        if (r.nextDouble() < (j == i ? 0.1 : p)) j,
    ],
};

/// Several independent [_randomGraph] components. Roots: `0, 100, 200, ...`.
Adjacency _randomComponents(Random r, int count, {bool cycles = false}) => {
  for (var c = 0; c < count; c++)
    ..._randomGraph(r, 2 + r.nextInt(5), cycles: cycles, offset: c * 100),
};

List<int> _rootsOf(Adjacency adj) => adj.keys
    .where((k) => !adj.entries.any((e) => e.key != k && e.value.contains(k)))
    .toList();

/// Builds a [Graph] populating it from [roots] (BFS or DFS).
Graph<int> _build(Adjacency adj, {List<int>? roots, bool bfs = true}) {
  var g = Graph<int>();
  g.populate(
    roots ?? _rootsOf(adj),
    outputsProvider: (s, v) => adj[v],
    bfs: bfs,
  );
  return g;
}

/// All the simple paths from [from] to [target] (brute force).
List<List<int>> _simplePaths(Adjacency adj, int from, int target) {
  var paths = <List<int>>[];

  void dfs(int node, List<int> path) {
    path = [...path, node];
    if (node == target) {
      paths.add(path);
      return;
    }
    for (var o in adj[node]!) {
      if (!path.contains(o)) dfs(o, path);
    }
  }

  dfs(from, []);
  return paths;
}

/// The BFS distance (in edges) from [from] to every reachable node.
Map<int, int> _distances(Adjacency adj, List<int> from) {
  var dist = <int, int>{for (var f in from) f: 0};
  var queue = [...from];
  while (queue.isNotEmpty) {
    var n = queue.removeAt(0);
    for (var o in adj[n]!) {
      if (!dist.containsKey(o)) {
        dist[o] = dist[n]! + 1;
        queue.add(o);
      }
    }
  }
  return dist;
}

/// Nodes reachable from [from] through at least one edge (excludes [from]).
Set<int> _reachable(Adjacency adj, int from) {
  var seen = <int>{};
  var stack = [...adj[from]!];
  while (stack.isNotEmpty) {
    var n = stack.removeLast();
    if (seen.add(n)) stack.addAll(adj[n]!);
  }
  return seen..remove(from);
}

Adjacency _reversed(Adjacency adj) {
  var rev = <int, List<int>>{for (var k in adj.keys) k: <int>[]};
  adj.forEach((k, l) {
    for (var o in l) {
      if (o != k && !rev[o]!.contains(k)) rev[o]!.add(k);
    }
  });
  return rev;
}

/// The expected edges of a graph built from [adj] (self-loops are ignored).
Set<String> _adjEdges(Adjacency adj) => {
  for (var e in adj.entries)
    for (var o in e.value)
      if (o != e.key) '${e.key}->$o',
};

Set<String> _graphEdges<T>(Graph<T> g) => {
  for (var n in g.allNodes)
    for (var o in n.outputs) '${n.value}->${o.value}',
};

Set<String> _pathsKeys(Iterable<List<Object?>> paths) =>
    paths.map((p) => p.join(',')).toSet();

void _expectValidPath<T>(List<Node<T>> path, T from, T target) {
  expect(path, isNotEmpty);
  expect(path.first.value, equals(from));
  expect(path.last.value, equals(target));
  for (var i = 1; i < path.length; i++) {
    expect(
      path[i - 1].containsOutputNode(path[i]),
      isTrue,
      reason: 'Missing edge ${path[i - 1].value} -> ${path[i].value}',
    );
  }
  expect(path.toSet().length, equals(path.length), reason: 'Not simple');
}

/// Runs [body] for a fixed set of seeds.
Future<void> _forSeeds(
  int count,
  FutureOr<void> Function(int seed, Random r) body,
) async {
  for (var seed = 0; seed < count; seed++) {
    await body(seed, Random(seed));
  }
}

void main() {
  group('GraphScanner vs brute force', () {
    for (var cycles in [false, true]) {
      for (var bfs in [true, false]) {
        test('findAll (cycles: $cycles, populated with bfs: $bfs)', () async {
          await _forSeeds(40, (seed, r) async {
            var n = 3 + r.nextInt(5);
            var adj = _randomGraph(r, n, cycles: cycles);
            var g = _build(adj, bfs: bfs);

            for (var t = 1; t < n; t++) {
              var expected = _pathsKeys(_simplePaths(adj, 0, t));

              var result = await GraphScanner<int>(findAll: true)
                  .scanPathsFrom(0, NodeEquals(t), graph: g);

              var paths = result.paths.toListOfValuePaths();
              expect(
                _pathsKeys(paths),
                equals(expected),
                reason: 'seed: $seed ; target: $t ; adj: $adj',
              );
              // No duplicated paths:
              expect(paths.length, equals(expected.length));
              for (var p in result.paths) {
                _expectValidPath(p, 0, t);
              }
              expect(result.findAll, isTrue);
              expect(result.roots, equals([0]));
              expect(result.graph, same(g));
            }
          });
        });
      }
    }

    for (var bfs in [true, false]) {
      test(
        'any digraph, any (from, target) pair (populated with bfs: $bfs)',
        () async {
          await _forSeeds(60, (seed, r) async {
            var n = 2 + r.nextInt(6);
            var adj = _randomDigraph(r, n);
            // Populated from every node: also the nodes in rootless cycles.
            var g = _build(adj, roots: adj.keys.toList(), bfs: bfs);

            for (var from = 0; from < n; from++) {
              var dist = _distances(adj, [from]);

              for (var t = 0; t < n; t++) {
                var reason =
                    'seed: $seed ; from: $from ; target: $t ; adj: $adj';
                var expected = _simplePaths(adj, from, t);

                // findAll: every simple path from `from` (and only them):
                var all = await g.scanPathsFrom(from, t, findAll: true);
                var paths = all.paths.toListOfValuePaths();
                expect(
                  _pathsKeys(paths),
                  equals(_pathsKeys(expected)),
                  reason: reason,
                );
                expect(paths.length, equals(expected.length), reason: reason);
                for (var p in all.paths) {
                  _expectValidPath(p, from, t);
                }
                // Sorted by length:
                expect(
                  paths.map((p) => p.length).toList(),
                  equals(paths.map((p) => p.length).toList()..sort()),
                  reason: reason,
                );

                // findAll: false: one of the shortest paths.
                var shortest = await g.scanPathsFrom(from, t);
                if (expected.isEmpty) {
                  expect(shortest.paths, isEmpty, reason: reason);
                  expect(
                    await g.shortestPathsFrom(from, t, findAll: true),
                    isEmpty,
                    reason: reason,
                  );
                  continue;
                }

                expect(shortest.paths, hasLength(1), reason: reason);
                expect(
                  shortest.paths.first.length,
                  equals(dist[t]! + 1),
                  reason: reason,
                );
                _expectValidPath(shortest.paths.first, from, t);

                var minLength = expected.map((p) => p.length).reduce(min);
                var shortestKeys = _pathsKeys(
                  expected.where((p) => p.length == minLength),
                );
                expect(
                  _pathsKeys(
                    (await g.shortestPathsFrom(from, t)).toListOfValuePaths(),
                  ),
                  everyElement(isIn(shortestKeys)),
                  reason: reason,
                );
                expect(
                  _pathsKeys(
                    (await g.shortestPathsFrom(
                      from,
                      t,
                      findAll: true,
                    )).toListOfValuePaths(),
                  ),
                  equals(shortestKeys),
                  reason: reason,
                );
                // Only the shortest are enumerated, in the same order:
                expect(
                  (await g.shortestPathsFrom(
                    from,
                    t,
                    findAll: true,
                  )).toListOfValuePaths(),
                  equals(all.paths.shortestPaths().toListOfValuePaths()),
                  reason: reason,
                );
              }

              // Many targets (and many starts):
              var targets = [
                for (var t = 0; t < n; t++)
                  if (t != from) t,
              ];
              var starts = {from, (from + 1) % n}.toList();
              var allMany = await g.scanPathsFromMany(
                starts,
                targets,
                findAll: true,
              );
              var expectedMany = [
                for (var s in starts)
                  for (var t in targets) ..._simplePaths(adj, s, t),
              ];
              expect(
                _pathsKeys(allMany.paths.toListOfValuePaths()),
                equals(_pathsKeys(expectedMany)),
                reason: 'seed: $seed ; from: $starts ; adj: $adj',
              );
              expect(
                (await g.shortestPathsFromMany(
                  starts,
                  targets,
                  findAll: true,
                )).toListOfValuePaths(),
                equals(allMany.paths.shortestPaths().toListOfValuePaths()),
                reason: 'seed: $seed ; from: $starts ; adj: $adj',
              );
              expect(
                (await g.shortestPathsMatching(
                  starts,
                  NodeMatcher.eq(targets),
                )).toListOfValuePaths(),
                equals(allMany.paths.shortestPaths().toListOfValuePaths()),
              );
            }
          });
        },
      );
    }

    for (var bfs in [true, false]) {
      test(
        'shortestPathToRoot / depth / resolveAllPathsToRoot (populated with bfs: $bfs)',
        () async {
          await _forSeeds(60, (seed, r) async {
            var n = 2 + r.nextInt(7);
            var adj = seed.isEven
                ? _randomDigraph(r, n)
                : _randomGraph(r, n, cycles: true);
            var g = _build(adj, roots: adj.keys.toList(), bfs: bfs);
            var roots = _rootsOf(adj);
            var dist = _distances(adj, roots);

            for (var node in g.allNodes) {
              var v = node.value;
              var reason = 'seed: $seed ; node: $v ; adj: $adj';

              var allToRoot = [
                for (var root in roots) ..._simplePaths(adj, root, v),
              ];
              expect(
                _pathsKeys(node.resolveAllPathsToRoot().toListOfValuePaths()),
                equals(_pathsKeys(allToRoot)),
                reason: reason,
              );

              var d = dist[v];
              if (d == null) {
                expect(() => node.depth, throwsStateError, reason: reason);
                expect(
                  () => node.shortestPathToRoot,
                  throwsStateError,
                  reason: reason,
                );
                continue;
              }

              expect(node.depth, equals(d + 1), reason: reason);
              var path = node.shortestPathToRoot;
              expect(path, hasLength(d + 1), reason: reason);
              expect(path.first.isRoot, isTrue, reason: reason);
              _expectValidPath(path, path.first.value, v);
              expect(node.isInputInShortestPathToRoot(path.first), isTrue);
              // Cached:
              expect(node.shortestPathToRoot, same(path));
            }
          });
        },
      );
    }

    test('scanPathsFromMany over disconnected components', () async {
      await _forSeeds(30, (seed, r) async {
        var adj = _randomComponents(r, 2 + r.nextInt(3), cycles: seed.isOdd);
        var roots = _rootsOf(adj);
        var g = _build(adj);

        // Each component's last node: reachable only from its own root.
        var targets = roots
            .map((root) => adj.keys.where((k) => k ~/ 100 == root ~/ 100).max)
            .where((t) => !roots.contains(t))
            .toList();
        if (targets.isEmpty) return;

        var expected = {
          for (var t in targets)
            ..._pathsKeys(_simplePaths(adj, t ~/ 100 * 100, t)),
        };

        var result = await GraphScanner<int>(findAll: true)
            .scanPathsFromMany(roots, NodeMatcher.eq(targets), graph: g);

        expect(
          _pathsKeys(result.paths.toListOfValuePaths()),
          equals(expected),
          reason: 'seed: $seed ; adj: $adj',
        );
        expect(g.targets.toListOfValues().toSet(), equals(targets.toSet()));
      });
    });

    test(
      'scan built by an async outputsProvider == scan of a built graph',
      () async {
        await _forSeeds(30, (seed, r) async {
          var n = 3 + r.nextInt(5);
          var adj = _randomGraph(r, n, cycles: seed.isOdd);
          var built = _build(adj);

          for (var from in [0, n ~/ 2]) {
            for (var t = 1; t < n; t++) {
              var reason = 'seed: $seed ; from: $from ; target: $t ; adj: $adj';

              for (var findAll in [true, false]) {
                var fromBuilt = await GraphScanner<int>(findAll: findAll)
                    .scanPathsFrom(from, NodeEquals(t), graph: built);

                Future<List<Node<int>>> provider(
                  Graph<int> graph,
                  Node<int> node,
                ) async {
                  await Future<void>.delayed(Duration.zero);
                  return adj[node.value]!.map(graph.node).toList();
                }

                // Populating a new graph:
                var fromProvider = await GraphScanner<int>(
                  findAll: findAll,
                ).scanPathsFrom(from, NodeEquals(t), outputsProvider: provider);

                // Over an empty graph, with the provider:
                var fromGraphProvider =
                    await GraphScanner<int>(findAll: findAll).scanPathsFrom(
                      from,
                      NodeEquals(t),
                      graph: Graph<int>()..node(from),
                      outputsProvider: provider,
                    );

                var expected = fromBuilt.paths.toListOfValuePaths();
                if (findAll) {
                  expect(
                    _pathsKeys(expected),
                    equals(_pathsKeys(_simplePaths(adj, from, t))),
                    reason: reason,
                  );
                }
                expect(
                  fromProvider.paths.toListOfValuePaths(),
                  equals(expected),
                  reason: reason,
                );
                expect(
                  fromGraphProvider.paths.toListOfValuePaths(),
                  equals(expected),
                  reason: reason,
                );
              }
            }
          }
        });
      },
    );
  });

  group('Generated shapes', () {
    test('self-loops are ignored', () async {
      await _forSeeds(30, (seed, r) async {
        var n = 2 + r.nextInt(6);
        var adj = _randomGraph(r, n, cycles: seed.isOdd, selfLoops: true);
        var g = _build(adj);

        expect(_graphEdges(g), equals(_adjEdges(adj)));

        for (var node in g.allNodes) {
          expect(node.outputs, isNot(contains(node)));
          expect(node.inputs, isNot(contains(node)));
          expect(node.addOutput(node.value), isNull);
          expect(node.addInput(node.value), isNull);
          expect(node.getOrAddOutput(node.value), same(node));
          expect(node.isOutputNode(node), isFalse);
        }

        for (var t = 1; t < n; t++) {
          var result = await GraphScanner<int>(findAll: true)
              .scanPathsFrom(0, NodeEquals(t), graph: g);
          expect(
            _pathsKeys(result.paths.toListOfValuePaths()),
            equals(_pathsKeys(_simplePaths(adj, 0, t))),
            reason: 'seed: $seed ; target: $t ; adj: $adj',
          );
        }
      });
    });

    test('chain of diamonds: 2^k paths of the same length', () async {
      for (var k = 1; k <= 6; k++) {
        // 0 -> (1|2) -> 3 -> (4|5) -> 6 ...
        var adj = <int, List<int>>{};
        for (var i = 0; i < k; i++) {
          var top = i * 3;
          adj[top] = [top + 1, top + 2];
          adj[top + 1] = [top + 3];
          adj[top + 2] = [top + 3];
        }
        var last = k * 3;
        adj[last] = [];

        var g = _build(adj);
        var expectedCount = pow(2, k).toInt();

        // The default (no `maxExpansion` cap) finds all the paths:
        var all = await GraphScanner<int>(findAll: true)
            .scanPathsFrom(0, NodeEquals(last), graph: g);
        expect(all.paths, hasLength(expectedCount));
        expect(
          _pathsKeys(all.paths.toListOfValuePaths()),
          equals(_pathsKeys(_simplePaths(adj, 0, last))),
        );
        for (var p in all.paths) {
          expect(p.length, equals(2 * k + 1));
          _expectValidPath(p, 0, last);
        }

        // All of them are shortest (and longest) paths:
        expect(all.paths.shortestPaths(), hasLength(expectedCount));
        expect(all.paths.longestPaths(), hasLength(expectedCount));

        var paths = await g.shortestPathsFrom(0, last, findAll: true);
        expect(
          _pathsKeys(paths.toListOfValuePaths()),
          equals(_pathsKeys(all.paths.toListOfValuePaths())),
        );
        expect(await g.allPaths, hasLength(expectedCount));
        expect(
          g.getNode(last)!.resolveAllPathsToRoot(),
          hasLength(expectedCount),
        );

        // An explicit `maxExpansion` caps the enumeration:
        var capped = await GraphScanner<int>(findAll: true)
            .scanPathsFrom(0, NodeEquals(last), graph: g, maxExpansion: 1);
        expect(capped.paths, isNotEmpty);
        expect(
          _pathsKeys(all.paths.toListOfValuePaths()),
          containsAll(_pathsKeys(capped.paths.toListOfValuePaths())),
        );
        if (k >= 2) {
          expect(capped.paths.length, lessThan(expectedCount));
        }

        expect(g.getNode(last)!.depth, equals(2 * k + 1));
      }
    });

    test('long chain', () async {
      const length = 300;
      var adj = <int, List<int>>{
        for (var i = 0; i < length; i++) i: [if (i < length - 1) i + 1],
      };
      var g = _build(adj);

      expect(g.length, equals(length));
      expect(g.rootValues, equals([0]));
      expect(g.allLeaves.toListOfValues(), equals([length - 1]));

      var last = g.getNode(length - 1)!;
      expect(last.depth, equals(length));
      expect(
        last.shortestPathToRoot.toListOfValues(),
        equals(List.generate(length, (i) => i)),
      );

      var paths = await g.scanPathsFrom(0, length - 1, findAll: true);
      expect(paths.paths, hasLength(1));
      expect(paths.paths.first, hasLength(length));

      expect(g.getNode(0)!.outputsInDepth(), hasLength(length - 1));
      expect(last.inputsInDepth(), hasLength(length - 1));
      expect(last.roots().toListOfValues(), equals([0]));
      expect(g.getNode(10)!.outputsInDepth(maxDepth: 5), hasLength(5));

      var order = g.walkOutputsOrderFrom([0]).toListOfValues();
      expect(order, equals(List.generate(length, (i) => i)));

      var json = g.toJson();
      expect(GraphWalker.extractAllEntries(json), hasLength(length));
      var g2 = Graph<int>.fromJson(
        json,
        nodeValueMapper: (s, k) => int.parse(k),
      );
      expect(_graphEdges(g2), equals(_graphEdges(g)));
      // (`equals` compares only 100 levels deep by default)
      expect(g2.toJson(), equals(json, length + 1));
    });
  });

  group('Reachability', () {
    test('outputsInDepth / inputsInDepth / isOutput / isInput', () async {
      await _forSeeds(40, (seed, r) async {
        var adj = seed.isEven
            ? _randomGraph(r, 2 + r.nextInt(6), cycles: seed % 4 == 0)
            : _randomComponents(r, 2, cycles: seed % 4 == 1);
        var g = _build(adj);
        var rev = _reversed(adj);

        for (var node in g.allNodes) {
          var v = node.value;
          var reason = 'seed: $seed ; node: $v ; adj: $adj';
          var outputs = _reachable(adj, v);
          var inputs = _reachable(rev, v);

          for (var bfs in [false, true]) {
            var outs = node.outputsInDepth(bfs: bfs).toListOfValues();
            expect(outs.toSet(), equals(outputs), reason: reason);
            expect(outs.length, equals(outputs.length), reason: reason);

            var ins = node.inputsInDepth(bfs: bfs).toListOfValues();
            expect(ins.toSet(), equals(inputs), reason: reason);
            expect(ins.length, equals(inputs.length), reason: reason);
          }

          // The direct neighbours are depth 1:
          expect(
            node.outputsInDepth(maxDepth: 1).toListOfValues(),
            equals(node.outputsValues),
            reason: reason,
          );

          // BFS and DFS with `maxDepth`: the nodes up to that distance
          // (each once).
          var dist = _distances(adj, [v]);
          var revDist = _distances(rev, [v]);
          for (var bfs in [true, false]) {
            for (var maxDepth in [1, 2, 3, 4]) {
              Set<int> upTo(Map<int, int> dist) => dist.entries
                  .where((e) => e.value >= 1 && e.value <= maxDepth)
                  .map((e) => e.key)
                  .toSet();

              var outs = node
                  .outputsInDepth(maxDepth: maxDepth, bfs: bfs)
                  .toListOfValues();
              expect(
                outs.toSet(),
                equals(upTo(dist)),
                reason: '$reason ; maxDepth: $maxDepth ; bfs: $bfs',
              );
              expect(outs.length, equals(outs.toSet().length));

              var ins = node
                  .inputsInDepth(maxDepth: maxDepth, bfs: bfs)
                  .toListOfValues();
              expect(
                ins.toSet(),
                equals(upTo(revDist)),
                reason: '$reason ; maxDepth: $maxDepth ; bfs: $bfs',
              );
              expect(ins.length, equals(ins.toSet().length));

              // The DFS order is kept: a node is visited after one of its
              // inputs (or the start node).
              if (!bfs) {
                for (var i = 0; i < outs.length; i++) {
                  var inputs = g.getNode(outs[i])!.inputsValues;
                  expect(
                    inputs.contains(v) ||
                        inputs.any((e) {
                          var j = outs.indexOf(e);
                          return j >= 0 && j < i;
                        }),
                    isTrue,
                    reason: '$reason ; maxDepth: $maxDepth',
                  );
                }
              }
            }
          }

          for (var other in g.allNodes) {
            var o = other.value;
            expect(
              node.isOutput(o),
              equals(o != v && outputs.contains(o)),
              reason: '$reason ; other: $o',
            );
            expect(
              node.isInput(o),
              equals(o != v && inputs.contains(o)),
              reason: '$reason ; other: $o',
            );
          }

          // `roots()`: the root ancestors (a root has none):
          var rootAncestors = inputs.where((e) => rev[e]!.isEmpty).toSet();
          expect(
            node.roots().toListOfValues().toSet(),
            equals(rootAncestors),
            reason: reason,
          );
        }

        expect(g.rootValues.toSet(), equals(_rootsOf(adj).toSet()));
        expect(
          g.allLeaves.toListOfValues().toSet(),
          equals(adj.keys.where((k) => adj[k]!.isEmpty).toSet()),
        );
      });
    });

    test('intersections of in depth outputs / inputs', () async {
      await _forSeeds(30, (seed, r) async {
        var adj = _randomGraph(r, 3 + r.nextInt(5), cycles: seed.isOdd);
        var g = _build(adj);
        var rev = _reversed(adj);
        var nodes = g.allNodes.toList();

        for (var a in nodes) {
          for (var b in nodes) {
            var outs = _reachable(
              adj,
              a.value,
            ).intersection(_reachable(adj, b.value));
            expect(
              a.outputsInDepthIntersection(b).toListOfValues().toSet(),
              equals(outs),
            );
            var ins = _reachable(
              rev,
              a.value,
            ).intersection(_reachable(rev, b.value));
            expect(
              a.inputsInDepthIntersection(b).toListOfValues().toSet(),
              equals(ins),
            );
          }
        }
      });
    });
  });

  group('Walk orders', () {
    test('walkOutputsOrderFrom: bfs and dfs visit the same nodes', () async {
      await _forSeeds(40, (seed, r) async {
        var adj = seed.isEven
            ? _randomGraph(r, 2 + r.nextInt(7), cycles: seed % 4 == 0)
            : _randomComponents(r, 3, cycles: seed % 4 == 1);
        var roots = _rootsOf(adj);
        var g = _build(adj);
        var dist = _distances(adj, roots);
        var reason = 'seed: $seed ; adj: $adj';

        var bfsOrder = g
            .walkOutputsOrderFrom(roots, bfs: true)
            .toListOfValues();
        var dfsOrder = g.walkOutputsOrderFrom(roots).toListOfValues();

        for (var order in [bfsOrder, dfsOrder]) {
          // Every node exactly once:
          expect(order.toSet(), equals(adj.keys.toSet()), reason: reason);
          expect(order.length, equals(adj.length), reason: reason);

          // A non-root node is visited after one of its inputs:
          for (var i = 0; i < order.length; i++) {
            var node = g.getNode(order[i])!;
            if (node.isRoot) continue;
            expect(
              node.inputsValues.any((e) => order.indexOf(e) < i),
              isTrue,
              reason: '$reason ; node: ${node.value}',
            );
          }
        }

        // BFS: by distance from the roots.
        var bfsDistances = bfsOrder.map((e) => dist[e]!).toList();
        expect(bfsDistances, equals([...bfsDistances]..sort()), reason: reason);

        // Both start at the first root:
        expect(dfsOrder.first, equals(roots.first), reason: reason);
        expect(bfsOrder.first, equals(roots.first), reason: reason);

        // processRoots: false skips only the roots (a root in the middle of
        // the walk is never re-visited).
        var withoutRoots = g
            .walkOutputsOrderFrom(roots, processRoots: false)
            .toListOfValues();
        expect(
          withoutRoots,
          equals(dfsOrder.where((e) => !roots.contains(e)).toList()),
          reason: reason,
        );
      });
    });

    test('walkInputsOrderFrom: reverse reachability', () async {
      await _forSeeds(30, (seed, r) async {
        var adj = _randomGraph(r, 2 + r.nextInt(7), cycles: seed.isOdd);
        var g = _build(adj);
        var rev = _reversed(adj);

        for (var v in adj.keys) {
          for (var bfs in [false, true]) {
            var order = g.walkInputsOrderFrom([v], bfs: bfs).toListOfValues();
            expect(order.first, equals(v));
            expect(order.toSet(), equals({v, ..._reachable(rev, v)}));
            expect(order.length, equals(order.toSet().length));
          }
        }
      });
    });

    test('walkOutputsFrom / walkInputsFrom visit as the walk order', () async {
      await _forSeeds(30, (seed, r) async {
        var adj = _randomGraph(r, 2 + r.nextInt(7), cycles: seed.isOdd);
        var g = _build(adj);

        for (var bfs in [false, true]) {
          var visited = <int>[];
          var ret = g.walkOutputsFrom<bool>([0], (step) {
            visited.add(step.nodeValue);
            return null;
          }, bfs: bfs);
          expect(ret, isFalse);
          expect(
            visited,
            equals(g.walkOutputsOrderFrom([0], bfs: bfs).toListOfValues()),
          );

          var leaf = adj.keys.max;
          var visitedInputs = <int>[];
          g.walkInputsFrom<bool>([leaf], (step) {
            visitedInputs.add(step.nodeValue);
            return null;
          }, bfs: bfs);
          expect(
            visitedInputs,
            equals(g.walkInputsOrderFrom([leaf], bfs: bfs).toListOfValues()),
          );
        }
      });
    });

    test('step depth and path to root (bfs, maxExpansion: 1)', () async {
      await _forSeeds(30, (seed, r) async {
        var adj = _randomGraph(r, 2 + r.nextInt(7), cycles: seed.isOdd);
        var g = _build(adj);
        var dist = _distances(adj, [0]);

        GraphWalker<int>(bfs: true).walkByNodes<bool>(
          [g.getNode(0)!],
          outputsProvider: (s, n) => n.outputs,
          process: (step) {
            // In a BFS, the 1st visit of a node is from the closest path:
            expect(step.depth, equals(dist[step.nodeValue]));
            var path = step.nodePathToRoot.toListOfValues();
            expect(path, equals(step.valuePathToRoot));
            expect(path.length, equals(step.depth + 1));
            expect(path.first, equals(0));
            expect(path.last, equals(step.nodeValue));
            for (var i = 1; i < path.length; i++) {
              expect(adj[path[i - 1]], contains(path[i]));
            }
            expect(step.fullPathToRoot(), equals(path.join('/')));
            return null;
          },
        );
      });
    });
  });

  group('Sync vs async', () {
    test('populate == populateAsync', () async {
      await _forSeeds(30, (seed, r) async {
        var adj = seed.isEven
            ? _randomGraph(r, 2 + r.nextInt(7), cycles: seed % 4 == 0)
            : _randomComponents(r, 3, cycles: seed % 4 == 1);
        var roots = _rootsOf(adj);

        for (var bfs in [false, true]) {
          var syncProcessed = <String>[];
          var gSync = Graph<int>();
          gSync.populate<bool>(
            roots,
            outputsProvider: (s, v) => adj[v],
            process: (s) {
              syncProcessed.add('${s.depth}:${s.nodeValue}');
              return null;
            },
            bfs: bfs,
          );

          var asyncProcessed = <String>[];
          var gAsync = Graph<int>();
          await gAsync.populateAsync<bool>(
            roots,
            outputsProvider: (s, v) async {
              await Future<void>.delayed(Duration.zero);
              return adj[v];
            },
            process: (s) async {
              asyncProcessed.add('${s.depth}:${s.nodeValue}');
              return null;
            },
            bfs: bfs,
          );

          expect(asyncProcessed, equals(syncProcessed));
          expect(gAsync.allNodesValues, equals(gSync.allNodesValues));
          expect(_graphEdges(gAsync), equals(_graphEdges(gSync)));
          expect(_graphEdges(gSync), equals(_adjEdges(adj)));
          for (var n in gSync.allNodes) {
            var other = gAsync.getNode(n.value)!;
            expect(other.outputsValues, equals(n.outputsValues));
            expect(other.inputsValues, equals(n.inputsValues));
          }
          expect(gAsync.toJson(), equals(gSync.toJson()));
        }
      });
    });

    test('walk == walkAsync', () async {
      await _forSeeds(30, (seed, r) async {
        var adj = _randomGraph(r, 2 + r.nextInt(7), cycles: seed.isOdd);
        var g = _build(adj);

        for (var bfs in [false, true]) {
          for (var maxExpansion in [1, 2]) {
            for (var maxDepth in [null, 1, 2]) {
              var walker = GraphWalker<int>(
                bfs: bfs,
                maxExpansion: maxExpansion,
              );

              var syncSteps = <String>[];
              var syncRet = walker.walk<int>(
                [0],
                nodeProvider: (s, v) => g.getNode(v),
                outputsProvider: (s, v) => adj[v],
                process: (s) {
                  syncSteps.add('${s.depth}:${s.nodeValue}');
                  return null;
                },
                maxDepth: maxDepth,
              );
              var syncProcessed = Map.of(walker.processedNodes);

              walker.reset();

              var asyncSteps = <String>[];
              var asyncRet = await walker.walkAsync<int>(
                [0],
                nodeProvider: (s, v) async => g.getNode(v),
                outputsProvider: (s, v) => Future.value(adj[v]),
                process: (s) async {
                  asyncSteps.add('${s.depth}:${s.nodeValue}');
                  return null;
                },
                maxDepth: maxDepth,
              );

              expect(asyncSteps, equals(syncSteps));
              expect(asyncRet, equals(syncRet));
              expect(walker.processedNodes, equals(syncProcessed));

              if (maxDepth != null) {
                // Every node within `maxDepth` is processed:
                var dist = _distances(adj, [0]);
                expect(
                  syncSteps.map((e) => int.parse(e.split(':')[1])).toSet(),
                  equals(dist.keys.where((k) => dist[k]! <= maxDepth).toSet()),
                  reason: 'seed: $seed ; maxDepth: $maxDepth ; adj: $adj',
                );
              }
            }
          }
        }
      });
    });

    test('walkByNodes == walkByNodesAsync', () async {
      await _forSeeds(30, (seed, r) async {
        var adj = _randomGraph(r, 2 + r.nextInt(7), cycles: seed.isOdd);
        var g = _build(adj);
        var target = adj.keys.max;

        for (var bfs in [false, true]) {
          for (var maxExpansion in [1, 3]) {
            GraphWalker<int> walker() =>
                GraphWalker<int>(bfs: bfs, maxExpansion: maxExpansion);

            Object? process(List<String> steps, GraphNodeStep<int> s) {
              steps.add('${s.depth}:${s.nodeValue}');
              return s.nodeValue == target
                  ? GraphWalkingInstruction.result(s.depth)
                  : null;
            }

            var syncSteps = <String>[];
            var syncRet = walker().walkByNodes<int>(
              [g.getNode(0)!],
              outputsProvider: (s, n) => n.outputs,
              process: (s) => process(syncSteps, s),
            );

            var asyncSteps = <String>[];
            var asyncRet = await walker().walkByNodesAsync<int>(
              [g.getNode(0)!],
              outputsProvider: (s, n) async => n.outputs,
              process: (s) async => process(asyncSteps, s),
            );

            expect(asyncSteps, equals(syncSteps));
            expect(asyncRet, equals(syncRet));
            // The walk finds the target at its first visit:
            expect(syncRet, isNotNull);
            if (bfs) {
              expect(syncRet, equals(_distances(adj, [0])[target]));
            }

            // With `maxDepth` (re-expansions in a DFS):
            for (var maxDepth in [1, 2, 3]) {
              var syncDepth = <String>[];
              walker().walkByNodes<int>(
                [g.getNode(0)!],
                outputsProvider: (s, n) => n.outputs,
                process: (s) {
                  syncDepth.add('${s.depth}:${s.nodeValue}');
                  return null;
                },
                maxDepth: maxDepth,
              );
              var asyncDepth = <String>[];
              await walker().walkByNodesAsync<int>(
                [g.getNode(0)!],
                outputsProvider: (s, n) async => n.outputs,
                process: (s) async {
                  asyncDepth.add('${s.depth}:${s.nodeValue}');
                  return null;
                },
                maxDepth: maxDepth,
              );
              expect(asyncDepth, equals(syncDepth));
              expect(
                GraphWalker<int>(bfs: bfs, maxExpansion: maxExpansion)
                    .walkOrder(
                      [0],
                      nodeProvider: (s, v) => g.getNode(v),
                      outputsProvider: (s, n) => n.outputs,
                      maxDepth: maxDepth,
                    )
                    .toListOfValues(),
                equals(
                  syncDepth.map((e) => int.parse(e.split(':')[1])).toSet(),
                ),
              );
            }
          }
        }
      });
    });
  });

  group('JSON round-trip', () {
    test('String nodes: toJson -> fromJson -> toJson', () async {
      await _forSeeds(40, (seed, r) async {
        var adj = seed.isEven
            ? _randomGraph(r, 1 + r.nextInt(8), cycles: seed % 4 == 0)
            : _randomComponents(r, 3, cycles: seed % 4 == 1);

        var g = Graph<String>();
        g.populate(
          _rootsOf(adj).map((e) => 'n$e'),
          outputsProvider: (s, v) =>
              adj[int.parse(v.substring(1))]!.map((e) => 'n$e'),
        );

        for (var bfs in [false, true]) {
          var json = g.toTree<String>(bfs: bfs);
          var g2 = Graph<String>.fromJson(json);
          var reason = 'seed: $seed ; bfs: $bfs ; adj: $adj';

          expect(_graphEdges(g2), equals(_graphEdges(g)), reason: reason);
          expect(g2.rootValues, equals(g.rootValues), reason: reason);
          expect(g2.toJson(), equals(g.toJson()), reason: reason);
          expect(g2.toTree<String>(bfs: bfs), equals(json), reason: reason);
        }
      });
    });

    test('int nodes: toJson -> fromJson -> toJson', () async {
      await _forSeeds(40, (seed, r) async {
        var adj = seed.isEven
            ? _randomGraph(r, 1 + r.nextInt(8), cycles: seed % 4 == 0)
            : _randomComponents(r, 3, cycles: seed % 4 == 1);
        var g = _build(adj, bfs: seed % 3 == 0);
        var reason = 'seed: $seed ; adj: $adj';

        var json = g.toJson();
        var g2 = Graph<int>.fromJson(
          json,
          nodeValueMapper: (s, k) => int.parse(k),
        );

        expect(g2.allNodesValues, everyElement(isA<int>()));
        expect(g2.length, equals(g.length), reason: reason);
        expect(_graphEdges(g2), equals(_graphEdges(g)), reason: reason);
        expect(_graphEdges(g2), equals(_adjEdges(adj)), reason: reason);
        expect(g2.rootValues, equals(g.rootValues), reason: reason);
        expect(g2.toJson(), equals(json), reason: reason);

        // `int` keys (no `keyCast` needed) and the `keyCast` variant agree:
        var intTree = g2.toTree<int>();
        expect(intTree.keys, everyElement(isA<int>()));
        expect(
          g2.toTree<String>(keyCast: (v) => 'n$v').keys,
          equals(intTree.keys.map((k) => 'n$k')),
        );

        // Paths are preserved:
        for (var t in adj.keys.where((k) => k % 100 != 0)) {
          var root = t ~/ 100 * 100;
          var p1 = await g.shortestPathsFrom(root, t, findAll: true);
          var p2 = await g2.shortestPathsFrom(root, t, findAll: true);
          expect(
            _pathsKeys(p2.toListOfValuePaths()),
            equals(_pathsKeys(p1.toListOfValuePaths())),
            reason: '$reason ; target: $t',
          );
        }
      });
    });
  });

  group('Paths extensions', () {
    test('shortestPaths / longestPaths / first*Path', () async {
      await _forSeeds(40, (seed, r) async {
        var n = 3 + r.nextInt(5);
        var adj = _randomGraph(r, n, cycles: seed.isOdd);
        var g = _build(adj);
        var result = await GraphScanner<int>(findAll: true)
            .scanPathsFrom(0, NodeEquals(n - 1), graph: g);
        var paths = result.paths;
        var lengths = paths.map((p) => p.length).toList();
        var minLength = lengths.reduce(min);
        var maxLength = lengths.reduce(max);

        var sorted = paths.sortedPathsByLength();
        expect(
          sorted.map((p) => p.length).toList(),
          equals([...lengths]..sort()),
        );

        var shortest = paths.shortestPaths();
        expect(shortest, isNotEmpty);
        expect(shortest.every((p) => p.length == minLength), isTrue);
        expect(
          shortest.length,
          equals(lengths.where((l) => l == minLength).length),
        );

        var longest = paths.longestPaths();
        expect(longest.every((p) => p.length == maxLength), isTrue);
        expect(
          longest.length,
          equals(lengths.where((l) => l == maxLength).length),
        );

        // The first shortest/longest path in the original order:
        expect(
          paths.firstShortestPath(),
          same(paths.firstWhere((p) => p.length == minLength)),
        );
        expect(
          paths.firstLongestPath(),
          same(paths.firstWhere((p) => p.length == maxLength)),
        );
        expect(shortest.first, same(paths.firstShortestPath()));

        expect(
          paths.toListOfStringPaths(),
          equals(
            paths
                .toListOfValuePaths()
                .map((p) => p.map((e) => '$e').toList())
                .toList(),
          ),
        );
      });
    });
  });
}

extension on Iterable<int> {
  int get max => reduce((a, b) => a > b ? a : b);
}
