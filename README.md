# graph_explorer

[![pub package](https://img.shields.io/pub/v/graph_explorer.svg?logo=dart&logoColor=00b9fc)](https://pub.dartlang.org/packages/graph_explorer)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Codecov](https://img.shields.io/codecov/c/github/gmpassos/graph_explorer)](https://app.codecov.io/gh/gmpassos/graph_explorer)
[![Dart CI](https://github.com/gmpassos/graph_explorer/actions/workflows/dart.yml/badge.svg?branch=master)](https://github.com/gmpassos/graph_explorer/actions/workflows/dart.yml)
[![GitHub Tag](https://img.shields.io/github/v/tag/gmpassos/graph_explorer?logo=git&logoColor=white)](https://github.com/gmpassos/graph_explorer/releases)
[![New Commits](https://img.shields.io/github/commits-since/gmpassos/graph_explorer/latest?logo=git&logoColor=white)](https://github.com/gmpassos/graph_explorer/network)
[![Last Commits](https://img.shields.io/github/last-commit/gmpassos/graph_explorer?logo=git&logoColor=white)](https://github.com/gmpassos/graph_explorer/commits/master)
[![Pull Requests](https://img.shields.io/github/issues-pr/gmpassos/graph_explorer?logo=github&logoColor=white)](https://github.com/gmpassos/graph_explorer/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/gmpassos/graph_explorer?logo=github&logoColor=white)](https://github.com/gmpassos/graph_explorer)
[![License](https://img.shields.io/github/license/gmpassos/graph_explorer?logo=open-source-initiative&logoColor=green)](https://github.com/gmpassos/graph_explorer/blob/master/LICENSE)

A versatile library for generating and analyzing graphs with support for `JSON` and `ASCIIArtTree`.

## Usage

```dart
import 'dart:convert';
import 'package:graph_explorer/graph_explorer.dart';

void main() async {
  var graph = Graph<String>();

  graph.node('a').getOrAddOutput('b')
    ..addOutput('c')
    ..addOutput('d');
  
  graph.node('c').addOutput('f');
  graph.node('d').getOrAddOutput('e').addOutput('f');
  
  graph.node('f').addOutput('x');
  
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

  print('\nGraph to JSON Tree:');
  print(_encodeJsonPretty(tree));
}

String _encodeJsonPretty(dynamic json) =>
    JsonEncoder.withIndent('  ').convert(json);
```

Output:
```text
Paths from `a` to `f`:
- [a, b, c, f]
- [a, b, d, e, f]

Shortest paths:
- [a, b, c, f]

Graph to JSON Tree:
{
  "a": {
    "b": {
      "c": {
        "f": {
          "x": null
        }
      },
      "d": {
        "e": {
          "f": "f"  // This is a reference to the node `f` above.
        }
      }
    }
  }
}
```

## ascii_art_tree

With the package [ascii_art_tree] you can easly generate an ASCII Art Tree of the `Graph` object:

```dart
import 'package:ascii_art_tree/ascii_art_tree.dart'; // Import extension on `Graph`
import 'package:graph_explorer/graph_explorer.dart';

void main() {
  var graph = Graph<String>();

  // Build the graph as
  // shown in the example above...

  // Build the `ASCIIArtTree`:
  var asciiArtTree = graph.toASCIIArtTree();

  // Generate the ASCII Art text:
  var tree = asciiArtTree.generate();
  print(tree);
}
```

Output:
```text
a
└─┬─ b
  ├─┬─ d
  │ └─┬─ e
  │   └─┬─ f
  │     └──> x
  └─┬─ c
    └─┬─ f ººº
```

[ascii_art_tree]: https://pub.dev/packages/ascii_art_tree

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/gmpassos/graph_explorer/issues

## Author

Graciliano M. Passos: [gmpassos@GitHub][github].

[github]: https://github.com/gmpassos

## Sponsor

Don't be shy, show some love, and become our [GitHub Sponsor][github_sponsors].
Your support means the world to us, and it keeps the code caffeinated! ☕✨

Thanks a million! 🚀😄

[github_sponsors]: https://github.com/sponsors/gmpassos

## License

Dart free & open-source [license](https://github.com/dart-lang/stagehand/blob/master/LICENSE).
