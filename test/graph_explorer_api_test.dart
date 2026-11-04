import 'dart:async';

import 'package:graph_explorer/graph_explorer.dart';
import 'package:test/test.dart';

/// Builds the diamond graph:
/// ```
/// a -> b -> d -> e
/// a -> c -> d
/// ```
Graph<String> _diamond() {
  var g = Graph<String>();
  var a = g.node('a');
  a.addOutput('b');
  a.addOutput('c');
  g.node('b').addOutput('d');
  g.node('c').addOutput('d');
  g.node('d').addOutput('e');
  return g;
}

List<Node<String>> _path(List<String> values) =>
    values.map((v) => Node(v)).toList();

/// Asserts that [order] visits every node of [_diamond] after its inputs.
/// (The relative order of the independent siblings `b` and `c` is not asserted.)
void _expectDiamondDependencyOrder(List<String> order) {
  expect(order, unorderedEquals(['a', 'b', 'c', 'd', 'e']));
  expect(order.first, equals('a'));
  expect(order.indexOf('d'), greaterThan(order.indexOf('b')));
  expect(order.indexOf('d'), greaterThan(order.indexOf('c')));
  expect(order.last, equals('e'));
}

void main() {
  group('NodeMatcher', () {
    test('NodeMatcher.eq', () {
      expect(NodeMatcher.eq(['a']), isA<NodeEquals<String>>());
      expect(NodeMatcher.eq(['a', 'b']), isA<MultipleNodesEquals<String>>());
    });

    test('hashCode and toString', () {
      expect(AnyNode<String>().hashCode, equals(AnyNode<String>().hashCode));
      expect(AnyNode<String>().toString(), equals('AnyNode{}'));

      expect(NoneNode<String>().hashCode, equals(NoneNode<String>().hashCode));
      expect(NoneNode<String>().toString(), equals('NoneNode{}'));

      expect(NodeEquals('a').hashCode, equals(NodeEquals('a').hashCode));
      expect(NodeEquals('a').toString(), equals('NodeEquals{targetValue: a}'));

      expect(
        MultipleNodesEquals(['a', 'b']).hashCode,
        equals(MultipleNodesEquals(['a', 'b']).hashCode),
      );
      expect(
        MultipleNodesEquals(['a', 'b']).toString(),
        equals('MultipleNodesEquals{targetValues: [a, b]}'),
      );
    });

    test('matchesNode', () {
      expect(AnyNode<String>().matchesNode(Node('x')), isTrue);
      expect(NoneNode<String>().matchesNode(Node('x')), isFalse);
      expect(NodeEquals('x').matchesNode(Node('x')), isTrue);
      expect(MultipleNodesEquals(['x', 'y']).matchesNode(Node('y')), isTrue);
      expect(MultipleNodesEquals(['x', 'y']).matchesNode(Node('z')), isFalse);
    });
  });

  group('Graph', () {
    test('node lookup', () {
      var g = _diamond();

      expect(g.length, equals(5));
      expect(g.isNotEmpty, isTrue);
      expect(g.allNodesValues, unorderedEquals(['a', 'b', 'c', 'd', 'e']));

      expect(g['a']?.value, equals('a'));
      expect(g['z'], isNull);
      expect(g.getNode(null), isNull);

      expect(
        g.getNodesNullable(['a', 'z', 'e']).map((e) => e?.value),
        equals(['a', null, 'e']),
      );
      expect(g.getNodes(['a', 'z', 'e']).toListOfValues(), equals(['a', 'e']));

      expect(g.valuesToNodes(['a', 'b']).toListOfValues(), equals(['a', 'b']));
      expect(
        () => g.valuesToNodes(['a', 'z']).toList(),
        throwsA(isA<StateError>()),
      );
      expect(
        g.valuesToNodes(['a', 'z'], createNodes: true).toListOfValues(),
        equals(['a', 'z']),
      );
      expect(g.length, equals(6));
    });

    test('NodeIO implementation', () {
      var g = Graph<String>();

      expect(g.addInput('a')?.value, equals('a'));
      expect(g.addInput('a'), isNull);
      expect(g.addOutput('b')?.value, equals('b'));
      expect(g.addOutput('b'), isNull);

      expect(g.containsInput('a'), isTrue);
      expect(g.containsOutput('b'), isTrue);
      expect(g.containsInput('z'), isFalse);

      expect(g.inputs.toListOfValues(), equals(['a', 'b']));
      expect(g.outputs.toListOfValues(), equals(['a', 'b']));
    });

    test('roots, rootValues, allLeaves', () {
      var g = _diamond();
      expect(g.rootValues, equals(['a']));
      expect(g.allLeaves.toListOfValues(), equals(['e']));
    });

    test('root (always root node)', () {
      var g = Graph<String>();

      var r = g.root('r');
      expect(r.isRoot, isTrue);
      expect(r.isAlwaysRoot, isTrue);
      expect(identical(g.root('r'), r), isTrue);

      // An always-root node can't receive inputs:
      expect(() => r.addInput('x'), throwsUnsupportedError);

      // Adding outputs keeps it as an always-root node:
      r.addOutput('x');
      expect(r.isAlwaysRoot, isTrue);
      expect(r.outputsValues, equals(['x']));

      // A normal root node is not an always-root node,
      // even after its shortest path to root has been resolved:
      var n = g.node('n');
      expect(n.isRoot, isTrue);
      expect(n.shortestPathToRoot.toListOfValues(), equals(['n']));
      expect(n.isAlwaysRoot, isFalse);
    });

    test('dispose', () {
      var g = _diamond();
      var a = g.node('a');
      var e = g.node('e');

      g.dispose();

      expect(g.isEmpty, isTrue);
      expect(a.graph, isNull);
      expect(e.graph, isNull);
      expect(() => a.addOutput('z'), throwsA(isA<StateError>()));
    });

    test('disposeGraph (nodes and paths)', () {
      var g1 = _diamond();
      [g1.node('a')].disposeGraph();
      expect(g1.isEmpty, isTrue);

      var g2 = _diamond();
      [
        [g2.node('a'), g2.node('b')],
      ].disposeGraph();
      expect(g2.isEmpty, isTrue);
    });

    test('toTree (bfs / dfs)', () {
      var g = _diamond();

      var expected = {
        'a': {
          'b': {
            'd': {'e': null},
          },
          'c': {'d': 'd'},
        },
      };

      expect(g.toTree<String>(), equals(expected));
      expect(g.toTree<String>(bfs: true), equals(expected));
      expect(g.toJson(), equals(expected));
    });

    test('toTree (dynamic and Node keys)', () {
      var g = Graph<int>();
      g.node(1).addOutput(2);

      expect(
        g.toTree(),
        equals({
          1: {2: null},
        }),
      );

      var nodeTree = GraphWalker<int>().toTreeFrom<Node<int>>(
        [1],
        nodeProvider: (s, v) => g.getNode(v),
        outputsProvider: (s, n) => n.outputs,
      );
      expect(nodeTree.keys.single, isA<Node<int>>());
      expect(nodeTree.keys.single.value, equals(1));
    });

    test('toTree / toTreeFrom (keyCast)', () {
      var g = _diamond();

      expect(
        g.toTree<String>(keyCast: (v) => v.toUpperCase()),
        equals({
          'A': {
            'B': {
              'D': {'E': null},
            },
            'C': {'D': 'D'},
          },
        }),
      );

      expect(
        g.toTreeFrom<String>(['b'], keyCast: (v) => '<$v>'),
        equals({
          '<b>': {
            '<d>': {'<e>': null},
          },
        }),
      );

      var gInt = Graph<int>()
        ..node(1).addOutput(2)
        ..node(2).addOutput(3);

      expect(
        gInt.toTree<String>(keyCast: (v) => 'n$v'),
        equals({
          'n1': {
            'n2': {'n3': null},
          },
        }),
      );
    });

    test('toTreeFrom (missing root)', () {
      var g = _diamond();
      expect(() => g.toTreeFrom<String>(['z']), throwsArgumentError);
    });

    test('fromJson (reference replaced by full node)', () {
      var g = Graph<String>.fromJson({
        'a': {'c': 'c'},
        'b': {
          'c': {'d': null},
        },
      });

      expect(g.node('a').outputsValues, equals(['c']));
      expect(g.node('b').outputsValues, equals(['c']));
      expect(g.node('c').outputsValues, equals(['d']));
      expect(g.node('c').inputsValues, unorderedEquals(['a', 'b']));
    });

    test('fromJson (merged node definitions)', () {
      var g = Graph<String>.fromJson({
        'a': {
          'c': {'d': null},
        },
        'b': {
          'c': {'e': null},
        },
      });

      expect(g.node('c').outputsValues, unorderedEquals(['d', 'e']));
    });

    test('fromJson (non-String node type)', () {
      var json = {
        '1': {
          '2': {'4': null},
          '3': {'4': '4'},
        },
      };

      var g = Graph<int>.fromJson(
        json,
        nodeValueMapper: (s, k) => int.parse(k),
      );

      expect(g.allNodesValues, unorderedEquals([1, 2, 3, 4]));
      expect(g.rootValues, equals([1]));
      expect(g.node(1).outputsValues, equals([2, 3]));
      expect(g.node(2).outputsValues, equals([4]));
      expect(g.node(3).outputsValues, equals([4]));
      expect(g.node(4).inputsValues, unorderedEquals([2, 3]));

      // Round-trip back to the same JSON:
      expect(g.toJson(), equals(json));
    });

    test('fromJson (non-String node type, merged definitions)', () {
      var g = Graph<int>.fromJson({
        '1': {
          '3': {'4': null},
        },
        '2': {
          '3': {'5': null},
        },
      }, nodeValueMapper: (s, k) => int.parse(k));

      expect(g.node(3).outputsValues, unorderedEquals([4, 5]));
      expect(g.node(3).inputsValues, unorderedEquals([1, 2]));
    });

    test('fromJson (non-String node type, reference with different key)', () {
      // Keys that map to the same node value through `nodeValueMapper`
      // but are spelled differently in the JSON:
      var g = Graph<int>.fromJson({
        '1': {
          '02': {'4': null},
        },
        '3': {'2': '2'},
      }, nodeValueMapper: (s, k) => int.parse(k));

      expect(g.node(1).outputsValues, equals([2]));
      expect(g.node(3).outputsValues, equals([2]));
      expect(g.node(2).outputsValues, equals([4]));
    });

    test('fromJson (invalid)', () {
      expect(
        () => Graph<String>.fromJson({'a': 123}),
        throwsA(isA<StateError>()),
      );

      expect(
        () => Graph<String>.fromJson({
          'a': {
            'c': {'d': null},
          },
          'b': {'c': 'x'},
        }),
        throwsA(isA<StateError>()),
      );

      expect(
        () => Graph<String>.fromJson({
          'a': {
            'c': {'d': null},
          },
          'b': {'c': 123},
        }),
        throwsA(isA<StateError>()),
      );
    });

    test('scanPathsMatching / shortestPaths*', () async {
      var g = _diamond();

      var result = await g.scanPathsMatching(['a'], NodeEquals('d'));
      expect(
        result.paths.toListOfStringPaths(),
        unorderedEquals([
          ['a', 'b', 'd'],
          ['a', 'c', 'd'],
        ]),
      );
      expect(result.findAll, isTrue);
      expect(result.toString(), contains('paths: 2'));

      expect(
        (await g.shortestPathsMatching([
          'a',
        ], MultipleNodesEquals(['b', 'e']))).toListOfStringPaths(),
        equals([
          ['a', 'b'],
        ]),
      );

      // `findAll: false`: stops at the first target found:
      expect(
        (await g.shortestPathsFromMany(
          ['a'],
          ['d', 'e'],
        )).toListOfStringPaths(),
        equals([
          ['a', 'b', 'd'],
        ]),
      );

      expect(
        (await g.shortestPathsFromMany(
          ['a'],
          ['d', 'e'],
          findAll: true,
        )).toListOfStringPaths(),
        unorderedEquals([
          ['a', 'b', 'd'],
          ['a', 'c', 'd'],
        ]),
      );

      expect(
        (await g.shortestPaths).toListOfStringPaths(),
        unorderedEquals([
          ['a', 'b', 'd', 'e'],
          ['a', 'c', 'd', 'e'],
        ]),
      );
    });

    test('GraphScanner with empty graph', () async {
      var result = await GraphScanner<String>().scanPathsFrom(
        'a',
        NodeEquals('b'),
        graph: Graph<String>(),
      );
      expect(result.paths, isEmpty);
      expect(result.time, equals(Duration.zero));
    });

    test('GraphScanner with an async outputsProvider', () async {
      var edges = {
        'a': ['b', 'c'],
        'b': ['d'],
        'c': ['d'],
        'd': <String>[],
      };

      var result = await GraphScanner<String>(findAll: true).scanPathsFrom(
        'a',
        NodeEquals('d'),
        outputsProvider: (g, n) async =>
            edges[n.value]!.map((e) => g.node(e)).toList(),
      );

      expect(
        result.paths.toListOfStringPaths(),
        unorderedEquals([
          ['a', 'b', 'd'],
          ['a', 'c', 'd'],
        ]),
      );
    });

    test('GraphScanner on existing graph with outputsProvider', () async {
      var g = _diamond();

      // The `outputsProvider` drives the walk: `a` has no outputs to explore.
      var blocked = await GraphScanner<String>().scanPathsFrom(
        'a',
        NodeEquals('d'),
        graph: g,
        outputsProvider: (g, n) => n.value == 'a' ? [] : n.outputs.toList(),
      );
      expect(blocked.paths, isEmpty);

      // Only expand through `c`:
      var visited = <String>[];
      var result = await GraphScanner<String>().scanPathsFrom(
        'a',
        NodeEquals('d'),
        graph: g,
        outputsProvider: (g, n) {
          visited.add(n.value);
          return n.value == 'a' ? [g.node('c')] : n.outputs.toList();
        },
      );
      expect(visited, equals(['a', 'c']));
      expect(result.paths, isNotEmpty);
      expect(result.paths.every((p) => p.last.value == 'd'), isTrue);
    });

    test('populate (inputsProvider + process result)', () {
      var g = Graph<String>();

      var ret = g.populate<String>(
        ['c'],
        inputsProvider: (s, v) => v == 'c' ? ['a', 'b'] : null,
        outputsProvider: (s, v) => v == 'c' ? ['d'] : null,
        process: (step) => step.nodeValue == 'd'
            ? GraphWalkingInstruction.result('found:${step.nodeValue}')
            : null,
      );

      expect(ret, equals('found:d'));
      expect(g.node('c').inputsValues, equals(['a', 'b']));
      expect(g.node('c').outputsValues, equals(['d']));
      expect(g.rootValues, unorderedEquals(['a', 'b']));
    });

    test('populateAsync (inputsProvider + process)', () async {
      var g = Graph<String>();
      var processed = <String>[];

      await g.populateAsync<bool>(
        ['c'],
        inputsProvider: (s, v) async => v == 'c' ? ['a', 'b'] : null,
        outputsProvider: (s, v) async => v == 'c' ? ['d'] : null,
        process: (step) async {
          processed.add(step.nodeValue);
          return null;
        },
      );

      expect(processed, equals(['c', 'd']));
      expect(g.node('c').inputsValues, equals(['a', 'b']));
      expect(g.node('d').inputsValues, equals(['c']));
    });

    test('walkInputsFrom / walkInputsOrderFrom', () {
      var g = _diamond();

      var visited = <String>[];
      var ret = g.walkInputsFrom<bool>(['e'], (step) {
        visited.add(step.nodeValue);
        return null;
      });
      expect(ret, isFalse);
      expect(visited, equals(['e', 'd', 'b', 'a', 'c']));

      var stopped = g.walkInputsFrom<Node<String>>(
        ['e'],
        (step) => null,
        stopMatcher: NodeEquals('b'),
      );
      expect(stopped?.value, equals('b'));

      expect(
        g.walkInputsOrderFrom(['e'], bfs: true).toListOfValues(),
        equals(['e', 'd', 'b', 'c', 'a']),
      );
      expect(
        g.walkInputsOrderFrom(['e'], processRoots: false).toListOfValues(),
        equals(['d', 'b', 'a', 'c']),
      );
    });

    test('walkOutputsOrderFrom (sortByInputDependency, stopMatcher)', () {
      var g = _diamond();

      _expectDiamondDependencyOrder(
        g
            .walkOutputsOrderFrom(['a'], sortByInputDependency: true, bfs: true)
            .toListOfValues(),
      );
      _expectDiamondDependencyOrder(
        g
            .walkOutputsOrderFrom(
              ['a'],
              sortByInputDependency: true,
              expandSideRoots: true,
            )
            .toListOfValues(),
      );

      expect(
        g
            .walkOutputsOrderFrom(
              ['a'],
              stopMatcher: NodeEquals('c'),
              bfs: true,
            )
            .toListOfValues(),
        equals(['a', 'b', 'c']),
      );
    });
  });

  group('Node', () {
    test('getOrAdd / get inputs and outputs', () {
      var g = Graph<String>();
      var a = g.node('a');

      var b = a.getOrAddOutput('b');
      expect(b.value, equals('b'));
      expect(identical(a.getOrAddOutput('b'), b), isTrue);
      expect(identical(a.getOrAddOutput('a'), a), isTrue);
      expect(a.getOutput('b'), equals(b));
      expect(a.getOutput('z'), isNull);
      expect(identical(a.getOutput('a'), a), isTrue);

      var x = b.getOrAddInput('x');
      expect(b.inputsValues, equals(['a', 'x']));
      expect(identical(b.getOrAddInput('x'), x), isTrue);
      expect(identical(b.getOrAddInput('b'), b), isTrue);
      expect(b.getInput('x'), equals(x));
      expect(b.getInput('z'), isNull);
      expect(identical(b.getInput('b'), b), isTrue);

      // Self references are ignored:
      expect(a.addOutput('a'), isNull);
      expect(a.addInput('a'), isNull);
      // Duplicates are ignored:
      expect(b.addInput('x'), isNull);
      expect(a.addOutput('b'), isNull);

      expect(a.containsOutputNode(b), isTrue);
      expect(b.containsInputNode(a), isTrue);
      expect(b.containsInput('a'), isTrue);
      expect(b.containsInput('z'), isFalse);
    });

    test('without graph', () {
      var n = Node('a');
      expect(n.graph, isNull);
      expect(() => n.addOutput('b'), throwsA(isA<StateError>()));
      expect(() => n.addInput('b'), throwsA(isA<StateError>()));
      expect(() => n.getOrAddOutput('b'), throwsA(isA<StateError>()));
      expect(() => n.getOrAddInput('b'), throwsA(isA<StateError>()));
    });

    test('isInput / isOutput', () {
      var g = _diamond();
      var a = g.node('a');
      var e = g.node('e');

      expect(a.isOutput('e'), isTrue);
      expect(e.isInput('a'), isTrue);
      expect(e.isOutput('a'), isFalse);
      expect(a.isInput('e'), isFalse);
      expect(a.isOutputNode(a), isFalse);
      expect(a.isInputNode(a), isFalse);
    });

    test('depth, shortestPathToRoot, toString', () {
      var g = _diamond();
      var e = g.node('e');

      expect(e.toString(), equals('(?) 1 -> e -> 0'));
      expect(e.depth, equals(4));
      expect(
        e.shortestPathToRoot.toListOfValues(),
        equals(['a', 'b', 'd', 'e']),
      );
      expect(e.toString(), equals('(4) 1 -> e -> 0'));
      expect(e.isInputInShortestPathToRoot(g.node('b')), isTrue);
      expect(e.isInputInShortestPathToRoot(g.node('c')), isFalse);
    });

    test('roots / dependencies / missingDependencies', () {
      var g = _diamond();
      var d = g.node('d');

      expect(d.roots().toListOfValues(), equals(['a']));

      expect(
        d.dependencies().toListOfValues(),
        unorderedEquals(['a', 'b', 'c']),
      );
      // Only the inputs of the in depth outputs (`e`):
      expect(
        d.dependencies(includeThisInputs: false).toListOfValues(),
        unorderedEquals(['a', 'b', 'c']),
      );
      expect(
        g.node('e').dependencies(includeThisInputs: false).toListOfValues(),
        isEmpty,
      );
      expect(
        g.node('b').dependencies(maxDepth: 1).toListOfValues(),
        unorderedEquals(['a', 'c']),
      );
      expect(
        g
            .node('b')
            .dependencies(maxDepth: 1, ignore: [g.node('d')])
            .toListOfValues(),
        equals(['a']),
      );

      expect(
        d.missingDependencies([g.node('a'), g.node('b')]).toListOfValues(),
        equals(['c']),
      );
    });

    test('in depth intersections', () {
      var g = _diamond();
      var b = g.node('b');
      var c = g.node('c');
      var e = g.node('e');

      expect(b.outputsInDepthIntersection(c).toListOfValues(), ['d', 'e']);
      expect(b.outputsInDepthIntersection(null), isEmpty);
      expect(b.outputsInDepthIntersection(e), isEmpty);

      expect(b.inputsInDepthIntersection(c).toListOfValues(), ['a']);
      expect(b.inputsInDepthIntersection(null), isEmpty);
      expect(b.inputsInDepthIntersection(g.node('a')), isEmpty);

      expect(
        [b, c].outputsInDepthIntersection().toListOfValues(),
        equals(['d', 'e']),
      );
      expect(
        [b, c].inputsInDepthIntersection().toListOfValues(),
        equals(['a']),
      );
    });

    test('reset', () {
      var n = Node('a');
      n.markAsTarget();
      n.attachment = 123;
      expect(n.isTarget, isTrue);

      n.reset();
      expect(n.isTarget, isFalse);
      expect(n.attachment, isNull);
    });
  });

  group('IterableNodeExtension', () {
    test('merge', () {
      var l = _path(['a', 'b']);
      expect(l.merge(l).toListOfValues(), equals(['a', 'b']));
      expect(<Node<String>>[].merge(l).toListOfValues(), equals(['a', 'b']));
      expect(<Node<String>>[].merge([]), isEmpty);
      expect(l.merge([]).toListOfValues(), equals(['a', 'b']));
      expect(
        l.merge(_path(['b', 'c'])).toListOfValues(),
        equals(['a', 'b', 'c']),
      );
    });

    test('intersection', () {
      var l = _path(['a', 'b']);
      expect(l.intersection(l).toListOfValues(), equals(['a', 'b']));
      expect(l.intersection([]), isEmpty);
      expect(<Node<String>>[].intersection(l), isEmpty);
      expect(l.intersection(_path(['b', 'c'])).toListOfValues(), ['b']);
    });

    test('complement', () {
      var l = _path(['a', 'b']);
      var o = _path(['b', 'c']);

      expect(l.complement(l), isEmpty);
      expect(l.complement(o).toListOfValues(), equals(['a', 'c']));
      expect(
        l.complement(o, includeOther: false).toListOfValues(),
        equals(['a']),
      );
      expect(
        l.complement(o, includeThis: false).toListOfValues(),
        equals(['c']),
      );
      expect(<Node<String>>[].complement(o).toListOfValues(), ['b', 'c']);
      expect(<Node<String>>[].complement(o, includeOther: false), isEmpty);
      expect(l.complement([]).toListOfValues(), ['a', 'b']);
      expect(l.complement([], includeThis: false), isEmpty);
    });

    test('sorted by depth / dependency', () {
      var g = _diamond();
      var nodes = g.getNodes(['e', 'a', 'd']).toList();

      expect(
        nodes.sortedByInputDepth().toListOfValues(),
        equals(['a', 'd', 'e']),
      );
      expect(
        nodes.sortedByOutputsDepth().toListOfValues(),
        equals(['e', 'd', 'a']),
      );
      expect(
        nodes.sortedByInputDependency().toListOfValues(),
        equals(['a', 'd', 'e']),
      );
      expect(
        g.getNodes(['c', 'a']).sortedByInputDependency().toListOfValues(),
        equals(['a', 'c']),
      );
      expect(
        g.getNodes(['a']).sortedByInputDependency().toListOfValues(),
        equals(['a']),
      );
    });

    test('toIterableOfString / toListOfString', () {
      var l = _path(['a', 'b']);
      expect(l.toIterableOfString().toList(), equals(['a', 'b']));
      expect(l.toListOfString(), equals(['a', 'b']));
    });
  });

  group('IterableOfListNodeExtension', () {
    test('shortest and longest paths', () {
      var paths = [
        _path(['a', 'b']),
        _path(['a', 'x', 'y', 'b']),
        _path(['a', 'c', 'b']),
        _path(['a', 'd']),
        _path(['a', 'z', 'w', 'b']),
      ];

      expect(
        paths.sortedPathsByLength().map((p) => p.length),
        equals([2, 2, 3, 4, 4]),
      );

      expect(
        paths.shortestPaths().toListOfStringPaths(),
        equals([
          ['a', 'b'],
          ['a', 'd'],
        ]),
      );
      expect(paths.firstShortestPath().toListOfValues(), equals(['a', 'b']));

      expect(
        paths.longestPaths().toListOfStringPaths(),
        equals([
          ['a', 'x', 'y', 'b'],
          ['a', 'z', 'w', 'b'],
        ]),
      );
      expect(
        paths.firstLongestPath().toListOfValues(),
        equals(['a', 'x', 'y', 'b']),
      );

      var sameLength = [
        _path(['a', 'b']),
        _path(['a', 'c']),
      ];
      expect(sameLength.shortestPaths().length, equals(2));
      expect(sameLength.longestPaths().length, equals(2));

      var empty = <List<Node<String>>>[];
      expect(empty.shortestPaths(), isEmpty);
      expect(empty.longestPaths(), isEmpty);
      expect(empty.firstShortestPath(), isEmpty);
      expect(empty.firstLongestPath(), isEmpty);
    });

    test('toListOfValuePaths', () {
      var paths = [
        _path(['a', 'b']),
      ];
      expect(
        paths.toListOfValuePaths(),
        equals([
          ['a', 'b'],
        ]),
      );
    });
  });

  group('Map extensions', () {
    test('toMapOfNodeValues / toMapOfListOfValues / toMapOfValues', () {
      var g = _diamond();
      var a = g.node('a');
      var b = g.node('b');

      expect({a: 1, b: 2}.toMapOfNodeValues(), equals({'a': 1, 'b': 2}));

      expect(
        {'k': a.outputs}.toMapOfListOfValues(),
        equals({
          'k': ['b', 'c'],
        }),
      );

      expect(
        [a, b].outputsInDepth(maxDepth: 1).toMapOfValues(),
        equals({
          'a': ['b', 'c'],
          'b': ['d'],
        }),
      );
      expect(
        [b].inputsInDepth().toMapOfValues(),
        equals({
          'b': ['a'],
        }),
      );
    });
  });

  group('GraphStep', () {
    test('valuePathToRoot / fullPathToRoot / toString', () {
      var g = _diamond();
      var steps = <GraphNodeStep<String>>[];

      g.walkOutputsFrom<bool>(['a'], (step) {
        steps.add(step);
        return null;
      });

      var e = steps.firstWhere((s) => s.nodeValue == 'e');
      var root = steps.first;

      expect(root.isRoot, isTrue);
      expect(root.isNotRoot, isFalse);
      expect(root.parentNode, isNull);
      expect(root.parentValue, isNull);
      expect(root.isSideRoot, isFalse);
      expect(root.toString(), equals('GraphStep[0]{ a }'));

      expect(e.isNotRoot, isTrue);
      expect(e.depth, equals(3));
      expect(e.parentValue, equals('d'));
      expect(e.parentNode?.value, equals('d'));
      expect(e.walker, isA<GraphWalker<String>>());
      expect(e.processed.keys.toListOfValues(), contains('e'));

      expect(e.nodePathToRoot.toListOfValues(), equals(['a', 'b', 'd', 'e']));
      expect(e.valuePathToRoot, equals(['a', 'b', 'd', 'e']));
      expect(
        e.valuePathToRootWith(head: ['<'], tail: ['>']),
        equals(['<', 'a', 'b', 'd', 'e', '>']),
      );
      expect(e.fullPathToRoot(), equals('a/b/d/e'));
      expect(
        e.fullPathToRoot(pathDelimiter: '.', head: ['x'], tail: ['y']),
        equals('x.a.b.d.e.y'),
      );
      expect(
        e.fullPathToRoot(headString: ['/root'], tailString: ['end']),
        equals('/root/a/b/d/e/end'),
      );
      expect(e.toString(), equals('GraphStep[3]{ ...d -> e }'));
      expect(steps[1].toString(), equals('GraphStep[1]{ a -> b }'));
    });

    test('valuePathToRoot without cached previous path', () {
      var walker = GraphWalker<String>();
      var root = GraphValueStep.root(walker, 'a');
      var b = GraphValueStep.subNode(root, 'b');
      var c = GraphValueStep.subNode(b, 'c');

      expect(c.depth, equals(2));
      expect(c.parentValue, equals('b'));
      expect(root.parentValue, isNull);
      // No previous path computed yet, forcing the full path resolution:
      expect(c.valuePathToRoot, equals(['a', 'b', 'c']));
      expect(b.valuePathToRoot, equals(['a', 'b']));
    });

    test('nodePathToRoot without cached previous path', () {
      var walker = GraphWalker<String>();
      var root = GraphNodeStep.root(walker, Node('a'));
      var b = GraphNodeStep.subNode(root, Node('b'));
      var c = GraphNodeStep.subNode(b, Node('c'), sideBranch: true);

      expect(c.sideBranch, isTrue);
      expect(c.isSideRoot, isTrue);
      expect(c.valuePathToRoot, equals(['c']));
      expect(c.nodePathToRoot.toListOfValues(), equals(['a', 'b', 'c']));
    });
  });

  group('GraphWalker', () {
    test('toString / maxProcessedExpansion / reset', () {
      var g = _diamond();
      var walker = GraphWalker<String>(maxExpansion: 2);

      walker.walkByNodes<bool>(
        [g.node('a')],
        outputsProvider: (s, n) => n.outputs,
        process: (s) => null,
      );

      expect(walker.maxProcessedExpansion, equals(2));
      expect(walker.processedNodes.length, equals(5));
      expect(
        walker.toString(),
        equals(
          'GraphWalker{bfs: false, maxExpansion: 2, processRoots: true, '
          'sortByInputDependency: false, stopMatcher: NoneNode{}, '
          'processedNodes: 5, maxProcessedExpansion: 2}',
        ),
      );

      walker.reset();
      expect(walker.processedNodes, isEmpty);
    });

    test('initialProcessedNodes', () {
      var g = _diamond();
      var b = g.node('b');

      var walker = GraphWalker<String>(initialProcessedNodes: {b: 1});
      expect(walker.processedNodes, equals({b: 1}));

      var visited = walker
          .walkOrder(
            ['a'],
            nodeProvider: (s, v) => g.getNode(v),
            outputsProvider: (s, n) => n.outputs,
          )
          .toListOfValues();
      expect(visited, equals(['a', 'c', 'd', 'e']));

      walker.reset(rollbackToInitialProcessedNodes: false);
      expect(walker.processedNodes, isEmpty);

      walker.reset();
      expect(walker.processedNodes, equals({b: 1}));
    });

    test('walk instructions (sync)', () {
      var g = _diamond();

      List<String> walk(Object? Function(GraphNodeStep<String> step) process) {
        var visited = <String>[];
        GraphWalker<String>().walk<String>(
          ['a'],
          nodeProvider: (s, v) => g.getNode(v),
          outputsProvider: (s, v) => g.getNode(v)!.outputsValues,
          process: (step) {
            visited.add(step.nodeValue);
            return process(step);
          },
        );
        return visited;
      }

      // `next` skips the outputs of `b`:
      expect(
        walk((s) => s.nodeValue == 'b' ? GraphWalkingInstruction.next() : null),
        equals(['a', 'b', 'c', 'd', 'e']),
      );

      expect(
        walk((s) => s.nodeValue == 'd' ? GraphWalkingInstruction.stop() : null),
        equals(['a', 'b', 'd']),
      );

      // Allow `d` to be expanded again:
      expect(
        walk(
          (s) => s.nodeValue == 'd'
              ? GraphWalkingInstruction.setExpansionCounter(0)
              : null,
        ),
        // `d` is processed again (counter reset), but `e` not (maxExpansion: 1):
        equals(['a', 'b', 'd', 'e', 'c', 'd']),
      );

      expect(
        walk(
          (s) => s.nodeValue == 'a'
              ? GraphWalkingInstruction.setNodesExpansionCounter({
                  g.node('d'): 1,
                  Node<int>(1): 1,
                })
              : null,
        ),
        equals(['a', 'b', 'c']),
      );

      var stopped = GraphWalker<String>(stopMatcher: NodeEquals('d'))
          .walk<Node<String>>(
            ['a'],
            nodeProvider: (s, v) => g.getNode(v),
            outputsProvider: (s, v) => g.getNode(v)!.outputsValues,
            process: (s) => null,
          );
      expect(stopped?.value, equals('d'));

      var custom = GraphWalker<String>().walk<String>(
        ['a'],
        nodeProvider: (s, v) => g.getNode(v),
        outputsProvider: (s, v) => g.getNode(v)!.outputsValues,
        process: (s) => s.nodeValue == 'c' ? 'value:c' : null,
      );
      expect(custom, equals('value:c'));

      expect(
        () => GraphWalker<String>().walk<String>(
          ['z'],
          nodeProvider: (s, v) => g.getNode(v),
          outputsProvider: (s, v) => null,
          process: (s) => null,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('walk with maxDepth', () {
      var g = _diamond();
      var visited = <String>[];

      GraphWalker<String>(bfs: true).walk<bool>(
        ['a'],
        nodeProvider: (s, v) => g.getNode(v),
        outputsProvider: (s, v) => g.getNode(v)!.outputsValues,
        process: (s) {
          visited.add(s.nodeValue);
          return null;
        },
        maxDepth: 1,
      );

      expect(visited, equals(['a', 'b', 'c']));
    });

    test('walkAsync instructions', () async {
      var g = _diamond();

      Future<List<String>> walk(
        FutureOr<Object?> Function(GraphNodeStep<String> step) process, {
        NodeMatcher<String>? stopMatcher,
      }) async {
        var visited = <String>[];
        await GraphWalker<String>(stopMatcher: stopMatcher).walkAsync<String>(
          ['a'],
          // Mix of sync and async node resolution:
          nodeProvider: (s, v) =>
              v == 'c' ? Future.value(g.getNode(v)) : g.getNode(v),
          outputsProvider: (s, v) async => g.getNode(v)!.outputsValues,
          process: (step) async {
            visited.add(step.nodeValue);
            return process(step);
          },
        );
        return visited;
      }

      expect(await walk((s) => null), equals(['a', 'b', 'd', 'e', 'c']));

      expect(
        await walk(
          (s) => s.nodeValue == 'b' ? GraphWalkingInstruction.next() : null,
        ),
        equals(['a', 'b', 'c', 'd', 'e']),
      );

      expect(
        await walk(
          (s) => s.nodeValue == 'd' ? GraphWalkingInstruction.stop() : null,
        ),
        equals(['a', 'b', 'd']),
      );

      expect(
        await walk(
          (s) => s.nodeValue == 'd'
              ? GraphWalkingInstruction.setExpansionCounter(0)
              : null,
        ),
        // `d` is processed again (counter reset), but `e` not (maxExpansion: 1):
        equals(['a', 'b', 'd', 'e', 'c', 'd']),
      );

      expect(
        await walk(
          (s) => s.nodeValue == 'a'
              ? GraphWalkingInstruction.setNodesExpansionCounter({
                  g.node('d'): 1,
                })
              : null,
        ),
        equals(['a', 'b', 'c']),
      );

      expect(
        await walk((s) => null, stopMatcher: NodeEquals('b')),
        equals(['a', 'b']),
      );

      var result = await GraphWalker<String>().walkAsync<String>(
        ['a'],
        nodeProvider: (s, v) async => g.getNode(v),
        outputsProvider: (s, v) async => g.getNode(v)!.outputsValues,
        process: (s) async => s.nodeValue == 'e'
            ? GraphWalkingInstruction.result('e!')
            : (s.nodeValue == 'x' ? 'x' : null),
      );
      expect(result, equals('e!'));

      var custom = await GraphWalker<String>().walkAsync<String>(
        ['a'],
        nodeProvider: (s, v) async => g.getNode(v),
        outputsProvider: (s, v) async => g.getNode(v)!.outputsValues,
        process: (s) async => s.nodeValue == 'd' ? 'value:d' : null,
      );
      expect(custom, equals('value:d'));
    });

    test('walkAsync with null nodes', () async {
      var g = _diamond();

      expect(
        () => GraphWalker<String>().walkAsync<bool>(
          ['z'],
          nodeProvider: (s, v) => g.getNode(v),
          outputsProvider: (s, v) => null,
          process: (s) => null,
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        () => GraphWalker<String>().walkAsync<bool>(
          ['a'],
          nodeProvider: (s, v) => v == 'a' ? g.getNode(v) : null,
          outputsProvider: (s, v) => g.getNode(v)!.outputsValues,
          process: (s) => null,
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        () => GraphWalker<String>().walkAsync<bool>(
          ['a'],
          nodeProvider: (s, v) async => v == 'a' ? g.getNode(v) : null,
          outputsProvider: (s, v) => g.getNode(v)!.outputsValues,
          process: (s) => null,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('walkByNodes instructions', () {
      var g = _diamond();

      List<String> walk(Object? Function(GraphNodeStep<String> step) process) {
        var visited = <String>[];
        GraphWalker<String>().walkByNodes<String>(
          [g.node('a')],
          outputsProvider: (s, n) => n.outputs,
          process: (step) {
            visited.add(step.nodeValue);
            return process(step);
          },
        );
        return visited;
      }

      expect(
        walk((s) => s.nodeValue == 'b' ? GraphWalkingInstruction.next() : null),
        equals(['a', 'b', 'c', 'd', 'e']),
      );
      expect(
        walk(
          (s) => s.nodeValue == 'd'
              ? GraphWalkingInstruction.setExpansionCounter(0)
              : null,
        ),
        // `d` is processed again (counter reset), but `e` not (maxExpansion: 1):
        equals(['a', 'b', 'd', 'e', 'c', 'd']),
      );
      expect(
        walk(
          (s) => s.nodeValue == 'a'
              ? GraphWalkingInstruction.setNodesExpansionCounter({
                  g.node('d'): 1,
                })
              : null,
        ),
        equals(['a', 'b', 'c']),
      );
    });

    test('walkByNodesAsync', () async {
      var g = _diamond();

      Future<List<String>> walk(
        FutureOr<Object?> Function(GraphNodeStep<String> step) process, {
        NodeMatcher<String>? stopMatcher,
        bool sortByInputDependency = false,
        bool expandSideBranches = false,
        int? maxDepth,
      }) async {
        var visited = <String>[];
        await GraphWalker<String>(
          stopMatcher: stopMatcher,
          sortByInputDependency: sortByInputDependency,
        ).walkByNodesAsync<String>(
          [g.node('a')],
          outputsProvider: (s, n) async => n.outputs,
          process: (step) async {
            visited.add(step.nodeValue);
            return process(step);
          },
          expandSideBranches: expandSideBranches,
          maxDepth: maxDepth,
        );
        return visited;
      }

      expect(await walk((s) => null), equals(['a', 'b', 'd', 'e', 'c']));
      expect(
        await walk((s) => null, sortByInputDependency: true),
        unorderedEquals(['a', 'b', 'c', 'd', 'e']),
      );
      // Expanding side branches: `c` (a missing dependency of `d`)
      // is walked before `d`:
      expect(
        await walk((s) => null, expandSideBranches: true),
        equals(['a', 'b', 'c', 'd', 'e']),
      );
      _expectDiamondDependencyOrder(
        await walk(
          (s) => null,
          expandSideBranches: true,
          sortByInputDependency: true,
        ),
      );
      expect(await walk((s) => null, maxDepth: 1), equals(['a', 'b', 'c']));
      expect(
        await walk((s) => null, stopMatcher: NodeEquals('d')),
        equals(['a', 'b', 'd']),
      );
      expect(
        await walk(
          (s) => s.nodeValue == 'b' ? GraphWalkingInstruction.next() : null,
        ),
        equals(['a', 'b', 'c', 'd', 'e']),
      );
      expect(
        await walk(
          (s) => s.nodeValue == 'd' ? GraphWalkingInstruction.stop() : null,
        ),
        equals(['a', 'b', 'd']),
      );
      expect(
        await walk(
          (s) => s.nodeValue == 'd'
              ? GraphWalkingInstruction.setExpansionCounter(0)
              : null,
        ),
        // `d` is processed again (counter reset), but `e` not (maxExpansion: 1):
        equals(['a', 'b', 'd', 'e', 'c', 'd']),
      );
      expect(
        await walk(
          (s) => s.nodeValue == 'a'
              ? GraphWalkingInstruction.setNodesExpansionCounter({
                  g.node('d'): 1,
                })
              : null,
        ),
        equals(['a', 'b', 'c']),
      );

      var result = await GraphWalker<String>().walkByNodesAsync<String>(
        [g.node('a')],
        outputsProvider: (s, n) => n.outputs,
        process: (s) =>
            s.nodeValue == 'e' ? GraphWalkingInstruction.result('e!') : null,
      );
      expect(result, equals('e!'));

      var custom = await GraphWalker<String>().walkByNodesAsync<String>(
        [g.node('a')],
        outputsProvider: (s, n) => n.outputs,
        process: (s) => s.nodeValue == 'c' ? 'value:c' : null,
      );
      expect(custom, equals('value:c'));
    });

    test('walkByNodesAsync (processSideBranches)', () async {
      var g = _diamond();
      var sideBranches = <String, List<String>>{};

      await GraphWalker<String>().walkByNodesAsync<bool>(
        [g.node('a')],
        outputsProvider: (s, n) => n.outputs,
        process: (s) => null,
        processSideBranches: (s, l) async {
          sideBranches[s.nodeValue] = l.toListOfValues();
          return null;
        },
      );

      // In DFS `c` (a dependency of `d`) is still not processed
      // while walking the `b` branch:
      expect(
        sideBranches,
        equals({
          'b': ['c'],
          'd': ['c'],
          'e': ['c'],
        }),
      );

      var sorted = <String, List<String>>{};
      await GraphWalker<String>(sortByInputDependency: true)
          .walkByNodesAsync<bool>(
            [g.node('a')],
            outputsProvider: (s, n) => n.outputs,
            process: (s) => null,
            processSideBranches: (s, l) {
              sorted[s.nodeValue] = l.toListOfValues();
              return s.nodeValue == 'd' ? GraphWalkingInstruction.stop() : null;
            },
          );
      expect(sorted.keys.last, equals('d'));
      expect(sorted.values.every((l) => l.length == 1), isTrue);
    });

    test('walkOrder (expandSideBranches, sortByInputDependency)', () {
      var g = _diamond();

      List<String> walkOrder({
        bool sortByInputDependency = false,
        bool expandSideBranches = false,
        bool bfs = false,
      }) =>
          GraphWalker<String>(
                sortByInputDependency: sortByInputDependency,
                bfs: bfs,
              )
              .walkOrder(
                ['a'],
                nodeProvider: (s, v) => g.getNode(v),
                outputsProvider: (s, n) => n.outputs,
                expandSideBranches: expandSideBranches,
              )
              .toListOfValues();

      expect(walkOrder(), equals(['a', 'b', 'd', 'e', 'c']));
      expect(walkOrder(bfs: true), equals(['a', 'b', 'c', 'd', 'e']));
      expect(
        walkOrder(expandSideBranches: true),
        equals(['a', 'b', 'c', 'd', 'e']),
      );
      _expectDiamondDependencyOrder(
        walkOrder(expandSideBranches: true, sortByInputDependency: true),
      );

      expect(
        () => GraphWalker<String>().walkOrder(
          ['z'],
          nodeProvider: (s, v) => g.getNode(v),
          outputsProvider: (s, n) => n.outputs,
        ),
        throwsArgumentError,
      );
    });

    test('extractAllEntries (bfs, non-String keys)', () {
      var entries = GraphWalker.extractAllEntries<int, dynamic>({
        1: {2: null},
        3: null,
      }, bfs: true);

      expect(entries.map((e) => e.key), equals([1, 3, 2]));
    });
  });
}
