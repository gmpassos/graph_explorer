// Copyright (c) 2023, Graciliano M P. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// Author:
// - Graciliano M. Passos: gmpassos @ GitHub
//

import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';

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

  /// Returns `true` if this is a side root step.
  bool get isSideRoot => false;

  List<T>? _valuePathToRoot;

  /// The values path to the root step.
  List<T> get valuePathToRoot => _valuePathToRoot ??= _valuePathToRootImpl();

  List<T> _valuePathToRootImpl() {
    if (isRoot || isSideRoot) {
      return [nodeValue];
    }

    final previousPath = previous?._valuePathToRoot;
    if (previousPath != null) {
      return [...previousPath, nodeValue];
    }

    List<T> path = [];

    GraphStep<T>? step = this;
    while (step != null) {
      path.add(step.nodeValue);

      if (step.isRoot || step.isSideRoot) break;

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

  GraphValueStep.root(this.walker, this.nodeValue)
      : previous = null,
        depth = 0;

  GraphValueStep.subNode(GraphStep<T> previous, this.nodeValue)
      : walker = previous.walker,
        // ignore: prefer_initializing_formals
        previous = previous,
        depth = previous.depth + 1;

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

  /// If `true` this is a [Node] step from a side branch.
  final bool sideBranch;

  GraphNodeStep.root(this.walker, this.node)
      : previous = null,
        depth = 0,
        sideBranch = false;

  GraphNodeStep.subNode(GraphNodeStep<T> previous, this.node,
      {this.sideBranch = false})
      : walker = previous.walker,
        // ignore: prefer_initializing_formals
        previous = previous,
        depth = previous.depth + 1;

  /// The [Node] of the [previous] step.
  Node<T>? get parentNode => previous?.node;

  @override
  T? get parentValue => parentNode?.value;

  @override
  T get nodeValue => node.value;

  @override
  bool get isSideRoot => sideBranch && node.isRoot;

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

typedef GraphWalkNodeProviderAsync<T> = FutureOr<Node<T>?> Function(
    GraphStep<T> step, T nodeValue);

typedef GraphWalkNodeProcessor<T, R> = Object? Function(GraphNodeStep<T> step);

typedef GraphWalkSideBranchProcessor<T, R> = Object? Function(
    GraphNodeStep<T> step, List<Node<T>> sideBranches);

typedef GraphWalkNodeProcessorAsync<T, R> = FutureOr<Object?> Function(
    GraphNodeStep<T> step);

typedef GraphWalkSideBranchProcessorAsync<T, R> = FutureOr<Object?> Function(
    GraphNodeStep<T> step, List<Node<T>> sideBranches);

typedef GraphWalkNodeOutputsProvider<T> = Iterable<Node<T>>? Function(
    GraphNodeStep<T> step, Node<T> node);

typedef GraphWalkNodeOutputsProviderAsync<T> = FutureOr<Iterable<Node<T>>?>
    Function(GraphNodeStep<T> step, Node<T> node);

typedef GraphWalkOutputsProvider<T> = Iterable<T>? Function(
    GraphNodeStep<T> step, T nodeValue);

typedef GraphWalkOutputsProviderAsync<T> = FutureOr<Iterable<T>?> Function(
    GraphNodeStep<T> step, T nodeValue);

class GraphWalkingInstruction<R> {
  GraphWalkingInstruction();

  factory GraphWalkingInstruction.result(R? result) =>
      GraphWalkingInstructionResult(result);

  factory GraphWalkingInstruction.stop() =>
      GraphWalkingInstructionOperation(GraphWalkingOperation.stop);

  factory GraphWalkingInstruction.next() =>
      GraphWalkingInstructionOperation(GraphWalkingOperation.next);

  factory GraphWalkingInstruction.setExpansionCounter(int count) =>
      GraphWalkingInstructionSetExpansionCounter(count);

  factory GraphWalkingInstruction.setNodesExpansionCounter(
          Map<Node, int> counter) =>
      GraphWalkingInstructionSetNodesExpansionCounter(counter);
}

enum GraphWalkingOperation {
  stop,
  next,
}

class GraphWalkingInstructionOperation<R> extends GraphWalkingInstruction<R> {
  final GraphWalkingOperation operation;

  GraphWalkingInstructionOperation(this.operation);
}

class GraphWalkingInstructionResult<R> extends GraphWalkingInstruction<R> {
  final R? result;

  GraphWalkingInstructionResult(this.result);
}

class GraphWalkingInstructionSetExpansionCounter<R>
    extends GraphWalkingInstruction<R> {
  final int count;

  GraphWalkingInstructionSetExpansionCounter(this.count);
}

class GraphWalkingInstructionSetNodesExpansionCounter<R>
    extends GraphWalkingInstruction<R> {
  final Map<Node, int> counter;

  GraphWalkingInstructionSetNodesExpansionCounter(this.counter);
}

/// [Graph] walker algorithms.
class GraphWalker<T> {
  /// The [NodeMatcher] used to stop the walking.
  final NodeMatcher<T> stopMatcher;

  /// If `true` will process root nodes.
  final bool processRoots;

  /// The maximum expansions that a node can have. Default: 1
  final int maxExpansion;

  /// If `true` sort nodes by input dependency.
  final bool sortByInputDependency;

  /// If `true` will perform a BFS (Breadth-First Search), if `false` an DFS (Depth-First Search).
  /// Default: `false` (DFS).
  final bool bfs;

  final Map<Node<T>, int>? _initialProcessedNodes;

  final Map<Node<T>, int> _processedNodes = <Node<T>, int>{};

  GraphWalker({
    NodeMatcher<T>? stopMatcher,
    this.processRoots = true,
    this.maxExpansion = 1,
    this.sortByInputDependency = false,
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

  /// Returns the maximum expansion count in [processedNodes].
  int get maxProcessedExpansion => _processedNodes.values.max;

  /// A generic walk algorithm.
  R? walk<R>(
    Iterable<T> from, {
    required GraphWalkNodeProvider<T> nodeProvider,
    required GraphWalkOutputsProvider<T> outputsProvider,
    required GraphWalkNodeProcessor<T, R> process,
    int? maxDepth,
  }) {
    maxDepth ??= defaultMaxDepth;

    final processed = _processedNodes;
    final queue = ListQueue<GraphNodeStep<T>>();

    for (var rootValue in from) {
      var rootStepValue = GraphValueStep.root(this, rootValue);

      final rootNode = nodeProvider(rootStepValue, rootValue) ??
          (throw StateError("Can't find root node: $rootValue"));

      var rootStep = GraphNodeStep.root(this, rootNode);
      queue.add(rootStep);
    }

    while (queue.isNotEmpty) {
      final step = queue.removeFirst();
      final node = step.node;
      final nodeValue = step.nodeValue;

      var processCount = processed.increment(node);

      if (processCount <= maxExpansion && step.depth <= maxDepth) {
        if (processRoots || step.isNotRoot) {
          var ret = process(step);

          if (ret != null) {
            if (ret is GraphWalkingInstructionResult) {
              return ret.result as R?;
            } else if (ret is GraphWalkingInstructionOperation) {
              switch (ret.operation) {
                case GraphWalkingOperation.stop:
                  return null;
                case GraphWalkingOperation.next:
                  continue;
              }
            } else if (ret is GraphWalkingInstructionSetExpansionCounter) {
              processed[node] = ret.count;
            } else if (ret is GraphWalkingInstructionSetNodesExpansionCounter) {
              processed.addCounter(ret.counter);
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
            var nodeStepValue = GraphValueStep.subNode(step, v);
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
    required GraphWalkNodeProviderAsync<T> nodeProvider,
    required GraphWalkOutputsProviderAsync<T> outputsProvider,
    required GraphWalkNodeProcessorAsync<T, R> process,
    int? maxDepth,
  }) async {
    maxDepth ??= defaultMaxDepth;

    final processed = _processedNodes;
    final queue = ListQueue<GraphNodeStep<T>>();

    for (var rootValue in from) {
      var rootStepValue = GraphValueStep.root(this, rootValue);

      final rootNode = await nodeProvider(rootStepValue, rootValue) ??
          (throw StateError("Can't find root node: $rootValue"));

      var rootStep = GraphNodeStep.root(this, rootNode);
      queue.add(rootStep);
    }

    while (queue.isNotEmpty) {
      final step = queue.removeFirst();
      final node = step.node;
      final nodeValue = step.nodeValue;

      var processCount = processed.increment(node);

      if (processCount <= maxExpansion && step.depth <= maxDepth) {
        if (processRoots || step.isNotRoot) {
          var ret = await process(step);

          if (ret != null) {
            if (ret is GraphWalkingInstructionResult) {
              return ret.result as R?;
            } else if (ret is GraphWalkingInstructionOperation) {
              switch (ret.operation) {
                case GraphWalkingOperation.stop:
                  return null;
                case GraphWalkingOperation.next:
                  continue;
              }
            } else if (ret is GraphWalkingInstructionSetExpansionCounter) {
              processed[node] = ret.count;
            } else if (ret is GraphWalkingInstructionSetNodesExpansionCounter) {
              processed.addCounter(ret.counter);
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
            var nodeStepValue = GraphValueStep.subNode(step, v);
            return nodeProvider(nodeStepValue, v);
          });

          queue.addAllToScanQueue(
              await outputsNodes.toGraphNodeStepAsync(step), bfs);
        }
      }
    }

    return _resolveWalkProcessReturn<T, R>(null, false);
  }

  static const int defaultMaxDepth = 9007199254740991;

  /// A generic walk algorithm using [Node]s.
  R? walkByNodes<R>(
    Iterable<Node<T>> from, {
    required GraphWalkNodeOutputsProvider<T> outputsProvider,
    required GraphWalkNodeProcessor<T, R> process,
    GraphWalkSideBranchProcessor<T, R>? processSideBranches,
    bool expandSideBranches = false,
    int? maxDepth,
  }) {
    maxDepth ??= defaultMaxDepth;

    final processed = _processedNodes;
    final queue = ListQueue<GraphNodeStep<T>>();

    if (sortByInputDependency) {
      from = from.sortedByInputDependency();
    }

    queue.addAll(from.toGraphRootStep(this));

    while (queue.isNotEmpty) {
      final step = queue.removeFirst();
      final node = step.node;

      var processCount = processed.increment(node);

      if (processCount <= maxExpansion && step.depth <= maxDepth) {
        if (processRoots || step.isNotRoot) {
          var ret = process(step);

          if (ret == null && processSideBranches != null) {
            var sideBranches = _computeSideBranch(node, processed);
            if (sideBranches.isNotEmpty) {
              if (sortByInputDependency) {
                sideBranches = sideBranches.sortedByInputDependency();
              }
              ret = processSideBranches(step, sideBranches);
            }
          }

          if (ret != null) {
            if (ret is GraphWalkingInstructionResult) {
              return ret.result as R?;
            } else if (ret is GraphWalkingInstructionOperation) {
              switch (ret.operation) {
                case GraphWalkingOperation.stop:
                  return null;
                case GraphWalkingOperation.next:
                  continue;
              }
            } else if (ret is GraphWalkingInstructionSetExpansionCounter) {
              processed[node] = ret.count;
            } else if (ret is GraphWalkingInstructionSetNodesExpansionCounter) {
              processed.addCounter(ret.counter);
            } else {
              return _resolveWalkProcessReturn<T, R>(node, ret);
            }
          }
        }

        if (stopMatcher.matchesNode(node)) {
          return _resolveWalkProcessReturn<T, R>(node, true);
        }

        List<Node<T>>? sideBranches;
        if (expandSideBranches && processSideBranches == null) {
          sideBranches = _computeSideBranch(node, processed);
          if (sortByInputDependency) {
            sideBranches = sideBranches.sortedByInputDependency();
          }
        }

        var outputs = outputsProvider(step, node);
        if (sortByInputDependency) {
          outputs = outputs?.sortedByInputDependency();
        }

        var nextStepsSideBranches =
            sideBranches?.toGraphNodeStep(step, sideBranch: true);
        var nextStepsOutputs = outputs?.toGraphNodeStep(step);

        queue.addAllToScanQueue2(nextStepsSideBranches, nextStepsOutputs, bfs);
      }
    }

    return _resolveWalkProcessReturn<T, R>(null, false);
  }

  /// A generic walk algorithm using [Node]s.
  Future<R?> walkByNodesAsync<R>(
    Iterable<Node<T>> from, {
    required GraphWalkNodeOutputsProviderAsync<T> outputsProvider,
    required GraphWalkNodeProcessorAsync<T, R> process,
    GraphWalkSideBranchProcessorAsync<T, R>? processSideBranches,
    bool expandSideBranches = false,
    int? maxDepth,
  }) async {
    maxDepth ??= defaultMaxDepth;

    final processed = _processedNodes;
    final queue = ListQueue<GraphNodeStep<T>>();

    if (sortByInputDependency) {
      from = from.sortedByInputDependency();
    }

    queue.addAll(from.toGraphRootStep(this));

    while (queue.isNotEmpty) {
      final step = queue.removeFirst();
      final node = step.node;

      var processCount = processed.increment(node);

      if (processCount <= maxExpansion && step.depth <= maxDepth) {
        if (processRoots || step.isNotRoot) {
          var ret = await process(step);

          if (ret == null && processSideBranches != null) {
            var sideBranches = _computeSideBranch(node, processed);
            if (sideBranches.isNotEmpty) {
              if (sortByInputDependency) {
                sideBranches = sideBranches.sortedByInputDependency();
              }
              ret = await processSideBranches(step, sideBranches);
            }
          }

          if (ret != null) {
            if (ret is GraphWalkingInstructionResult) {
              return ret.result as R?;
            } else if (ret is GraphWalkingInstructionOperation) {
              switch (ret.operation) {
                case GraphWalkingOperation.stop:
                  return null;
                case GraphWalkingOperation.next:
                  continue;
              }
            } else if (ret is GraphWalkingInstructionSetExpansionCounter) {
              processed[node] = ret.count;
            } else if (ret is GraphWalkingInstructionSetNodesExpansionCounter) {
              processed.addCounter(ret.counter);
            } else {
              return _resolveWalkProcessReturn<T, R>(node, ret);
            }
          }
        }

        if (stopMatcher.matchesNode(node)) {
          return _resolveWalkProcessReturn<T, R>(node, true);
        }

        List<Node<T>>? sideBranches;
        if (expandSideBranches && processSideBranches == null) {
          sideBranches = _computeSideBranch(node, processed);
          if (sortByInputDependency) {
            sideBranches = sideBranches.sortedByInputDependency();
          }
        }

        var outputs = await outputsProvider(step, node);
        if (sortByInputDependency) {
          outputs = outputs?.sortedByInputDependency();
        }

        var nextStepsSideBranches =
            sideBranches?.toGraphNodeStep(step, sideBranch: true);
        var nextStepsOutputs = outputs?.toGraphNodeStep(step);

        queue.addAllToScanQueue2(nextStepsSideBranches, nextStepsOutputs, bfs);
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

  /// Returns the walk order of nodes.
  List<Node<T>> walkOrder(
    List<T> roots, {
    required GraphWalkNodeProvider<T> nodeProvider,
    required GraphWalkNodeOutputsProvider<T> outputsProvider,
    bool expandSideBranches = false,
    int? maxDepth,
  }) {
    maxDepth ??= defaultMaxDepth;

    final walkOrder = <Node<T>>{};

    final processed = _processedNodes;
    final queue = ListQueue<GraphNodeStep<T>>();

    var rootNodes = roots.map((e) {
      var rootStep = GraphValueStep.root(this, e);
      return nodeProvider(rootStep, e) ??
          (throw ArgumentError("Root not present in graph: $e"));
    }).toList();

    if (sortByInputDependency) {
      rootNodes = rootNodes.sortedByInputDependency();
    }

    queue.addAll(rootNodes.toGraphRootStep(this));

    while (queue.isNotEmpty) {
      final step = queue.removeFirst();
      final node = step.node;

      var processCount = processed.increment(node);

      if (processCount <= maxExpansion && step.depth <= maxDepth) {
        if (processRoots || step.isNotRoot) {
          walkOrder.add(node);
        }

        if (stopMatcher.matchesNode(node)) {
          break;
        }

        List<Node<T>>? sideBranches;
        if (expandSideBranches) {
          sideBranches = _computeSideBranch(node, processed);
          if (sortByInputDependency) {
            sideBranches = sideBranches.sortedByInputDependency();
          }
        }

        var outputs = outputsProvider(step, node);
        if (sortByInputDependency) {
          outputs = outputs?.sortedByInputDependency();
        }

        var nextStepsSideBranch =
            sideBranches?.toGraphNodeStep(step, sideBranch: true);
        var nextStepsOutputs = outputs?.toGraphNodeStep(step);

        queue.addAllToScanQueue2(nextStepsSideBranch, nextStepsOutputs, bfs);
      }
    }

    return walkOrder.toList();
  }

  List<Node<T>> _computeSideBranch(Node<T> node, Map<Node<T>, int> processed) {
    var sideRoots = node.sideRoots(maxDepth: 1);

    var knownDependencies = processed.keys.where((e) => e != node).toList();

    var missing =
        node.missingDependencies(knownDependencies, maxDepth: 1).toList();

    if (missing.isNotEmpty) {
      var sideBranches = sideRoots.merge(missing);
      return sideBranches;
    }

    return sideRoots;
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
      var rootStep = GraphValueStep.root(this, e);
      return nodeProvider(rootStep, e) ??
          (throw ArgumentError("Root not present in graph: $e"));
    }).toList();

    if (sortByInputDependency) {
      rootNodes = rootNodes.sortedByInputDependency();
    }

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
          if (sortByInputDependency) {
            outputs = outputs.sortedByInputDependency();
          }

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

  @override
  String toString() {
    return 'GraphWalker{bfs: $bfs, maxExpansion: $maxExpansion, processRoots: $processRoots, sortByInputDependency: $sortByInputDependency, stopMatcher: $stopMatcher, processedNodes: ${_processedNodes.length}, maxProcessedExpansion: $maxProcessedExpansion}';
  }
}

extension _MapOfIntExtension<K> on Map<K, int> {
  int increment(K key) => update(key, (count) => count + 1, ifAbsent: () => 1);
}

extension _MapOfNodeCounterExtension<T> on Map<Node<T>, int> {
  void addCounter(Map<Node, int> counter) =>
      addEntries(counter.entries.map((e) {
        if (e is MapEntry<Node<T>, int>) {
          return e;
        } else {
          var node = e.key;
          if (node is! Node<T>) return null;
          return MapEntry(node, e.value);
        }
      }).whereNotNull());
}

extension _ListTypeExtension<T> on List<T> {
  Type get genericType => T;

  List<T> toReversedList() => reversed.toList();
}

extension _ToGraphNodeStepIterableExtension<T> on Iterable<Node<T>> {
  Iterable<GraphNodeStep<T>> toGraphRootStep(GraphWalker<T> walker) =>
      map((node) => GraphNodeStep<T>.root(walker, node));

  Iterable<GraphNodeStep<T>> toGraphNodeStep(GraphNodeStep<T> previous,
          {bool sideBranch = false}) =>
      map((node) =>
          GraphNodeStep<T>.subNode(previous, node, sideBranch: sideBranch));
}

extension _ToGraphNodeStepIterableAsyncExtension<T>
    on Iterable<FutureOr<Node<T>?>> {
  FutureOr<List<GraphNodeStep<T>>> toGraphNodeStepAsync(
      GraphNodeStep<T> previous) {
    var l = <FutureOr<GraphNodeStep<T>>>[];

    var futureCount = 0;
    for (var node in this) {
      if (node is Future<Node<T>?>) {
        var stepAsync = node.then((node) {
          if (node == null) {
            throw StateError("Null node");
          }
          return GraphNodeStep<T>.subNode(previous, node);
        });
        l.add(stepAsync);
        futureCount++;
      } else {
        if (node == null) {
          throw StateError("Null node");
        }
        var step = GraphNodeStep<T>.subNode(previous, node);
        l.add(step);
      }
    }

    final length = l.length;

    if (length == 0) {
      return [];
    } else if (futureCount == 0) {
      return l.cast<GraphNodeStep<T>>();
    } else if (futureCount == length) {
      return Future.wait(l.cast<Future<GraphNodeStep<T>>>());
    } else {
      return Future.wait(l.map((e) {
        return e is Future<GraphNodeStep<T>> ? e : Future.value(e);
      }));
    }
  }
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

  void addAllToScanQueue2(
      Iterable<T>? elements1, Iterable<T>? elements2, bool bfs) {
    if (bfs) {
      if (elements1 != null) addAll(elements1);
      if (elements2 != null) addAll(elements2);
    } else {
      Iterable<T> elements;

      if (elements1 != null && elements2 != null) {
        elements = CombinedIterableView([elements1, elements2]);
      } else if (elements1 != null) {
        elements = elements1;
      } else if (elements2 != null) {
        elements = elements2;
      } else {
        return;
      }

      var reversed = elements is List<T>
          ? elements.reversed
          : elements.toList(growable: false).reversed;

      for (var e in reversed) {
        addFirst(e);
      }
    }
  }
}
