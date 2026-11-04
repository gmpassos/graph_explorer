// Regression tests for the behaviour fixed in 1.2.0 (formerly pinned quirks),
// and walker options not exercised elsewhere.

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
  // Regressions: each of these failed before 1.2.0.
  group('Fixed in 1.2.0', () {
    test('sortByInputDependency: tied siblings keep insertion order', () {
      var g = _fork();

      expect(
        g.walkOutputsOrderFrom(['a']).toListOfValues(),
        equals(['a', 'b', 'c']),
      );
      expect(
        g.walkOutputsOrderFrom([
          'a',
        ], sortByInputDependency: true).toListOfValues(),
        equals(['a', 'b', 'c']),
      );
      expect(
        g
            .walkOutputsOrderFrom(['a'], sortByInputDependency: true, bfs: true)
            .toListOfValues(),
        equals(['a', 'b', 'c']),
      );

      expect(g.toTree().values.single.keys, equals(['b', 'c']));
      expect(
        g.toTree(sortByInputDependency: true).values.single.keys,
        equals(['b', 'c']),
      );
      expect(
        g.toJson(sortByInputDependency: true),
        equals({
          'a': {'b': null, 'c': null},
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
      expect(visited, equals(['a', 'b', 'c']));

      // Many tied siblings, and ties among nodes with more outputs:
      var wide = Graph<String>();
      var siblings = List.generate(12, (i) => 's$i');
      for (var s in siblings) {
        wide.node('root').addOutput(s);
      }
      expect(
        wide.node('root').outputs.sortedByInputDependency().toListOfValues(),
        equals(siblings),
      );
      expect(
        wide.node('root').outputs.sortedByOutputsDepth().toListOfValues(),
        equals(siblings),
      );
      expect(
        wide.node('root').outputs.sortedByInputDepth().toListOfValues(),
        equals(siblings),
      );

      // `y` and `z` have more outputs in depth, so they come first (tied):
      var g2 = Graph<String>();
      g2.node('a')
        ..addOutput('x')
        ..addOutput('y')
        ..addOutput('z');
      g2.node('y').addOutput('y1');
      g2.node('z').addOutput('z1');
      expect(
        g2.node('a').outputs.sortedByInputDependency().toListOfValues(),
        equals(['y', 'z', 'x']),
      );
    });

    test('Node.root: depth 1 ([self]) like an ordinary root', () {
      var g = Graph<String>();
      var alwaysRoot = g.root('r');
      var ordinaryRoot = g.node('a');

      expect(alwaysRoot.isRoot, isTrue);
      expect(ordinaryRoot.isRoot, isTrue);

      expect(alwaysRoot.shortestPathToRoot, equals([alwaysRoot]));
      expect(alwaysRoot.depth, equals(1));

      expect(ordinaryRoot.shortestPathToRoot, equals([ordinaryRoot]));
      expect(ordinaryRoot.depth, equals(1));

      // Children are counted from the root node itself in both cases:
      alwaysRoot.addOutput('x');
      ordinaryRoot.addOutput('y');
      expect(g.node('x').shortestPathToRoot.toListOfValues(), ['r', 'x']);
      expect(g.node('x').depth, equals(2));
      expect(g.node('y').depth, equals(2));

      // Unchanged after getting outputs:
      expect(alwaysRoot.depth, equals(1));
      expect(alwaysRoot.shortestPathToRoot, equals([alwaysRoot]));

      expect(Node.root('n').depth, equals(1));
      expect(Node.root('n').shortestPathToRoot.toListOfValues(), ['n']);
    });

    test('scan paths start at `from`', () async {
      // x -> d
      // a -> d
      var g = Graph<String>();
      g.node('x').addOutput('d');
      g.node('a').addOutput('d');

      var shortest = await g.scanPathsFrom('a', 'd');
      expect(
        shortest.paths.toListOfStringPaths(),
        equals([
          ['a', 'd'],
        ]),
      );

      var all = await g.scanPathsFrom('a', 'd', findAll: true);
      expect(
        all.paths.toListOfStringPaths(),
        equals([
          ['a', 'd'],
        ]),
      );

      expect(
        (await g.shortestPathsFrom('x', 'd')).toListOfValuePaths(),
        equals([
          ['x', 'd'],
        ]),
      );
      expect(
        (await g.scanPathsMatching([
          'a',
        ], NodeEquals('d'))).paths.toListOfValuePaths(),
        equals([
          ['a', 'd'],
        ]),
      );
      expect(
        (await g.shortestPathsMatching([
          'x',
        ], NodeEquals('d'))).toListOfValuePaths(),
        equals([
          ['x', 'd'],
        ]),
      );

      // Scanning from a non-root node:
      var chain = Graph<String>();
      chain.node('a').addOutput('b');
      chain.node('b').addOutput('d');
      for (var findAll in [false, true]) {
        var r = await chain.scanPathsFrom('b', 'd', findAll: findAll);
        expect(
          r.paths.toListOfStringPaths(),
          equals([
            ['b', 'd'],
          ]),
        );
      }

      // Scanning from a node in a cycle (that has no root):
      var cycle = Graph<String>();
      cycle.node('a').addOutput('b');
      cycle.node('b').addOutput('c');
      cycle.node('c').addOutput('a');
      for (var findAll in [false, true]) {
        var r = await cycle.scanPathsFrom('b', 'a', findAll: findAll);
        expect(
          r.paths.toListOfStringPaths(),
          equals([
            ['b', 'c', 'a'],
          ]),
        );
      }

      // With an `outputsProvider` (populating a new graph):
      var adj = {
        'x': ['d'],
        'a': ['d'],
        'b': ['x'],
      };
      for (var findAll in [false, true]) {
        var r = await GraphScanner<String>(findAll: findAll).scanPathsFrom(
          'b',
          NodeEquals('d'),
          outputsProvider: (g, n) => [...?adj[n.value]].map(g.node).toList(),
        );
        expect(
          r.paths.toListOfStringPaths(),
          equals([
            ['b', 'x', 'd'],
          ]),
        );
      }
    });

    test('shortestPathToRoot / depth are the shortest', () async {
      // a -> b -> c -> d, then a -> d:
      var g = Graph<String>();
      g.node('a').addOutput('b');
      g.node('b').addOutput('c');
      g.node('c').addOutput('d');

      var d = g.node('d');
      expect(d.depth, equals(4));
      expect(d.shortestPathToRoot.toListOfValues(), ['a', 'b', 'c', 'd']);

      // A new edge invalidates the cached path and depth:
      g.node('a').addOutput('d');
      expect(d.inputsValues, equals(['c', 'a']));

      expect(d.shortestPathToRoot.toListOfValues(), ['a', 'd']);
      expect(d.depth, equals(2));
      expect(d.isInputInShortestPathToRoot(g.node('b')), isFalse);
      expect(
        (await g.shortestPathsFrom('a', 'd')).toListOfValuePaths(),
        equals([
          ['a', 'd'],
        ]),
      );
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

      // A change upstream (not touching `e` or `d`) also invalidates them:
      // `r -> c` makes `c` reachable from a new root.
      var e = g.node('e');
      g.node('d').addOutput('e');
      expect(e.depth, equals(3));
      expect(e.shortestPathToRoot.toListOfValues(), ['a', 'd', 'e']);
      g.node('c').addOutput('x');
      g.node('x').addOutput('e');
      expect(e.depth, equals(3));
      g.node('r').addOutput('x');
      // `r -> x -> e` (3) ties with `a -> d -> e` (3): the 1st input wins.
      expect(e.inputsValues, equals(['d', 'x']));
      expect(e.shortestPathToRoot.toListOfValues(), ['a', 'd', 'e']);
      g.node('r2').addOutput('e');
      expect(e.depth, equals(2));
      expect(e.shortestPathToRoot.toListOfValues(), ['r2', 'e']);
      expect(g.node('x').depth, equals(2));
      expect(g.node('x').shortestPathToRoot.toListOfValues(), ['r', 'x']);

      // An edge that doesn't touch `u` invalidates its cached path:
      var chain = Graph<String>();
      chain.node('p').addOutput('q');
      chain.node('q').addOutput('s');
      chain.node('s').addOutput('u');
      var u = chain.node('u');
      expect(u.shortestPathToRoot.toListOfValues(), ['p', 'q', 's', 'u']);
      expect(u.toString(), startsWith('(4)'));
      chain.node('p').addOutput('s');
      expect(u.toString(), startsWith('(?)'));
      expect(u.shortestPathToRoot.toListOfValues(), ['p', 's', 'u']);
      expect(u.depth, equals(3));

      // Ties: the 1st input in a shortest path.
      var t = Graph<String>();
      t.node('a')
        ..addOutput('b')
        ..addOutput('c');
      t.node('c').addOutput('d');
      t.node('b').addOutput('d');
      expect(t.node('d').inputsValues, equals(['c', 'b']));
      expect(t.node('d').shortestPathToRoot.toListOfValues(), ['a', 'c', 'd']);

      // A node created with the `Node` constructor (not in the graph):
      var foreign = Node('f', graph: t);
      foreign.addOutput('d');
      expect(t.node('d').depth, equals(2));
      expect(t.node('d').shortestPathToRoot.toListOfValues(), ['f', 'd']);
    });

    test('default maxExpansion: findAll returns all the paths', () async {
      // 3 chained diamonds: 2^3 paths through the same nodes.
      var g = Graph<String>();
      for (var i = 0; i < 3; i++) {
        g.node('t$i')
          ..addOutput('l$i')
          ..addOutput('r$i');
        g.node('l$i').addOutput('t${i + 1}');
        g.node('r$i').addOutput('t${i + 1}');
      }

      var all = await g.scanPathsFrom('t0', 't3', findAll: true);
      expect(all.paths, hasLength(8));
      expect(
        await g.shortestPathsFrom('t0', 't3', findAll: true),
        hasLength(8),
      );
      expect(await g.allPaths, hasLength(8));
      expect(g.node('t3').resolveAllPathsToRoot(), hasLength(8));

      // An explicit cap:
      var capped = await GraphScanner<String>(findAll: true)
          .scanPathsFrom('t0', NodeEquals('t3'), graph: g, maxExpansion: 1);
      expect(capped.paths.length, inInclusiveRange(1, 7));
      expect(
        g.node('t3').resolveAllPathsToRoot(maxExpansion: 1).length,
        inInclusiveRange(1, 7),
      );
    });
  });

  group('Graph without roots', () {
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

    test('DFS with maxDepth >= 2: a node first reached deeper', () async {
      // a -> b -> c -> d, a -> c: `d` is at distance 2 (a -> c -> d), but a
      // DFS reaches `c` first at depth 2 (through `b`), where `d` (depth 3)
      // is beyond `maxDepth`. Since 1.2.0 `c` is expanded again when
      // reached at depth 1 (without being processed again).
      var g = Graph<String>();
      g.node('a')
        ..addOutput('b')
        ..addOutput('c');
      g.node('b').addOutput('c');
      g.node('c').addOutput('d');

      var a = g.node('a');
      expect(
        a.outputsInDepth(maxDepth: 2).toListOfValues(),
        equals(['b', 'c', 'd']),
      );
      expect(
        a.outputsInDepth(maxDepth: 2, bfs: true).toListOfValues(),
        equals(['b', 'c', 'd']),
      );
      // DFS order is kept, and `maxDepth: 1` is unchanged:
      expect(a.outputsInDepth().toListOfValues(), equals(['b', 'c', 'd']));
      expect(
        a.outputsInDepth(maxDepth: 1).toListOfValues(),
        equals(['b', 'c']),
      );
      expect(g.node('d').inputsInDepth(maxDepth: 2).toListOfValues(), [
        'c',
        'a',
        'b',
      ]);

      // Every walker API (the step depths of the re-expansion are shallower):
      List<String> steps(void Function(List<String> steps) walk) {
        var l = <String>[];
        walk(l);
        return l;
      }

      Object? record(List<String> l, GraphNodeStep<String> s) {
        l.add('${s.depth}:${s.nodeValue}');
        return null;
      }

      var expected = ['0:a', '1:b', '2:c', '2:d'];

      expect(
        steps(
          (l) => GraphWalker<String>().walkByNodes<bool>(
            [a],
            outputsProvider: (s, n) => n.outputs,
            process: (s) => record(l, s),
            maxDepth: 2,
          ),
        ),
        equals(expected),
      );

      var byNodesAsync = <String>[];
      await GraphWalker<String>().walkByNodesAsync<bool>(
        [a],
        outputsProvider: (s, n) async => n.outputs,
        process: (s) async => record(byNodesAsync, s),
        maxDepth: 2,
      );
      expect(byNodesAsync, equals(expected));

      expect(
        steps(
          (l) => GraphWalker<String>().walk<bool>(
            ['a'],
            nodeProvider: (s, v) => g.getNode(v),
            outputsProvider: (s, v) => g.getNode(v)!.outputsValues,
            process: (s) => record(l, s),
            maxDepth: 2,
          ),
        ),
        equals(expected),
      );

      var walkAsync = <String>[];
      await GraphWalker<String>().walkAsync<bool>(
        ['a'],
        nodeProvider: (s, v) async => g.getNode(v),
        outputsProvider: (s, v) async => g.getNode(v)!.outputsValues,
        process: (s) async => record(walkAsync, s),
        maxDepth: 2,
      );
      expect(walkAsync, equals(expected));

      expect(
        GraphWalker<String>()
            .walkOrder(
              ['a'],
              nodeProvider: (s, v) => g.getNode(v),
              outputsProvider: (s, n) => n.outputs,
              maxDepth: 2,
            )
            .toListOfValues(),
        equals(['a', 'b', 'c', 'd']),
      );

      // A node skipped by the processor (`next`) is not re-expanded:
      expect(
        steps(
          (l) => GraphWalker<String>().walkByNodes<bool>(
            [a],
            outputsProvider: (s, n) => n.outputs,
            process: (s) {
              record(l, s);
              return s.nodeValue == 'c' ? GraphWalkingInstruction.next() : null;
            },
            maxDepth: 2,
          ),
        ),
        equals(['0:a', '1:b', '2:c']),
      );
    });

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
