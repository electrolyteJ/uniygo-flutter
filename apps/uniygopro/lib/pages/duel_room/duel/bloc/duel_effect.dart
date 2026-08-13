import 'package:duelink/duelink.dart';

/// 决斗音效种类：核心只声明"发生了什么"，具体播放实现由 UI 层映射。
enum DuelSound {
  duelStart,
  newTurn,
  newPhase,
  attack,
  damage,
  recover,
  chain,
  chainEnd,
  summon,
  specialSummon,
  flipSummon,
  battle,
  duelWin,
  shuffleDeck,
  damageStep,
  cardDraw,
  cardDestroy,
  posChange,
  setCard,
  coinToss,
  dice,
  dialogOpen,
  zoneOpen,
  zoneClose,
  menuOpen,
  menuClose,
}

/// 核心归约过程中产生的一次性副作用。
///
/// 副作用不适合放进状态快照（会被重复消费），因此走独立通道：
/// 协议类副作用（[DuelSendGameResponse]）由 Bloc 内部消化；
/// 表现类副作用（[DuelSoundEffect]）经 [DuelBloc.effects] 转发给 UI 层。
sealed class DuelEffect {
  const DuelEffect();
}

/// 播放一次决斗音效。
final class DuelSoundEffect extends DuelEffect {
  final DuelSound sound;
  const DuelSoundEffect(this.sound);
}

/// 向服务器发送选择题/操作响应。
final class DuelSendGameResponse extends DuelEffect {
  final CtosGameMsgResponse response;
  const DuelSendGameResponse(this.response);
}
