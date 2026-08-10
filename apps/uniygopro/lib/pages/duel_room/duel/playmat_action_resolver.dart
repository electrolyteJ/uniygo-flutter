import 'package:duelink/duelink.dart';

import '../../../models/BattleAction.dart';
import '../../../models/IdleAction.dart';
import 'duel_field_store.dart';

class PlaymatResolvedAction {
  final String label;
  final int response;
  final PlaymatResolvedActionKind kind;
  final int? code;
  final int? controller;
  final int? location;
  final int? sequence;

  const PlaymatResolvedAction({
    required this.label,
    required this.response,
    this.kind = PlaymatResolvedActionKind.unknown,
    this.code,
    this.controller,
    this.location,
    this.sequence,
  });
}

enum PlaymatResolvedActionKind {
  summon,
  specialSummon,
  positionChange,
  monsterSet,
  spellSet,
  activate,
  attack,
  directAttack,
  toBattlePhase,
  toMainPhase2,
  toEndPhase,
  unknown,
}

class PlaymatActionResolver {
  static List<PlaymatResolvedAction> resolveHandActions(
    DuelFieldStore duelStore,
    int myController,
    int sequence,
  ) {
    if (!duelStore.hasIdleCommandWindow ||
        !duelStore.ownsCurrentWindow(myController)) {
      return const [];
    }

    return duelStore.selectedIdleActions
        .where(
          (action) =>
              action.controller == myController &&
              action.location == CARD_ZONE_HAND &&
              action.locationSequence == sequence,
        )
        .map(_resolveIdleAction)
        .toList(growable: false);
  }

  static List<PlaymatResolvedAction> resolveFieldActions(
    DuelFieldStore duelStore,
    int player,
    int controller,
    int location,
    int sequence,
    int? code,
  ) {
    if (!duelStore.ownsCurrentWindow(player)) {
      return const [];
    }

    final actions = <PlaymatResolvedAction>[];
    if (duelStore.hasIdleCommandWindow) {
      final idleActions = duelStore.selectedIdleActions
          .where(
            (action) =>
                action.controller == controller && action.location == location,
          )
          .toList(growable: false);
      final exactIdleActions = idleActions
          .where((action) => action.locationSequence == sequence)
          .map(_resolveIdleAction);
      actions.addAll(exactIdleActions);
      if (actions.isEmpty && code != null && code > 0) {
        final codeMatchedActions = idleActions
            .where((action) => action.code == code)
            .map(_resolveIdleAction)
            .toList(growable: false);
        if (codeMatchedActions.length == 1) {
          actions.addAll(codeMatchedActions);
        }
      }
    }
    if (duelStore.hasBattleCommandWindow) {
      actions.addAll(
        duelStore.selectedBattleActions
            .where(
              (action) =>
                  action.attackerController == controller &&
                  action.attackerLocation == location &&
                  action.attackerSequence == sequence,
            )
            .map(_resolveBattleAction),
      );
    }
    return actions;
  }

  static List<PlaymatResolvedAction> resolveZoneActions(
    DuelFieldStore duelStore,
    int player,
    int controller,
    int location,
    int code,
    int? sequence,
  ) {
    if (!duelStore.ownsCurrentWindow(player) || !_isBrowserZone(location)) {
      return const [];
    }

    final actions = <PlaymatResolvedAction>[];
    if (duelStore.hasIdleCommandWindow) {
      actions.addAll(
        duelStore.selectedIdleActions
            .where(
              (action) =>
                  action.code == code &&
                  action.controller == controller &&
                  action.location == location &&
                  (sequence == null || action.locationSequence == sequence),
            )
            .map(_resolveIdleAction),
      );
    }
    // 战斗阶段窗口的 activate 组也可能包含墓地/除外/额外的卡。
    if (duelStore.hasBattleCommandWindow) {
      actions.addAll(
        duelStore.selectedBattleActions
            .where(
              (action) =>
                  action.type == 0 &&
                  action.code == code &&
                  action.attackerController == controller &&
                  action.attackerLocation == location &&
                  (sequence == null || action.attackerSequence == sequence),
            )
            .map(_resolveBattleAction),
      );
    }
    return actions;
  }

  static List<PlaymatResolvedAction> resolvePhaseActions(
    DuelFieldStore duelStore,
    int player,
  ) {
    if (!duelStore.ownsCurrentWindow(player)) {
      return const [];
    }

    if (duelStore.hasIdleCommandWindow) {
      return [
        if (duelStore.enableBp)
          const PlaymatResolvedAction(
            label: '进入战斗阶段',
            response: 6,
            kind: PlaymatResolvedActionKind.toBattlePhase,
          ),
        if (duelStore.enableEp)
          const PlaymatResolvedAction(
            label: '结束回合',
            response: 7,
            kind: PlaymatResolvedActionKind.toEndPhase,
          ),
      ];
    }

    if (duelStore.hasBattleCommandWindow) {
      return [
        if (duelStore.enableM2)
          const PlaymatResolvedAction(
            label: '进入主要阶段2',
            response: 2,
            kind: PlaymatResolvedActionKind.toMainPhase2,
          ),
        if (duelStore.enableEp)
          const PlaymatResolvedAction(
            label: '结束回合',
            response: 3,
            kind: PlaymatResolvedActionKind.toEndPhase,
          ),
      ];
    }

    return const [];
  }

  static PlaymatResolvedAction _resolveIdleAction(IdleAction action) {
    return PlaymatResolvedAction(
      label: _idleActionLabel(action),
      response: action.sequence,
      kind: _idleActionKind(action),
      code: action.code,
      controller: action.controller,
      location: action.location,
      sequence: action.locationSequence,
    );
  }

  static PlaymatResolvedAction _resolveBattleAction(BattleAction action) {
    return PlaymatResolvedAction(
      label: _battleActionLabel(action),
      response: action.sequence,
      kind: _battleActionKind(action),
      code: action.code,
      controller: action.attackerController,
      location: action.attackerLocation,
      sequence: action.attackerSequence,
    );
  }

  static String _idleActionLabel(IdleAction action) {
    switch (action.type) {
      case 0:
        return '召唤';
      case 1:
        return '特殊召唤';
      case 2:
        return '改变表示形式';
      case 3:
      case 4:
        return '盖放';
      case 5:
        return '发动效果';
      default:
        return '行动 #${action.sequence}';
    }
  }

  static String _battleActionLabel(BattleAction action) {
    switch (action.type) {
      case 0:
        return '发动效果';
      case 1:
        return action.directAttack ? '直接攻击' : '攻击';
      default:
        return '行动 #${action.sequence}';
    }
  }

  static PlaymatResolvedActionKind _idleActionKind(IdleAction action) {
    switch (action.type) {
      case 0:
        return PlaymatResolvedActionKind.summon;
      case 1:
        return PlaymatResolvedActionKind.specialSummon;
      case 2:
        return PlaymatResolvedActionKind.positionChange;
      case 3:
        return PlaymatResolvedActionKind.monsterSet;
      case 4:
        return PlaymatResolvedActionKind.spellSet;
      case 5:
        return PlaymatResolvedActionKind.activate;
      default:
        return PlaymatResolvedActionKind.unknown;
    }
  }

  static PlaymatResolvedActionKind _battleActionKind(BattleAction action) {
    switch (action.type) {
      case 0:
        return PlaymatResolvedActionKind.activate;
      case 1:
        return action.directAttack
            ? PlaymatResolvedActionKind.directAttack
            : PlaymatResolvedActionKind.attack;
      default:
        return PlaymatResolvedActionKind.unknown;
    }
  }

  static bool _isBrowserZone(int location) {
    return location == CARD_ZONE_GRAVE ||
        location == CARD_ZONE_REMOVED ||
        location == CARD_ZONE_EXTRA;
  }
}
