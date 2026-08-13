/// End-to-end golden replay with the REAL on-device model: runs every
/// recorded golden duel through the full Dart [predict] pipeline backed by
/// [TfliteYgoModel] (instead of the replay ModelFn used in
/// `packages/ygo_agent`), and requires the pipeline to make the exact same
/// decisions as upstream:
///
///  - identical chosen action (response-space index + response bytes) at
///    every step,
///  - identical `prev_action_idx` threading,
///  - probs / win_rate within [runtimeEpsilon] (runtime rounding only;
///    shortcut steps stay exact because the model is never called there).
///
/// This is the integration-level guarantee that matters for the app: wired
/// into the duel engine, the Dart pipeline answers every golden decision
/// exactly like the upstream Python agent did.
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ygo_agent/ygo_agent.dart';
import 'package:ygo_agent_tflite/ygo_agent_tflite.dart';

import 'golden_support.dart';

void main() {
  final goldenBase = findGoldenBase();
  final goldenRoot = '$goldenBase/golden';
  final modelFile = File('$goldenBase/models/0546_26550M.tflite');
  final codeListFile = File('$goldenBase/models/code_list.txt');
  if (!modelFile.existsSync() || !codeListFile.existsSync()) {
    throw StateError('missing golden artifacts under $goldenBase/models');
  }
  final duelDirs = goldenDuelDirs(goldenRoot);
  if (duelDirs.isEmpty) {
    throw StateError('no golden duels found under $goldenRoot');
  }

  final codeList = CodeList.parse(codeListFile.readAsStringSync());
  final model = TfliteYgoModel.fromFile(modelFile);
  tearDownAll(model.close);

  for (final duelPath in duelDirs) {
    final duelId = duelPath.split(Platform.pathSeparator).last;

    test('end-to-end replay: $duelId', () {
      final stepInputs = stepInputPaths(duelPath);
      expect(stepInputs, isNotEmpty);

      final state = PredictState(codeList: codeList);
      int? prevIdx;

      for (final inputPath in stepInputs) {
        final prefix =
            inputPath.substring(0, inputPath.length - '_input.json'.length);
        final stepId = prefix.split(Platform.pathSeparator).last;
        final reason = '$duelId/$stepId';

        final input = Input.fromJson(readJsonMap(inputPath));
        final pred = readJsonMap('${prefix}_pred.json');
        final shortcut = pred['single_action_shortcut'] as bool;

        final resp = predict(model.modelFn, input, prevIdx, state);

        expect(resp.actionPreds.length, (pred['probs'] as List).length,
            reason: '$reason n_preds');
        final expProbs = [
          for (final e in pred['probs'] as List) (e as num).toDouble(),
        ];
        for (var i = 0; i < expProbs.length; i++) {
          final d = (resp.actionPreds[i].prob - expProbs[i]).abs();
          // Shortcut steps never call the model: exact. Model steps carry
          // only the runtime rounding gap.
          final eps = shortcut ? 0.0 : runtimeEpsilon;
          if (d > eps) {
            fail('$reason prob[$i] diff $d > $eps '
                '(${resp.actionPreds[i].prob} vs ${expProbs[i]})');
          }
          expect(resp.actionPreds[i].response, (pred['responses'] as List)[i],
              reason: '$reason response[$i]');
        }

        final expWinRate = (pred['win_rate'] as num).toDouble();
        if (shortcut) {
          expect(resp.winRate, expWinRate, reason: '$reason win_rate');
        } else {
          final d = (resp.winRate - expWinRate).abs();
          if (d > runtimeEpsilon) {
            fail('$reason win_rate diff $d > $runtimeEpsilon');
          }
        }

        // Choice: first argmax over the response-space probs (-1 entries can
        // never win), matching upstream `int(np.argmax(probs))`.
        var chosen = 0;
        for (var i = 1; i < resp.actionPreds.length; i++) {
          if (resp.actionPreds[i].prob > resp.actionPreds[chosen].prob) {
            chosen = i;
          }
        }
        expect(chosen, pred['chosen_idx'], reason: '$reason chosen_idx');
        expect(resp.actionPreds[chosen].response, pred['chosen_response'],
            reason: '$reason chosen_response');
        expect(pred['prev_action_idx'], prevIdx,
            reason: '$reason prev_action_idx');
        prevIdx = chosen;
      }
    });
  }
}
