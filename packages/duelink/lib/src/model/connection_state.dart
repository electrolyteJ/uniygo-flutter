/// 网络连接状态。
sealed class ConnectionState {}

class ConnectionDisconnected extends ConnectionState {}

class ConnectionConnecting extends ConnectionState {}

class ConnectionConnected extends ConnectionState {}

class ConnectionError extends ConnectionState {
  /// 错误信息。
  final String message;

  ConnectionError({required this.message});
}
