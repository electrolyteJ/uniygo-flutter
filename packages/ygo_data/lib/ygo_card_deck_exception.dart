/// ygo_card_deck 统一的异常类型
class YgoCardDeckException implements Exception {
  /// 错误类型
  final YgoCardDeckErrorType type;

  /// 人类可读消息
  final String message;

  /// HTTP 状态码（如果来自 HTTP 响应）
  final int? statusCode;

  /// 原始错误
  final Object? cause;

  const YgoCardDeckException({
    required this.type,
    required this.message,
    this.statusCode,
    this.cause,
  });

  @override
  String toString() {
    final buf = StringBuffer('YgoCardDeckException($type): $message');
    if (statusCode != null) buf.write(' [HTTP $statusCode]');
    if (cause != null) buf.write(' Caused by: $cause');
    return buf.toString();
  }
}

/// 分类错误类型
enum YgoCardDeckErrorType {
  /// 网络连接失败
  networkError,

  /// 服务端错误 (HTTP 5xx)
  serverError,

  /// 客户端错误 (HTTP 4xx)
  clientError,

  /// 认证失败 (HTTP 401/403)
  unauthorized,

  /// 数据解析失败
  parseError,

  /// 请求超时
  timeout,

  /// 资源不存在
  notFound,

  /// 未知错误
  unknown,
}
