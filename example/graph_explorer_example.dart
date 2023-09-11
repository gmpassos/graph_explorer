import 'dart:convert';

import 'package:graph_explorer/graph_explorer.dart';

void main() async {
  var graph = Graph<String>();

  graph.node('a').getOrAddOutput('b')
    ..addOutput('c')
    ..addOutput('d');

  graph.node('c').addOutput('f');
  graph.node('d').getOrAddOutput('e').addOutput('f');

  var result = await graph.scanPathsFrom('a', 'f', findAll: true);

  print("Paths from `a` to `f`:");
  for (var p in result.paths) {
    var lStr = p.toListOfString();
    print('- $lStr');
  }

  var shortest = result.paths.shortestPaths().toListOfStringPaths();
  print('\nShortest paths:');
  for (var p in shortest) {
    print('- $p');
  }

  var tree = graph.toTree();

  print('\nGraph to Tree:');
  print(_encodeJsonPretty(tree));

  var asciiArtTree = graph.toASCIIArtTree();
  print('\nGraph to ASCII Art Tree:');
  print(asciiArtTree.generate());
}

String _encodeJsonPretty(dynamic json) =>
    JsonEncoder.withIndent('  ').convert(json);

/////////////
// OUTPUT: //
/////////////
// Paths from `a` to `f`:
// - [a, b, c, f]
// - [a, b, d, e, f]
//
// Shortest paths:
// - [a, b, c, f]
//
// Graph to Tree:
// {
//   "a": {
//     "b": {
//       "c": {
//         "f": {}
//       },
//       "d": {
//         "e": {
//           "f": "f"
//         }
//       }
//     }
//   }
// }
//
// Graph to ASCII Art Tree:
// a
// └─┬─ b
//   ├─┬─ c
//   │ └──> f
//   └─┬─ d
//     └─┬─ e
//       └──> f ººº
//
