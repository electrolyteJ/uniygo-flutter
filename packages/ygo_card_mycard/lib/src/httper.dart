// ---------------------------------------------------------------------------
// 模块级 HTTP 工具
// ---------------------------------------------------------------------------
import 'package:http/http.dart';
import 'package:ygo_data/ygo_card_deck_exception.dart';

final Client _client = Client();
final timeout = const Duration(seconds: 30);

Future<Response> fetch(String url) async {
  try {
    final response = await _client.get(Uri.parse(url)).timeout(timeout);
    _ensureSuccess(response);
    return response;
  } on YgoCardDeckException {
    rethrow;
  } catch (e) {
    throw _mapError(e);
  }
}

void _ensureSuccess(Response response) {
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  if (response.statusCode == 401 || response.statusCode == 403) {
    throw YgoCardDeckException(
      type: YgoCardDeckErrorType.unauthorized,
      message: 'Unauthorized',
      statusCode: response.statusCode,
    );
  }
  if (response.statusCode == 404) {
    throw YgoCardDeckException(
      type: YgoCardDeckErrorType.notFound,
      message: 'Resource not found',
      statusCode: response.statusCode,
    );
  }
  if (response.statusCode >= 500) {
    throw YgoCardDeckException(
      type: YgoCardDeckErrorType.serverError,
      message: 'Server error',
      statusCode: response.statusCode,
    );
  }
  throw YgoCardDeckException(
    type: YgoCardDeckErrorType.clientError,
    message: 'HTTP ${response.statusCode}',
    statusCode: response.statusCode,
  );
}

YgoCardDeckException _mapError(Object e) {
  if (e is YgoCardDeckException) return e;
  if (e is ClientException) {
    return YgoCardDeckException(
      type: YgoCardDeckErrorType.networkError,
      message: e.message,
      cause: e,
    );
  }
  return YgoCardDeckException(
    type: YgoCardDeckErrorType.unknown,
    message: e.toString(),
    cause: e,
  );
}
