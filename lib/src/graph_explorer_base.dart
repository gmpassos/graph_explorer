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

import 'graph_explorer_walker.dart';

/// A [Node] matcher, used by [GraphScanner].
abstract class NodeMatcher<T> {
  NodeMatcher();

  factory NodeMatcher.eq(List<T> targets) {
    return targets.length == 1
        ? NodeEquals(targets.first)
        : MultipleNodesEquals(targets);
  }

  /// Returns `true` if [node] matches.
  bool matchesNode(Node<T> node) => matchesValue(node.value);

  /// Returns `true` if [value] matches.
  bool matchesValue(T value);
}

/// A [Node] matcher that matches ANY node (always returns `true` for a match).
class AnyNode<T> extends NodeMatcher<T> {
  @override
  bool matchesNode(Node<T> node) => true;

  @override
  bool matchesValue(T value) => true;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is NodeMatcher) {
      return true;
    } else if (other is Node) {
      return true;
    } else if (other is List) {
      return true;
    } else if (other is T) {
      return true;
    }

    return false;
  }

  @override
  int get hashCode => 1;

  @override
  String toString() {
    return 'AnyNode{}';
  }
}

/// A [Node] matcher that always returns `false` and never matches a node.
class NoneNode<T> extends NodeMatcher<T> {
  @override
  bool matchesNode(Node<T> node) => false;

  @override
  bool matchesValue(T value) => false;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is NodeMatcher) {
      return false;
    } else if (other is Node) {
      return false;
    } else if (other is List) {
      return false;
    } else if (other is T) {
      return false;
    }

    return false;
  }

  @override
  int get hashCode => 0;

  @override
  String toString() {
    return 'NoneNode{}';
  }
}

/// A [Node] matcher that uses object equality (`==` operator).
class NodeEquals<T> extends NodeMatcher<T> {
  final T targetValue;

  NodeEquals(this.targetValue);

  @override
  bool matchesValue(T value) => targetValue == value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is NodeEquals) {
      return targetValue == other.targetValue;
    } else if (other is MultipleNodesEquals) {
      return other.targetValues.every((e) => e == targetValue);
    } else if (other is Node<T>) {
      return targetValue == other.value;
    } else if (other is T) {
      return targetValue == other;
    } else if (other is List<T>) {
      return other.every((e) => e == targetValue);
    }

    return false;
  }

  @override
  int get hashCode => targetValue.hashCode;

  @override
  String toString() {
    return 'NodeEquals{targetValue: $targetValue}';
  }
}

/// A multiple [Node] matcher that uses object equality (`==` operator).
class MultipleNodesEquals<T> extends NodeMatcher<T> {
  final List<T> targetValues;

  MultipleNodesEquals(this.targetValues);

  @override
  bool matchesValue(T value) => targetValues.any((v) => v == value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is MultipleNodesEquals<T>) {
      return other.targetValues.every((e) => targetValues.contains(e));
    } else if (other is NodeEquals<T>) {
      return targetValues.contains(other.targetValue);
    } else if (other is List<Node<T>>) {
      return other.every((e) => targetValues.contains(e.value));
    } else if (other is Node<T>) {
      return targetValues.contains(other.value);
    } else if (other is List<T>) {
      return other.every((e) => targetValues.contains(e));
    } else if (other is T) {
      return targetValues.contains(other);
    }

    return false;
  }

  static final ListEquality _listEquality = ListEquality();

  @override
  int get hashCode => _listEquality.hash(targetValues);

  @override
  String toString() {
    return 'MultipleNodesEquals{targetValues: $targetValues}';
  }
}

typedef NodesProvider<T> = FutureOr<List<Node<T>>> Function(
  Graph<T> graph,
  Node<T> node,
);

class GraphScanResult<T> {
  final Graph<T> graph;

  final List<T> roots;
  final NodeMatcher<T> targetMatcher;
  final bool findAll;

  final List<List<Node<T>>> paths;

  final Duration time;
  final Duration resolvePathsTime;

  GraphScanResult(
    this.graph,
    this.roots,
    this.targetMatcher,
    this.paths, {
    required this.findAll,
    required this.time,
    required this.resolvePathsTime,
  });

  @override
  String toString() {
    return 'GraphScanResult{graph: $graph, paths: ${paths.length}, findAll: $findAll, time: $time, resolvePathsTime: $resolvePathsTime}';
  }
}

/// A [Graph] Path Scanner.
class GraphScanner<T> {
  /// If `true` searches for all paths.
  final bool findAll;

  GraphScanner({this.findAll = false});

  /// Performs a scan and returns the found node paths.
  ///
  /// Every path starts at [from] and ends at a node that matches [targetMatcher].
  /// See [scanPathsFromMany].
  Future<GraphScanResult<T>> scanPathsFrom(
    T from,
    NodeMatcher<T> targetMatcher, {
    Graph<T>? graph,
    NodesProvider<T>? outputsProvider,
    int? maxExpansion,
  }) async {
    return scanPathsFromMany(
      [from],
      targetMatcher,
      graph: graph,
      outputsProvider: outputsProvider,
      maxExpansion: maxExpansion,
    );
  }

  /// Performs a scan and returns the found node paths.
  ///
  /// Every path starts at one of the nodes in [fromMany] and ends at a node
  /// that matches [targetMatcher] (a path can pass through other matching
  /// nodes). Paths are simple (no repeated node).
  ///
  /// - If [findAll] is `false`, returns one of the shortest paths
  ///   (the scan is a BFS that stops at the 1st matching node).
  /// - If [findAll] is `true`, returns all the paths, grouped by target
  ///   (in [Graph.targets] order) and sorted by length.
  /// - [maxExpansion]: an optional cap for [findAll], the maximum number of
  ///   times a node is expanded while enumerating paths. With a cap only a
  ///   subset of the paths may be returned. Default: `null` (no cap: all paths).
  ///   Note that the number of paths can grow exponentially with the graph size.
  /// - [outputsProvider]: provides the outputs of a node. If [graph] is `null`,
  ///   a new [Graph] is populated with it.
  Future<GraphScanResult<T>> scanPathsFromMany(
    List<T> fromMany,
    NodeMatcher<T> targetMatcher, {
    Graph<T>? graph,
    NodesProvider<T>? outputsProvider,
    int? maxExpansion,
  }) => _scanPathsFromMany(
    fromMany,
    targetMatcher,
    graph: graph,
    outputsProvider: outputsProvider,
    maxExpansion: maxExpansion,
  );

  /// - [shortestOnly]: with [findAll], enumerates only the shortest paths
  ///   (the same as `shortestPaths()` of all the paths, without enumerating
  ///   the longer ones).
  Future<GraphScanResult<T>> _scanPathsFromMany(
    List<T> fromMany,
    NodeMatcher<T> targetMatcher, {
    Graph<T>? graph,
    NodesProvider<T>? outputsProvider,
    int? maxExpansion,
    bool shortestOnly = false,
  }) async {
    var initTime = DateTime.now();

    // The nodes reached by the scan walk:
    final reached = <Node<T>>{};
    // The step of the 1st target found (when not [findAll]):
    GraphNodeStep<T>? targetStep;

    GraphWalkingInstruction<bool>? processTarget(GraphNodeStep<T> step) {
      var node = step.node;
      reached.add(node);

      if (targetMatcher.matchesNode(node)) {
        node.markAsTarget();
        if (!findAll) {
          targetStep = step;
          return GraphWalkingInstruction.stop();
        }
      }
      return null;
    }

    Iterable<Node<T>> outputsOfNode(Node<T> node) => node._outputs;
    Iterable<Node<T>> Function(Node<T> node) outputsOf = outputsOfNode;
    List<Node<T>> fromNodes;

    if (graph == null) {
      graph = Graph<T>();

      if (outputsProvider == null) {
        return GraphScanResult(
          graph,
          fromMany,
          targetMatcher,
          [],
          findAll: findAll,
          time: Duration.zero,
          resolvePathsTime: Duration.zero,
        );
      }

      FutureOr<Iterable<T>> nodeOutputsProvider(
        GraphNodeStep<T> step,
        T nodeValue,
      ) {
        var l = outputsProvider(graph!, graph.node(nodeValue));

        if (l is Future<List<Node<T>>>) {
          return l.then((l) => l.toIterableOfValues());
        } else {
          return l.toIterableOfValues();
        }
      }

      // A BFS: the 1st target found is one of the closest to [fromMany].
      await graph.populateAsync(
        fromMany,
        outputsProvider: nodeOutputsProvider,
        process: processTarget,
        maxExpansion: 1,
        bfs: true,
      );

      fromNodes = graph.getNodes(fromMany).toList();
    } else {
      if (graph.isEmpty && outputsProvider == null) {
        return GraphScanResult(
          graph,
          fromMany,
          targetMatcher,
          [],
          findAll: findAll,
          time: Duration.zero,
          resolvePathsTime: Duration.zero,
        );
      }

      graph.reset();

      GraphWalkNodeOutputsProviderAsync<T> nodeOutputsProvider;
      if (outputsProvider != null) {
        // Paths follow the provided outputs (not necessarily graph edges):
        final provided = <Node<T>, List<Node<T>>>{};
        outputsOf = (node) => provided[node] ?? const [];

        nodeOutputsProvider = (step, node) {
          var l = outputsProvider(graph!, node);
          if (l is Future<List<Node<T>>>) {
            return l.then((l) => provided[node] = l);
          } else {
            return provided[node] = l;
          }
        };
      } else {
        nodeOutputsProvider = (step, node) => node._outputs;
      }

      fromNodes = graph.valuesToNodes(fromMany, createNodes: true).toList();

      // A BFS: the 1st target found is one of the closest to [fromMany].
      await GraphWalker<T>(bfs: true).walkByNodesAsync<bool>(
        fromNodes,
        process: processTarget,
        outputsProvider: nodeOutputsProvider,
      );
    }

    var pathsInitTime = DateTime.now();

    List<List<Node<T>>> paths;
    if (findAll) {
      paths = _enumeratePaths<T>(
        fromNodes,
        graph.targets,
        reached,
        outputsOf,
        maxExpansion: maxExpansion,
        shortestOnly: shortestOnly,
      );
    } else {
      var step = targetStep;
      paths = step == null ? [] : [step.nodePathToRoot.toList()];
    }

    var endTime = DateTime.now();
    var time = endTime.difference(initTime);
    var timePaths = endTime.difference(pathsInitTime);

    return GraphScanResult(
      graph,
      fromMany,
      targetMatcher,
      paths,
      findAll: findAll,
      time: time,
      resolvePathsTime: timePaths,
    );
  }
}

/// Enumerates all the simple paths starting at one of the [starts] and
/// ending at one of the [ends], following [nextOf].
///
/// - [reached]: the nodes reachable from [starts] (following [nextOf]).
///   Only nodes in [reached] that lead to an end node are expanded.
/// - [maxExpansion]: an optional cap of times a node is expanded.
/// - [shortestOnly]: only the shortest paths (of all the [ends]).
/// - Returns the paths grouped by end node (in [ends] order), each group
///   sorted by length (stable: ties keep the enumeration order, a DFS).
List<List<Node<T>>> _enumeratePaths<T>(
  Iterable<Node<T>> starts,
  List<Node<T>> ends,
  Set<Node<T>> reached,
  Iterable<Node<T>> Function(Node<T> node) nextOf, {
  int? maxExpansion,
  bool shortestOnly = false,
}) {
  if (ends.isEmpty) return [];

  if (shortestOnly) {
    // The distance from the [starts] (a BFS). Every node in a shortest path
    // (of length `minDistance + 1`) is at distance `i` from the [starts] at
    // position `i`, so only edges to the next BFS layer are followed, and
    // only the closest [ends] are kept.
    final distances = <Node<T>, int>{for (var s in starts) s: 0};
    final queue = ListQueue<Node<T>>.of(distances.keys);
    while (queue.isNotEmpty) {
      var node = queue.removeFirst();
      var distance = distances[node]! + 1;
      for (var next in nextOf(node)) {
        if (!distances.containsKey(next)) {
          distances[next] = distance;
          queue.add(next);
        }
      }
    }

    var minDistance = ends.map((e) => distances[e]).nonNulls.minOrNull;
    if (minDistance == null) return [];

    ends = ends.where((e) => distances[e] == minDistance).toList();

    final allNextOf = nextOf;
    nextOf = (node) {
      var nextDistance = distances[node]! + 1;
      return allNextOf(node).where((e) => distances[e] == nextDistance);
    };
  }

  // The reverse of [nextOf] over the [reached] nodes:
  final previousOf = <Node<T>, List<Node<T>>>{};
  for (var node in reached) {
    for (var next in nextOf(node)) {
      (previousOf[next] ??= <Node<T>>[]).add(node);
    }
  }

  // The nodes that lead to an end node:
  final leadsToEnd = <Node<T>>{...ends};
  final queue = ListQueue<Node<T>>.of(ends);
  while (queue.isNotEmpty) {
    var node = queue.removeFirst();
    for (var previous in previousOf[node] ?? const []) {
      if (leadsToEnd.add(previous)) {
        queue.add(previous);
      }
    }
  }

  final pathsByEnd = <Node<T>, List<List<Node<T>>>>{
    for (var e in ends) e: <List<Node<T>>>[],
  };

  final expansions = <Node<T>, int>{};
  final path = <Node<T>>[];
  final onPath = <Node<T>>{};
  final iterators = <Iterator<Node<T>>>[];

  void enter(Node<T> node) {
    path.add(node);
    onPath.add(node);

    pathsByEnd[node]?.add(path.toList(growable: false));

    var count = expansions.increment(node);
    var expand = maxExpansion == null || count <= maxExpansion;
    iterators.add(expand ? nextOf(node).iterator : const <Never>[].iterator);
  }

  // Iterative DFS (avoids deep recursion on long paths):
  for (var start in starts.toSet()) {
    if (!leadsToEnd.contains(start)) continue;

    enter(start);

    while (iterators.isNotEmpty) {
      var it = iterators.last;
      if (it.moveNext()) {
        var next = it.current;
        if (leadsToEnd.contains(next) && !onPath.contains(next)) {
          enter(next);
        }
      } else {
        iterators.removeLast();
        onPath.remove(path.removeLast());
      }
    }
  }

  return [for (var e in ends) ...pathsByEnd[e]!.sortedPathsByLength()];
}

/// Interface for an element that have [input] and [output] nodes.
/// See [Graph] and [Node].
abstract class NodeIO<T> {
  /// Returns the input [Node]s
  List<Node<T>> get inputs;

  /// Returns `true` if [inputs] contains a [Node] with [nodeValue]
  bool containsInput(T nodeValue);

  /// Adds an unique input node with [nodeValue].
  /// Returns the added [Node] if not add yet.
  Node<T>? addInput(T nodeValue);

  /// Returns the output [Node]s
  List<Node<T>> get outputs;

  /// Returns `true` if [outputs] contains a [Node] with [nodeValue]
  bool containsOutput(T nodeValue);

  /// Adds an unique output node with [nodeValue].
  /// Returns the added [Node] if not add yet.
  Node<T>? addOutput(T nodeValue);

  /// Resets this element for a path scan.
  void reset();
}

/// A [Graph] of [Node]s.
///
/// - Can be generated by [GraphScanner.searchPaths].
class Graph<T> implements NodeIO<T> {
  /// All nodes in this graph.
  final Map<T, Node<T>> _allNodes = {};

  /// Returns all the [Node]s in this graph.
  Iterable<Node<T>> get allNodes => _allNodes.values;

  /// Returns all the [Node.value]s in this graph.
  Iterable<T> get allNodesValues => _allNodes.values.map((e) => e.value);

  /// Returns `true` this graph is empty.
  bool get isEmpty => _allNodes.isEmpty;

  /// Returns `true` this graph NOT is empty.
  bool get isNotEmpty => _allNodes.isNotEmpty;

  /// Returns the total amount of [Node]s in this graph.
  int get length => _allNodes.length;

  Graph();

  /// Creates a [Graph] from [json].
  factory Graph.fromJson(
    Map<String, dynamic> json, {
    T Function(GraphStep<T>? previousStep, String key)? nodeValueMapper,
  }) {
    if (nodeValueMapper == null) {
      if (T == String) {
        nodeValueMapper = (s, k) => k.toString() as T;
      } else {
        nodeValueMapper = (s, k) => k as T;
      }
    }

    var allEntries = GraphWalker.extractAllEntries(json);
    var maxExpansion = allEntries.length + 1;

    final graph = Graph<T>();

    // The JSON keys are always `String`s, but the node values are `T`.
    // Looking up a JSON node by its node value only works when `T` is
    // `String`, so track which JSON key each node value was mapped from,
    // per parent (`null` for the roots).
    final jsonKeys = <T?, Map<T, String>>{};

    T mapKey(GraphStep<T>? step, T? parentValue, String key) {
      var value = nodeValueMapper!(step, key);
      (jsonKeys[parentValue] ??= <T, String>{})[value] = key;
      return value;
    }

    graph.populate(
      json.keys.map((k) => mapKey(null, null, k)).toList(),
      maxExpansion: maxExpansion,
      nodeProvider: (step, nodeValue) {
        var node = graph.node(nodeValue);

        var parentValue = step.parentValue;
        var parentNode = graph.getNode(parentValue);
        Map parentJsonNode = parentNode?.attachment ?? json;
        var jsonKey = jsonKeys[parentValue]?[nodeValue];
        var jsonNode = parentJsonNode[jsonKey ?? nodeValue];

        var nodeAttachment = node.attachment;
        if (nodeAttachment == null) {
          if (jsonNode != null && (jsonNode is! Map && jsonNode is! String)) {
            throw StateError("Invalid node type> $nodeValue: $jsonNode");
          }
          node.attachment = jsonNode;
        } else if (!identical(jsonNode, nodeAttachment)) {
          if (jsonNode is Map) {
            if (nodeAttachment is Map) {
              nodeAttachment.addAll(jsonNode);
            } else if (nodeAttachment is String) {
              node.attachment = jsonNode;
            }
          } else if (jsonNode is String) {
            if (jsonNode != jsonKey &&
                jsonNode != nodeValue.toString() &&
                nodeValueMapper!(step, jsonNode) != nodeValue) {
              throw StateError(
                "Invalid node reference: $nodeValue -> $jsonNode",
              );
            }
          } else if (jsonNode != null) {
            throw StateError(
              "Invalid node type (graph)> $nodeValue: $jsonNode",
            );
          }
        }

        return node;
      },
      outputsProvider: (step, nodeValue) {
        var jsonNode = graph.getNode(nodeValue)?.attachment;
        if (jsonNode is! Map || jsonNode.isEmpty) return null;
        var outputs = jsonNode.keys
            .map((k) => mapKey(step, nodeValue, k.toString()))
            .toList();
        return outputs;
      },
    );

    return graph;
  }

  /// Returns all the leaves of this graph (nodes without outputs)
  List<Node<T>> get allLeaves =>
      _allNodes.values.where((e) => e.isLeaf).toList();

  /// Alias to [allNodes].
  @override
  List<Node<T>> get inputs => allNodes.toList();

  /// Returns `true` if contains a [Node] with [nodeValue].
  /// See [allNodes]
  @override
  bool containsInput(T nodeValue) => _allNodes.containsKey(nodeValue);

  /// Adds a [Node] to the graph.
  /// Alias to [node].
  @override
  Node<T>? addInput(T nodeValue) {
    if (!_allNodes.containsKey(nodeValue)) {
      return node(nodeValue);
    }
    return null;
  }

  /// Alias to [allNodes].
  @override
  List<Node<T>> get outputs => allNodes.toList();

  /// Returns `true` if contains a [Node] with [nodeValue].
  /// See [allNodes]
  @override
  bool containsOutput(T nodeValue) => _allNodes.containsKey(nodeValue);

  /// Adds a [Node] to the graph.
  /// Alias to [node].
  @override
  Node<T>? addOutput(T nodeValue) => addInput(nodeValue);

  /// Incremented on every structural change (new node or new edge).
  /// Invalidates the cached [Node.shortestPathToRoot] and [Node.depth].
  int _version = 0;

  void _changed() => _version++;

  /// `true` if an edge links a [Node] that is not in [_allNodes]
  /// (e.g. created with the [Node] constructor), so the cached
  /// [_resolveRootDistances] can't be used.
  bool _hasForeignNodes = false;

  Map<Node<T>, int>? _rootDistances;
  int _rootDistancesVersion = -1;

  /// The distance (in edges) from the closest root to each node
  /// (absent for nodes not reachable from a root).
  /// A multi-source BFS from the [roots], cached until the graph changes.
  Map<Node<T>, int> _resolveRootDistances() {
    var distances = _rootDistances;
    if (distances != null && _rootDistancesVersion == _version) {
      return distances;
    }

    _rootDistances = distances = _computeRootDistances(_allNodes.values);
    _rootDistancesVersion = _version;
    return distances;
  }

  /// Returns a [Node] with [value] or creates it.
  Node<T> node(T value) {
    var node = _allNodes[value];
    if (node == null) {
      _allNodes[value] = node = Node(value, graph: this);
      _changed();
    }
    return node;
  }

  /// Returns a [Node] with [value] or `null` if not present.
  Node<T>? getNode(T? value) {
    if (value == null) return null;
    return _allNodes[value];
  }

  /// Returns a list of [Node] with [values] or `null` for absent nodes.
  Iterable<Node<T>?> getNodesNullable(Iterable<T> values) =>
      values.map((v) => getNode(v));

  /// Returns a list of [Node] with [values] present.
  Iterable<Node<T>> getNodes(Iterable<T> values) =>
      values.map((v) => getNode(v)).nonNulls;

  /// Alias to [getNode].
  Node<T>? operator [](T value) => getNode(value);

  /// Maps [values] to [Node]s in this graph.
  /// - If [createNodes] is `false` will throw a [StateError] if the node is not present in this graph.
  Iterable<Node<T>> valuesToNodes(
    Iterable<T> values, {
    bool createNodes = false,
  }) {
    if (createNodes) {
      return values.map((value) => node(value));
    } else {
      return values.map(
        (value) =>
            getNode(value) ??
            (throw StateError("Can't find node with value: $value")),
      );
    }
  }

  /// Returns a [Node] with [value] or creates it as always root.
  Node<T> root(T value) {
    var node = _allNodes[value];
    if (node == null) {
      _allNodes[value] = node = Node.root(value, graph: this);
      _changed();
    }
    return node;
  }

  /// Returns a list of root nodes (without inputs).
  List<Node<T>> get roots =>
      _allNodes.values.where((e) => e.isRoot).toList(growable: false);

  /// Returns a list of root values (without inputs).
  List<T> get rootValues => roots.map((e) => e.value).toList(growable: false);

  /// Returns a list of nodes market as targets.
  List<Node<T>> get targets =>
      _allNodes.values.where((e) => e.isTarget).toList(growable: false);

  /// Resets this graph and all its [Node]s for a path scan.
  /// See [Node.reset].
  @override
  void reset() {
    for (var node in _allNodes.values) {
      node.reset();
    }
  }

  /// Disposes this graphs, cleaning internal references to this [Graph] from [Node]s.
  void dispose() {
    var nodes = _allNodes.values.toList(growable: false);

    _allNodes.clear();
    _changed();
    _rootDistances = null;

    for (var e in nodes) {
      e.disposeGraph();
    }
  }

  /// Returns a [Map] representation of this graph.
  Map<K, dynamic> toTree<K>({
    K Function(T value)? keyCast,
    bool sortByInputDependency = false,
    bool bfs = false,
  }) {
    var rootValues = roots.map((e) => e.value).toList();
    return toTreeFrom<K>(
      rootValues,
      keyCast: keyCast,
      sortByInputDependency: sortByInputDependency,
      bfs: bfs,
    );
  }

  /// Returns a [Map] representation of this graph from [roots].
  Map<K, dynamic> toTreeFrom<K>(
    List<T> roots, {
    K Function(T value)? keyCast,
    bool sortByInputDependency = false,
    bool bfs = false,
  }) {
    return GraphWalker<T>(
      sortByInputDependency: sortByInputDependency,
      bfs: bfs,
    ).toTreeFrom<K>(
      roots,
      nodeProvider: (s, v) => getNode(v),
      outputsProvider: (s, n) => n._outputs,
      keyCast: keyCast == null ? null : (s, v) => keyCast(v),
    );
  }

  /// Returns a JSON representation of this graph.
  Map<String, dynamic> toJson({bool sortByInputDependency = false}) =>
      toTree<String>(sortByInputDependency: sortByInputDependency);

  /// Scans and returns the paths from [root] to [target].
  /// Every path starts at [root] (that doesn't need to be a [roots] node).
  /// - [findAll]: if `true` returns all the paths, otherwise one of the shortest.
  /// - [maxExpansion]: an optional cap for [findAll] (default: no cap).
  /// - See [GraphScanner.scanPathsFromMany].
  Future<GraphScanResult<T>> scanPathsFrom(
    T root,
    T target, {
    bool findAll = false,
    int? maxExpansion,
  }) => GraphScanner<T>(findAll: findAll)._scanPathsFromMany(
    [root],
    NodeEquals(target),
    graph: this,
    maxExpansion: maxExpansion,
  );

  /// Scans and returns the paths from [roots] to [targets].
  /// Every path starts at one of the [roots] (any node, not only the graph [roots]).
  /// - [findAll]: default `true` if there's more than one root or target.
  /// - [maxExpansion]: an optional cap for [findAll] (default: no cap).
  /// - See [GraphScanner.scanPathsFromMany].
  Future<GraphScanResult<T>> scanPathsFromMany(
    List<T> roots,
    List<T> targets, {
    bool? findAll,
    int? maxExpansion,
  }) => _scanPathsFromMany(
    roots,
    targets,
    findAll: findAll,
    maxExpansion: maxExpansion,
  );

  Future<GraphScanResult<T>> _scanPathsFromMany(
    List<T> roots,
    List<T> targets, {
    bool? findAll,
    int? maxExpansion,
    bool shortestOnly = false,
  }) {
    findAll ??= roots.length > 1 || targets.length > 1;
    return GraphScanner<T>(findAll: findAll)._scanPathsFromMany(
      roots,
      NodeMatcher.eq(targets),
      graph: this,
      maxExpansion: maxExpansion,
      shortestOnly: shortestOnly,
    );
  }

  /// Scans and returns the paths from [roots] to [Node]s matching [targetMatcher].
  /// Every path starts at one of the [roots] (any node, not only the graph [roots]).
  /// - [maxExpansion]: an optional cap for [findAll] (default: no cap).
  /// - See [GraphScanner.scanPathsFromMany].
  Future<GraphScanResult<T>> scanPathsMatching(
    List<T> roots,
    NodeMatcher<T> targetMatcher, {
    bool findAll = true,
    int? maxExpansion,
  }) => GraphScanner<T>(findAll: findAll)._scanPathsFromMany(
    roots,
    targetMatcher,
    graph: this,
    maxExpansion: maxExpansion,
  );

  /// Returns the shortest paths from [root] to [target].
  /// - [findAll]: if `true` returns all the shortest paths,
  ///   otherwise one of them (a BFS).
  ///   (Only the shortest paths are enumerated, not all the paths.)
  Future<List<List<Node<T>>>> shortestPathsFrom(
    T root,
    T target, {
    bool findAll = false,
  }) async {
    var result = await GraphScanner<T>(findAll: findAll)._scanPathsFromMany(
      [root],
      NodeEquals(target),
      graph: this,
      shortestOnly: true,
    );
    return result.paths.shortestPaths();
  }

  /// Returns the shortest paths from [roots] to [targets].
  /// - See [shortestPathsFrom].
  Future<List<List<Node<T>>>> shortestPathsFromMany(
    List<T> roots,
    List<T> targets, {
    bool findAll = false,
  }) async {
    var result = await _scanPathsFromMany(
      roots,
      targets,
      findAll: findAll,
      shortestOnly: true,
    );
    return result.paths.shortestPaths();
  }

  /// Returns the shortest paths from [roots] to [Nodes] matching [targetMatcher].
  /// - See [shortestPathsFrom].
  Future<List<List<Node<T>>>> shortestPathsMatching(
    List<T> roots,
    NodeMatcher<T> targetMatcher, {
    bool findAll = true,
  }) async {
    var result = await GraphScanner<T>(
      findAll: findAll,
    )._scanPathsFromMany(roots, targetMatcher, graph: this, shortestOnly: true);
    return result.paths.shortestPaths();
  }

  /// Returns all the paths from [roots] to [allLeaves].
  /// The number of paths can grow exponentially with the graph size:
  /// see [scanPathsFromMany] (`maxExpansion`).
  Future<List<List<Node<T>>>> get allPaths async {
    var roots = this.roots.toListOfValues();
    var leaves = allLeaves.toListOfValues();

    var result = await scanPathsFromMany(roots, leaves, findAll: true);
    return result.paths;
  }

  /// Returns all the shortest paths from [roots] to [allLeaves].
  /// (Only the shortest paths are enumerated, not all the paths.)
  Future<List<List<Node<T>>>> get shortestPaths async {
    var roots = this.roots.toListOfValues();
    var leaves = allLeaves.toListOfValues();

    var result = await _scanPathsFromMany(
      roots,
      leaves,
      findAll: true,
      shortestOnly: true,
    );
    return result.paths.shortestPaths();
  }

  /// Populates this graph with [entries].
  /// - [inputsProvider]: provides the inputs of an entry.
  /// - [outputsProvider]: provides the outputs of an entry.
  R? populate<R>(
    Iterable<T> entries, {
    GraphWalkNodeProvider<T>? nodeProvider,
    GraphWalkOutputsProvider<T>? inputsProvider,
    GraphWalkOutputsProvider<T>? outputsProvider,
    GraphWalkNodeProcessor<T, R>? process,
    int maxExpansion = 3,
    bool bfs = false,
  }) {
    nodeProvider ??= (s, e) => node(e);
    inputsProvider ??= (s, e) => [];
    outputsProvider ??= (s, e) => [];

    var graphWalker = GraphWalker<T>(maxExpansion: maxExpansion, bfs: bfs);

    return graphWalker.walk<R>(
      entries,
      nodeProvider: nodeProvider,
      outputsProvider: outputsProvider,
      process: (step) {
        var node = step.node;
        var nodeValue = node.value;

        var outputs = outputsProvider!(step, nodeValue) ?? [];
        for (var child in outputs) {
          node.addOutput(child);
        }

        var inputs = inputsProvider!(step, nodeValue) ?? [];
        for (var dep in inputs) {
          node.addInput(dep);
        }

        if (process == null) {
          return null;
        }

        var ret = process(step);
        return ret;
      },
    );
  }

  Future<R?> populateAsync<R>(
    Iterable<T> entries, {
    GraphWalkNodeProviderAsync<T>? nodeProvider,
    GraphWalkOutputsProviderAsync<T>? inputsProvider,
    GraphWalkOutputsProviderAsync<T>? outputsProvider,
    GraphWalkNodeProcessorAsync<T, R>? process,
    int maxExpansion = 3,
    bool bfs = false,
  }) async {
    nodeProvider ??= (s, e) => node(e);
    inputsProvider ??= (s, e) => [];
    outputsProvider ??= (s, e) => [];

    var graphWalker = GraphWalker<T>(maxExpansion: maxExpansion, bfs: bfs);

    return graphWalker.walkAsync<R>(
      entries,
      nodeProvider: nodeProvider,
      outputsProvider: outputsProvider,
      process: (step) async {
        var node = step.node;
        var nodeValue = node.value;

        var outputs = await outputsProvider!(step, nodeValue) ?? [];
        for (var child in outputs) {
          node.addOutput(child);
        }

        var inputs = await inputsProvider!(step, nodeValue) ?? [];
        for (var dep in inputs) {
          node.addInput(dep);
        }

        if (process == null) {
          return null;
        }

        var ret = await process(step);
        return ret;
      },
    );
  }

  /// Walk the graph nodes outputs starting [from] and stopping at [stopMatcher] (if provided).
  R? walkOutputsFrom<R>(
    Iterable<T> from,
    GraphWalkNodeProcessor<T, R> process, {
    NodeMatcher<T>? stopMatcher,
    bool processRoots = true,
    int maxExpansion = 1,
    bool bfs = false,
  }) =>
      GraphWalker<T>(
        stopMatcher: stopMatcher,
        processRoots: processRoots,
        maxExpansion: maxExpansion,
        bfs: bfs,
      ).walkByNodes<R>(
        valuesToNodes(from),
        process: process,
        outputsProvider: (step, node) => node._outputs,
      );

  /// Walk the graph nodes inputs starting [from] and stopping at [stopMatcher] (if provided).
  R? walkInputsFrom<R>(
    Iterable<T> from,
    GraphWalkNodeProcessor<T, R> process, {
    NodeMatcher<T>? stopMatcher,
    bool processRoots = true,
    int maxExpansion = 1,
    bool bfs = false,
  }) =>
      GraphWalker<T>(
        stopMatcher: stopMatcher,
        processRoots: processRoots,
        maxExpansion: maxExpansion,
        bfs: bfs,
      ).walkByNodes<R>(
        valuesToNodes(from),
        process: process,
        outputsProvider: (step, node) => node._inputs,
      );

  /// Walk the graph nodes outputs starting [from] and stopping at [stopMatcher] (if provided).
  List<Node<T>> walkOutputsOrderFrom<R>(
    Iterable<T> from, {
    NodeMatcher<T>? stopMatcher,
    bool processRoots = true,
    int maxExpansion = 1,
    bool expandSideRoots = false,
    bool sortByInputDependency = false,
    bool bfs = false,
  }) =>
      GraphWalker<T>(
        stopMatcher: stopMatcher,
        processRoots: processRoots,
        maxExpansion: maxExpansion,
        sortByInputDependency: sortByInputDependency,
        bfs: bfs,
      ).walkOrder(
        from.toList(),
        nodeProvider: (step, nodeValue) => getNode(nodeValue),
        outputsProvider: (step, node) => node._outputs,
        expandSideBranches: expandSideRoots,
      );

  /// Walk the graph nodes outputs starting [from] and stopping at [stopMatcher] (if provided).
  List<Node<T>> walkInputsOrderFrom<R>(
    Iterable<T> from, {
    NodeMatcher<T>? stopMatcher,
    bool processRoots = true,
    int maxExpansion = 1,
    bool sortByInputDependency = false,
    bool bfs = false,
  }) =>
      GraphWalker<T>(
        stopMatcher: stopMatcher,
        processRoots: processRoots,
        maxExpansion: maxExpansion,
        sortByInputDependency: sortByInputDependency,
        bfs: bfs,
      ).walkOrder(
        from.toList(),
        nodeProvider: (step, nodeValue) => node(nodeValue),
        outputsProvider: (step, node) => node._inputs,
      );
}

/// A [Graph] [Node].
class Node<T> extends NodeIO<T> {
  /// The [Graph] of this node.
  Graph<T>? _graph;

  /// The node [value].
  final T value;

  /// The output nodes.
  ///
  /// A [List] of unique elements. See [_addOutputNode].
  /// - Root nodes have an unmodifiable empty list.
  /// - Avoid the use of [Set] to reduce memory usage,
  ///   as small lists won't benefit from a [Set].
  final List<Node<T>> _outputs = [];

  /// The input nodes.
  ///
  /// A [List] of unique elements. See [_addInputNode].
  /// - Root nodes have an unmodifiable empty list.
  /// - Avoid the use of [Set] to reduce memory usage,
  ///   as small lists won't benefit from a [Set].
  final List<Node<T>> _inputs;

  /// `true` if created with [Node.root].
  final bool _alwaysRoot;

  Node(this.value, {this._graph}) : _inputs = [], _alwaysRoot = false;

  Node.root(this.value, {this._graph})
    : _inputs = List.unmodifiable([]),
      _alwaysRoot = true;

  Graph<T>? get graph => _graph;

  /// Disposes the [graph].
  void disposeGraph() {
    var g = _graph;
    _graph = null;
    g?.dispose();
  }

  /// Temporary attachment to associate with this node.
  /// See [reset] and [Graph.reset].
  dynamic attachment;

  bool _target = false;

  /// Marks this node as a target.
  void markAsTarget() => _target = true;

  /// If `true` matches a target in the scan.
  /// See [NodeMatcher.matches].
  bool get isTarget => _target;

  /// Returns `true` if it's a leaf node (no outputs).
  bool get isLeaf => _outputs.isEmpty;

  /// Return the outputs of this node.
  @override
  List<Node<T>> get outputs => _outputs;

  /// Return the outputs values of this node.
  List<T> get outputsValues => _outputs.toListOfValues();

  /// Returns `true` if [outputs] contains [node].
  bool containsOutputNode(Node<T> node) => _outputs.contains(node);

  /// Returns `true` if [outputs] contains a [Node] with [nodeValue].
  @override
  bool containsOutput(T nodeValue) {
    for (var node in _outputs) {
      if (node.value == nodeValue) {
        return true;
      }
    }
    return false;
  }

  /// Add a [node] to the [outputs] if it has not been added yet.
  /// Returns `true` if it was added without duplication.
  Node<T>? _addOutputNode(Node<T> node, {bool addInput = true}) {
    if (node == this) return null;

    if (!containsOutputNode(node)) {
      _outputs.add(node);
      _edgeAdded(node);

      if (addInput) {
        node._addInputNode(this, addOutput: false);
      }

      return node;
    }

    return null;
  }

  /// Add a [node] to the [outputs] if it has not been added yet.
  /// - Resolves [nodeValue] to a [Node] using [graph].
  /// - Returns the `Node` if it was added without duplication.
  /// - Throws a [StateError] if [graph] is `null` when trying to resolve [nodeValue] to a [Node].
  @override
  Node<T>? addOutput(T nodeValue) {
    if (nodeValue == value) return null;

    if (!containsOutput(nodeValue)) {
      var node = _resolveNode(nodeValue);
      return _addOutputNode(node);
    }

    return null;
  }

  /// Gets a [Node] in the [outputs] or add it.
  /// - Resolves [nodeValue] to a [Node] using [graph].
  /// - Returns the [Node].
  /// - Throws a [StateError] if [graph] is `null` when trying to resolve [nodeValue] to a [Node].
  Node<T> getOrAddOutput(T nodeValue) {
    if (nodeValue == value) return this;

    if (!containsOutput(nodeValue)) {
      var node = _resolveNode(nodeValue);
      return _addOutputNode(node) ??
          (throw StateError(
            "Error adding output node `$nodeValue` to `$value`",
          ));
    }

    var node = _resolveNode(nodeValue);
    assert(_outputs.contains(node));
    return node;
  }

  /// Gets a [Node] in the [outputs].
  /// - Resolves [nodeValue] to a [Node] using [graph].
  /// - Returns the [Node] or `null` if not present.
  /// - Throws a [StateError] if [graph] is `null` when trying to resolve [nodeValue] to a [Node].
  Node<T>? getOutput(T nodeValue) {
    if (nodeValue == value) return this;

    var node = _outputs.firstWhereOrNull((e) => e.value == nodeValue);
    return node;
  }

  /// Resolves [nodeValue] to a [Node] using [graph].
  /// - Throws a [StateError] if [graph] is `null` when trying to resolve [nodeValue] to a [Node].
  Node<T> _resolveNode(T nodeValue) {
    final graph = this.graph;
    if (graph == null) {
      throw StateError(
        "Can't resolve `nodeValue` to a node (null `graph`): $nodeValue",
      );
    }

    var node = graph.node(nodeValue);
    return node;
  }

  /// Returns `true` if it's a root node (no inputs).
  bool get isRoot => _inputs.isEmpty;

  /// Returns `true` if this node was created with [Node.root] (can't have inputs).
  bool get isAlwaysRoot => _alwaysRoot;

  /// Return the inputs of this node.
  @override
  List<Node<T>> get inputs => _inputs;

  /// Return the inputs values of this node.
  List<T> get inputsValues => _inputs.toListOfValues();

  /// Returns `true` if [node] is a [inputs].
  bool containsInputNode(Node<T> node) => _inputs.contains(node);

  /// Returns `true` if [nodeValue] is a [inputs].
  @override
  bool containsInput(T nodeValue) {
    for (var node in _inputs) {
      if (node.value == nodeValue) {
        return true;
      }
    }
    return false;
  }

  /// Add a [node] to the [inputs] if it has not been added yet.
  /// - Returns `true` if it was added without duplication.
  Node<T>? _addInputNode(Node<T> node, {bool addOutput = true}) {
    if (node == this) return null;

    if (!containsInputNode(node)) {
      _inputs.add(node);
      _edgeAdded(node);

      if (addOutput) {
        node._addOutputNode(this, addInput: false);
      }

      return node;
    }
    return null;
  }

  /// Add a [node] to the [inputs] if it has not been added yet.
  /// - Resolves [nodeValue] to a [Node] using [graph].
  /// - Returns `true` if it was added without duplication.
  /// - Throws a [StateError] if [graph] is `null` when trying to resolve [nodeValue] to a [Node].
  @override
  Node<T>? addInput(T nodeValue) {
    if (nodeValue == value) return null;

    if (!containsInput(nodeValue)) {
      var node = _resolveNode(nodeValue);
      return _addInputNode(node);
    }

    return null;
  }

  /// Gets a [Node] in the [inputs] or add it.
  /// - Resolves [nodeValue] to a [Node] using [graph].
  /// - Returns the [Node].
  /// - Throws a [StateError] if [graph] is `null` when trying to resolve [nodeValue] to a [Node].
  Node<T> getOrAddInput(T nodeValue) {
    if (nodeValue == value) return this;

    if (!containsInput(nodeValue)) {
      var node = _resolveNode(nodeValue);
      return _addInputNode(node) ??
          (throw StateError(
            "Error adding input node `$nodeValue` to `$value`",
          ));
    }

    var node = _resolveNode(nodeValue);
    assert(_inputs.contains(node));
    return node;
  }

  /// Gets a [Node] in the [inputs].
  /// - Resolves [nodeValue] to a [Node] using [graph].
  /// - Returns the [Node] or `null` if not present.
  /// - Throws a [StateError] if [graph] is `null` when trying to resolve [nodeValue] to a [Node].
  Node<T>? getInput(T nodeValue) {
    if (nodeValue == value) return this;

    var node = _inputs.firstWhereOrNull((e) => e.value == nodeValue);
    return node;
  }

  /// Returns `true` if [targetValue] is an input of this node.
  bool isInput(T targetValue) => isInputNode(_resolveNode(targetValue));

  /// Returns `true` if [target] is an input of this node.
  bool isInputNode(Node<T> target) {
    if (this == target) return false;

    var graphWalker = GraphWalker<T>(stopMatcher: NodeEquals<T>(target.value));

    return graphWalker.walkByNodes<bool>(
          [this],
          outputsProvider: (step, node) => node._inputs,
          process: (step) =>
              step.node == target ? GraphWalkingInstruction.result(true) : null,
        ) ??
        false;
  }

  /// Returns `true` if [targetValue] is an output of this node.
  bool isOutput(T targetValue) => isOutputNode(_resolveNode(targetValue));

  /// Returns `true` if [target] is an output of this node.
  bool isOutputNode(Node<T> target) {
    if (this == target) return false;

    var graphWalker = GraphWalker<T>(stopMatcher: NodeEquals<T>(target.value));

    return graphWalker.walkByNodes<bool>(
          [this],
          outputsProvider: (step, node) => node._outputs,
          process: (step) =>
              step.node == target ? GraphWalkingInstruction.result(true) : null,
        ) ??
        false;
  }

  /// Returns all the [outputs] in depth, scanning all the [outputs] of [outputs].
  List<Node<T>> outputsInDepth({
    int? maxDepth,
    bool bfs = false,
    Iterable<Node<T>>? ignore,
  }) {
    final allNodes = <Node<T>>[];

    var initialProcessedNodes = ignore != null
        ? Map.fromEntries(ignore.map((e) => MapEntry(e, 1)))
        : null;

    var graphWalker = GraphWalker<T>(
      processRoots: false,
      bfs: bfs,
      initialProcessedNodes: initialProcessedNodes,
    );

    graphWalker.walkByNodes<bool>(
      [this],
      outputsProvider: (step, node) => node._outputs,
      process: (step) {
        allNodes.add(step.node);
        return null;
      },
      maxDepth: maxDepth,
    );

    return allNodes;
  }

  /// Returns all the [inputs] in depth, scanning all the [inputs] of [inputs].
  List<Node<T>> inputsInDepth({
    int? maxDepth,
    bool bfs = false,
    Iterable<Node<T>>? ignore,
  }) {
    final allNodes = <Node<T>>[];

    var initialProcessedNodes = ignore != null
        ? Map.fromEntries(ignore.map((e) => MapEntry(e, 1)))
        : null;

    var graphWalker = GraphWalker<T>(
      processRoots: false,
      bfs: bfs,
      initialProcessedNodes: initialProcessedNodes,
    );

    graphWalker.walkByNodes<bool>(
      [this],
      outputsProvider: (step, node) => node._inputs,
      process: (step) {
        allNodes.add(step.node);
        return null;
      },
      maxDepth: maxDepth,
    );

    return allNodes;
  }

  List<Node<T>> roots({bool bfs = false}) {
    final roots = <Node<T>>[];

    var graphWalker = GraphWalker<T>(processRoots: false, bfs: bfs);

    graphWalker.walkByNodes<bool>(
      [this],
      outputsProvider: (step, node) => node._inputs,
      process: (step) {
        var node = step.node;
        if (node.isRoot) {
          roots.add(node);
        }
        return null;
      },
    );

    return roots;
  }

  List<Node<T>> outputsInDepthIntersection(Node<T>? other) {
    var l2 = other?.outputsInDepth();
    if (l2 == null || l2.isEmpty) return [];

    var l1 = outputsInDepth();
    return l1.intersection(l2);
  }

  List<Node<T>> inputsInDepthIntersection(Node<T>? other) {
    var l2 = other?.inputsInDepth();
    if (l2 == null || l2.isEmpty) return [];

    var l1 = inputsInDepth();
    return l1.intersection(l2);
  }

  /// Return the list of side roots after this [Node].
  /// - A side root is a root [Node] that is not common to the [roots] of this [Node],
  ///   but is common to the in depth [outputs]'s [roots] of this [Node].
  ///   It's the [complement] of [roots] and [outputsInDepth]'s [roots].
  List<Node<T>> sideRoots({int? maxDepth}) {
    var myRoots = roots();

    var outputs = outputsInDepth(maxDepth: maxDepth).toList(growable: false);

    var outputsRoots = outputs
        .expand((e) => e.roots())
        .toSet()
        .toList(growable: false);

    var complement = myRoots.complement(outputsRoots, includeThis: false);
    complement.remove(this);

    return complement;
  }

  /// Returns all the dependencies.
  /// - A dependency [Node] is all the [inputs] of all the in depth [outputs] (respecting [maxDepth]).
  /// - If [includeThisInputs] is `true`, also include the [inputs] of this [Node],
  ///   other wise will use only the [inputs] of the in depth [outputs].
  List<Node<T>> dependencies({
    bool includeThisInputs = true,
    int? maxDepth,
    Iterable<Node<T>>? ignore,
  }) {
    ignore = ignore is List<Node<T>>
        ? ignore
        : (ignore?.toList() ?? <Node<T>>[]);

    Iterable<Node<T>> outputs;
    if (maxDepth != null && maxDepth == 1) {
      outputs = ignore.isNotEmpty
          ? this.outputs.where((e) => !ignore!.contains(e))
          : this.outputs;
    } else {
      outputs = outputsInDepth(maxDepth: maxDepth, ignore: ignore);
    }

    var outputsDependencies = outputs
        .where((e) => e != this)
        .expand((e) => e.inputsInDepth(ignore: ignore));

    var dependencies = <Node<T>>[
      if (includeThisInputs) ...inputsInDepth(),
      ...outputsDependencies,
    ].where((e) => e != this).toSet().toList();

    return dependencies;
  }

  /// Returns all the missing [dependencies] not present in the [knownDependencies] parameter.
  List<Node<T>> missingDependencies(
    Iterable<Node<T>> knownDependencies, {
    int? maxDepth,
  }) {
    knownDependencies = knownDependencies is List<Node<T>>
        ? knownDependencies
        : knownDependencies.toList();

    var allDependencies = dependencies(
      ignore: knownDependencies,
      maxDepth: maxDepth,
    );

    var missingDependencies = allDependencies
        .where((e) => !knownDependencies.contains(e))
        .toList();

    return missingDependencies;
  }

  /// Returns `true` if [target] is an input in the [shortestPathToRoot].
  bool isInputInShortestPathToRoot(Node target) =>
      shortestPathToRoot.contains(target);

  /// The node depth from root: the length of [shortestPathToRoot]
  /// (`1` for a root node).
  /// - Throws a [StateError] if no root reaches this node (e.g. a pure cycle).
  int get depth {
    var path = _validShortestPathToRoot;
    if (path != null) return path.length;

    var distances = _graphRootDistances();
    if (distances == null) {
      // Not cached by a graph: compute (and cache) the path.
      return shortestPathToRoot.length;
    }

    var distance = distances[this];
    if (distance == null) {
      throw StateError("No path to root from: $value");
    }
    return distance + 1;
  }

  UnmodifiableListView<Node<T>>? _shortestPathToRoot;
  int _shortestPathToRootVersion = -1;

  int get _graphVersion => _graph?._version ?? 0;

  UnmodifiableListView<Node<T>>? get _validShortestPathToRoot =>
      _shortestPathToRootVersion == _graphVersion ? _shortestPathToRoot : null;

  /// Invalidates the cached paths after adding an edge with [other].
  /// (Both ends are in the same [graph]: [other] is resolved by [_resolveNode].)
  void _edgeAdded(Node<T> other) {
    _shortestPathToRoot = null;
    other._shortestPathToRoot = null;

    final graph = _graph;
    if (graph != null) {
      graph._changed();
      if (!identical(graph._allNodes[value], this) ||
          !identical(graph._allNodes[other.value], other)) {
        graph._hasForeignNodes = true;
      }
    }
  }

  /// Returns the shortest path from a root to this node (unmodifiable [List]).
  /// - A root node returns `[this]`.
  /// - Cached until the [graph] changes.
  /// - See [resolveShortestPathToRoot].
  List<Node<T>> get shortestPathToRoot {
    var path = _validShortestPathToRoot;
    if (path == null) {
      _shortestPathToRoot = path = UnmodifiableListView(
        resolveShortestPathToRoot(),
      );
      _shortestPathToRootVersion = _graphVersion;
    }
    return path;
  }

  /// The distances from the closest root of all the [graph] nodes
  /// (computed once until the graph changes), or `null` if this node is not
  /// in the [graph] (or the graph has foreign nodes).
  Map<Node<T>, int>? _graphRootDistances() {
    final graph = _graph;
    if (graph != null &&
        !graph._hasForeignNodes &&
        identical(graph._allNodes[value], this)) {
      return graph._resolveRootDistances();
    }
    return null;
  }

  /// The distance from the closest root to this node and its ancestors.
  Map<Node<T>, int> _rootDistances() {
    var distances = _graphRootDistances();
    if (distances != null) return distances;

    // Not in a [Graph]: only the ancestors matter.
    final ancestors = <Node<T>>{this, ...inputsInDepth()};
    return _computeRootDistances(ancestors, within: ancestors);
  }

  /// Resolves the shortest path from a root to this node
  /// (a BFS over the [inputs], see [shortestPathToRoot]).
  ///
  /// - Ties are resolved by the [inputs] order (the 1st input that is in
  ///   a shortest path).
  /// - Throws a [StateError] if no root reaches this node (e.g. a pure cycle).
  List<Node<T>> resolveShortestPathToRoot() {
    final distances = _rootDistances();

    final distance = distances[this];
    if (distance == null) {
      throw StateError("No path to root from: $value");
    }

    final path = List<Node<T>>.filled(distance + 1, this);

    var node = this;
    for (var d = distance - 1; d >= 0; d--) {
      node = node._inputs.firstWhere((e) => distances[e] == d);
      path[d] = node;
    }

    return path;
  }

  /// Resolves all the simple paths from a root to this node.
  ///
  /// - [maxExpansion]: an optional cap of times a node is expanded while
  ///   enumerating the paths. With a cap only a subset of the paths may be
  ///   returned. Default: `null` (no cap: all paths).
  /// - Returns the paths sorted by length.
  List<List<Node<T>>> resolveAllPathsToRoot({int? maxExpansion}) {
    final ancestors = <Node<T>>{this, ...inputsInDepth()};
    final roots = ancestors.where((e) => e.isRoot).toList();

    var paths = _enumeratePaths<T>(
      [this],
      roots,
      ancestors,
      (node) => node._inputs,
      maxExpansion: maxExpansion,
    );

    return paths.map((p) => p.reversed.toList()).toList().sortedPathsByLength();
  }

  /// Resets this node for a path scan.
  /// Clears [_target] and [attachment].
  @override
  void reset() {
    _target = false;
    attachment = null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is Node<T>) {
      return value == other.value;
    } else if (other is String) {
      return value.toString() == other;
    } else if (other is T) {
      return value == other;
    } else if (other is NodeMatcher<T>) {
      return other.matchesNode(this);
    } else {
      return false;
    }
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return '(${_validShortestPathToRoot?.length ?? '?'}) ${_inputs.length} -> $value -> ${_outputs.length}';
  }
}

/// The distance (in edges) from the closest root to each node reachable from
/// a root in [nodes] (a multi-source BFS over the outputs).
/// - [within]: if provided, only these nodes are walked.
Map<Node<T>, int> _computeRootDistances<T>(
  Iterable<Node<T>> nodes, {
  Set<Node<T>>? within,
}) {
  final distances = <Node<T>, int>{};
  final queue = ListQueue<Node<T>>();

  for (var node in nodes) {
    if (node.isRoot && !distances.containsKey(node)) {
      distances[node] = 0;
      queue.add(node);
    }
  }

  while (queue.isNotEmpty) {
    var node = queue.removeFirst();
    var distance = distances[node]! + 1;

    for (var output in node._outputs) {
      if (distances.containsKey(output)) continue;
      if (within != null && !within.contains(output)) continue;

      distances[output] = distance;
      queue.add(output);
    }
  }

  return distances;
}

extension _MapOfIntExtension<K> on Map<K, int> {
  int increment(K key) => update(key, (count) => count + 1, ifAbsent: () => 1);
}

extension IterableNodeExtension<T> on Iterable<Node<T>> {
  Iterable<T> toIterableOfValues() => map((e) => e.value);

  Iterable<String> toIterableOfString() => map((e) => e.value.toString());

  List<T> toListOfValues() => toIterableOfValues().toList();

  List<String> toListOfString() => toIterableOfString().toList();

  /// Dispose the graph of all the [Node]s.
  void disposeGraph() {
    for (var e in this) {
      e.disposeGraph();
    }
  }

  List<Node<T>> merge(List<Node<T>> other) {
    if (identical(this, other)) return toList();

    if (isEmpty) {
      return other.isEmpty ? [] : other.toList();
    } else if (other.isEmpty) {
      return toList();
    }

    var merge = {...this, ...other}.toList();
    return merge;
  }

  List<Node<T>> intersection(List<Node<T>> other) {
    if (identical(this, other)) return toList();
    if (isEmpty || other.isEmpty) return [];

    var intersection = where((e) => other.contains(e)).toList();
    return intersection;
  }

  List<Node<T>> complement(
    List<Node<T>> other, {
    bool includeThis = true,
    bool includeOther = true,
  }) {
    if (identical(this, other)) return [];

    if (isEmpty) return includeOther ? other.toList() : [];
    if (other.isEmpty) return includeThis ? toList() : [];

    var complement = [
      if (includeThis) ...where((e) => !other.contains(e)),
      if (includeOther) ...other.where((e) => !contains(e)),
    ];

    return complement;
  }

  Map<Node<T>, List<Node<T>>> outputsInDepth({
    int? maxDepth,
    bool bfs = false,
  }) => Map<Node<T>, List<Node<T>>>.fromEntries(
    map((e) => MapEntry(e, e.outputsInDepth(maxDepth: maxDepth, bfs: bfs))),
  );

  Map<Node<T>, List<Node<T>>> inputsInDepth({
    int? maxDepth,
    bool bfs = false,
  }) => Map<Node<T>, List<Node<T>>>.fromEntries(
    map((e) => MapEntry(e, e.inputsInDepth(maxDepth: maxDepth, bfs: bfs))),
  );

  List<Node<T>> outputsInDepthIntersection({int? maxDepth, bool bfs = false}) {
    var intersection = outputsInDepth(
      maxDepth: maxDepth,
      bfs: bfs,
    ).values.reduce((intersection, l) => intersection.intersection(l));
    return intersection;
  }

  List<Node<T>> inputsInDepthIntersection({int? maxDepth, bool bfs = false}) {
    var intersection = inputsInDepth(
      maxDepth: maxDepth,
      bfs: bfs,
    ).values.reduce((intersection, l) => intersection.intersection(l));
    return intersection;
  }

  /// Returns the nodes sorted by the number of [Node.outputsInDepth]
  /// (stable: ties keep the original order).
  List<Node<T>> sortedByOutputsDepth({bool bfs = false}) =>
      _sortedByLength(outputsInDepth(bfs: bfs));

  /// Returns the nodes sorted by the number of [Node.inputsInDepth]
  /// (stable: ties keep the original order).
  List<Node<T>> sortedByInputDepth({bool bfs = false}) =>
      _sortedByLength(inputsInDepth(bfs: bfs));

  /// Same as [sortedByOutputsDepth], but in descending order
  /// (also stable, unlike reversing an ascending sort).
  List<Node<T>> _sortedByOutputsDepthDescending() =>
      _sortedByLength(outputsInDepth(), descending: true);

  static List<Node<T>> _sortedByLength<T>(
    Map<Node<T>, List<Node<T>>> nodesLists, {
    bool descending = false,
  }) {
    var entries = nodesLists.entries.toList();

    // `mergeSort` is stable (`List.sort` is not):
    if (descending) {
      mergeSort(
        entries,
        compare: (a, b) => b.value.length.compareTo(a.value.length),
      );
    } else {
      mergeSort(
        entries,
        compare: (a, b) => a.value.length.compareTo(b.value.length),
      );
    }

    return entries.keys.toList();
  }

  List<Node<T>> sortedByOutputDependency({int? maxDepth, bool bfs = false}) {
    var nodesOutputs = outputsInDepth(maxDepth: maxDepth, bfs: bfs);

    var nodesOutputsEntries = nodesOutputs.entries.toList();

    var alone = nodesOutputsEntries.where((e) => e.value.isEmpty).keys.toList();

    alone = alone.sortedByInputDepth();

    if (alone.length == nodesOutputsEntries.length) {
      return alone;
    }

    nodesOutputsEntries.removeWhere((e) => alone.contains(e.key));

    var entriesIntersections = nodesOutputsEntries.map((e) {
      var entriesOutputs = e.value;
      var others = nodesOutputsEntries.where((e2) => e2 != e);

      var intersections = others
          .map(
            (other) =>
                MapEntry(other.key, entriesOutputs.intersection(other.value)),
          )
          .where((other) => other.value.isNotEmpty);

      return MapEntry(e.key, Map.fromEntries(intersections));
    }).toList();

    var isolated = entriesIntersections
        .where((e) => e.value.isEmpty)
        .keys
        .toList();

    nodesOutputsEntries.removeWhere((e) => isolated.contains(e.key));

    isolated = isolated._sortedByOutputsDepthDescending();

    var sideRoots = nodesOutputsEntries
        .map((e) => MapEntry(e.key, e.key.sideRoots()))
        .toList();

    var withoutSideRoots = sideRoots
        .where((e) => e.value.isEmpty)
        .keys
        .toList(growable: false);

    nodesOutputsEntries.removeWhere((e) => withoutSideRoots.contains(e.key));

    var rest = nodesOutputsEntries.keys._sortedByOutputsDepthDescending();

    var nodes = [...alone, ...isolated, ...withoutSideRoots, ...rest].toList();
    return nodes;
  }

  List<Node<T>> sortedByInputDependency({int? maxDepth, bool bfs = false}) {
    var nodesInputs = inputsInDepth(bfs: bfs);

    var nodesInputsEntries = nodesInputs.entries.toList();

    var directRoots = nodesInputsEntries
        .where((e) => e.value.isEmpty)
        .keys
        .toList();

    directRoots = directRoots.sortedByOutputDependency(maxDepth: maxDepth);

    if (directRoots.length == nodesInputsEntries.length) {
      return directRoots;
    }

    nodesInputsEntries.removeWhere((e) => directRoots.contains(e.key));

    var entriesIntersections = nodesInputsEntries.map((e) {
      var entryInputs = e.value;
      var otherEntries = nodesInputsEntries.where((e2) => e2 != e);

      var intersections = otherEntries
          .map(
            (other) =>
                MapEntry(other.key, entryInputs.intersection(other.value)),
          )
          .where((other) => other.value.isNotEmpty);

      return MapEntry(e.key, Map.fromEntries(intersections));
    }).toList();

    var isolated = entriesIntersections
        .where((e) => e.value.isEmpty)
        .keys
        .toList();

    nodesInputsEntries.removeWhere((e) => isolated.contains(e.key));

    isolated = isolated._sortedByOutputsDepthDescending();

    var rest = nodesInputsEntries.keys._sortedByOutputsDepthDescending();

    var nodes = [...directRoots, ...isolated, ...rest].toList();
    return nodes;
  }
}

extension IterableOfListNodeExtension<T> on Iterable<List<Node<T>>> {
  /// Returns a [List] with the paths sorted by length
  /// (stable: paths with the same length keep their order).
  List<List<Node<T>>> sortedPathsByLength() {
    var paths = toList();
    mergeSort(paths, compare: (a, b) => a.length.compareTo(b.length));
    return paths;
  }

  /// Returns the shortest paths.
  List<List<Node<T>>> shortestPaths() {
    if (isEmpty) return [];

    var sorted = sortedPathsByLength();

    var min = sorted.first.length;

    var idx = sorted.indexWhere((p) => p.length > min);

    if (idx < 0) {
      return sorted;
    } else {
      var shortest = sorted.sublist(0, idx);
      return shortest;
    }
  }

  /// Returns the first shortest path.
  List<Node<T>> firstShortestPath() {
    if (isEmpty) return [];

    return reduce(
      (shortest, path) => path.length < shortest.length ? path : shortest,
    );
  }

  /// Returns the longest paths.
  List<List<Node<T>>> longestPaths() {
    if (isEmpty) return [];

    var sorted = sortedPathsByLength();

    var max = sorted.last.length;

    var idx = sorted.lastIndexWhere((p) => p.length < max);

    if (idx < 0) {
      return sorted;
    } else {
      var longest = sorted.sublist(idx + 1);
      return longest;
    }
  }

  /// Returns the first longest path.
  List<Node<T>> firstLongestPath() {
    if (isEmpty) return [];

    return reduce(
      (longest, path) => path.length > longest.length ? path : longest,
    );
  }

  List<List<T>> toListOfValuePaths() => map((e) => e.toListOfValues()).toList();

  List<List<String>> toListOfStringPaths() =>
      map((e) => e.toListOfString()).toList();

  /// Dispose the graph of all the [Node] paths.
  void disposeGraph() {
    for (var e in this) {
      e.disposeGraph();
    }
  }
}

extension MapNodeExtension<T, V> on Map<Node<T>, V> {
  Map<T, V> toMapOfNodeValues() =>
      map((node, value) => MapEntry(node.value, value));
}

extension MapListNodeExtension<K, T> on Map<K, List<Node<T>>> {
  Map<K, List<T>> toMapOfListOfValues() =>
      map((key, l) => MapEntry(key, l.map((node) => node.value).toList()));
}

extension MapNodeListNodeExtension<T> on Map<Node<T>, List<Node<T>>> {
  Map<T, List<T>> toMapOfValues() => map(
    (key, l) => MapEntry(key.value, l.map((node) => node.value).toList()),
  );
}

extension _MapExtension<K, V> on Iterable<MapEntry<K, V>> {
  Iterable<K> get keys => map((e) => e.key);
}
