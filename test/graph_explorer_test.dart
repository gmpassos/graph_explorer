import 'package:graph_explorer/graph_explorer.dart';
import 'package:test/test.dart';
import 'dart:convert' as dart_convert;
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

      expect(eqA == Node('a'), isTrue);
      expect(eqA == Node('c'), isFalse);

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

      expect(eqAB == Node('a'), isTrue);
      expect(eqAB == Node('c'), isFalse);

      expect(eqAB == [Node('a'), Node('b')], isTrue);
      expect(eqAB == [Node('x'), Node('y')], isFalse);

      expect(eqAB == NodeEquals('a'), isTrue);
      expect(eqAB == NodeEquals('b'), isTrue);
      expect(eqAB == NodeEquals('c'), isFalse);

      expect(eqAB == MultipleNodesEquals(['a', 'b']), isTrue);
      expect(eqAB == MultipleNodesEquals(['a']), isTrue);
      expect(eqAB == MultipleNodesEquals(['b']), isTrue);
      expect(eqAB == MultipleNodesEquals(['a', 'c']), isFalse);
    });
  });

  group('AnyNode', () {
    test('basic', () {
      var any = AnyNode();
      expect(any == 'a', isTrue);
      expect(any == 'b', isTrue);

      expect(any == ['a'], isTrue);
      expect(any == ['a', 'b'], isTrue);

      expect(any == Node('c'), isTrue);
      expect(any == [Node('x'), Node('y')], isTrue);

      expect(any == NodeEquals('a'), isTrue);
      expect(any == NodeEquals('b'), isTrue);

      expect(any == MultipleNodesEquals(['a']), isTrue);
      expect(any == MultipleNodesEquals(['a', 'a']), isTrue);
      expect(any == MultipleNodesEquals(['b']), isTrue);
      expect(any == MultipleNodesEquals(['a', 'b']), isTrue);

      expect(any.matchesValue('c'), isTrue);
      expect(any.matchesNode(Node('x')), isTrue);
    });
  });

  group('NoneNode', () {
    test('basic', () {
      var none = NoneNode();
      expect(none == 'a', isFalse);
      expect(none == 'b', isFalse);

      expect(none == ['a'], isFalse);
      expect(none == ['a', 'b'], isFalse);

      expect(none == Node('c'), isFalse);
      expect(none == [Node('x'), Node('y')], isFalse);

      expect(none == NodeEquals('a'), isFalse);
      expect(none == NodeEquals('b'), isFalse);

      expect(none == MultipleNodesEquals(['a']), isFalse);
      expect(none == MultipleNodesEquals(['a', 'a']), isFalse);
      expect(none == MultipleNodesEquals(['b']), isFalse);
      expect(none == MultipleNodesEquals(['a', 'b']), isFalse);

      expect(none.matchesValue('c'), isFalse);
      expect(none.matchesNode(Node('x')), isFalse);
    });
  });

  group('Graph', () {
    test('basic', () async {
      var graph = Graph<String>();

      expect(graph.allNodes, isEmpty);
      expect(graph.allNodesValues, isEmpty);
      expect(graph.inputs, isEmpty);
      expect(graph.outputs, isEmpty);

      expect(graph.containsInput('a'), isFalse);
      expect(graph.containsInput('b'), isFalse);

      expect(graph.containsOutput('a'), isFalse);
      expect(graph.containsOutput('b'), isFalse);

      expect(graph.addInput('a'), equals(Node('a')));
      expect(graph.addInput('a'), isNull);

      expect(graph.containsInput('a'), isTrue);
      expect(graph.containsInput('b'), isFalse);

      expect(graph.containsOutput('a'), isTrue);
      expect(graph.containsOutput('b'), isFalse);

      expect(graph.allNodesValues, equals(['a']));
      expect(graph.inputs, equals([Node('a')]));
      expect(graph.outputs, equals([Node('a')]));

      expect(graph.addOutput('b'), equals(Node('b')));

      expect(graph.containsInput('a'), isTrue);
      expect(graph.containsInput('b'), isTrue);

      expect(graph.containsOutput('a'), isTrue);
      expect(graph.containsOutput('b'), isTrue);

      expect(graph.allNodesValues, equals(['a', 'b']));
      expect(graph.inputs, equals([Node('a'), Node('b')]));
      expect(graph.outputs, equals([Node('a'), Node('b')]));
    });

    test('toJson/fromJson', () async {
      var graph = Graph<String>();

      graph.node('a').getOrAddOutput('b')
        ..addOutput('c')
        ..addOutput('d');

      graph.node('c').addOutput('f');
      graph.node('d').getOrAddOutput('e').addOutput('f');

      expect(graph.roots.toListOfString(), equals(['a']));
      expect(graph.allNodes.toListOfString(),
          equals(['a', 'b', 'c', 'd', 'f', 'e']));
      expect(graph.allLeaves.toListOfString(), equals(['f']));

      var json = graph.toJson();

      expect(
          json,
          equals({
            'a': {
              'b': {
                'c': {'f': null},
                'd': {
                  'e': {'f': 'f'}
                }
              }
            }
          }));

      var graph2 = Graph.fromJson(json);

      expect(graph2.roots.toListOfString(), equals(['a']));
      expect(graph2.allNodes.toListOfString(),
          unorderedEquals(['a', 'b', 'c', 'd', 'f', 'e']));

      expect(graph2.toJson(), equals(json));
    });

    test('explore 1', () async {
      var graph = Graph<String>();

      graph.node('a').getOrAddOutput('b')
        ..addOutput('c')
        ..addOutput('d');

      graph.node('c').addOutput('f');
      graph.node('d').getOrAddOutput('e').addOutput('f');

      expect(graph.roots.toListOfString(), equals(['a']));
      expect(graph.allNodes.toListOfString(),
          equals(['a', 'b', 'c', 'd', 'f', 'e']));
      expect(graph.allLeaves.toListOfString(), equals(['f']));

      expect(graph.getNode('b')?.isInput('a'), isTrue);
      expect(graph.getNode('b')?.isInput('0'), isFalse);
      expect(graph.getNode('b')?.isInput('b'), isFalse);

      expect(graph.getNode('b')?.isOutput('c'), isTrue);
      expect(graph.getNode('b')?.isOutput('d'), isTrue);
      expect(graph.getNode('b')?.isOutput('x'), isFalse);
      expect(graph.getNode('b')?.isOutput('b'), isFalse);

      expect(graph.getNode('b')?.outputsInDepth().toListOfString(),
          equals(['c', 'f', 'd', 'e']));

      expect(graph.getNode('b')?.outputsInDepth(bfs: true).toListOfString(),
          equals(['c', 'd', 'f', 'e']));

      expect(
          graph.getNode('c')?.outputsInDepth().toListOfString(), equals(['f']));

      expect(graph.getNode('d')?.outputsInDepth().toListOfString(),
          equals(['e', 'f']));

      expect(
          graph.getNode('b')?.inputsInDepth().toListOfString(), equals(['a']));

      expect(graph.getNode('c')?.inputsInDepth().toListOfString(),
          equals(['b', 'a']));

      expect(graph.getNode('d')?.inputsInDepth().toListOfString(),
          equals(['b', 'a']));

      expect(graph.getNode('f')?.inputsInDepth().toListOfString(),
          equals(['c', 'b', 'a', 'e', 'd']));

      expect(graph.getNode('f')?.inputsInDepth(bfs: true).toListOfString(),
          equals(['c', 'e', 'b', 'd', 'a']));

      expect(
          graph
              .getNode('c')
              ?.outputsInDepthIntersection(graph.getNode('d'))
              .toListOfString(),
          equals(['f']));

      expect(
          graph
              .getNode('c')
              ?.inputsInDepthIntersection(graph.getNode('d'))
              .toListOfString(),
          equals(['b', 'a']));

      {
        var walk = <String>[];

        graph.walkOutputsFrom(['a'], (step) => walk.add(step.nodeValue));

        expect(walk, equals(['a', 'b', 'c', 'f', 'd', 'e']));
      }

      {
        var walk = <String>[];

        graph.walkOutputsFrom(['a'], (step) => walk.add(step.nodeValue),
            bfs: true);

        expect(walk, equals(['a', 'b', 'c', 'd', 'f', 'e']));
      }

      {
        var walk = <String>[];

        graph.walkOutputsFrom(['a'], (step) => walk.add(step.nodeValue),
            stopMatcher: NodeEquals('d'));

        expect(walk, equals(['a', 'b', 'c', 'f', 'd']));
      }

      {
        var walk = <String>[];

        graph.walkOutputsFrom(['a'], (step) => walk.add(step.nodeValue),
            stopMatcher: NodeEquals('d'), bfs: true);

        expect(walk, equals(['a', 'b', 'c', 'd']));
      }

      {
        var walk = <String>[];

        graph.walkOutputsFrom(['a'], (step) => walk.add(step.nodeValue),
            stopMatcher: NodeEquals('d'), processRoots: false);

        expect(walk, equals(['b', 'c', 'f', 'd']));
      }

      {
        var walk = <String>[];

        graph.walkOutputsFrom(['a'], (step) => walk.add(step.nodeValue),
            stopMatcher: NodeEquals('d'), processRoots: false, bfs: true);

        expect(walk, equals(['b', 'c', 'd']));
      }

      {
        var walk = <String>[];

        graph.walkInputsFrom(['f'], (step) => walk.add(step.nodeValue));

        expect(walk, equals(['f', 'c', 'b', 'a', 'e', 'd']));
      }

      {
        var walk = <String>[];

        graph.walkInputsFrom(['f'], (step) => walk.add(step.nodeValue),
            bfs: true);

        expect(walk, equals(['f', 'c', 'e', 'b', 'd', 'a']));
      }

      {
        var walk = <String>[];

        graph.walkInputsFrom(['f'], (step) => walk.add(step.nodeValue),
            stopMatcher: NodeEquals('b'));

        expect(walk, equals(['f', 'c', 'b']));
      }

      {
        var walk = <String>[];

        graph.walkInputsFrom(['f'], (step) => walk.add(step.nodeValue),
            stopMatcher: NodeEquals('b'), bfs: true);

        expect(walk, equals(['f', 'c', 'e', 'b']));
      }

      {
        var walk = <String>[];

        graph.walkInputsFrom(['f'], (step) => walk.add(step.nodeValue),
            stopMatcher: NodeEquals('b'), processRoots: false);

        expect(walk, equals(['c', 'b']));
      }

      {
        var walk = <String>[];

        graph.walkInputsFrom(['f'], (step) => walk.add(step.nodeValue),
            stopMatcher: NodeEquals('b'), processRoots: false, bfs: true);

        expect(walk, equals(['c', 'e', 'b']));
      }

      {
        expect(graph.getNode('c')?.inputsValues, equals(['b']));
        expect(graph.getNode('c')?.outputsValues, equals(['f']));

        expect(graph.getNode('b')?.outputsInDepth(maxDepth: 1).toListOfValues(),
            equals(['c', 'd']));
        expect(graph.getNode('c')?.outputsInDepth(maxDepth: 1).toListOfValues(),
            equals(['f']));

        expect(graph.getNode('b')?.outputsInDepth().toListOfValues(),
            equals(['c', 'f', 'd', 'e']));
        expect(graph.getNode('b')?.outputsInDepth(bfs: true).toListOfValues(),
            equals(['c', 'd', 'f', 'e']));
        expect(graph.getNode('c')?.outputsInDepth().toListOfValues(),
            equals(['f']));

        expect(graph.getNode('c')?.inputsInDepth(maxDepth: 1).toListOfValues(),
            equals(['b']));

        expect(graph.getNode('c')?.inputsInDepth().toListOfValues(),
            equals(['b', 'a']));

        expect(graph.getNode('f')?.shortestPathToRoot.toListOfValues(),
            equals(['a', 'b', 'c', 'f']));

        expect(
            graph
                .getNode('f')
                ?.isInputInShortestPathToRoot(graph.getNode('c')!),
            isTrue);

        expect(
            graph
                .getNode('f')
                ?.isInputInShortestPathToRoot(graph.getNode('d')!),
            isFalse);

        expect(graph.getNode('a')?.depth, equals(1));
        expect(graph.getNode('b')?.depth, equals(2));
        expect(graph.getNode('c')?.depth, equals(3));
        expect(graph.getNode('d')?.depth, equals(3));
        expect(graph.getNode('e')?.depth, equals(4));
        expect(graph.getNode('f')?.depth, equals(4));

        expect(graph.getNode('c')?.missingDependencies([]).toListOfValues(),
            equals(['b', 'a', 'e', 'd']));

        expect(
            graph
                .getNode('c')
                ?.missingDependencies(graph.getNodes(['b']).toList())
                .toListOfValues(),
            equals(['a', 'e', 'd']));

        expect(
            graph
                .getNode('c')
                ?.missingDependencies(graph
                    .getNodes(['b'])
                    .inputsInDepth()
                    .values
                    .expand((l) => l)
                    .toSet())
                .toListOfValues(),
            equals(['b', 'e', 'd']));

        expect(
            graph
                .getNode('c')
                ?.missingDependencies(graph
                    .getNodes(['b'])
                    .inputsInDepth()
                    .values
                    .expand((l) => l)
                    .toSet()
                  ..add(graph.node('b')))
                .toListOfValues(),
            equals(['e', 'd']));

        expect(
            graph.getNodes(['b', 'c']).outputsInDepth().toMapOfValues(),
            equals({
              'b': ['c', 'f', 'd', 'e'],
              'c': ['f']
            }));

        expect(
            graph
                .getNodes(['b', 'c'])
                .outputsInDepth(maxDepth: 1)
                .toMapOfValues(),
            equals({
              'b': ['c', 'd'],
              'c': ['f']
            }));

        expect(
            graph.getNodes(['b', 'c']).inputsInDepth().toMapOfValues(),
            equals({
              'b': ['a'],
              'c': ['b', 'a']
            }));

        expect(
            graph.getNodes(['c', 'd']).inputsInDepth().toMapOfValues(),
            equals({
              'c': ['b', 'a'],
              'd': ['b', 'a']
            }));

        expect(
            graph
                .getNodes(['c', 'd'])
                .inputsInDepth(maxDepth: 1)
                .toMapOfValues(),
            equals({
              'c': ['b'],
              'd': ['b']
            }));

        expect(
            graph.getNodes(['e', 'f']).inputsInDepth().toMapOfValues(),
            equals({
              'e': ['d', 'b', 'a'],
              'f': ['c', 'b', 'a', 'e', 'd']
            }));

        expect(
            graph
                .getNode('b')!
                .outputsInDepth(maxDepth: 1)
                .merge(graph.getNode('c')!.outputsInDepth(maxDepth: 1))
                .toListOfValues(),
            equals(['c', 'd', 'f']));

        expect(
            graph
                .getNode('b')!
                .outputsInDepth()
                .merge(graph.getNode('c')!.outputsInDepth())
                .toListOfValues(),
            equals(['c', 'f', 'd', 'e']));

        {
          var outputsInDepth = graph.getNode('b')!.outputsInDepth();
          expect(outputsInDepth.merge(outputsInDepth).toListOfValues(),
              equals(['c', 'f', 'd', 'e']));
        }

        {
          var outputsInDepth = graph.getNode('b')!.outputsInDepth();
          expect(outputsInDepth.merge([]).toListOfValues(),
              equals(['c', 'f', 'd', 'e']));
        }

        {
          var outputsInDepth = graph.getNode('b')!.outputsInDepth();
          expect(<Node<String>>[].merge(outputsInDepth).toListOfValues(),
              equals(['c', 'f', 'd', 'e']));
        }

        {
          expect(<Node<String>>[].merge([]).toListOfValues(), equals([]));
        }

        expect(
            graph
                .getNode('b')!
                .outputsInDepth()
                .intersection(graph.getNode('c')!.outputsInDepth(maxDepth: 1))
                .toListOfValues(),
            equals(['f']));

        expect(
            graph
                .getNode('b')!
                .outputsInDepth(maxDepth: 1)
                .intersection(graph.getNode('c')!.outputsInDepth(maxDepth: 1))
                .toListOfValues(),
            equals([]));

        {
          var outputsInDepth = graph.getNode('b')!.outputsInDepth();
          expect(outputsInDepth.intersection(outputsInDepth).toListOfValues(),
              equals(['c', 'f', 'd', 'e']));
        }

        {
          var outputsInDepth = graph.getNode('b')!.outputsInDepth();
          expect(outputsInDepth.intersection([]).toListOfValues(), equals([]));
        }

        {
          var outputsInDepth = graph.getNode('b')!.outputsInDepth();
          expect(<Node<String>>[].intersection(outputsInDepth).toListOfValues(),
              equals([]));
        }

        expect(
            graph
                .getNode('b')!
                .outputsInDepth(maxDepth: 1)
                .complement(graph.getNode('c')!.outputsInDepth(maxDepth: 1))
                .toListOfValues(),
            equals(['c', 'd', 'f']));

        expect(
            graph
                .getNode('b')!
                .outputsInDepth()
                .complement(graph.getNode('c')!.outputsInDepth())
                .toListOfValues(),
            equals(['c', 'd', 'e']));

        {
          var outputsInDepth = graph.getNode('b')!.outputsInDepth();
          expect(outputsInDepth.complement(outputsInDepth).toListOfValues(),
              equals([]));
        }

        {
          var outputsInDepth = graph.getNode('b')!.outputsInDepth();
          expect(outputsInDepth.complement([]).toListOfValues(),
              equals(['c', 'f', 'd', 'e']));
        }

        {
          var outputsInDepth = graph.getNode('b')!.outputsInDepth();
          expect(<Node<String>>[].complement(outputsInDepth).toListOfValues(),
              equals(['c', 'f', 'd', 'e']));
        }

        expect(
            graph
                .getNodes(['c', 'd'])
                .outputsInDepthIntersection()
                .toListOfValues(),
            equals(['f']));

        expect(
            graph
                .getNodes(['e', 'c'])
                .outputsInDepthIntersection()
                .toListOfValues(),
            equals(['f']));

        expect(
            graph
                .getNodes(['c', 'd'])
                .inputsInDepthIntersection()
                .toListOfValues(),
            equals(['b', 'a']));

        expect(graph.getNodes(['e', 'c']).sortedByInputDepth().toListOfValues(),
            equals(['c', 'e']));

        expect(graph.getNodes(['e', 'd']).sortedByInputDepth().toListOfValues(),
            equals(['d', 'e']));

        expect(
            graph.getNodes(['d', 'c']).sortedByOutputsDepth().toListOfValues(),
            equals(['c', 'd']));

        expect(
            graph.getNodes(['e', 'f']).sortedByOutputsDepth().toListOfValues(),
            equals(['f', 'e']));
      }
    });

    test('explore 2', () async {
      var graph = Graph<String>();

      graph.node('a').getOrAddOutput('b')
        ..addOutput('c')
        ..getOrAddOutput('d').getOrAddOutput('h').addOutput('i');

      graph.node('c').addOutput('f')!.addOutput('x');
      graph.node('c').addOutput('g');

      graph.node('d').getOrAddOutput('e').addOutput('f');

      graph.node('m').getOrAddOutput('n').getOrAddOutput('c');

      expect(
          graph.toJson(),
          equals({
            'a': {
              'b': {
                'c': {
                  'f': {'x': null},
                  'g': null
                },
                'd': {
                  'e': {'f': 'f'},
                  'h': {'i': null}
                }
              }
            },
            'm': {
              'n': {'c': 'c'}
            }
          }));

      expect(graph.getNode('i')!.sideRoots().toListOfValues(), equals([]));

      expect(graph.getNode('h')!.sideRoots().toListOfValues(), equals([]));

      expect(graph.getNode('x')!.sideRoots().toListOfValues(), equals([]));

      expect(graph.getNode('c')!.sideRoots().toListOfValues(), equals([]));

      expect(graph.getNode('d')!.sideRoots().toListOfValues(), equals(['m']));

      expect(graph.getNode('b')!.sideRoots().toListOfValues(), equals(['m']));

      expect(graph.getNode('d')!.sideRoots().toListOfValues(), equals(['m']));

      expect(graph.getNode('a')!.sideRoots().toListOfValues(), equals(['m']));

      expect(graph.getNode('m')!.sideRoots().toListOfValues(), equals(['a']));

      expect(graph.getNode('n')!.sideRoots().toListOfValues(), equals(['a']));

      expect(
          graph
              .getNodes(['d', 'c'])
              .sortedByOutputDependency()
              .toListOfValues(),
          equals(['c', 'd']));

      expect(
          graph
              .getNodes(['m', 'a'])
              .sortedByOutputDependency()
              .toListOfValues(),
          equals(['a', 'm']));
    });
    test('allPath', () async {
      var graph = Graph<String>();

      graph.node('a').getOrAddOutput('b')
        ..addOutput('c')
        ..addOutput('d');

      graph.node('c').addOutput('f');
      graph.node('d').getOrAddOutput('e').addOutput('f');

      expect(graph.roots.toListOfString(), equals(['a']));
      expect(graph.allNodes.toListOfString(),
          equals(['a', 'b', 'c', 'd', 'f', 'e']));
      expect(graph.allLeaves.toListOfString(), equals(['f']));

      var paths = await graph.allPaths;
      expect(
          paths.toListOfStringPaths(),
          equals([
            ['a', 'b', 'c', 'f'],
            ['a', 'b', 'd', 'e', 'f']
          ]));

      var shortestPaths = await graph.shortestPaths;
      expect(
          shortestPaths.toListOfStringPaths(),
          equals([
            ['a', 'b', 'c', 'f']
          ]));
    });

    test('scanPathsFrom 1', () async {
      var graph = Graph<String>();

      expect(graph.allNodes, isEmpty);
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
                    'c': null,
                    'd': null,
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
                    graph.node('c'): null,
                    graph.node('d'): null,
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
                    graph.node('c'): null,
                    graph.node('d'): null,
                  },
                }
              })));

      graph.node('c').addOutput('f');
      graph.node('d').getOrAddOutput('e').addOutput('f');

      expect(graph.allNodes.toListOfString(),
          equals(['a', 'b', 'c', 'd', 'f', 'e']));

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
                'c': {'f': null},
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
              'c': {'f': null},
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

    test('walkOutputsOrderFrom 1', () async {
      var graph = Graph<String>();

      graph.node('a').addOutput('b')!
        ..addOutput('c')
        ..addOutput('d');

      graph.node('c').addOutput('f');
      graph.node('d').addOutput('e')!.addOutput('f');

      graph.node('x').addOutput('y')!.addOutput('z');

      expect(graph.walkOutputsOrderFrom(['b']).toListOfValues(),
          equals(['b', 'c', 'f', 'd', 'e']));

      expect(graph.walkOutputsOrderFrom(['b'], bfs: true).toListOfValues(),
          equals(['b', 'c', 'd', 'f', 'e']));

      expect(graph.walkOutputsOrderFrom(['c']).toListOfValues(),
          equals(['c', 'f']));

      expect(
          graph.walkOutputsOrderFrom(['c'],
              processRoots: false).toListOfValues(),
          equals(['f']));

      expect(graph.walkInputsOrderFrom(['c']).toListOfValues(),
          equals(['c', 'b', 'a']));

      expect(
          graph
              .walkInputsOrderFrom(['c'], processRoots: false).toListOfValues(),
          equals(['b', 'a']));

      expect(graph.walkInputsOrderFrom(['f']).toListOfValues(),
          equals(['f', 'c', 'b', 'a', 'e', 'd']));

      expect(graph.walkInputsOrderFrom(['f'], bfs: true).toListOfValues(),
          equals(['f', 'c', 'e', 'b', 'd', 'a']));
    });
  });

  group('GraphScanner', () {
    test('walk/walkByNodes', () async {
      await doWalkerTest(
        (step, walk) => walk.add(step.nodeValue),
        isFalse,
        ['a', 'b', 'c', 'f', 'x', 'd', 'e', 'h', 'g'],
        ['a', 'b', 'c', 'f', 'x', 'd', 'e', 'h', 'g'],
      );

      await doWalkerTest(
        (step, walk) => walk.add(step.nodeValue),
        isFalse,
        ['a', 'b', 'c', 'd', 'f', 'e', 'g', 'x', 'h'],
        ['a', 'b', 'c', 'd', 'f', 'e', 'g', 'x', 'h'],
        bfs: true,
      );

      await doWalkerTest(
        (step, walk) {
          walk.add(step.nodeValue);
          if (step.nodeValue == 'x') {
            return 'found';
          }
          return null;
        },
        equals('found'),
        ['a', 'b', 'c', 'f', 'x'],
        ['a', 'b', 'c', 'f', 'x', 'd', 'e', 'h', 'g'],
      );

      await doWalkerTest(
        (step, walk) {
          walk.add(step.nodeValue);
          if (step.nodeValue == 'x') {
            return step.node;
          }
          return null;
        },
        equals(Node('x')),
        ['a', 'b', 'c', 'f', 'x'],
        ['a', 'b', 'c', 'f', 'x', 'd', 'e', 'h', 'g'],
      );

      await doWalkerTest<String>(
        (step, walk) => walk.add(step.nodeValue),
        isNull,
        ['a', 'b', 'c', 'f', 'x', 'd', 'e', 'f', 'x', 'h', 'g'],
        ['a', 'b', 'c', 'f', 'x', 'd', 'e', 'h', 'g'],
        maxExpansion: 3,
      );

      await doWalkerTest<String>(
        (step, walk) {
          walk.add(step.nodeValue);
          if (step.nodeValue == 'f') {
            return GraphWalkingInstruction.result('f');
          }
          return null;
        },
        equals(Node('f')),
        ['a', 'b', 'c', 'f'],
        ['a', 'b', 'c', 'f', 'x', 'd', 'e', 'h', 'g'],
        maxExpansion: 3,
      );

      await doWalkerTest<String>(
        (step, walk) {
          walk.add(step.nodeValue);
          if (step.nodeValue == 'f') {
            return GraphWalkingInstruction.setExpansionCounter(10);
          }
          return null;
        },
        isNull,
        ['a', 'b', 'c', 'f', 'x', 'd', 'e', 'h', 'g'],
        ['a', 'b', 'c', 'f', 'x', 'd', 'e', 'h', 'g'],
        maxExpansion: 3,
      );

      await doWalkerTest<String>(
        (step, walk) {
          walk.add(step.nodeValue);
          if (step.nodeValue == 'f') {
            return GraphWalkingInstruction.setNodesExpansionCounter(
                {step.node: 10});
          }
          return null;
        },
        isNull,
        ['a', 'b', 'c', 'f', 'x', 'd', 'e', 'h', 'g'],
        ['a', 'b', 'c', 'f', 'x', 'd', 'e', 'h', 'g'],
        maxExpansion: 3,
      );

      await doWalkerTest<String>(
        (step, walk) {
          walk.add(step.nodeValue);
          if (step.nodeValue == 'x') {
            return GraphWalkingInstruction.stop();
          }
          return null;
        },
        isNull,
        ['a', 'b', 'c', 'f', 'x'],
        ['a', 'b', 'c', 'f', 'x', 'd', 'e', 'h', 'g'],
        maxExpansion: 3,
      );

      await doWalkerTest<String>(
        (step, walk) {
          walk.add(step.nodeValue);
          if (step.nodeValue == 'd') {
            return GraphWalkingInstruction.next();
          }
          return null;
        },
        isNull,
        ['a', 'b', 'c', 'f', 'x', 'd'],
        ['a', 'b', 'c', 'f', 'x', 'd', 'e', 'h', 'g'],
        maxExpansion: 3,
      );
    });

    test('walkByNodes (processSideBranches)', () {
      {
        var graph = Graph<String>();

        graph.node('a').getOrAddOutput('b');

        graph.node('b')
          ..getOrAddOutput('c')
          ..getOrAddOutput('d');

        graph.node('c').getOrAddOutput('f');

        graph.node('d')
          ..getOrAddOutput('e')
          ..getOrAddOutput('g');

        graph.node('e')
          ..getOrAddOutput('f')
          ..getOrAddOutput('h');

        graph.node('f').getOrAddOutput('x');

        graph.node('m').getOrAddOutput('n');

        graph.node('n').getOrAddOutput('f');

        var graphWalker = GraphWalker<String>(maxExpansion: 1, bfs: false);

        var paths1 = <String>[];
        var pathsSide1 = <String, List<String>>{};

        graphWalker.walkByNodes(
          graph.getNodes(['a']),
          outputsProvider: (step, node) => node.outputs,
          process: (step) {
            paths1.add(step.fullPathToRoot());
            return null;
          },
          processSideBranches: (step, sideBranches) {
            pathsSide1[step.nodeValue] = sideBranches.toListOfValues();
            return null;
          },
        );

        expect(
            paths1,
            equals([
              'a',
              'a/b',
              'a/b/c',
              'a/b/c/f',
              'a/b/c/f/x',
              'a/b/d',
              'a/b/d/e',
              'a/b/d/e/h',
              'a/b/d/g'
            ]));

        expect(
            pathsSide1,
            equals({
              'c': ['m', 'e', 'd', 'n'],
              'f': ['e', 'd', 'n', 'm'],
              'x': ['e', 'd', 'n', 'm'],
              'e': ['m']
            }));

        graphWalker.reset();

        var paths2 = <String>[];

        graphWalker.walkByNodes(
          graph.getNodes(['a']),
          expandSideBranches: true,
          outputsProvider: (step, node) => node.outputs,
          process: (step) {
            var fullPathToRoot = step.fullPathToRoot();
            paths2.add(fullPathToRoot);
            return null;
          },
        );

        print(dart_convert.json.encode(paths2));

        expect(
            paths2,
            equals([
              'a',
              'a/b',
              'a/b/c',
              'm',
              'm/n',
              'm/n/e',
              'm/n/e/d',
              'm/n/e/d/g',
              'm/n/e/f',
              'm/n/e/f/x',
              'm/n/e/h'
            ]));
      }
    });
  });

  group('GraphScanner', () {
    test('scanPathsFrom (null outputsProvider)', () async {
      var graphScanner = GraphScanner<String>();

      var result = await graphScanner.scanPathsFrom('a', AnyNode());

      expect(result.paths, isEmpty);
    });

    test('scanPathsFromMany (null outputsProvider)', () async {
      var graphScanner = GraphScanner<String>();

      var result = await graphScanner.scanPathsFromMany(['a'], AnyNode());

      expect(result.paths, isEmpty);
    });

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

Future<GraphWalker<String>> doWalkerTest<R>(
    Function(GraphNodeStep<String> step, List<String> walk) process,
    dynamic returnExpected,
    List<String> expectedWalk,
    List<String> expectedOrder,
    {int maxExpansion = 1,
    bool bfs = false}) async {
  outputsProvider(step, nodeValue) {
    switch (nodeValue) {
      case 'a':
        return ['b'];
      case 'b':
        return ['c', 'd'];
      case 'c':
        return ['f'];
      case 'd':
        return ['e', 'g'];
      case 'e':
        return ['f', 'h'];
      case 'f':
        return ['x'];
      default:
        return null;
    }
  }

  outputsProviderNodes(step, node) =>
      outputsProvider(step, node.value)?.toNodes();

  outputsProviderAsync(step, nodeValue) async =>
      outputsProvider(step, nodeValue);

  outputsProviderNodesAsync(step, node) async =>
      outputsProviderNodes(step, node);

  var graphWalker = GraphWalker<String>(maxExpansion: maxExpansion, bfs: bfs);

  {
    graphWalker.reset();

    var order = graphWalker.walkOrder(
      ['a'],
      nodeProvider: (step, nodeValue) => Node(nodeValue),
      outputsProvider: outputsProviderNodes,
    );

    expect(order.toListOfValues(), equals(expectedOrder));
  }

  {
    graphWalker.reset();

    var walk = <String>[];

    var res = graphWalker.walk<R>(
      ['a'],
      nodeProvider: (step, value) => Node<String>(value),
      outputsProvider: outputsProvider,
      process: (s) => process(s, walk),
    );

    expect(walk, equals(expectedWalk));
    expect(res, returnExpected);
  }

  {
    graphWalker.reset();

    var walk = <String>[];

    var res = graphWalker.walkByNodes<R>(
      ['a'].toNodes(),
      outputsProvider: outputsProviderNodes,
      process: (s) => process(s, walk),
    );

    expect(walk, equals(expectedWalk));
    expect(res, returnExpected);
  }

  {
    graphWalker.reset();

    var walk = <String>[];

    var res = await graphWalker.walkAsync<R>(
      ['a'],
      nodeProvider: (step, value) async => Node<String>(value),
      outputsProvider: outputsProviderAsync,
      process: (s) async => process(s, walk),
    );

    expect(walk, equals(expectedWalk));
    expect(res, returnExpected);
  }

  {
    graphWalker.reset();

    var walk = <String>[];

    var res = await graphWalker.walkByNodesAsync<R>(
      ['a'].toNodes(),
      outputsProvider: outputsProviderNodesAsync,
      process: (s) async => process(s, walk),
    );

    expect(walk, equals(expectedWalk));
    expect(res, returnExpected);
  }

  return graphWalker;
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

extension _IterableExtension<T> on Iterable<T> {
  List<Node<T>> toNodes() => map((e) => Node(e)).toList();
}
