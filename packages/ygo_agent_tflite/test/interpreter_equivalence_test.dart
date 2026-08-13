/// Runtime equivalence test: feeds every non-shortcut golden step's captured
/// tensors (rstate_before + the four observation tensors) into the real
/// LiteRT interpreter and gates the outputs against the upstream-captured
/// `rstate1_after`/`rstate2_after`/`probs_raw`/`value`.
///
/// Gate: max abs diff <= [runtimeEpsilon] on every output, and identical
/// first-argmax on probs at every step. See `golden_support.dart` for why
/// bit-exactness across runtimes is not the bar here (the golden capture and
/// this runtime are different LiteRT builds; both are correct f32
/// computations). The bit-exact layer of this verification lives in
/// `packages/ygo_agent` (feature encoding vs upstream Python), which stays
/// bit-exact because it is pure Dart.
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ygo_agent/ygo_agent.dart';
import 'package:ygo_agent_tflite/ygo_agent_tflite.dart';

import 'golden_support.dart';
import 'npy.dart';

/// First index of the maximum (numpy-argmax semantics).
int firstArgmax(List<double> xs) {
  var best = 0;
  for (var i = 1; i < xs.length; i++) {
    if (xs[i] > xs[best]) best = i;
  }
  return best;
}

void main() {
  final goldenBase = findGoldenBase();
  final goldenRoot = '$goldenBase/golden';
  final modelFile = File('$goldenBase/models/0546_26550M.tflite');
  if (!modelFile.existsSync()) {
    throw StateError('missing ${modelFile.path}; see tools/ygo_agent_golden');
  }
  final duelDirs = goldenDuelDirs(goldenRoot);
  if (duelDirs.isEmpty) {
    throw StateError('no golden duels found under $goldenRoot');
  }

  // One interpreter for the whole suite; the model is stateless.
  final model = TfliteYgoModel.fromFile(modelFile);
  tearDownAll(model.close);

  test('runtime loads and matches the 0546_26550M I/O contract', () {
    // Construction already verified the contract; this also documents the
    // runtime the gate is pinned to.
    expect(TfliteYgoModel.runtimeVersion, isNotEmpty);
    // ignore: avoid_print
    print('LiteRT runtime: ${TfliteYgoModel.runtimeVersion}');
  });

  for (final duelPath in duelDirs) {
    final duelId = duelPath.split(Platform.pathSeparator).last;

    test('runtime equivalence: $duelId', () {
      final tensors = stepTensorPaths(duelPath);
      expect(tensors, isNotEmpty);

      var checked = 0;
      var worst = 0.0;
      for (final npzPath in tensors) {
        final prefix =
            npzPath.substring(0, npzPath.length - '_tensors.npz'.length);
        final stepId = prefix.split(Platform.pathSeparator).last;
        final reason = '$duelId/$stepId';

        final pred = readJsonMap('${prefix}_pred.json');
        if (pred['single_action_shortcut'] as bool) {
          continue; // The upstream pipeline never called the model here.
        }

        final npz = parseNpz(File(npzPath).readAsBytesSync());
        final input = ModelInput(
          cards: npz['cards_']!.asUint8(context: '$reason cards_'),
          global: npz['global_']!.asUint8(context: '$reason global_'),
          actions: npz['actions_']!.asUint8(context: '$reason actions_'),
          hActions: npz['h_actions_']!.asUint8(context: '$reason h_actions_'),
        );
        final rstate = (
          npz['rstate1_before']!.asFloat32(context: '$reason rstate1_before'),
          npz['rstate2_before']!.asFloat32(context: '$reason rstate2_before'),
        );

        final out = model.modelFn(rstate, input);

        final er1 = npz['rstate1_after']!.asFloat32(context: '$reason rstate1_after');
        final er2 = npz['rstate2_after']!.asFloat32(context: '$reason rstate2_after');
        final eProbs = npz['probs_raw']!.asFloat32Doubles(context: '$reason probs_raw');
        final eValue = npz['value']!.asScalarFloat32(context: '$reason value');

        expect(out.rstate.$1.length, er1.length, reason: '$reason rstate1 len');
        expect(out.rstate.$2.length, er2.length, reason: '$reason rstate2 len');
        expect(out.probs.length, eProbs.length, reason: '$reason probs len');

        for (var i = 0; i < er1.length; i++) {
          final d1 = (out.rstate.$1[i] - er1[i]).abs();
          final d2 = (out.rstate.$2[i] - er2[i]).abs();
          if (d1 > runtimeEpsilon) {
            fail('$reason rstate1[$i] diff $d1 > $runtimeEpsilon');
          }
          if (d2 > runtimeEpsilon) {
            fail('$reason rstate2[$i] diff $d2 > $runtimeEpsilon');
          }
          worst = d1 > worst ? d1 : worst;
          worst = d2 > worst ? d2 : worst;
        }
        for (var i = 0; i < eProbs.length; i++) {
          final d = (out.probs[i] - eProbs[i]).abs();
          if (d > runtimeEpsilon) {
            fail('$reason prob[$i] diff $d > $runtimeEpsilon');
          }
          worst = d > worst ? d : worst;
        }
        final dv = (out.value - eValue).abs();
        if (dv > runtimeEpsilon) {
          fail('$reason value diff $dv > $runtimeEpsilon');
        }
        worst = dv > worst ? dv : worst;

        // Behavioral gate: the chosen action must agree exactly.
        expect(firstArgmax(out.probs), firstArgmax(eProbs),
            reason: '$reason argmax');
        checked++;
      }
      // Duels where every step was a single-action shortcut never invoked
      // the model upstream; nothing to compare here (the end-to-end replay
      // test still covers them, exactly).
      if (checked == 0) return;
      // ignore: avoid_print
      print('$duelId: $checked model steps, worst diff $worst');
    });
  }
}
