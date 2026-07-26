import 'package:test/test.dart';
import 'package:ygo_card_deck/exceptions/ygo_card_deck_exception.dart';

void main() {
  group('YgoCardDeckException', () {
    test('creates with all fields', () {
      final ex = YgoCardDeckException(
        type: YgoCardDeckErrorType.networkError,
        message: 'Connection refused',
        statusCode: 500,
        cause: Exception('timeout'),
      );

      expect(ex.type, YgoCardDeckErrorType.networkError);
      expect(ex.message, 'Connection refused');
      expect(ex.statusCode, 500);
      expect(ex.cause, isA<Exception>());
    });

    test('creates without optional fields', () {
      final ex = YgoCardDeckException(
        type: YgoCardDeckErrorType.parseError,
        message: 'Invalid JSON',
      );

      expect(ex.type, YgoCardDeckErrorType.parseError);
      expect(ex.statusCode, isNull);
      expect(ex.cause, isNull);
    });

    test('toString includes all info', () {
      final ex = YgoCardDeckException(
        type: YgoCardDeckErrorType.serverError,
        message: 'Internal error',
        statusCode: 500,
        cause: Exception('Boom'),
      );

      final str = ex.toString();
      expect(str, contains('serverError'));
      expect(str, contains('Internal error'));
      expect(str, contains('500'));
      expect(str, contains('Boom'));
    });

    test('toString without optional fields', () {
      final ex = YgoCardDeckException(
        type: YgoCardDeckErrorType.unknown,
        message: 'Something happened',
      );

      final str = ex.toString();
      expect(str, contains('unknown'));
      expect(str, contains('Something happened'));
      expect(str, isNot(contains('HTTP')));
      expect(str, isNot(contains('Caused')));
    });
  });

  group('YgoCardDeckErrorType', () {
    test('has all expected values', () {
      expect(YgoCardDeckErrorType.values.length, 8);
      expect(YgoCardDeckErrorType.values, contains(YgoCardDeckErrorType.networkError));
      expect(YgoCardDeckErrorType.values, contains(YgoCardDeckErrorType.serverError));
      expect(YgoCardDeckErrorType.values, contains(YgoCardDeckErrorType.clientError));
      expect(YgoCardDeckErrorType.values, contains(YgoCardDeckErrorType.unauthorized));
      expect(YgoCardDeckErrorType.values, contains(YgoCardDeckErrorType.parseError));
      expect(YgoCardDeckErrorType.values, contains(YgoCardDeckErrorType.timeout));
      expect(YgoCardDeckErrorType.values, contains(YgoCardDeckErrorType.notFound));
      expect(YgoCardDeckErrorType.values, contains(YgoCardDeckErrorType.unknown));
    });
  });
}
