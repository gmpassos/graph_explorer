// Copyright (c) 2023, Graciliano M P. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// Author:
// - Graciliano M. Passos: gmpassos @ GitHub
//

import 'dart:async';
import 'dart:collection';

import 'package:ascii_art_tree/ascii_art_tree.dart';
import 'package:collection/collection.dart';

/// A [Node] matcher, used by [GraphScanner].
abstract class NodeMatcher<T> {
  NodeMatcher();

  /// Returns `true` if [node] matches.
  bool matchesNode(Node<T> node) => matchesValue(node.value);

  /// Returns `true` if [value] matches.
  bool matchesValue(T value);
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

    if (graph == null) {
      graph = Graph<T>();
    } else {
      graph.reset();
    }

    var populate = true;
    if (outputsProvider == null) {
      outputsProvider = (Graph<T> graph, Node<T> node) => node._outputs;
      populate = false;
    }

    final scanQueue = ListQueue<Node<T>>(fromMany.length * 2);

    for (var fromNode in fromMany) {
      scanQueue.add(graph.node(fromNode));
    }

    final scannedNodes = <Node<T>>{};

    SCAN:
    while (scanQueue.isNotEmpty) {
      var node = scanQueue.removeFirst();

      var outputs = await outputsProvider(graph, node);

      for (var output in outputs) {
        var checkNode = true;
        if (populate) {
          checkNode = output._addInputNode(node) != null;
          node._addOutputNode(output);
        } else {
          output._addInputNode(node);
        }

        // Probably a new node:
        if (checkNode) {
          // Found a target:
          if (targetMatcher.matchesNode(output)) {
            output.markAsTarget();

            if (!findAll) {
              break SCAN;
            }
          }

          // New node to scan:
          if (scannedNodes.add(output)) {
            scanQueue.addLast(output);
          }
        }
      }
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

/// A [Graph] of [Node]s.
///
/// - Can be generated by [GraphScanner.searchPaths].
class Graph<T> {
  /// All nodes in this graph.
  final Map<T, Node<T>> _allNodes = {};

  Map<T, Node<T>> get allNodes => UnmodifiableMapView(_allNodes);

  /// Returns `true` this graph is empty.
  bool get isEmpty => _allNodes.isEmpty;

  /// Returns `true` this graph NOT is empty.
  bool get isNotEmpty => _allNodes.isNotEmpty;

  /// Returns the total amount of [Node]s in this graph.
  int get length => _allNodes.length;

  Graph();

  /// Returns a [Node] with [value] or creates it.
  Node<T> node(T value) => _allNodes[value] ??= Node(value, graph: this);

  /// Returns a [Node] with [value] or `null` if not present.
  Node<T>? getNode(T value) => _allNodes[value];

  /// Alias to [getNode].
  Node<T>? operator [](T value) => getNode(value);

  /// Returns a [Node] with [value] or creates it as always root.
  Node<T> root(T value) {
    var node = _allNodes[value] ??= Node.root(value, graph: this);
    return node;
  }

  /// Returns a list of root nodes (without inputs).
  List<Node<T>> get roots =>
      _allNodes.values.where((e) => e.isRoot).toList(growable: false);

  /// Returns a list of nodes market as targets.
  List<Node<T>> get targets =>
      _allNodes.values.where((e) => e.isTarget).toList(growable: false);

  void reset() {
    for (var node in _allNodes.values) {
      node.reset();
    }
  }

  void dispose() {
    var nodes = _allNodes.values.toList(growable: false);

    _allNodes.clear();

    for (var e in nodes) {
      e.disposeGraph();
    }
  }

  Map<K, dynamic> toTree<K>({K Function(T value)? keyCast}) {
    var rootValues = roots.map((e) => e.value).toList();
    return toTreeFrom<K>(rootValues, keyCast: keyCast);
  }

  Map<K, dynamic> toTreeFrom<K>(List<T> roots, {K Function(T value)? keyCast}) {
    if (keyCast == null) {
      if (K == String) {
        keyCast = (v) => v.toString() as K;
      } else if (K == Node || K == <Node<T>>[].genericType) {
        keyCast = (v) => getNode(v) as K;
      } else {
        keyCast = (v) => v as K;
      }
    }

    Map<K, dynamic> Function() createNode = K == dynamic
        ? () => (<T, dynamic>{} as Map<K, dynamic>)
        : () => <K, dynamic>{};

    Map<K, Map<K, dynamic>> allTreeNodes = K == dynamic
        ? (<T, Map<T, dynamic>>{} as Map<K, Map<K, dynamic>>)
        : <K, Map<K, dynamic>>{};

    Map<K, dynamic> tree =
        K == dynamic ? (<T, dynamic>{} as Map<K, dynamic>) : <K, dynamic>{};

    var processedNode = <Node<T>>{};
    var queue = ListQueue<Node<T>>();

    for (var root in roots) {
      var rootNode = getNode(root) ??
          (throw ArgumentError("Root not present in graph: $root"));

      assert(rootNode.value == root);

      processedNode.add(rootNode);
      queue.add(rootNode);

      var rootK = keyCast(root);

      tree[rootK] ??= allTreeNodes[rootK] ??= createNode();
    }

    while (queue.isNotEmpty) {
      var node = queue.removeFirst();

      var nodeK = keyCast(node.value);

      var treeNode = allTreeNodes[nodeK] ??= createNode();

      for (var child in node._outputs) {
        var childValue = child.value;
        var childK = keyCast(childValue);

        dynamic ref;

        var childTreeNode = allTreeNodes[childValue];
        if (childTreeNode == null) {
          childTreeNode = allTreeNodes[childK] = createNode();
          ref = childTreeNode;
        } else {
          ref = childValue;
        }

        treeNode[childK] ??= ref;

        if (processedNode.add(child)) {
          queue.add(child);
        }
      }
    }

    return tree;
  }

  Map<String, dynamic> toJson() => toTree<String>();

  ASCIIArtTree toASCIIArtTree(
      {String? stripPrefix,
      String? stripSuffix,
      ASCIIArtTreeStyle style = ASCIIArtTreeStyle.elegant,
      bool allowGraphs = true}) {
    var tree = toTree<String>();
    return ASCIIArtTree(tree,
        stripPrefix: stripPrefix,
        stripSuffix: stripSuffix,
        style: style,
        allowGraphs: allowGraphs);
  }

  Future<GraphScanResult<T>> scanPathsFrom(T root, T target,
      {bool findAll = false}) {
    var scanner = GraphScanner<T>(findAll: findAll);
    return scanner.scanPathsFrom(root, NodeEquals(target), graph: this);
  }

  Future<GraphScanResult<T>> scanPathsFromMany(List<T> from, List<T> targets,
      {bool? findAll}) {
    findAll ??= from.length > 1 || targets.length > 1;
    var scanner = GraphScanner<T>(findAll: findAll);
    return scanner.scanPathsFromMany(from, MultipleNodesEquals(targets),
        graph: this);
  }

  Future<GraphScanResult<T>> scanPathsMatching(
      List<T> roots, NodeMatcher<T> targetMatcher,
      {bool findAll = true}) {
    var scanner = GraphScanner<T>(findAll: findAll);
    return scanner.scanPathsFromMany(roots, targetMatcher, graph: this);
  }

  Future<List<List<Node<T>>>> shortestPathsFrom(T root, T target,
      {bool findAll = false}) async {
    var result = await scanPathsFrom(root, target, findAll: findAll);
    return result.paths.shortestPaths();
  }

  Future<List<List<Node<T>>>> shortestPathsFromMany(
      List<T> roots, List<T> targets,
      {bool findAll = false}) async {
    var result = await scanPathsFromMany(roots, targets, findAll: findAll);
    return result.paths.shortestPaths();
  }

  Future<List<List<Node<T>>>> shortestPathsMatching(
      List<T> roots, NodeMatcher<T> targetMatcher,
      {bool findAll = true}) async {
    var result =
        await scanPathsMatching(roots, targetMatcher, findAll: findAll);
    return result.paths.shortestPaths();
  }
}

/// A [Graph] [Node].
class Node<T> {
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

  bool _target = false;

  /// Marks this node as a target.
  void markAsTarget() => _target = true;

  /// If `true` matches a target in the scan.
  /// See [NodeMatcher.matches].
  bool get isTarget => _target;

  /// Return the outputs of this node.
  List<Node<T>> get outputs => _outputs;

  /// Return the outputs values of this node.
  List<T> get outputsValues => _outputs.map((e) => e.value).toList();

  /// Returns `true` if [outputs] contains [node].
  bool containsOutputNode(Node<T> node) => _outputs.contains(node);

  /// Returns `true` if [outputs] contains a [Node] with [nodeValue].
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

  /// Returns `true` if it's a root node (no inputs)
  bool get isRoot => _inputs.isEmpty;

  /// Returns `true` if this node was created with [Node.root] (can't have inputs).
  bool get isAlwaysRoot =>
      _shortestPathToRoot is UnmodifiableListView && _inputs.isEmpty;

  /// Return the inputs of this node.
  List<Node<T>> get inputs => _inputs;

  /// Return the inputs values of this node.
  List<T> get inputsValues => _inputs.map((e) => e.value).toList();

  /// Returns `true` if [node] is a [inputs].
  bool containsInputNode(Node<T> node) => _inputs.contains(node);

  /// Returns `true` if [nodeValue] is a [inputs].
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

  /// Returns `true` if [target] is an input of this node.
  bool isInput(Node target) {
    if (this == target) return true;

    var processedNode = <Node<T>>{this};
    var queue = ListQueue<Node<T>>()..add(this);

    while (queue.isNotEmpty) {
      var node = queue.removeFirst();

      for (var p in node._inputs) {
        if (p == target) {
          return true;
        }

        if (processedNode.add(p)) {
          queue.add(p);
        }
      }
    }

    return false;
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

    final processedNodes = <Node<T>>{};
    final queue = ListQueue<Node<T>>()..add(this);

    final computingPathsIdxRet = <int>[0];
    var expandCursor = 0;

    while (queue.isNotEmpty) {
      var node = queue.removeFirst();

      var computingPaths = _getComputingPaths(
          computingPathsBuffer, node, expandCursor, computingPathsIdxRet);

      if (computingPaths == null) continue;

      var computingPathsIdx = computingPathsIdxRet[0];

      if (node.isRoot) {
        // [computingPaths] of [node] completed.
        // Return one of the shortest path (1st):
        return computingPaths.first;
      }

      var newNode = processedNodes.add(node);
      if (!newNode) {
        // Only computing the shortest branch:
        continue;
      }

      var inputs = node._inputs;

      // In a BFS the 1st input will be one of the closest to root,
      // don't need to expand with all the inputs:
      var closerToRoot = inputs.first;
      inputs = [closerToRoot];

      expandCursor = _expandComputingPaths(computingPathsBuffer, computingPaths,
          computingPathsIdx, inputs, expandCursor);

      queue.add(closerToRoot);
    }

    throw StateError("No path to root.");
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

    // Count the number of times that a node was processed:
    final processedNodesCounter = <Node<T>, int>{};

    final queue = ListQueue<Node<T>>()..add(this);

    final computingPathsIdxRet = <int>[0];
    var expandCursor = 0;

    while (queue.isNotEmpty) {
      var node = queue.removeFirst();

      var computingPaths = _getComputingPaths(
          computingPathsBuffer, node, expandCursor, computingPathsIdxRet);

      if (computingPaths == null) continue;

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
        processedNodesCounter[node] = 0;
        continue;
      }

      // Increment the processed node counter for [node]:
      final nodeProcessCount =
          processedNodesCounter.update(node, (c) => c + 1, ifAbsent: () => 1);

      final newNode = nodeProcessCount == 1;

      // Skip target nodes (leafs with `target == true`)
      // already processed (avoids self-reference):
      if (node.isTarget && !newNode) {
        continue;
      }

      var inputs = node._inputs;

      if (!newNode) {
        var unprocessed =
            inputs.where((e) => !processedNodesCounter.containsKey(e)).toList();

        // Not all inputs are unprocessed:
        if (unprocessed.length < inputs.length) {
          // Allow inputs that are not targets (leaves with `matches`)
          // or that are [unprocessed].
          var allowedIts =
              inputs.where((e) => !e.isTarget || unprocessed.contains(e));

          // Ensure that inputs processed more than 3 times are skipped,
          // to avoid infinite loops or meaningless branches already seen:
          allowedIts =
              allowedIts.where((e) => (processedNodesCounter[e] ?? 0) <= 3);

          var allowed = allowedIts.toList();

          // Only expand with allowed inputs:
          inputs = allowed;
        }
      }

      expandCursor = _expandComputingPaths(computingPathsBuffer, computingPaths,
          computingPathsIdx, inputs, expandCursor);

      queue.addAll(inputs);
    }

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
  List<List<Node<T>>>? _getComputingPaths(
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
  int _expandComputingPaths(
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

  void reset() {
    _target = false;
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
  List<T> toListOfValues() => map((e) => e.value).toList();

  List<String> toListOfString() => map((e) => e.value.toString()).toList();

  /// Dispose the graph of all the [Node]s.
  void disposeGraph() {
    for (var e in this) {
      e.disposeGraph();
    }
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

  /*
  asasd() {
    ASCIIArtTree.fr
  }
   */

  /// Dispose the graph of all the [Node] paths.
  void disposeGraph() {
    for (var e in this) {
      e.disposeGraph();
    }
  }
}

extension _ListTypeExtension<T> on List<T> {
  Type get genericType => T;
}
