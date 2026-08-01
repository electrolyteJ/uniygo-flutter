# duelink

`duelink` 是 `uniygopro` 的 ygopro 对战协议封装层，提供：

- `YgoCtosMsg` / `YgoStocMsg` 编解码
- `STOC_GAME_MSG` 到具体 `GameMsg` 的路由
- 常见协议字段的语义 getter，减少业务层直接做位运算

## Quick Start

```dart
import 'dart:typed_data';

import 'package:duelink/duelink.dart';

void decodeStoc(Uint8List wireBytes) {
  final stocs = decodeStocs(wireBytes);

  for (final stoc in stocs) {
    if (stoc.gameMsg case final StocGameMessage gameMsg?) {
      switch (gameMsg.innerMsg) {
        case MsgStart start:
          print('duel start, observer=${start.isObserver}');
        case MsgHint hint:
          print('hint type=${hint.hintType} data=${hint.hintData}');
      }
    }
  }
}
```

```dart
import 'dart:typed_data';

import 'package:duelink/duelink.dart';

void decodeSingleGameMsg(Uint8List payload) {
  final gameMsg = StocGameMessage.decode(payload);

  if (gameMsg.innerMsg case MsgHint hint) {
    print('func=${gameMsg.func} hintType=${hint.hintType}');
  }
}
```

```dart
import 'package:duelink/duelink.dart';

void useSemanticGetters(MsgStart start, MsgUpdateCard update, MsgHint hint) {
  if (start.isObserver) {
    print('current client is observing');
  }

  print('zone=${update.zoneEnum} rawZone=${update.rawZone}');
  print('hintType=${hint.hintType}');
}
```

```dart
import 'package:duelink/duelink.dart';

void sendResponse() {
  final reply = YgoCtosMsg.response(
    CtosGameMsgResponse.selectOption(2),
  );

  final bytes = encodeCtos(reply);
  print('encoded ${bytes.length} bytes');
}
```

```dart
import 'dart:typed_data';

import 'package:duelink/duelink.dart';

void handleFallback(Uint8List payload) {
  final gameMsg = StocGameMessage.decode(payload);

  switch (gameMsg.innerMsg) {
    case MsgUpdateCard update:
      print('structured zone=${update.zoneEnum}, raw=${update.rawData.length} bytes');
    case MsgUnimplemented unknown:
      print('unknown msg=${unknown.command}, raw=${unknown.data.length} bytes');
  }
}
```

## Coverage

协议支持分为三层：

1. 完整结构化
2. 部分结构化，同时保留 `rawData`
3. 未显式支持时回退到 `MsgUnimplemented`

### Fully Structured

已覆盖房间消息和大部分常见 `GameMsg`，包括：

- 房间层：`YgoCtosMsg`、`YgoStocMsg`、`StocTypeChange`、`StocHsPlayerChange`、`StocErrorMsg`
- 对局层：`MsgStart`、`MsgDraw`、`MsgNewTurn`、`MsgNewPhase`、`MsgHint`
- 交互层：`MsgSelectCard`、`MsgSelectPosition`、`MsgSelectOption`、`MsgSelectChain`、`MsgSelectPlace`
- 场面变化：`MsgMove`、`MsgPosChange`、`MsgSet`、`MsgShuffleDeck`、`MsgConfirmCards`
- 连锁 / 战斗 / 结算：`MsgChaining`、`MsgAttack`、`MsgDamage`、`MsgRecover`、`MsgWin`

### Partial Structured With Raw Fallback

以下消息已做结构化解析，但仍保留 `rawData`：

- `MsgUpdateData`
- `MsgUpdateCard`
- `MsgReloadField`
- `MsgSelectSum`
- `MsgSelectUnselectCard`
- `MsgBattle`

### Unimplemented Fallback

未显式建模的 `GameMsg` 会回退为 `MsgUnimplemented`，保留原始命令号和负载，便于调试、录像或后续补充支持。

## API Conventions

优先使用语义 getter：

- `isObserver` / `isFirst` / `isSecond`
- `zoneEnum` / `zoneValue`
- `positionEnum` / `cardPosition`
- `hintType`

需要协议原值时再读取 `rawZone`、`rawPosition`、`rawPlayerType`、`rawData`。

## Reference Notes

实现主要对照：`ocgcore.proto`、`../neos-ts`、`../ygopro`、`../YGOProUnity_V2`。

- `ocgcore.proto` 提供语义参考，但不是原始 ygopro 二进制协议的完整 1:1 镜像
- 当前实现以 `ygopro` 的真实可运行协议和现有前端行为为准
- 某些命名与 protobuf 不完全一致，例如原始协议 `HsToDuelist` 对应语义名 `CtosHsToDuelList`
