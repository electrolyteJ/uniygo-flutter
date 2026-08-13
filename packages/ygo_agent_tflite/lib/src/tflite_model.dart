/// On-device LiteRT wrapper for the ygo-agent `0546_26550M` model.
///
/// Binds the model's fixed I/O contract (verified against the flatbuffer
/// schema in `tools/ygo_agent_golden`) to ygo_agent's synchronous [ModelFn]
/// so [predict] can drive it directly:
///
/// Inputs (by index):
///  - 0 `inputs`   (1, 512)     f32 — rstate1 (recurrent h)
///  - 1 `inputs_1` (1, 512)     f32 — rstate2 (recurrent c)
///  - 2 `inputs_2` (1, 24, 12)  u8  — legal-action rows
///  - 3 `inputs_3` (1, 160, 41) u8  — card features
///  - 4 `inputs_4` (1, 23)      u8  — global features
///  - 5 `inputs_5` (1, 32, 14)  u8  — history actions
///
/// Outputs (by index):
///  - 0 (1, 512) f32 — next rstate1
///  - 1 (1, 512) f32 — next rstate2
///  - 2 (1, 24)  f32 — action probabilities (first [maxActions] are legal)
///  - 3 (1, 1)   f32 — value head (win rate = (value + 1) / 2)
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_litert/flutter_litert.dart';
import 'package:ygo_agent/ygo_agent.dart';

/// Expected tensor shapes, in element counts (batch 1 folded in).
const _rstateElements = nRnnChannels; // 512
const _actionsElements = maxActions * nActionFeatures; // 24 * 12
const _cardsElements = 2 * maxCards * nCardFeatures; // 160 * 41
const _globalElements = nGlobalFeatures; // 23
const _hActionsElements = nHistoryActions * hActionsFeats; // 32 * 14
const _probsElements = maxActions; // 24

/// The loaded model behind a [ModelFn]. Create one per duel session (the
/// interpreter is stateless; all recurrent state lives in [RState]).
class TfliteYgoModel {
  TfliteYgoModel._(this._interpreter) {
    _verifyContract();
  }

  final Interpreter _interpreter;

  /// Loads the model from a file on disk (native platforms).
  ///
  /// [threads] defaults to 1 to match the single-threaded upstream golden
  /// capture bit-for-bit; raise it for production latency once equivalence
  /// at higher counts has been re-verified.
  factory TfliteYgoModel.fromFile(File modelFile, {int threads = 1}) {
    final options = InterpreterOptions()..threads = threads;
    return TfliteYgoModel._(Interpreter.fromFile(modelFile, options: options));
  }

  /// Loads the model from in-memory bytes (e.g. a Flutter asset loaded via
  /// `rootBundle.load`).
  factory TfliteYgoModel.fromBytes(Uint8List bytes, {int threads = 1}) {
    final options = InterpreterOptions()..threads = threads;
    return TfliteYgoModel._(Interpreter.fromBuffer(bytes, options: options));
  }

  /// The LiteRT runtime version string (diagnostics).
  static String get runtimeVersion => Interpreter.version;

  /// Synchronous model call, shaped for [predict].
  ModelFn get modelFn => _call;

  /// Releases native resources. The instance is unusable afterwards.
  void close() => _interpreter.close();

  ModelOutput _call(RState rstate, ModelInput input) {
    // Byte-exact writes straight into the input tensor buffers.
    _setBytes(0, _floatBytes(rstate.$1));
    _setBytes(1, _floatBytes(rstate.$2));
    _setBytes(2, input.actions);
    _setBytes(3, input.cards);
    _setBytes(4, input.global);
    _setBytes(5, input.hActions);

    _interpreter.invoke();

    // Fresh output handles after invoke: tensor storage may move between
    // invocations (XNNPACK workspace reuse).
    final rstate1 = _readFloat32(0, _rstateElements);
    final rstate2 = _readFloat32(1, _rstateElements);
    final probs = _readFloat32(2, _probsElements);
    final value = _readFloat32(3, 1);

    return ModelOutput(
      rstate: (rstate1, rstate2),
      // f32 -> double is exact; upstream likewise widens the f32 outputs to
      // Python floats.
      probs: [for (final p in probs) p.toDouble()],
      value: value[0].toDouble(),
    );
  }

  void _setBytes(int inputIndex, Uint8List bytes) {
    _interpreter.getInputTensor(inputIndex).data = bytes;
  }

  /// Copies the output tensor at [outputIndex] into an owned Float32List.
  Float32List _readFloat32(int outputIndex, int expectedElements) {
    final tensor = _interpreter.getOutputTensor(outputIndex);
    final src = tensor.data; // unmodifiable view, valid until next invoke
    final elements = src.length ~/ 4;
    if (elements != expectedElements) {
      throw StateError(
        'Output tensor $outputIndex (${tensor.name}) has $elements '
        'float32 elements, expected $expectedElements.',
      );
    }
    final copy = Uint8List(src.length)..setAll(0, src);
    return copy.buffer.asFloat32List(0, elements);
  }

  Uint8List _floatBytes(Float32List x) =>
      x.buffer.asUint8List(x.offsetInBytes, x.lengthInBytes);

  /// Fails fast with a readable message if the loaded model is not the
  /// expected 0546_26550M graph.
  void _verifyContract() {
    const inputs = [
      ('rstate1', TensorType.float32, _rstateElements),
      ('rstate2', TensorType.float32, _rstateElements),
      ('actions', TensorType.uint8, _actionsElements),
      ('cards', TensorType.uint8, _cardsElements),
      ('global', TensorType.uint8, _globalElements),
      ('h_actions', TensorType.uint8, _hActionsElements),
    ];
    const outputs = [
      ('rstate1_next', TensorType.float32, _rstateElements),
      ('rstate2_next', TensorType.float32, _rstateElements),
      ('probs', TensorType.float32, _probsElements),
      ('value', TensorType.float32, 1),
    ];
    for (var i = 0; i < inputs.length; i++) {
      final (label, type, elements) = inputs[i];
      _checkTensor(_interpreter.getInputTensor(i), label, type, elements,
          kind: 'input');
    }
    for (var i = 0; i < outputs.length; i++) {
      final (label, type, elements) = outputs[i];
      _checkTensor(_interpreter.getOutputTensor(i), label, type, elements,
          kind: 'output');
    }
  }

  void _checkTensor(Tensor tensor, String label, TensorType type, int elements,
      {required String kind}) {
    if (tensor.type != type) {
      throw StateError(
        'Model $kind ($label): expected $type, got ${tensor.type}. '
        'Is this the 0546_26550M ygo-agent model?',
      );
    }
    final actual = tensor.numElements();
    if (actual != elements) {
      throw StateError(
        'Model $kind ($label): expected $elements elements, got $actual '
        '(shape ${tensor.shape}).',
      );
    }
  }
}
