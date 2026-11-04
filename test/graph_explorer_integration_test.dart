// End-to-end: a realistic package dependency tree, loaded from JSON and
// queried as a dependency graph.

import 'dart:convert';

import 'package:graph_explorer/graph_explorer.dart';
import 'package:test/test.dart';

/// Two apps of a monorepo and their (transitive) package dependencies.
/// A package already listed is referenced by name (a `String` value).
const _dependenciesJson = '''
{
  "my_app": {
    "http": {
      "async": {"collection": null, "meta": null},
      "http_parser": {
        "collection": "collection",
        "source_span": {"collection": "collection", "path": null, "term_glyph": null},
        "string_scanner": {"source_span": "source_span"},
        "typed_data": {"collection": "collection"}
      },
      "meta": "meta",
      "web": null
    },
    "path": "path",
    "graph_explorer": {"collection": "collection"},
    "logging": null
  },
  "my_cli": {"args": null, "http": "http", "logging": "logging"}
}
''';

/// The same dependencies, as a flat map (like a lock file with the direct
/// dependencies of each package).
const _lockFile = <String, List<String>>{
  'my_app': ['http', 'path', 'graph_explorer', 'logging'],
  'my_cli': ['args', 'http', 'logging'],
  'http': ['async', 'http_parser', 'meta', 'web'],
  'async': ['collection', 'meta'],
  'http_parser': ['collection', 'source_span', 'string_scanner', 'typed_data'],
  'source_span': ['collection', 'path', 'term_glyph'],
  'string_scanner': ['source_span'],
  'typed_data': ['collection'],
  'graph_explorer': ['collection'],
  'args': [],
  'collection': [],
  'logging': [],
  'meta': [],
  'path': [],
  'term_glyph': [],
  'web': [],
};

Map<String, dynamic> _json() =>
    (jsonDecode(_dependenciesJson) as Map).cast<String, dynamic>();

Set<String> _edges<T>(Graph<T> g, [String Function(T v)? name]) {
  name ??= (v) => '$v';
  return {
    for (var n in g.allNodes)
      for (var o in n.outputs) '${name(n.value)}->${name(o.value)}',
  };
}

void main() {
  group('Package dependency graph', () {
    late Graph<String> graph;

    setUp(() => graph = Graph<String>.fromJson(_json()));

    test('structure', () {
      expect(graph.length, equals(_lockFile.length));
      expect(graph.rootValues, equals(['my_app', 'my_cli']));
      expect(
        graph.allLeaves.toListOfString().toSet(),
        equals({
          'collection',
          'meta',
          'path',
          'term_glyph',
          'web',
          'logging',
          'args',
        }),
      );

      // Direct dependencies, in declaration order:
      for (var e in _lockFile.entries) {
        expect(graph.node(e.key).outputsValues, equals(e.value), reason: e.key);
      }

      // Direct dependents:
      expect(
        graph.node('collection').inputsValues.toSet(),
        equals({
          'async',
          'http_parser',
          'source_span',
          'typed_data',
          'graph_explorer',
        }),
      );
      expect(graph.node('http').inputsValues, equals(['my_app', 'my_cli']));
    });

    test('transitive dependencies and dependents', () {
      var myApp = graph.node('my_app');
      expect(
        myApp.outputsInDepth().toListOfString().toSet(),
        equals(_lockFile.keys.toSet()..removeAll(['my_app', 'my_cli', 'args'])),
      );
      expect(
        graph.node('my_cli').outputsInDepth(maxDepth: 1).toListOfString(),
        equals(['args', 'http', 'logging']),
      );

      expect(
        graph.node('collection').inputsInDepth().toListOfString().toSet(),
        equals({
          'async',
          'http_parser',
          'source_span',
          'typed_data',
          'graph_explorer',
          'http',
          'string_scanner',
          'my_app',
          'my_cli',
        }),
      );

      expect(myApp.isOutput('term_glyph'), isTrue);
      expect(graph.node('my_cli').isOutput('graph_explorer'), isFalse);
      expect(graph.node('term_glyph').isInput('my_cli'), isTrue);

      // The apps that (transitively) use `source_span`:
      expect(
        graph.node('source_span').roots().toListOfString().toSet(),
        equals({'my_app', 'my_cli'}),
      );
      expect(
        graph.node('graph_explorer').roots().toListOfString(),
        equals(['my_app']),
      );

      // Shared by both apps:
      expect(
        myApp
            .outputsInDepthIntersection(graph.node('my_cli'))
            .toListOfString()
            .toSet(),
        equals(
          graph.node('http').outputsInDepth().toListOfString().toSet()
            ..addAll(['http', 'logging']),
        ),
      );
    });

    test('why does `my_app` depend on `term_glyph`?', () async {
      var shortest = await graph.shortestPathsFrom('my_app', 'term_glyph');
      expect(
        shortest.toListOfStringPaths(),
        equals([
          ['my_app', 'http', 'http_parser', 'source_span', 'term_glyph'],
        ]),
      );
      expect(graph.node('term_glyph').depth, equals(5));

      var result = await graph.scanPathsFrom(
        'my_app',
        'term_glyph',
        findAll: true,
      );
      var paths = result.paths.toListOfStringPaths();

      // The paths are resolved back to the graph roots, so the paths through
      // `my_cli` (which also depends on `http`) are included too:
      expect(
        paths.toSet(),
        equals({
          ['my_app', 'http', 'http_parser', 'source_span', 'term_glyph'],
          [
            'my_app',
            'http',
            'http_parser',
            'string_scanner',
            'source_span',
            'term_glyph',
          ],
          ['my_cli', 'http', 'http_parser', 'source_span', 'term_glyph'],
          [
            'my_cli',
            'http',
            'http_parser',
            'string_scanner',
            'source_span',
            'term_glyph',
          ],
        }),
      );
      expect(paths.where((p) => p.first == 'my_app'), hasLength(2));
      expect(result.paths.longestPaths(), hasLength(2));
      expect(result.toString(), contains('paths: 4'));
    });

    test('scanPathsMatching: the closest of several packages', () async {
      var paths = await graph.shortestPathsMatching([
        'my_app',
      ], MultipleNodesEquals(['meta', 'term_glyph', 'logging']));
      expect(
        paths.toListOfStringPaths(),
        equals([
          ['my_app', 'logging'],
          ['my_cli', 'logging'],
        ]),
      );

      var all = await graph.scanPathsMatching(['my_app'], AnyNode());
      expect(
        graph.targets.length,
        equals(graph.length - 2),
        reason: '`my_cli` and `args` are not reachable from `my_app`',
      );
      expect(all.paths, isNotEmpty);
    });

    test('walk orders', () {
      var bfs = graph.walkOutputsOrderFrom([
        'my_app',
      ], bfs: true).toListOfString();
      expect(
        bfs.take(5),
        equals(['my_app', 'http', 'path', 'graph_explorer', 'logging']),
      );
      expect(bfs.toSet(), hasLength(14));
      expect(bfs.length, equals(14));

      var dfs = graph.walkOutputsOrderFrom(['my_app']).toListOfString();
      expect(
        dfs,
        equals([
          'my_app',
          'http',
          'async',
          'collection',
          'meta',
          'http_parser',
          'source_span',
          'path',
          'term_glyph',
          'string_scanner',
          'typed_data',
          'web',
          'graph_explorer',
          'logging',
        ]),
      );

      // Every package is walked after (at least) one of its dependents:
      for (var i = 1; i < dfs.length; i++) {
        var inputs = graph.node(dfs[i]).inputsValues;
        expect(inputs.any((e) => dfs.indexOf(e) < i), isTrue);
      }

      // The dependents of `source_span`, up to the roots:
      expect(
        graph.walkInputsOrderFrom(['source_span'], bfs: true).toListOfString(),
        equals([
          'source_span',
          'http_parser',
          'string_scanner',
          'http',
          'my_app',
          'my_cli',
        ]),
      );
    });

    test('toJson reproduces the source JSON', () {
      expect(graph.toJson(), equals(_json()));
      expect(
        Graph<String>.fromJson(graph.toJson()).toJson(),
        equals(graph.toJson()),
      );
      expect(jsonDecode(jsonEncode(graph.toJson())), equals(_json()));
    });

    test('same graph as populating from a lock file', () {
      for (var bfs in [false, true]) {
        var fromLock = Graph<String>()
          ..populate(
            ['my_app', 'my_cli'],
            outputsProvider: (s, v) => _lockFile[v],
            bfs: bfs,
          );
        expect(_edges(fromLock), equals(_edges(graph)));
        expect(fromLock.rootValues, equals(graph.rootValues));
        expect(fromLock.toJson(), equals(graph.toJson()));
      }
    });

    test('scanning while resolving dependencies asynchronously', () async {
      var fetched = <String>[];

      var result = await GraphScanner<String>(findAll: true).scanPathsFrom(
        'my_app',
        NodeEquals('term_glyph'),
        outputsProvider: (g, node) async {
          // Simulates fetching the package metadata:
          await Future<void>.delayed(Duration.zero);
          fetched.add(node.value);
          return _lockFile[node.value]!.map(g.node).toList();
        },
        maxExpansion: 10,
      );

      // Only `my_app` is a root in the scanned graph:
      expect(
        result.paths.toListOfStringPaths().toSet(),
        equals({
          ['my_app', 'http', 'http_parser', 'source_span', 'term_glyph'],
          [
            'my_app',
            'http',
            'http_parser',
            'string_scanner',
            'source_span',
            'term_glyph',
          ],
        }),
      );
      expect(result.graph.rootValues, equals(['my_app']));
      expect(fetched, isNot(contains('my_cli')));
      expect(fetched.toSet(), containsAll(['my_app', 'http', 'source_span']));
    });
  });

  group('Package dependency graph (int ids)', () {
    // Packages identified by ids, named only in the JSON:
    final names = _lockFile.keys.toList();
    int id(String name) => names.indexOf(name);

    test('fromJson with a nodeValueMapper and toTree with a keyCast', () async {
      var graph = Graph<int>.fromJson(
        _json(),
        nodeValueMapper: (s, k) => id(k),
      );

      expect(graph.length, equals(names.length));
      expect(graph.rootValues, equals([id('my_app'), id('my_cli')]));
      expect(
        _edges(graph, (v) => names[v]),
        equals(_edges(Graph<String>.fromJson(_json()))),
      );

      expect(graph.toTree<String>(keyCast: (v) => names[v]), equals(_json()));

      var paths = await graph.shortestPathsFrom(id('my_app'), id('meta'));
      expect(
        paths.first.map((n) => names[n.value]).toList(),
        equals(['my_app', 'http', 'meta']),
      );

      // Round-trip through the default (`toString`) JSON keys:
      var json = graph.toJson();
      expect(json.keys, equals(['${id('my_app')}', '${id('my_cli')}']));
      var graph2 = Graph<int>.fromJson(
        json,
        nodeValueMapper: (s, k) => int.parse(k),
      );
      expect(_edges(graph2), equals(_edges(graph)));
      expect(graph2.toJson(), equals(json));
    });
  });
}
