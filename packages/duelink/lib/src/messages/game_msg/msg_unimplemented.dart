import 'dart:typed_data';

/// 未显式支持的 GameMsg 子消息占位类型。
///
/// 用于保留原始 `MSG_*` 命令号，避免把未知消息误解成其他已知类型。
class MsgUnimplemented {
  final int command;
  final Uint8List data;

  const MsgUnimplemented({required this.command, required this.data});

  Uint8List encode() => data;

  static MsgUnimplemented decode(int command, Uint8List data) =>
      MsgUnimplemented(command: command, data: data);

  @override
  String toString() =>
      'MsgUnimplemented(command:$command dataLen:${data.length})';
}
