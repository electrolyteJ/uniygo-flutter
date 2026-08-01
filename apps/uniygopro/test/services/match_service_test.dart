import 'package:flutter_test/flutter_test.dart';
import 'package:uniygopro/services/match_service.dart';

void main() {
  group('MatchResult', () {
    test('fromJson parses correctly', () {
      final json = {'address': 'koishi.momobako.com', 'port': 7211, 'password': 'test123'};
      final result = MatchResult.fromJson(json);
      expect(result.address, 'koishi.momobako.com');
      expect(result.port, 7211);
      expect(result.password, 'test123');
    });
  });
}
