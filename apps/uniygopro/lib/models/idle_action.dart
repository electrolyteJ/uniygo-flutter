class IdleAction {
  final int type;
  final int sequence;
  final int code;
  final int controller;
  final int location;
  final int locationSequence;
  final int position;

  const IdleAction({
    required this.type,
    required this.sequence,
    required this.code,
    required this.controller,
    required this.location,
    this.locationSequence = 0,
    required this.position,
  });
}
