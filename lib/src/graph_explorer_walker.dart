// Copyright (c) 2023, Graciliano M P. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// Author:
// - Graciliano M. Passos: gmpassos @ GitHub
//

import 'dart:async';
import 'dart:collection';

import 'graph_explorer_base.dart';

/// A [GraphWalker] step context.
abstract class GraphStep<T> {
  GraphWalker<T> get walker;

  /// The table of processed [Node]s
  Map<Node<T>, int> get processed => walker.processedNodes;

  /// The previous step.
  GraphStep<T>? get previous;

  /// This step depth.
  int get depth;

  /// The parent step node value.
  T? get parentValue;

  /// The step node value.
  T get nodeValue;

  /// Returns `true` if this step is a root step.
  /// - Does NOT mean that this step node is root ([Node.isRoot]).
  bool get isRoot => previous == null;

  /// NOT [isRoot].
  bool get isNotRoot => previous != null;

  List<T>? _valuePathToRoot;

  /// The values path to the root step.
  List<T> get valuePathToRoot => _valuePathToRoot ??= _valuePathToRootImpl();

  List<T> _valuePathToRootImpl() {
    final previousPath = previous?._valuePathToRoot;
    if (previousPath != null) {
      return [...previousPath, nodeValue];
    }

    List<T> path = [];

    GraphStep<T>? step = this;
    while (step != null) {
      path.add(step.nodeValue);
      step = step.previous;
    }

    return path.toReversedList();
  }

  /// Same as [valuePathToRoot], but with additional [head] and [tail].
  List<T> valuePathToRootWith({Iterable<T>? head, Iterable<T>? tail}) {
    final valuePathToRoot = this.valuePathToRoot;

    if (head != null || tail != null) {
      return [...?head, ...valuePathToRoot, ...?tail];
    } else {
      return valuePathToRoot;
    }
  }

  /// Returns a [String] that represents a full path to the root step.
  String fullPathToRoot(
      {String pathDelimiter = '/',
      Iterable<T>? head,
      Iterable<T>? tail,
      Iterable<String>? headString,
      Iterable<String>? tailString}) {
    var pathToRoot =
        valuePathToRootWith(head: head, tail: tail).map((e) => e.toString());
    if (headString != null || tailString != null) {
      pathToRoot = [...?headString, ...pathToRoot, ...?tailString];
    }
    return pathToRoot.join(pathDelimiter);
  }

  @override
  String toString() {
    final previous = this.previous;
    return 'GraphStep[$depth]{ ${previous != null ? '${previous.isNotRoot ? '...' : ''}${previous.nodeValue} -> ' : ''}$nodeValue }';
  }
}

/// A [GraphStep] that has only the node value,
/// but without a resolved [Node] yet.
/// See [Graph.populate].
class GraphValueStep<T> extends GraphStep<T> {
  @override
  final GraphWalker<T> walker;

  @override
  final GraphStep<T>? previous;
  @override
  final int depth;

  @override
  final T nodeValue;

  GraphValueStep(this.walker, this.previous, this.nodeValue)
      : depth = previous != null ? previous.depth + 1 : 0;

  @override
  T? get parentValue => previous?.nodeValue;
}

/// A [GraphStep] with a [Node] resolved.
class GraphNodeStep<T> extends GraphStep<T> {
  @override
  final GraphWalker<T> walker;

  @override
  final GraphNodeStep<T>? previous;
  @override
  final int depth;

  /// The node of this step.
  final Node<T> node;

  GraphNodeStep(this.walker, this.previous, this.node)
      : depth = previous != null ? previous.depth + 1 : 0;

  /// The [Node] of the [previous] step.
  Node<T>? get parentNode => previous?.node;

  @override
  T? get parentValue => parentNode?.value;

  @override
  T get nodeValue => node.value;

  List<Node<T>>? _nodePathToRoot;

  List<Node<T>> get nodePathToRoot => _nodePathToRoot ??= _nodePathToRootImpl();

  List<Node<T>> _nodePathToRootImpl() {
    final previousPath = previous?._nodePathToRoot;
    if (previousPath != null) {
      return [...previousPath, node];
    }

    List<Node<T>> path = [];

    GraphNodeStep<T>? step = this;
    while (step != null) {
      path.add(step.node);
      step = step.previous;
    }

    return path.toReversedList();
  }
}

typedef GraphWalkNodeProvider<T> = Node<T>? Function(
    GraphStep<T> step, T nodeValue);

typedef GraphWalkNodeProcessor<T> = dynamic Function(GraphNodeStep<T> step);

typedef GraphWalkNodeOutputsProvider<T> = Iterable<Node<T>>? Function(
    GraphNodeStep<T> step, Node<T> node);

typedef GraphWalkNodeOutputsProviderAsync<T> = FutureOr<Iterable<Node<T>>?>
    Function(GraphNodeStep<T> step, Node<T> node);

typedef GraphWalkOutputsProvider<T> = Iterable<T>? Function(
    GraphNodeStep<T> step, T nodeValue);

typedef GraphWalkOutputsProviderAsync<T> = FutureOr<Iterable<T>?> Function(
    GraphNodeStep<T> step, T nodeValue);

enum GraphWalking {
  stop,
  next,
}

/// [Graph] walker algorithms.
class GraphWalker<T> {
  /// The [NodeMatcher] used to stop the walking.
  final NodeMatcher<T> stopMatcher;

  /// If `true` will process root nodes.
  final bool processRoots;

  /// The maximum expansions that a node can have. Default: 1
  final int maxExpansion;

  /// If `true` will perform a BFS (Breadth-First Search), if `false` an DFS (Depth-First Search).
  /// Default: `false` (DFS).
  final bool bfs;

  final Map<Node<T>, int>? _initialProcessedNodes;

  final Map<Node<T>, int> _processedNodes = <Node<T>, int>{};

  GraphWalker({
    NodeMatcher<T>? stopMatcher,
    this.processRoots = true,
    this.maxExpansion = 1,
    this.bfs = false,
    Map<Node<T>, int>? initialProcessedNodes,
  })  : stopMatcher = stopMatcher ?? NoneNode(),
        _initialProcessedNodes = initialProcessedNodes {
    reset();
  }

  late final Map<Node<T>, int> processedNodes =
      UnmodifiableMapView(_processedNodes);

  void reset({bool rollbackToInitialProcessedNodes = true}) {
    _processedNodes.clear();

    final initialProcessedNodes = _initialProcessedNodes;
    if (rollbackToInitialProcessedNodes && initialProcessedNodes != null) {
      _processedNodes.addAll(initialProcessedNodes);
    }
  }

  /// A generic walk algorithm.
  R? walk<R>(
    Iterable<T> from, {
    required GraphWalkNodeProvider<T> nodeProvider,
    required GraphWalkOutputsProvider<T> outputsProvider,
    required GraphWalkNodeProcessor<T> process,
  }) {
    final processed = _processedNodes;
    final queue = ListQueue<GraphNodeStep<T>>();

    for (var rootValue in from) {
      var rootStepValue = GraphValueStep(this, null, rootValue);

      final rootNode = nodeProvider(rootStepValue, rootValue) ??
          (throw StateError("Can't find root node: $rootValue"));

      var rootStep = GraphNodeStep(this, null, rootNode);
      queue.add(rootStep);
    }

    while (queue.isNotEmpty) {
      final step = queue.removeFirst();
      final node = step.node;
      final nodeValue = step.nodeValue;

      var processCount = processed.increment(node);

      if (processCount <= maxExpansion) {
        if (processRoots || step.isNotRoot) {
          var ret = process(step);

          if (ret != null) {
            if (ret is GraphWalking) {
              switch (ret) {
                case GraphWalking.stop:
                  return null;
                case GraphWalking.next:
                  continue;
              }
            } else if (ret is bool) {
              if (ret) {
                return _resolveWalkProcessReturn<T, R>(node, ret);
              }
            } else {
              return _resolveWalkProcessReturn<T, R>(node, ret);
            }
          }
        }

        if (stopMatcher.matchesNode(node)) {
          return _resolveWalkProcessReturn<T, R>(node, true);
        }

        var outputs = outputsProvider(step, nodeValue);
        if (outputs != null) {
          var outputsNodes = outputs.map((v) {
            var nodeStepValue = GraphValueStep(this, step, v);
            return nodeProvider(nodeStepValue, v)!;
          });

          queue.addAllToScanQueue(outputsNodes.toGraphNodeStep(step), bfs);
        }
      }
    }

    return _resolveWalkProcessReturn<T, R>(null, false);
  }

  /// A generic walk algorithm.
  Future<R?> walkAsync<R>(
    Iterable<T> from, {
    required GraphWalkNodeProvider<T> nodeProvider,
    required GraphWalkOutputsProviderAsync<T> outputsProvider,
    required GraphWalkNodeProcessor<T> process,
  }) async {
    final processed = _processedNodes;
    final queue = ListQueue<GraphNodeStep<T>>();

    for (var rootValue in from) {
      var rootStepValue = GraphValueStep(this, null, rootValue);

      final rootNode = nodeProvider(rootStepValue, rootValue) ??
          (throw StateError("Can't find root node: $rootValue"));

      var rootStep = GraphNodeStep(this, null, rootNode);
      queue.add(rootStep);
    }

    while (queue.isNotEmpty) {
      final step = queue.removeFirst();
      final node = step.node;
      final nodeValue = step.nodeValue;

      var processCount = processed.increment(node);

      if (processCount <= maxExpansion) {
        if (processRoots || step.isNotRoot) {
          var ret = await process(step);

          if (ret != null) {
            if (ret is GraphWalking) {
              switch (ret) {
                case GraphWalking.stop:
                  return null;
                case GraphWalking.next:
                  continue;
              }
            } else if (ret is bool) {
              if (ret) {
                return _resolveWalkProcessReturn<T, R>(node, ret);
              }
            } else {
              return _resolveWalkProcessReturn<T, R>(node, ret);
            }
          }
        }

        if (stopMatcher.matchesNode(node)) {
          return _resolveWalkProcessReturn<T, R>(node, true);
        }

        var outputs = await outputsProvider(step, nodeValue);
        if (outputs != null) {
          var outputsNodes = outputs.map((v) {
            var nodeStepValue = GraphValueStep(this, step, v);
            return nodeProvider(nodeStepValue, v)!;
          });

          queue.addAllToScanQueue(outputsNodes.toGraphNodeStep(step), bfs);
        }
      }
    }

    return _resolveWalkProcessReturn<T, R>(null, false);
  }

  /// A generic walk algorithm using [Node]s.
  R? walkByNodes<R>(
    Iterable<Node<T>> from, {
    required GraphWalkNodeOutputsProvider<T> outputsProvider,
    required GraphWalkNodeProcessor<T> process,
  }) {
    final processed = _processedNodes;
    final queue = ListQueue<GraphNodeStep<T>>();

    for (var rootNode in from) {
      var rootStep = GraphNodeStep(this, null, rootNode);
      queue.add(rootStep);
    }

    while (queue.isNotEmpty) {
      final step = queue.removeFirst();
      final node = step.node;

      var processCount = processed.increment(node);

      if (processCount <= maxExpansion) {
        if (processRoots || step.isNotRoot) {
          var ret = process(step);

          if (ret != null) {
            if (ret is GraphWalking) {
              switch (ret) {
                case GraphWalking.stop:
                  return null;
                case GraphWalking.next:
                  continue;
              }
            } else if (ret is bool) {
              if (ret) {
                return _resolveWalkProcessReturn<T, R>(node, ret);
              }
            } else if (ret is int) {
              processed[node] = ret;
            } else {
              return _resolveWalkProcessReturn<T, R>(node, ret);
            }
          }
        }

        if (stopMatcher.matchesNode(node)) {
          return _resolveWalkProcessReturn<T, R>(node, true);
        }

        var outputs = outputsProvider(step, node);
        if (outputs != null) {
          queue.addAllToScanQueue(outputs.toGraphNodeStep(step), bfs);
        }
      }
    }

    return _resolveWalkProcessReturn<T, R>(null, false);
  }

  /// A generic walk algorithm using [Node]s.
  Future<R?> walkByNodesAsync<R>(
    Iterable<Node<T>> from, {
    required GraphWalkNodeOutputsProviderAsync<T> outputsProvider,
    required GraphWalkNodeProcessor<T> process,
  }) async {
    final processed = _processedNodes;
    final queue = ListQueue<GraphNodeStep<T>>();

    for (var rootNode in from) {
      var rootStep = GraphNodeStep(this, null, rootNode);
      queue.add(rootStep);
    }

    while (queue.isNotEmpty) {
      final step = queue.removeFirst();
      final node = step.node;

      var processCount = processed.increment(node);

      if (processCount <= maxExpansion) {
        if (processRoots || step.isNotRoot) {
          var ret = await process(step);

          if (ret != null) {
            if (ret is GraphWalking) {
              switch (ret) {
                case GraphWalking.stop:
                  return null;
                case GraphWalking.next:
                  continue;
              }
            } else if (ret is bool) {
              if (ret) {
                return _resolveWalkProcessReturn<T, R>(node, ret);
              }
            } else if (ret is int) {
              processed[node] = ret;
            } else {
              return _resolveWalkProcessReturn<T, R>(node, ret);
            }
          }
        }

        if (stopMatcher.matchesNode(node)) {
          return _resolveWalkProcessReturn<T, R>(node, true);
        }

        var outputs = await outputsProvider(step, node);
        if (outputs != null) {
          queue.addAllToScanQueue(outputs.toGraphNodeStep(step), bfs);
        }
      }
    }

    return _resolveWalkProcessReturn<T, R>(null, false);
  }

  static R? _resolveWalkProcessReturn<T, R>(Node<T>? node, Object? o) {
    if (R == bool) {
      if (o is R) return o;
      return null;
    }

    if (o is R) {
      return o;
    }

    if (node is R) {
      return node as R;
    }

    return null;
  }

  /// Returns a [Map] representation of this graph from [roots].
  Map<K, dynamic> toTreeFrom<K>(
    List<T> roots, {
    required GraphWalkNodeProvider<T> nodeProvider,
    required GraphWalkNodeOutputsProvider<T> outputsProvider,
    K Function(GraphStep<T> step, T value)? keyCast,
  }) {
    final processed = _processedNodes;

    if (keyCast == null) {
      if (K == String) {
        keyCast = (s, v) => v.toString() as K;
      } else if (K == Node || K == <Node<T>>[].genericType) {
        keyCast = (s, v) => nodeProvider(s, v) as K;
      } else {
        keyCast = (s, v) => v as K;
      }
    }

    Map<K, dynamic> Function() createNode = K == dynamic
        ? () => (<T, dynamic>{} as Map<K, dynamic>)
        : () => <K, dynamic>{};

    Map<Node<T>, Map<K, dynamic>> allTreeNodes = K == dynamic
        ? (<Node<T>, Map<T, dynamic>>{} as Map<Node<T>, Map<K, dynamic>>)
        : <Node<T>, Map<K, dynamic>>{};

    Map<K, dynamic> tree =
        K == dynamic ? (<T, dynamic>{} as Map<K, dynamic>) : <K, dynamic>{};

    var rootNodes = roots.map((e) {
      var rootStep = GraphValueStep(this, null, e);
      return nodeProvider(rootStep, e) ??
          (throw ArgumentError("Root not present in graph: $e"));
    }).toList();

    rootNodes = rootNodes.sortedByInputDependency();

    final queue = ListQueue<GraphNodeStep<T>>();

    queue.addAll(rootNodes.toGraphRootStep(this));

    while (queue.isNotEmpty) {
      final step = queue.removeFirst();
      final node = step.node;

      var processedCount = processed.increment(node);

      var nodeKey = keyCast(step, node.value);

      if (processedCount <= 1) {
        var parentNode = step.parentNode;
        var parentTreeNode =
            parentNode != null ? allTreeNodes[parentNode]! : tree;

        var treeNode = allTreeNodes[node];
        if (treeNode == null) {
          treeNode = allTreeNodes[node] = createNode();
          parentTreeNode[nodeKey] = node.outputs.isEmpty ? null : treeNode;
        } else {
          parentTreeNode[nodeKey] = nodeKey;
        }

        var outputs = outputsProvider(step, node);

        if (outputs != null) {
          queue.addAllToScanQueue(outputs.toGraphNodeStep(step), bfs);
        }
      } else {
        var parentNode = step.parentNode;
        var parentTreeNode =
            parentNode != null ? allTreeNodes[parentNode]! : tree;

        var treeNode = allTreeNodes[node];
        assert(treeNode != null);
        parentTreeNode[nodeKey] = nodeKey;
      }
    }

    return tree;
  }
}

extension _ToGraphNodeStepIterableExtension<T> on Iterable<Node<T>> {
  Iterable<GraphNodeStep<T>> toGraphNodeStep(GraphNodeStep<T> previous) =>
      map((node) => GraphNodeStep<T>(previous.walker, previous, node));

  Iterable<GraphNodeStep<T>> toGraphRootStep(GraphWalker<T> walker) =>
      map((node) => GraphNodeStep<T>(walker, null, node));
}

extension _MapOfIntExtension<K> on Map<K, int> {
  int increment(K key) => update(key, (count) => count + 1, ifAbsent: () => 1);
}

extension _ListTypeExtension<T> on List<T> {
  Type get genericType => T;

  List<T> toReversedList() => reversed.toList();
}

extension _ListQueueExtension<T> on ListQueue<T> {
  void addAllToScanQueue(Iterable<T> elements, bool bfs) {
    if (bfs) {
      addAll(elements);
    } else {
      var reversed = elements is List<T>
          ? elements.reversed
          : elements.toList(growable: false).reversed;
      for (var e in reversed) {
        addFirst(e);
      }
    }
  }
}