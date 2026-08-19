/// 连锁链上的一环（发动的卡及其位置）。
class ChainLink {
  final int code;
  final int controller;
  final int zone;
  final int sequence;

  const ChainLink({
    required this.code,
    required this.controller,
    required this.zone,
    required this.sequence,
  });
}
