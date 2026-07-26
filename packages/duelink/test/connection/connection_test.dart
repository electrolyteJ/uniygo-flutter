import 'package:duelink/duelink.dart';
import 'package:test/test.dart';

void main() {
  group('ConnectionState', () {
    test('enum values exist', () {
      expect(ConnectionState.values.length, 4);
      expect(ConnectionState.disconnected, isA<ConnectionState>());
      expect(ConnectionState.connecting, isA<ConnectionState>());
      expect(ConnectionState.connected, isA<ConnectionState>());
      expect(ConnectionState.error, isA<ConnectionState>());
    });
  });
}
