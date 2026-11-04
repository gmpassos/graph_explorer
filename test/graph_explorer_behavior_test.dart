// Pins of current behaviour (including known quirks) and walker options not
// exercised elsewhere.

import 'package:graph_explorer/graph_explorer.dart';
import 'package:test/test.dart';

/// `a -> b`, `a -> c` (`b` and `c` are tied siblings).
Graph<String> _fork() {
  var g = Graph<String>();
  g.node('a')
    ..addOutput('b')
    ..addOutput('c');
  return g;
}

/// `a -> b -> c` and `a -> c`: `c` is a direct output of `a`, but a DFS
/// reaches it first through `b` (at depth 2).
Graph<String> _shortcut() {
  var g = Graph<String>();
  g.node('a')
    ..addOutput('b')
    ..addOutput('c');
  g.node('b').addOutput('c');
  return g;
}

void main() {
  group('Known quirks (pinned)', () {
    test('sortByInputDependency: tied siblings come out reversed', () {
      var g = _fork();

      expect(
        g.walkOutputsOrderFrom(['a']).toListOfValues(),
        equals(['a', 'b', 'c']),
      );
      expect(
        g.walkOutputsOrderFrom([
          'a',
        ], sortByInputDependency: true).toListOfValues(),
        equals(['a', 'c', 'b']),
      );
      expect(
        g
            .walkOutputsOrderFrom(['a'], sortByInputDependency: true, bfs: true)
            .toListOfValues(),
        equals(['a', 'c', 'b']),
      );

      expect(g.toTree().values.single.keys, equals(['b', 'c']));
      expect(
        g.toTree(sortByInputDependency: true).values.single.keys,
        equals(['c', 'b']),
      );
      expect(
        g.toJson(sortByInputDependency: true),
        equals({
          'a': {'c': null, 'b': null},
        }),
      );

      var visited = <String>[];
      GraphWalker<String>(sortByInputDependency: true).walkByNodes<bool>(
        [g.node('a')],
        outputsProvider: (s, n) => n.outputs,
        process: (s) {
          visited.add(s.nodeValue);
          return null;
        },
      );
      expect(visited, equals(['a', 'c', 'b']));
    });

    test('Node.root: depth 0 (empty shortestPathToRoot)', () {
      var g = Graph<String>();
      var alwaysRoot = g.root('r');
      var ordinaryRoot = g.node('a');

      expect(alwaysRoot.isRoot, isTrue);
      expect(ordinaryRoot.isRoot, isTrue);

      expect(alwaysRoot.shortestPathToRoot, isEmpty);
      expect(alwaysRoot.depth, equals(0));

      expect(ordinaryRoot.shortestPathToRoot, equals([ordinaryRoot]));
      expect(ordinaryRoot.depth, equals(1));

      // Children are counted from the root node itself in both cases:
      alwaysRoot.addOutput('x');
      ordinaryRoot.addOutput('y');
      expect(g.node('x').shortestPathToRoot.toListOfValues(), ['r', 'x']);
      expect(g.node('x').depth, equals(2));
      expect(g.node('y').depth, equals(2));

      // Adding outputs invalidates the cached path of the always root:
      expect(alwaysRoot.depth, equals(1));
    });

    test(
      'scan paths are resolved back to the graph roots, not to `from`',
      () async {
        // x -> d
        // a -> d
        var g = Graph<String>();
        g.node('x').addOutput('d');
        g.node('a').addOutput('d');

        var shortest = await g.scanPathsFrom('a', 'd');
        expect(
          shortest.paths.toListOfStringPaths(),
          equals([
            ['x', 'd'],
          ]),
        );

        var all = await g.scanPathsFrom('a', 'd', findAll: true);
        expect(
          all.paths.toListOfStringPaths(),
          equals([
            ['x', 'd'],
            ['a', 'd'],
          ]),
        );

        // Scanning from a non-root node returns the path from the root:
        var chain = Graph<String>();
        chain.node('a').addOutput('b');
        chain.node('b').addOutput('d');
        for (var findAll in [false, true]) {
          var r = await chain.scanPathsFrom('b', 'd', findAll: findAll);
          expect(
            r.paths.toListOfStringPaths(),
            equals([
              ['a', 'b', 'd'],
            ]),
          );
        }
      },
    );

    test('shortestPathToRoot follows the 1st input', () async {
      // a -> b -> c -> d, then a -> d:
      var g = Graph<String>();
      g.node('a').addOutput('b');
      g.node('b').addOutput('c');
      g.node('c').addOutput('d');
      g.node('a').addOutput('d');

      var d = g.node('d');
      expect(d.inputsValues, equals(['c', 'a']));

      // Not the shortest path, since `inputs` was not populated in BFS:
      expect(d.shortestPathToRoot.toListOfValues(), ['a', 'b', 'c', 'd']);
      expect(d.depth, equals(4));
      expect(
        (await g.shortestPathsFrom('a', 'd')).toListOfValuePaths(),
        equals([
          ['a', 'b', 'c', 'd'],
        ]),
      );

      // With `findAll` all the paths are computed first:
      expect(
        (await g.shortestPathsFrom(
          'a',
          'd',
          findAll: true,
        )).toListOfValuePaths(),
        equals([
          ['a', 'd'],
        ]),
      );

      // Populated in BFS, the 1st input is the closest to the root:
      var adj = {
        'a': ['b', 'd'],
        'b': ['c'],
        'c': ['d'],
      };
      var bfs = Graph<String>()
        ..populate(['a'], outputsProvider: (s, v) => adj[v], bfs: true);
      expect(bfs.node('d').inputsValues, equals(['a', 'c']));
      expect(bfs.node('d').depth, equals(2));
    });

    test('shortestPathToRoot without a root (pure cycle)', () {
      var g = Graph<String>();
      g.node('a').addOutput('b');
      g.node('b').addOutput('a');

      expect(g.roots, isEmpty);
      expect(() => g.node('a').shortestPathToRoot, throwsStateError);
      expect(() => g.node('b').depth, throwsStateError);
      expect(g.node('a').resolveAllPathsToRoot(), isEmpty);
      expect(g.toTree(), isEmpty);
    });
  });

  group('maxDepth', () {
    // Before 1.1.2 a step beyond `maxDepth` was counted as processed, so a
    // DFS could skip a node that is also reachable within `maxDepth`.
    test('outputsInDepth / inputsInDepth (DFS)', () {
      var g = _shortcut();

      expect(
        g.node('a').outputsInDepth(maxDepth: 1).toListOfValues(),
        equals(['b', 'c']),
      );
      expect(
        g.node('a').outputsInDepth(maxDepth: 1, bfs: true).toListOfValues(),
        equals(['b', 'c']),
      );
      expect(g.node('a').outputsInDepth().toListOfValues(), equals(['b', 'c']));

      expect(g.node('c').inputsValues, equals(['a', 'b']));
      expect(
        g.node('c').inputsInDepth(maxDepth: 1).toListOfValues(),
        equals(['a', 'b']),
      );
      expect(g.node('c').inputsInDepth().toListOfValues(), equals(['a', 'b']));
    });

    test(
      'walk / walkAsync / walkByNodes / walkByNodesAsync / walkOrder',
      () async {
        var g = _shortcut();
        var a = g.node('a');

        var walk = <String>[];
        GraphWalker<String>().walk<bool>(
          ['a'],
          nodeProvider: (s, v) => g.getNode(v),
          outputsProvider: (s, v) => g.getNode(v)!.outputsValues,
          process: (s) {
            walk.add('${s.depth}:${s.nodeValue}');
            return null;
          },
          maxDepth: 1,
        );
        expect(walk, equals(['0:a', '1:b', '1:c']));

        var walkAsync = <String>[];
        await GraphWalker<String>().walkAsync<bool>(
          ['a'],
          nodeProvider: (s, v) async => g.getNode(v),
          outputsProvider: (s, v) async => g.getNode(v)!.outputsValues,
          process: (s) {
            walkAsync.add('${s.depth}:${s.nodeValue}');
            return null;
          },
          maxDepth: 1,
        );
        expect(walkAsync, equals(walk));

        var byNodes = <String>[];
        var walker = GraphWalker<String>();
        walker.walkByNodes<bool>(
          [a],
          outputsProvider: (s, n) => n.outputs,
          process: (s) {
            byNodes.add('${s.depth}:${s.nodeValue}');
            return null;
          },
          maxDepth: 1,
        );
        expect(byNodes, equals(walk));
        // A step beyond `maxDepth` is not counted:
        expect(walker.processedNodes.values, everyElement(1));

        var byNodesAsync = <String>[];
        await GraphWalker<String>().walkByNodesAsync<bool>(
          [a],
          outputsProvider: (s, n) async => n.outputs,
          process: (s) {
            byNodesAsync.add('${s.depth}:${s.nodeValue}');
            return null;
          },
          maxDepth: 1,
        );
        expect(byNodesAsync, equals(walk));

        expect(
          GraphWalker<String>()
              .walkOrder(
                ['a'],
                nodeProvider: (s, v) => g.getNode(v),
                outputsProvider: (s, n) => n.outputs,
                maxDepth: 1,
              )
              .toListOfValues(),
          equals(['a', 'b', 'c']),
        );
        expect(
          GraphWalker<String>()
              .walkOrder(
                ['a'],
                nodeProvider: (s, v) => g.getNode(v),
                outputsProvider: (s, n) => n.outputs,
                maxDepth: 0,
              )
              .toListOfValues(),
          equals(['a']),
        );
      },
    );

    test('sideRoots(maxDepth: 1) sees every direct output', () {
      // a -> b -> c, a -> c, x -> c: `x` is a side root of `a`.
      var g = _shortcut();
      g.node('x').addOutput('c');

      expect(g.node('a').sideRoots(maxDepth: 1).toListOfValues(), ['x']);
      expect(g.node('a').sideRoots().toListOfValues(), ['x']);
    });
  });

  group('populate', () {
    test('without outputsProvider (inputsProvider only)', () {
      var g = Graph<String>();
      g.populate(['a', 'b']);
      expect(g.allNodesValues, equals(['a', 'b']));
      expect(g.allLeaves, hasLength(2));

      g.populate(['c'], inputsProvider: (s, v) => v == 'c' ? ['a', 'b'] : []);
      expect(g.node('c').inputsValues, equals(['a', 'b']));
      expect(g.node('a').outputsValues, equals(['c']));
      expect(g.rootValues, equals(['a', 'b']));
    });

    test(
      'populateAsync without outputsProvider (inputsProvider only)',
      () async {
        var g = Graph<String>();
        await g.populateAsync(['a', 'b']);
        expect(g.allNodesValues, equals(['a', 'b']));

        await g.populateAsync([
          'c',
        ], inputsProvider: (s, v) async => v == 'c' ? ['a', 'b'] : []);
        expect(g.node('c').inputsValues, equals(['a', 'b']));
        expect(g.toJson(), {
          'a': {'c': null},
          'b': {'c': 'c'},
        });
      },
    );
  });

  group('GraphWalker side branches', () {
    /// `a -> c`, `b -> c`, `c -> d`: walking from `a`, `b` is a side root.
    Graph<String> sideRootGraph() {
      var g = Graph<String>();
      g.node('a').addOutput('c');
      g.node('b').addOutput('c');
      g.node('c').addOutput('d');
      return g;
    }

    test('walkByNodes (processSideBranches, sortByInputDependency)', () {
      var g = sideRootGraph();

      var sideBranches = <String, List<String>>{};
      var visited = <String>[];
      GraphWalker<String>(sortByInputDependency: true).walkByNodes<bool>(
        [g.node('a')],
        outputsProvider: (s, n) => n.outputs,
        process: (s) {
          visited.add(s.nodeValue);
          return null;
        },
        processSideBranches: (s, l) {
          sideBranches[s.nodeValue] = l.toListOfValues();
          return null;
        },
      );

      expect(visited, equals(['a', 'c', 'd']));
      // `b` is never walked (the processor doesn't expand it), so it stays a
      // missing dependency of `c` and `d`:
      expect(
        sideBranches,
        equals({
          'a': ['b'],
          'c': ['b'],
          'd': ['b'],
        }),
      );
    });

    test('walkOrder (expandSideBranches, bfs)', () {
      var g = sideRootGraph();

      List<String> order({bool bfs = false}) =>
          GraphWalker<String>(bfs: bfs)
              .walkOrder(
                ['a'],
                nodeProvider: (s, v) => g.getNode(v),
                outputsProvider: (s, n) => n.outputs,
                expandSideBranches: true,
              )
              .toListOfValues();

      expect(order(), equals(['a', 'b', 'c', 'd']));
      expect(order(bfs: true), equals(['a', 'b', 'c', 'd']));
      expect(
        g.walkOutputsOrderFrom(['a'], expandSideRoots: true).toListOfValues(),
        equals(['a', 'b', 'c', 'd']),
      );
    });

    test('walkByNodes (expandSideBranches, null outputs)', () {
      var g = sideRootGraph();

      var steps = <String>[];
      GraphWalker<String>().walkByNodes<bool>(
        [g.node('a')],
        // Only the side branches are expanded:
        outputsProvider: (s, n) => null,
        process: (s) {
          steps.add(
            '${s.nodeValue}${s.sideBranch ? ' (side)' : ''}'
            '${s.isSideRoot ? ' (side root)' : ''}',
          );
          return null;
        },
        expandSideBranches: true,
      );

      expect(steps, equals(['a', 'b (side) (side root)']));

      // Neither outputs nor side branches: only the root.
      var noExpansion = <String>[];
      GraphWalker<String>().walkByNodes<bool>(
        [g.node('a')],
        outputsProvider: (s, n) => null,
        process: (s) {
          noExpansion.add(s.nodeValue);
          return null;
        },
      );
      expect(noExpansion, equals(['a']));
    });

    test('walkByNodes (expandSideBranches, sortByInputDependency)', () {
      var g = sideRootGraph();

      var steps = <String>[];
      GraphWalker<String>(sortByInputDependency: true).walkByNodes<bool>(
        [g.node('a')],
        outputsProvider: (s, n) => n.outputs,
        process: (s) {
          steps.add('${s.nodeValue}${s.sideBranch ? ' (side)' : ''}');
          return null;
        },
        expandSideBranches: true,
      );

      expect(steps, equals(['a', 'b (side)', 'c', 'd']));
    });
  });

  group('GraphNodeStep', () {
    test('nodePathToRoot reuses the previous step path', () {
      var g = Graph<String>();
      g.node('a').addOutput('b');
      g.node('b').addOutput('c');

      var paths = <String>[];
      GraphWalker<String>().walkByNodes<bool>(
        [g.node('a')],
        outputsProvider: (s, n) => n.outputs,
        process: (s) {
          paths.add(s.nodePathToRoot.toListOfValues().join('/'));
          // Cached:
          expect(s.nodePathToRoot, same(s.nodePathToRoot));
          return null;
        },
      );

      expect(paths, equals(['a', 'a/b', 'a/b/c']));
    });
  });
}
