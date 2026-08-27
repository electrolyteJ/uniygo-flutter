import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  test('GET / 返回服务信息', () async {
    final response = route.onRequest(_MockRequestContext());
    expect(response.statusCode, HttpStatus.ok);
    final body = await response.json() as Map<String, dynamic>;
    expect(body['service'], 'ygo_deck_server');
  });
}
