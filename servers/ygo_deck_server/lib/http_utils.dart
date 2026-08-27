/// 统一错误/成功响应工具。
library;

import 'package:dart_frog/dart_frog.dart';

/// JSON 错误响应。
Response jsonError(int status, String message) => Response.json(
  statusCode: status,
  body: {'success': false, 'error': message},
);

/// 统一成功响应。
Response jsonSuccess([Map<String, dynamic>? extra]) => Response.json(
  body: {'success': true, ...?extra},
);
