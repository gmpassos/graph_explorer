// Copyright (c) 2023, Graciliano M P. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// Author:
// - Graciliano M. Passos: gmpassos @ GitHub
//

import 'dart:async';

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
}

/// A [Node] matcher that always returns `false` and never matches a node.
class NoneNode<T> extends NodeMatcher<T> {
  @override
  bool matchesNode(Node<T> node) => false;

  @override
  bool matchesValue(T value) => false;
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
    Graph<T> graph, Node<T> node);

class GraphScanResult<T> {
  final Graph<T> graph;

  final List<T> roots;
  final NodeMatcher<T> targetMatcher;
  final bool findAll;

  final List<List<Node<T>>> paths;

  final Duration time;
  final Duration resolvePathsTime;

  GraphScanResult(this.graph, this.roots, this.targetMatcher, this.paths,
      {required this.findAll,
      required this.time,
      required this.resolvePathsTime});

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
  /// The paths should start at [from] and end at a node that matches [targetMatcher].
  Future<GraphScanResult<T>> scanPathsFrom(T from, NodeMatcher<T> targetMatcher,
      {Graph<T>? graph, NodesProvider<T>? outputsProvider}) async {
    return scanPathsFromMany([from], targetMatcher,
        graph: graph, outputsProvider: outputsProvider);
  }

  /// Performs a scan and returns the found node paths.
  ///
  /// The paths should start one of the nodes at [fromMany] and end at a node that
  /// matches [targetMatcher].
  Future<GraphScanResult<T>> scanPathsFromMany(
      List<T> fromMany, NodeMatcher<T> targetMatcher,
      {Graph<T>? graph, NodesProvider<T>? outputsProvider}) async {
    var initTime = DateTime.now();

    GraphWalkingInstruction<bool>? processTarget(GraphNodeStep<T> step) {
      var node = step.node;

      if (targetMatcher.matchesNode(node)) {
        node.markAsTarget();
        if (!findAll) {
          return GraphWalkingInstruction.stop();
        }
      }
      return null;
    }

    if (graph == null) {
      graph = Graph<T>();

      if (outputsProvider == null) {
        return GraphScanResult(graph, fromMany, targetMatcher, [],
            findAll: findAll,
            time: Duration.zero,
            resolvePathsTime: Duration.zero);
      }

      FutureOr<Iterable<T>> nodeOutputsProvider(
          GraphNodeStep<T> step, T nodeValue) {
        var l = outputsProvider(graph!, graph.node(nodeValue));

        if (l is Future<List<Node<T>>>) {
          return l.then((l) => l.toIterableOfValues());
        } else {
          return l.toIterableOfValues();
        }
      }

      await graph.populateAsync(fromMany,
          outputsProvider: nodeOutputsProvider, process: processTarget);
    } else {
      if (graph.isEmpty && outputsProvider == null) {
        return GraphScanResult(graph, fromMany, targetMatcher, [],
            findAll: findAll,
            time: Duration.zero,
            resolvePathsTime: Duration.zero);
      }

      graph.reset();

      final nodeOutputsProvider = outputsProvider != null
          ? (GraphNodeStep<T> step, Node<T> node) =>
              outputsProvider(graph!, node)
          : (GraphNodeStep<T> step, Node<T> node) => node._outputs;

      await GraphWalker<T>(
        maxExpansion: 3,
        bfs: true,
      ).walkByNodesAsync<bool>(
        graph.valuesToNodes(fromMany, createNodes: true),
        process: processTarget,
        outputsProvider: nodeOutputsProvider,
      );
    }

    var pathsInitTime = DateTime.now();

    var targets = graph.targets;

    var paths = _resolvePaths(targets);

    if (!findAll) {
      paths = paths.shortestPaths();
    }

    var endTime = DateTime.now();
    var time = endTime.difference(initTime);
    var timePaths = endTime.difference(pathsInitTime);

    return GraphScanResult(graph, fromMany, targetMatcher, paths,
        findAll: findAll, time: time, resolvePathsTime: timePaths);
  }

  List<List<Node<T>>> _resolvePaths(List<Node<T>> targets) {
    var pathsItr = findAll
        ? targets.expand((e) => e.resolveAllPathsToRoot())
        : targets.map((e) => e.shortestPathToRoot);

    var paths = pathsItr.toList();
    return paths;
  }
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

  /// Returns `true` this graph is empty.
  bool get isEmpty => _allNodes.isEmpty;

  /// Returns `true` this graph NOT is empty.
  bool get isNotEmpty => _allNodes.isNotEmpty;

  /// Returns the total amount of [Node]s in this graph.
  int get length => _allNodes.length;

  Graph();

  /// Creates a [Graph] from [json].
  factory Graph.fromJson(Map<String, dynamic> json,
      {T Function(GraphStep<T>? previousStep, String key)? nodeValueMapper}) {
    if (nodeValueMapper == null) {
      if (T == String) {
        nodeValueMapper = (s, k) => k.toString() as T;
      } else {
        nodeValueMapper = (s, k) => k as T;
      }
    }

    final graph = Graph<T>();

    graph.populate(
      json.keys.map((k) => nodeValueMapper!(null, k)),
      nodeProvider: (step, nodeValue) {
        var node = graph.node(nodeValue);

        var parentNode = graph.getNode(step.parentValue);
        Map parentJsonNode = parentNode?.attachment ?? json;
        var jsonNode = parentJsonNode[nodeValue];

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
            if (jsonNode != nodeValue.toString()) {
              throw StateError(
                  "Invalid node reference: $nodeValue -> $jsonNode");
            }
          } else {
            throw StateError(
                "Invalid node type (graph)> $nodeValue: $jsonNode");
          }
        }

        return node;
      },
      outputsProvider: (step, nodeValue) {
        var jsonNode = graph.getNode(nodeValue)?.attachment;
        if (jsonNode is! Map || jsonNode.isEmpty) return null;
        return jsonNode.keys.map((k) => nodeValueMapper!(step, k));
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
  Node<T>? addInput(T nodeValue) => node(nodeValue);

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
  Node<T>? addOutput(T nodeValue) => node(nodeValue);

  /// Returns a [Node] with [value] or creates it.
  Node<T> node(T value) => _allNodes[value] ??= Node(value, graph: this);

  /// Returns a [Node] with [value] or `null` if not present.
  Node<T>? getNode(T? value) {
    if (value == null) return null;
    return _allNodes[value];
  }

  /// Alias to [getNode].
  Node<T>? operator [](T value) => getNode(value);

  /// Maps [values] to [Node]s in this graph.
  /// - If [createNodes] is `false` will throw a [StateError] if the node is not present in this graph.
  Iterable<Node<T>> valuesToNodes(Iterable<T> values,
      {bool createNodes = false}) {
    if (createNodes) {
      return values.map((value) => node(value));
    } else {
      return values.map((value) =>
          getNode(value) ??
          (throw StateError("Can't find node with value: $value")));
    }
  }

  /// Returns a [Node] with [value] or creates it as always root.
  Node<T> root(T value) {
    var node = _allNodes[value] ??= Node.root(value, graph: this);
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

    for (var e in nodes) {
      e.disposeGraph();
    }
  }

  /// Returns a [Map] representation of this graph.
  Map<K, dynamic> toTree<K>({K Function(T value)? keyCast, bool bfs = false}) {
    var rootValues = roots.map((e) => e.value).toList();
    return toTreeFrom<K>(rootValues, keyCast: keyCast, bfs: bfs);
  }

  /// Returns a [Map] representation of this graph from [roots].
  Map<K, dynamic> toTreeFrom<K>(List<T> roots,
          {K Function(T value)? keyCast, bool bfs = false}) =>
      GraphWalker<T>().toTreeFrom<K>(roots,
          nodeProvider: (s, v) => getNode(v),
          outputsProvider: (s, n) => n._outputs);

  /// Returns a JSON representation of this graph.
  Map<String, dynamic> toJson() => toTree<String>();

  /// Scans and returns the paths from [root] to [target].
  Future<GraphScanResult<T>> scanPathsFrom(T root, T target,
      {bool findAll = false}) {
    var scanner = GraphScanner<T>(findAll: findAll);
    return scanner.scanPathsFrom(root, NodeEquals(target), graph: this);
  }

  /// Scans and returns the paths from [roots] to [targets].
  Future<GraphScanResult<T>> scanPathsFromMany(List<T> roots, List<T> targets,
      {bool? findAll}) {
    findAll ??= roots.length > 1 || targets.length > 1;
    var scanner = GraphScanner<T>(findAll: findAll);
    return scanner.scanPathsFromMany(roots, NodeMatcher.eq(targets),
        graph: this);
  }

  /// Scans and returns the paths from [root] to [Node]s matching [targetMatcher].
  Future<GraphScanResult<T>> scanPathsMatching(
      List<T> roots, NodeMatcher<T> targetMatcher,
      {bool findAll = true}) {
    var scanner = GraphScanner<T>(findAll: findAll);
    return scanner.scanPathsFromMany(roots, targetMatcher, graph: this);
  }

  /// Returns the shortest paths from [root] to [target].
  Future<List<List<Node<T>>>> shortestPathsFrom(T root, T target,
      {bool findAll = false}) async {
    var result = await scanPathsFrom(root, target, findAll: findAll);
    return result.paths.shortestPaths();
  }

  /// Returns the shortest paths from [roots] to [targets].
  Future<List<List<Node<T>>>> shortestPathsFromMany(
      List<T> roots, List<T> targets,
      {bool findAll = false}) async {
    var result = await scanPathsFromMany(roots, targets, findAll: findAll);
    return result.paths.shortestPaths();
  }

  /// Returns the shortest paths from [roots] to [Nodes] matching [targetMatcher].
  Future<List<List<Node<T>>>> shortestPathsMatching(
      List<T> roots, NodeMatcher<T> targetMatcher,
      {bool findAll = true}) async {
    var result =
        await scanPathsMatching(roots, targetMatcher, findAll: findAll);
    return result.paths.shortestPaths();
  }

  /// Returns all the paths from [roots] to [allLeaves];
  Future<List<List<Node<T>>>> get allPaths async {
    var roots = this.roots.toListOfValues();
    var leaves = allLeaves.toListOfValues();

    var result = await scanPathsFromMany(roots, leaves, findAll: true);
    return result.paths;
  }

  /// Returns all the shortest paths from [root] to [allLeaves].
  Future<List<List<Node<T>>>> get shortestPaths async {
    var paths = await this.allPaths;
    return paths.shortestPaths();
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
    nodeProvider ??= (s, e) => this.node(e);
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
    nodeProvider ??= (s, e) => this.node(e);
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

  Node(this.value, {Graph<T>? graph})
      : _graph = graph,
        _inputs = [];

  Node.root(this.value, {Graph<T>? graph})
      : _graph = graph,
        _inputs = List.unmodifiable([]) {
    _shortestPathToRoot = UnmodifiableListView([]);
  }

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
  List<T> get outputsValues => _outputs.map((e) => e.value).toList();

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
      _shortestPathToRoot = null;

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
              "Error adding output node `$nodeValue` to `$value`"));
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
          "Can't resolve `nodeValue` to a node (null `graph`): $nodeValue");
    }

    var node = graph.node(nodeValue);
    return node;
  }

  /// Returns `true` if it's a root node (no inputs).
  bool get isRoot => _inputs.isEmpty;

  /// Returns `true` if this node was created with [Node.root] (can't have inputs).
  bool get isAlwaysRoot =>
      _shortestPathToRoot is UnmodifiableListView && _inputs.isEmpty;

  /// Return the inputs of this node.
  @override
  List<Node<T>> get inputs => _inputs;

  /// Return the inputs values of this node.
  List<T> get inputsValues => _inputs.map((e) => e.value).toList();

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
      _shortestPathToRoot = null;

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
              "Error adding input node `$nodeValue` to `$value`"));
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

    var graphWalker = GraphWalker<T>(
      stopMatcher: NodeEquals<T>(target.value),
    );

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

    var graphWalker = GraphWalker<T>(
      stopMatcher: NodeEquals<T>(target.value),
    );

    return graphWalker.walkByNodes<bool>(
          [this],
          outputsProvider: (step, node) => node._outputs,
          process: (step) =>
              step.node == target ? GraphWalkingInstruction.result(true) : null,
        ) ??
        false;
  }

  /// Returns all the [outputs] in depth, scanning all the [outputs] of [outputs].
  List<Node<T>> outputsInDepth({bool bfs = false}) {
    final allNodes = <Node<T>>[];

    var graphWalker = GraphWalker<T>(
      processRoots: false,
      bfs: bfs,
    );

    graphWalker.walkByNodes<bool>(
      [this],
      outputsProvider: (step, node) => node._outputs,
      process: (step) {
        allNodes.add(step.node);
        return null;
      },
    );

    return allNodes;
  }

  /// Returns all the [inputs] in depth, scanning all the [inputs] of [inputs].
  List<Node<T>> inputsInDepth({bool bfs = false}) {
    final allNodes = <Node<T>>[];

    var graphWalker = GraphWalker<T>(
      processRoots: false,
      bfs: bfs,
    );

    graphWalker.walkByNodes<bool>(
      [this],
      outputsProvider: (step, node) => node._inputs,
      process: (step) {
        allNodes.add(step.node);
        return null;
      },
    );

    return allNodes;
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

  /// Returns `true` if [target] is an input in the [shortestPathToRoot].
  bool isInputInShortestPathToRoot(Node target) =>
      shortestPathToRoot.contains(target);

  /// The node depth from root.
  /// See [shortestPathToRoot].
  int get depth => shortestPathToRoot.length;

  UnmodifiableListView<Node<T>>? _shortestPathToRoot;

  /// Returns the shortest path to root (unmodifiable [List]).
  List<Node<T>> get shortestPathToRoot =>
      _shortestPathToRoot ??= UnmodifiableListView(resolveShortestPathToRoot());

  /// Resolves the shortest path to root from this node.
  /// Since [inputs] is populated in BFS, the 1st input is one of the closest to the root.
  List<Node<T>> resolveShortestPathToRoot() {
    // A buffer on paths being computed until the root:
    final computingPathsBuffer = [
      [this]
    ];

    final computingPathsIdxRet = <int>[0];
    var expandCursor = 0;

    var graphWalker = GraphWalker<T>();

    var shortestPath = graphWalker.walkByNodes<List<Node<T>>>(
      [this],
      outputsProvider: (step, node) {
        var inputs = node._inputs;
        return inputs.isEmpty ? [] : [inputs.first];
      },
      process: (step) {
        var node = step.node;

        var computingPaths = _getComputingPaths<T>(
            computingPathsBuffer, node, expandCursor, computingPathsIdxRet);

        if (computingPaths == null) return null;

        var computingPathsIdx = computingPathsIdxRet[0];

        if (node.isRoot) {
          // [computingPaths] of [node] completed.
          // Return one of the shortest path (1st):
          return GraphWalkingInstruction.result(computingPaths.first);
        }

        // In a BFS the 1st input will be one of the closest to root,
        // don't need to expand with all the inputs:
        var closerToRoot = node._inputs.first;

        var inputs = [closerToRoot];

        expandCursor = _expandComputingPaths<T>(computingPathsBuffer,
            computingPaths, computingPathsIdx, inputs, expandCursor);

        return null;
      },
    );

    if (shortestPath == null) {
      throw StateError("No path to root from: $value");
    }

    return shortestPath;
  }

  /// Resolves all the paths to the root from this node.
  ///
  /// The algorithm tries to remove meaningless
  /// nodes, such as branches that only exist due to indirect self-references.
  List<List<Node<T>>> resolveAllPathsToRoot() {
    var rootPaths = <List<Node<T>>>[];

    // A buffer on paths being computed until the root:
    final computingPathsBuffer = [
      [this]
    ];

    final computingPathsIdxRet = <int>[0];
    var expandCursor = 0;

    var graphWalker = GraphWalker<T>(maxExpansion: 3);

    graphWalker.walkByNodes<List<Node<T>>>(
      [this],
      outputsProvider: (step, node) => node._inputs,
      process: (step) {
        var node = step.node;

        var computingPaths = _getComputingPaths<T>(
            computingPathsBuffer, node, expandCursor, computingPathsIdxRet);

        if (computingPaths == null) return null;

        var computingPathsIdx = computingPathsIdxRet[0];
        var computingPathsEndIdx = computingPathsIdx + computingPaths.length;

        if (node.isRoot) {
          // [computingPaths] of [node] completed,
          // remove it from [computingPathsBuffer].
          computingPathsBuffer.removeRange(
              computingPathsIdx, computingPathsEndIdx);

          rootPaths.addAll(computingPaths);
          expandCursor = computingPathsIdx;

          // Allow independent branches to be computed:
          // Reset counter to 0:
          return GraphWalkingInstruction.setExpansionCounter(0);
        }

        final processed = step.processed;

        final newNode = processed[node] == 1;

        // Skip target nodes (leafs with `target == true`)
        // already processed (avoids self-reference):
        if (node.isTarget && !newNode) {
          return null;
        }

        var inputs = node._inputs;

        if (!newNode) {
          var unprocessed =
              inputs.where((e) => !processed.containsKey(e)).toList();

          // Not all inputs are unprocessed:
          if (unprocessed.length < inputs.length) {
            // Allow inputs that are not targets (leaves with `matches`)
            // or that are [unprocessed].
            var allowedIts =
                inputs.where((e) => !e.isTarget || unprocessed.contains(e));

            // Ensure that inputs processed more than 3 times are skipped,
            // to avoid infinite loops or meaningless branches already seen:
            allowedIts = allowedIts.where((e) => (processed[e] ?? 0) <= 3);

            var allowed = allowedIts.toList();

            // Only expand with allowed inputs:
            inputs = allowed;
          }
        }

        expandCursor = _expandComputingPaths(computingPathsBuffer,
            computingPaths, computingPathsIdx, inputs, expandCursor);

        return null;
      },
    );

    return rootPaths;
  }

  /// Returns the computing paths of [node].
  ///
  /// - [computingPathsBuffer] is populated in the same order that [node] is added
  ///   to the queue to be processed, so the computing paths of [node] are in
  ///   an ordered way.
  /// - [expandCursor] points to the last `"expanded path" + 1`, indicating where
  ///   the [node] computing paths should be. See [_expandComputingPaths].
  /// - The [node[ computing paths are the ones where the 1st element is [node].
  // Change `computingPathIdx` to records when moving to Dart 3:
  static List<List<Node<T>>>? _getComputingPaths<T>(
      List<List<Node<T>>> computingPathsBuffer,
      Node node,
      int expandCursor,
      List<int> computingPathsIdx) {
    var idx1 =
        computingPathsBuffer.indexWhere((e) => e.first == node, expandCursor);
    if (idx1 < 0) {
      idx1 = computingPathsBuffer.indexWhere((e) => e.first == node, 0);
      if (idx1 < 0) {
        return null;
      }
    }

    var idx2 = computingPathsBuffer.indexWhere((e) => e.first != node, idx1);
    if (idx2 < 0) {
      idx2 = computingPathsBuffer.length;
    }

    var inputPaths = computingPathsBuffer.getRange(idx1, idx2).toList();
    computingPathsIdx[0] = idx1;

    return inputPaths;
  }

  /// Expands the computing paths of [node],
  /// [computingPathsBuffer]
  static int _expandComputingPaths<T>(
      List<List<Node<T>>> computingPathsBuffer,
      List<List<Node<T>>> computingPaths,
      int computingPathsIdx,
      List<Node<T>> nodeInputs,
      int expandCursor) {
    final expandedPaths = computingPaths.expand((c) {
      // Avoid to expand paths with an input that is an indirect self-reference:
      var nonRecursiveInputs = nodeInputs.where((p) => !c.contains(p));
      return nonRecursiveInputs.map((p) => [p, ...c]);
    }).toList(growable: false);

    final computingPathsEndIdx = computingPathsIdx + computingPaths.length;

    // Replace the [computingPathsBuffer] region that contains [computingPaths]
    // with the [expandedPaths].
    if (computingPaths.length == expandedPaths.length) {
      computingPathsBuffer.setRange(
          computingPathsIdx, computingPathsEndIdx, expandedPaths);
      expandCursor = computingPathsEndIdx;
    } else {
      computingPathsBuffer.replaceRange(
          computingPathsIdx, computingPathsEndIdx, expandedPaths);
      expandCursor = computingPathsIdx + expandedPaths.length;
    }

    return expandCursor;
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
    return '(${_shortestPathToRoot?.length ?? '?'}) ${_inputs.length} -> $value -> ${_outputs.length}';
  }
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

  List<Node<T>> intersection(List<Node<T>> other) {
    if (identical(this, other)) return toList();
    if (isEmpty || other.isEmpty) return [];

    var intersection = where((e) => other.contains(e)).toList();
    return intersection;
  }

  Map<Node<T>, List<Node<T>>> outputsInDepth({bool bfs = false}) =>
      Map<Node<T>, List<Node<T>>>.fromEntries(
          map((e) => MapEntry(e, e.outputsInDepth(bfs: bfs))));

  Map<Node<T>, List<Node<T>>> inputsInDepth({bool bfs = false}) =>
      Map<Node<T>, List<Node<T>>>.fromEntries(
          map((e) => MapEntry(e, e.inputsInDepth(bfs: bfs))));

  List<Node<T>> outputsInDepthIntersection({bool bfs = false}) {
    var intersection = outputsInDepth(bfs: bfs)
        .values
        .reduce((intersection, l) => intersection.intersection(l));
    return intersection;
  }

  List<Node<T>> inputsInDepthIntersection({bool bfs = false}) {
    var intersection = inputsInDepth(bfs: bfs)
        .values
        .reduce((intersection, l) => intersection.intersection(l));
    return intersection;
  }

  List<Node<T>> sortedByOutputsDepth({bool bfs = false}) {
    var nodesOutputs = outputsInDepth(bfs: bfs);

    var entries = nodesOutputs.entries.toList();

    entries.sort((a, b) => a.value.length.compareTo(b.value.length));

    var nodes = entries.map((e) => e.key).toList();
    return nodes;
  }

  List<Node<T>> sortedByInputDepth({bool bfs = false}) {
    var nodesInputs = inputsInDepth(bfs: bfs);

    var entries = nodesInputs.entries.toList();

    entries.sort((a, b) => a.value.length.compareTo(b.value.length));

    var nodes = entries.map((e) => e.key).toList();
    return nodes;
  }

  List<Node<T>> sortedByOutputDependency({bool bfs = false}) {
    var nodesOutputs = outputsInDepth(bfs: bfs);

    var entries = nodesOutputs.entries.toList();

    var alone =
        entries.where((e) => e.value.isEmpty).map((e) => e.key).toList();
    entries.removeWhere((e) => alone.contains(e.key));

    alone = alone.sortedByInputDepth();

    var entriesIntersections = entries.map((e1) {
      var nodes1 = e1.value;
      var others = entries.where((e2) => e2 != e1);

      var intersections = others
          .map((other) => MapEntry(other.key, nodes1.intersection(other.value)))
          .where((e) => e.value.isNotEmpty)
          .toList();

      return MapEntry(e1.key, Map.fromEntries(intersections));
    }).toList();

    var isolated = entriesIntersections
        .where((e) => e.value.isEmpty)
        .map((e) => e.key)
        .toList();

    entriesIntersections.removeWhere((e) => isolated.contains(e.key));
    entries.removeWhere((e) => isolated.contains(e.key));

    isolated = isolated.sortedByInputDepth();

    var rest = entries.map((e) => e.key).sortedByInputDepth();

    var nodes = [...alone, ...isolated, ...rest].toList();
    return nodes;
  }

  List<Node<T>> sortedByInputDependency({bool bfs = false}) {
    var nodesInputs = inputsInDepth(bfs: bfs);

    var entries = nodesInputs.entries.toList();

    var alone =
        entries.where((e) => e.value.isEmpty).map((e) => e.key).toList();
    entries.removeWhere((e) => alone.contains(e.key));

    alone = alone.sortedByOutputsDepth().toReversedList();

    var entriesIntersections = entries.map((e1) {
      var nodes1 = e1.value;
      var others = entries.where((e2) => e2 != e1);

      var intersections = others
          .map((other) => MapEntry(other.key, nodes1.intersection(other.value)))
          .where((e) => e.value.isNotEmpty)
          .toList();

      return MapEntry(e1.key, Map.fromEntries(intersections));
    }).toList();

    var isolated = entriesIntersections
        .where((e) => e.value.isEmpty)
        .map((e) => e.key)
        .toList();

    entriesIntersections.removeWhere((e) => isolated.contains(e.key));
    entries.removeWhere((e) => isolated.contains(e.key));

    isolated = isolated.sortedByOutputsDepth().toReversedList();

    var rest =
        entries.map((e) => e.key).sortedByOutputsDepth().toReversedList();

    var nodes = [...alone, ...isolated, ...rest].toList();
    return nodes;
  }
}

extension IterableOfListNodeExtension<T> on Iterable<List<Node<T>>> {
  /// Returns a [List] with the paths sorted by length.
  List<List<Node<T>>> sortedPathsByLength() =>
      sorted((a, b) => a.length.compareTo(b.length)).toList();

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
        (shortest, path) => path.length < shortest.length ? path : shortest);
  }

  /// Returns the longest paths.
  List<List<Node<T>>> longestPaths() {
    if (isEmpty) return [];

    var sorted = sortedPathsByLength();

    var max = sorted.last.length;

    var idx = sorted.indexWhere((p) => p.length < max);

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
        (longest, path) => path.length > longest.length ? path : longest);
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

extension _ListTypeExtension<T> on List<T> {
  List<T> toReversedList() => reversed.toList();
}
