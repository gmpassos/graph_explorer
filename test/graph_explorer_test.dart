import 'package:graph_explorer/graph_explorer.dart';
import 'package:test/test.dart';

// ignore_for_file: unrelated_type_equality_checks

void main() {
  group('Node', () {
    test('basic', () {
      var nodeA = Node('a');
      expect(nodeA == 'a', isTrue);
      expect(nodeA == 'b', isFalse);
      expect(nodeA == Node('a'), isTrue);
      expect(nodeA == Node('b'), isFalse);
      expect(nodeA == NodeEquals('a'), isTrue);
      expect(nodeA == NodeEquals('b'), isFalse);

      var node1 = Node(1);

      expect(node1 == 1, isTrue);
      expect(node1 == 2, isFalse);
      expect(node1 == Node(1), isTrue);
      expect(node1 == Node(2), isFalse);
      expect(node1 == NodeEquals(1), isTrue);
      expect(node1 == NodeEquals(2), isFalse);
      expect(node1 == '1', isTrue);
      expect(node1 == '2', isFalse);
    });
  });

  group('NodeEquals', () {
    test('basic', () {
      var eqA = NodeEquals('a');
      expect(eqA == 'a', isTrue);
      expect(eqA == 'b', isFalse);

      expect(eqA == ['a'], isTrue);
      expect(eqA == ['a', 'a'], isTrue);
      expect(eqA == ['b'], isFalse);

      expect(eqA == NodeEquals('a'), isTrue);
      expect(eqA == NodeEquals('b'), isFalse);

      expect(eqA == MultipleNodesEquals(['a']), isTrue);
      expect(eqA == MultipleNodesEquals(['a', 'a']), isTrue);
      expect(eqA == MultipleNodesEquals(['b']), isFalse);
      expect(eqA == MultipleNodesEquals(['a', 'b']), isFalse);
    });
  });

  group('MultipleNodesEquals', () {
    test('basic', () {
      var eqAB = MultipleNodesEquals(['a', 'b']);
      expect(eqAB == 'a', isTrue);
      expect(eqAB == 'b', isTrue);
      expect(eqAB == 'c', isFalse);

      expect(eqAB == ['a'], isTrue);
      expect(eqAB == ['b'], isTrue);
      expect(eqAB == ['a', 'b'], isTrue);
      expect(eqAB == ['c'], isFalse);
      expect(eqAB == ['a', 'c'], isFalse);

      expect(eqAB == NodeEquals('a'), isTrue);
      expect(eqAB == NodeEquals('b'), isTrue);
      expect(eqAB == NodeEquals('c'), isFalse);

      expect(eqAB == MultipleNodesEquals(['a', 'b']), isTrue);
      expect(eqAB == MultipleNodesEquals(['a']), isTrue);
      expect(eqAB == MultipleNodesEquals(['b']), isTrue);
      expect(eqAB == MultipleNodesEquals(['a', 'c']), isFalse);
    });
  });

  group('Graph', () {
    test('scanPathsFrom 1', () async {
      var graph = Graph<String>();

      expect(graph.allNodes.keys, isEmpty);
      expect(graph.isEmpty, isTrue);
      expect(graph.isNotEmpty, isFalse);
      expect(graph.length, equals(0));

      expect(graph.getNode('a'), isNull);
      expect(graph.getNode('b'), isNull);
      expect(graph.getNode('c'), isNull);
      expect(graph.getNode('x'), isNull);

      expect(graph['a'], isNull);
      expect(graph['b'], isNull);
      expect(graph['x'], isNull);

      expect(graph.roots, isEmpty);

      graph.node('a').getOrAddOutput('b')
        ..addOutput('c')
        ..addOutput('d');

      expect(graph.getNode('a')?.value, equals('a'));
      expect(graph.getNode('b')?.value, equals('b'));
      expect(graph.getNode('c')?.value, equals('c'));
      expect(graph.getNode('x'), isNull);

      expect(graph['a']?.value, equals('a'));
      expect(graph['b']?.value, equals('b'));
      expect(graph['x'], isNull);

      expect(graph.isEmpty, isFalse);
      expect(graph.isNotEmpty, isTrue);
      expect(graph.length, equals(4));
      expect(graph.roots.toListOfString(), equals(['a']));

      expect(
          graph.toTree(),
          allOf(
              isA<Map<String, dynamic>>(),
              equals({
                'a': {
                  'b': {
                    'c': {},
                    'd': {},
                  },
                }
              })));

      expect(
          graph.toTree<Node>(),
          allOf(
              isA<Map<Node, dynamic>>(),
              equals({
                graph.node('a'): {
                  graph.node('b'): {
                    graph.node('c'): {},
                    graph.node('d'): {},
                  },
                }
              })));

      expect(
          graph.toTree<Node<String>>(),
          allOf(
              isA<Map<Node<String>, dynamic>>(),
              equals({
                graph.node('a'): {
                  graph.node('b'): {
                    graph.node('c'): {},
                    graph.node('d'): {},
                  },
                }
              })));

      graph.node('c').addOutput('f');
      graph.node('d').getOrAddOutput('e').addOutput('f');

      expect(graph.allNodes.keys, equals(['a', 'b', 'c', 'd', 'f', 'e']));

      expect(graph.node('a').inputs, equals([]));
      expect(graph.node('a').outputs.toListOfString(), equals(['b']));

      expect(graph.node('b').inputsValues, equals(['a']));
      expect(graph.node('b').outputsValues, equals(['c', 'd']));

      expect(graph.node('b').getOrAddInput('a').value, equals('a'));
      expect(graph.node('b').getOrAddOutput('c').value, equals('c'));

      expect(graph.node('b').inputsValues, equals(['a']));
      expect(graph.node('b').outputsValues, equals(['c', 'd']));

      expect(graph.node('b').getInput('a')?.value, equals('a'));
      expect(graph.node('b').getInput('x'), isNull);

      expect(graph.node('b').getOutput('c')?.value, equals('c'));
      expect(graph.node('b').getOutput('y'), isNull);

      expect(graph.isEmpty, isFalse);
      expect(graph.isNotEmpty, isTrue);
      expect(graph.length, equals(6));
      expect(graph.roots.toListOfString(), equals(['a']));

      expect(
          graph.toTree(),
          equals({
            'a': {
              'b': {
                'c': {'f': {}},
                'd': {
                  'e': {'f': 'f'},
                },
              },
            }
          }));

      expect(
          graph.toTreeFrom(['b']),
          equals({
            'b': {
              'c': {'f': {}},
              'd': {
                'e': {'f': 'f'},
              },
            }
          }));

      expect(() => graph.toTreeFrom(['x']), throwsArgumentError);

      {
        var result = await graph.scanPathsFrom('a', 'd');
        var pathsStr = result.paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['a', 'b', 'd']
            ]));
      }

      {
        var result = await graph.scanPathsFrom('a', 'c');
        var pathsStr = result.paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['a', 'b', 'c']
            ]));
      }

      {
        var result = await graph.scanPathsFromMany(['a'], ['c', 'd']);
        var pathsStr = result.paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['a', 'b', 'c'],
              ['a', 'b', 'd']
            ]));
      }

      {
        var paths =
            await graph.shortestPathsFromMany(['a'], ['c', 'd'], findAll: true);

        expect(
            paths.toListOfStringPaths(),
            equals([
              ['a', 'b', 'c'],
              ['a', 'b', 'd']
            ]));

        expect(
            paths.toListOfValuePaths(),
            equals([
              ['a', 'b', 'c'],
              ['a', 'b', 'd']
            ]));

        expect(paths.firstShortestPath().toListOfString(),
            equals(['a', 'b', 'c']));

        expect(paths.firstShortestPath().toListOfValues(),
            equals(['a', 'b', 'c']));

        expect(
            paths.longestPaths().toListOfStringPaths(),
            equals([
              ['a', 'b', 'c'],
              ['a', 'b', 'd']
            ]));

        expect(
            paths.firstLongestPath().toListOfString(), equals(['a', 'b', 'c']));

        expect(
            paths.firstLongestPath().toListOfValues(), equals(['a', 'b', 'c']));
      }

      {
        var result = await graph.scanPathsFromMany(['a'], ['b', 'd']);
        var pathsStr = result.paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['a', 'b'],
              ['a', 'b', 'd']
            ]));

        expect(
            result.paths.shortestPaths().toListOfValuePaths(),
            equals([
              ['a', 'b']
            ]));

        expect(result.paths.firstShortestPath().toListOfString(),
            equals(['a', 'b']));

        expect(
            result.paths.longestPaths().toListOfStringPaths(),
            equals([
              ['a', 'b', 'd']
            ]));

        expect(result.paths.firstLongestPath().toListOfString(),
            equals(['a', 'b', 'd']));
      }

      {
        var result = await graph.scanPathsFrom('a', 'f');
        var pathsStr = result.paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['a', 'b', 'c', 'f']
            ]));
      }

      {
        var result = await graph.scanPathsFrom('a', 'f', findAll: true);
        var pathsStr = result.paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['a', 'b', 'c', 'f'],
              ['a', 'b', 'd', 'e', 'f']
            ]));
      }

      {
        var paths = await graph.shortestPathsFrom('a', 'f');
        var pathsStr = paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['a', 'b', 'c', 'f']
            ]));
      }

      {
        var paths = await graph.shortestPathsFromMany(['a'], ['b', 'd']);
        var pathsStr = paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['a', 'b'],
            ]));
      }

      {
        var paths = await graph.shortestPathsFromMany(['a', 'c'], ['b', 'd']);
        var pathsStr = paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['a', 'b'],
            ]));
      }

      {
        var result = await graph.scanPathsFrom('a', 'b');
        var pathsStr = result.paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['a', 'b']
            ]));
      }

      {
        graph.dispose();

        var result = await graph.scanPathsFrom('a', 'b');
        expect(result.paths, isEmpty);
      }
    });

    test('scanPathsFrom 2', () async {
      var graph = Graph<String>();

      graph.node('a').addOutput('b')!
        ..addOutput('c')
        ..addOutput('d');

      graph.node('c').addOutput('f');
      graph.node('d').addOutput('e')!.addOutput('f');

      graph.node('x').addOutput('y')!.addOutput('z');

      {
        var result = await graph.scanPathsFrom('a', 'd');
        var pathsStr = result.paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['a', 'b', 'd']
            ]));
      }

      {
        var result = await graph.scanPathsFrom('x', 'z');
        var pathsStr = result.paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['x', 'y', 'z']
            ]));
      }

      {
        var result = await graph.scanPathsFromMany(['a', 'x'], ['f', 'z']);
        var pathsStr = result.paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['a', 'b', 'c', 'f'],
              ['a', 'b', 'd', 'e', 'f'],
              ['x', 'y', 'z']
            ]));
      }

      {
        var result = await graph
            .scanPathsFromMany(['a', 'x'], ['f', 'z'], findAll: true);
        var pathsStr = result.paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['a', 'b', 'c', 'f'],
              ['a', 'b', 'd', 'e', 'f'],
              ['x', 'y', 'z']
            ]));
      }

      {
        var result = await graph
            .scanPathsFromMany(['a', 'x'], ['f', 'z'], findAll: false);
        var pathsStr = result.paths.toListOfStringPaths();
        expect(
            pathsStr,
            equals([
              ['x', 'y', 'z']
            ]));
      }
    });
  });

  group('GraphScanner', () {
    test(
        'a -> f (1)',
        () => doGraphScannerTest(
            roots: ['a'],
            target: NodeEquals('f'),
            findAll: false,
            graph: {
              ''
                  'a': ['x', 'b', 'c'],
              'b': ['d'],
              'c': ['d'],
              'd': ['f'],
              'f': [],
              'x': ['y'],
              'y': ['z'],
              'z': [],
            },
            expectedPaths: [
              ['a', 'b', 'd', 'f']
            ]));

    test(
        'a -> f (2)',
        () => doGraphScannerTest(
            roots: ['a'],
            target: NodeEquals('f'),
            findAll: true,
            graph: {
              'a': ['x', 'b', 'c'],
              'b': ['d'],
              'c': ['d'],
              'd': ['f'],
              'f': [],
              'x': ['y'],
              'y': ['z'],
              'z': [],
            },
            expectedPaths: [
              ['a', 'b', 'd', 'f'],
              ['a', 'c', 'd', 'f']
            ]));

    test(
        'a -> b -> d -> f (with loop x->y->z->x)',
        () => doGraphScannerTest(
            roots: ['a'],
            target: NodeEquals('f'),
            findAll: false,
            graph: {
              'a': ['x', 'b', 'c'],
              'b': ['d'],
              'c': ['d'],
              'd': ['f'],
              'f': [],
              'x': ['y'],
              'y': ['z'],
              'z': ['x'],
            },
            expectedPaths: [
              ['a', 'b', 'd', 'f']
            ]));

    test(
        'a -> c -> d -> f (with loop x->y->z->x)',
        () => doGraphScannerTest(
            roots: ['a'],
            target: NodeEquals('f'),
            findAll: false,
            graph: {
              'a': ['x', 'c', 'b'],
              'b': ['d'],
              'c': ['d'],
              'd': ['f'],
              'f': [],
              'x': ['y'],
              'y': ['z'],
              'z': ['x'],
            },
            expectedPaths: [
              ['a', 'c', 'd', 'f']
            ]));

    test(
        'a -> x -> y -> z -> f (1)',
        () => doGraphScannerTest(
            roots: ['a'],
            target: NodeEquals('f'),
            findAll: false,
            graph: {
              'a': ['b', 'c', 'x'],
              'b': ['d'],
              'c': ['d'],
              'd': [],
              'f': [],
              'x': ['y'],
              'y': ['z'],
              'z': ['f'],
            },
            expectedPaths: [
              ['a', 'x', 'y', 'z', 'f']
            ]));

    test(
        'a -> x -> y -> z -> f (with loop x->y->z->x)',
        () => doGraphScannerTest(
            roots: ['a'],
            target: NodeEquals('f'),
            findAll: false,
            graph: {
              'a': ['b', 'c', 'x'],
              'b': ['d'],
              'c': ['d'],
              'd': [],
              'f': [],
              'x': ['y'],
              'y': ['z'],
              'z': ['x', 'f'],
            },
            expectedPaths: [
              ['a', 'x', 'y', 'z', 'f']
            ]));
  });
}

Future<void> doGraphScannerTest({
  required List<String> roots,
  required NodeMatcher<String> target,
  required Map<String, List<String>> graph,
  required List<List<String>> expectedPaths,
  required bool findAll,
}) async {
  var graphScanner = GraphScanner<String>(findAll: findAll);

  var result = await graphScanner.scanPathsFromMany(
    roots,
    target,
    outputsProvider: (g, n) {
      var children = graph[n.value];
      if (children == null) {
        throw ArgumentError("Can't find the children of node: ${n.value}");
      }
      return children.map((e) => g.node(e)).toList();
    },
  );

  var paths = result.paths;

  expect(paths, isNotEmpty);

  var pathsStr = paths.toListOfStringPaths();

  expect(pathsStr, equals(expectedPaths));

  expect(result.roots, equals(roots));
  expect(result.targetMatcher, equals(target));

  expect(paths.every((path) => roots.contains(path.first.value)), isTrue);
  expect(paths.every((path) => target.matchesNode(path.last)), isTrue);
}
