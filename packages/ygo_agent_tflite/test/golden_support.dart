/// Shared helpers for the golden tests in this package.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Numeric gate for runtime-vs-golden comparisons.
///
/// The golden tensors were captured with ai-edge-litert's bundled LiteRT
/// build; this package ships flutter_litert's (`2.20.0-dev0+selfbuilt`).
/// Their XNNPACK microkernels round at the ulp level, so bit-exact
/// agreement across runtimes is not physically attainable. Observed worst
/// case over the full golden set: max abs diff ~3e-6 with identical argmax
/// everywhere. The gate below leaves ~30x headroom on magnitude while still
/// catching any real binding/delegate error (which would show as O(1e-1)
/// diffs or flipped actions).
const runtimeEpsilon = 1e-4;

/// Locates `tools/ygo_agent_golden` by walking up from the current
/// directory, so the tests work both from the package directory and from the
/// workspace root. (flutter_litert's macOS dylib resolution requires the
/// workspace-root invocation: it finds the pub cache through
/// `<cwd>/.dart_tool/package_config.json`, which only exists at the root in
/// a pub workspace.)
String findGoldenBase() {
  var dir = Directory.current;
  while (true) {
    final candidate = Directory('${dir.path}/tools/ygo_agent_golden');
    if (candidate.existsSync()) return candidate.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
          'cannot locate tools/ygo_agent_golden from ${Directory.current.path}');
    }
    dir = parent;
  }
}

List<String> goldenDuelDirs(String goldenRoot) => Directory(goldenRoot)
    .listSync()
    .whereType<Directory>()
    .map((d) => d.path)
    .toList()
  ..sort();

/// Step tensor files of one duel, sorted.
List<String> stepTensorPaths(String duelPath) => Directory(duelPath)
    .listSync()
    .whereType<File>()
    .map((f) => f.path)
    .where((p) => p.endsWith('_tensors.npz'))
    .toList()
  ..sort();

/// Step input files of one duel, sorted.
List<String> stepInputPaths(String duelPath) => Directory(duelPath)
    .listSync()
    .whereType<File>()
    .map((f) => f.path)
    .where((p) => p.endsWith('_input.json'))
    .toList()
  ..sort();

Map<String, dynamic> readJsonMap(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Uint8List float32Bytes(Float32List x) =>
    x.buffer.asUint8List(x.offsetInBytes, x.lengthInBytes);
