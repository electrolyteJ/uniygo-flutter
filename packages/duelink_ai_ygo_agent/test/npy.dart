/// Minimal NPY/NPZ reader for the golden tensors.
///
/// Supports exactly what `numpy.savez_compressed` writes for this project:
/// zip-compressed `.npy` members, format version 1.x/2.x headers, C order,
/// dtypes `<f4` and `|u1`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One array from an `.npy` file.
class NpyArray {
  NpyArray({required this.dtype, required this.shape, required this.bytes});

  /// NPY descr, e.g. `<f4` or `|u1`.
  final String dtype;
  final List<int> shape;

  /// Raw little-endian payload.
  final Uint8List bytes;

  int get elementCount => shape.fold(1, (a, b) => a * b);

  Uint8List asUint8({String context = ''}) {
    if (dtype != '|u1') {
      throw StateError('$context: expected dtype |u1, got $dtype');
    }
    if (bytes.length != elementCount) {
      throw StateError('$context: byte length ${bytes.length} != $elementCount');
    }
    return bytes;
  }

  /// Copies the payload into a freshly allocated (4-aligned) Float32List.
  Float32List asFloat32({String context = ''}) {
    if (dtype != '<f4') {
      throw StateError('$context: expected dtype <f4, got $dtype');
    }
    if (bytes.length != elementCount * 4) {
      throw StateError('$context: byte length ${bytes.length} != ${elementCount * 4}');
    }
    final copy = Uint8List(bytes.length)..setAll(0, bytes);
    return copy.buffer.asFloat32List(0, elementCount);
  }

  double asScalarFloat32({String context = ''}) {
    final v = asFloat32(context: context);
    if (v.length != 1) {
      throw StateError('$context: expected scalar, got shape $shape');
    }
    return v[0].toDouble();
  }

  List<double> asFloat32Doubles({String context = ''}) =>
      [for (final v in asFloat32(context: context)) v.toDouble()];
}

final RegExp _descrRe = RegExp(r"'descr':\s*'([^']+)'");
final RegExp _fortranRe = RegExp(r"'fortran_order':\s*(True|False)");
final RegExp _shapeRe = RegExp(r"'shape':\s*\(([^)]*)\)");

/// Parses one `.npy` blob.
NpyArray parseNpy(Uint8List data, {String context = ''}) {
  if (data.length < 10 ||
      data[0] != 0x93 ||
      data[1] != 0x4E || // N
      data[2] != 0x55 || // U
      data[3] != 0x4D || // M
      data[4] != 0x50 || // P
      data[5] != 0x59) {
    throw StateError('$context: not an .npy file');
  }
  final major = data[6];
  final int headerLen;
  final int headerStart;
  if (major == 1) {
    headerLen = data[8] | (data[9] << 8);
    headerStart = 10;
  } else if (major == 2 || major == 3) {
    headerLen = data[8] | (data[9] << 8) | (data[10] << 16) | (data[11] << 24);
    headerStart = 12;
  } else {
    throw StateError('$context: unsupported .npy version $major');
  }
  final header = ascii.decode(
      data.sublist(headerStart, headerStart + headerLen));

  final descrMatch = _descrRe.firstMatch(header);
  final fortranMatch = _fortranRe.firstMatch(header);
  final shapeMatch = _shapeRe.firstMatch(header);
  if (descrMatch == null || fortranMatch == null || shapeMatch == null) {
    throw StateError('$context: unparseable .npy header: $header');
  }
  if (fortranMatch.group(1) == 'True') {
    throw StateError('$context: fortran_order arrays are not supported');
  }
  final shape = [
    for (final part in shapeMatch.group(1)!.split(','))
      if (part.trim().isNotEmpty) int.parse(part.trim()),
  ];
  final bytes = Uint8List.sublistView(data, headerStart + headerLen);
  return NpyArray(dtype: descrMatch.group(1)!, shape: shape, bytes: bytes);
}

/// Parses a `.npz` (zip of `.npy`) blob into a name -> array map.
Map<String, NpyArray> parseNpz(Uint8List zipBytes) {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  final out = <String, NpyArray>{};
  for (final file in archive.files) {
    if (!file.isFile || !file.name.endsWith('.npy')) {
      continue;
    }
    final bytes = file.content;
    final name = file.name.substring(0, file.name.length - '.npy'.length);
    out[name] = parseNpy(bytes, context: name);
  }
  return out;
}
