import 'package:test/test.dart';
import 'package:ygo_card_deck/models/lflist_info.dart';

void main() {
  group('LflistEntry', () {
    group('fromLine', () {
      test('parses forbidden card', () {
        final entry = LflistEntry.fromLine('12345678 0');
        expect(entry.code, 12345678);
        expect(entry.limit, 0);
        expect(entry.isForbidden, isTrue);
        expect(entry.isLimited, isFalse);
        expect(entry.isSemiLimited, isFalse);
      });

      test('parses limited card', () {
        final entry = LflistEntry.fromLine('89631139 1');
        expect(entry.code, 89631139);
        expect(entry.limit, 1);
        expect(entry.isForbidden, isFalse);
        expect(entry.isLimited, isTrue);
      });

      test('parses semi-limited card', () {
        final entry = LflistEntry.fromLine('83764718 2');
        expect(entry.code, 83764718);
        expect(entry.limit, 2);
        expect(entry.isSemiLimited, isTrue);
      });

      test('throws FormatException on malformed line', () {
        expect(
          () => LflistEntry.fromLine('abc'),
          throwsFormatException,
        );
      });

      test('handles extra whitespace', () {
        final entry = LflistEntry.fromLine('  12345   1  ');
        expect(entry.code, 12345);
        expect(entry.limit, 1);
      });

      test('handles comment after data', () {
        final entry = LflistEntry.fromLine('12345 2 # some comment');
        expect(entry.code, 12345);
        expect(entry.limit, 2);
      });
    });

    group('toJson/fromJson', () {
      test('roundtrips correctly', () {
        final original = LflistEntry(code: 12345, limit: 1);
        final restored = LflistEntry.fromJson(original.toJson());
        expect(restored.code, 12345);
        expect(restored.limit, 1);
      });
    });
  });

  group('LflistInfo', () {
    group('parse', () {
      test('parses complete lflist.conf', () {
        const content = '''
#name 2024.01 OCG
#date 2024-01-01
#description Official OCG banlist
12345678 0
89631139 1
83764718 2
''';

        final lflist = LflistInfo.parse(content);

        expect(lflist.name, '2024.01 OCG');
        expect(lflist.date, '2024-01-01');
        expect(lflist.entries.length, 3);
        expect(lflist.entries[0].code, 12345678);
        expect(lflist.entries[0].limit, 0);
        expect(lflist.entries[1].code, 89631139);
        expect(lflist.entries[1].limit, 1);
        expect(lflist.entries[2].code, 83764718);
        expect(lflist.entries[2].limit, 2);
      });

      test('handles empty content', () {
        final lflist = LflistInfo.parse('');
        expect(lflist.name, '');
        expect(lflist.date, '');
        expect(lflist.entries, isEmpty);
      });

      test('handles content with only comments', () {
        const content = '''
#name Test List
#date 2024-01-01
!header line
!another header
''';

        final lflist = LflistInfo.parse(content);

        expect(lflist.name, 'Test List');
        expect(lflist.date, '2024-01-01');
        expect(lflist.entries, isEmpty);
      });

      test('skips malformed lines', () {
        const content = '''
#name Test
12345678 0
bad line here
87654321 1
''';

        final lflist = LflistInfo.parse(content);

        expect(lflist.entries.length, 2);
        expect(lflist.entries[0].code, 12345678);
        expect(lflist.entries[1].code, 87654321);
      });
    });

    group('getLimit', () {
      late LflistInfo lflist;

      setUp(() {
        lflist = LflistInfo(entries: [
          const LflistEntry(code: 100, limit: 0),
          const LflistEntry(code: 200, limit: 1),
          const LflistEntry(code: 300, limit: 2),
        ]);
      });

      test('returns correct limit for known card', () {
        expect(lflist.getLimit(100), 0);
        expect(lflist.getLimit(200), 1);
        expect(lflist.getLimit(300), 2);
      });

      test('returns 3 (unlimited) for unknown card', () {
        expect(lflist.getLimit(99999), 3);
      });
    });

    group('getLimitText', () {
      late LflistInfo lflist;

      setUp(() {
        lflist = LflistInfo(entries: [
          const LflistEntry(code: 100, limit: 0),
          const LflistEntry(code: 200, limit: 1),
          const LflistEntry(code: 300, limit: 2),
        ]);
      });

      test('returns correct Chinese text', () {
        expect(lflist.getLimitText(100), '禁止');
        expect(lflist.getLimitText(200), '限制');
        expect(lflist.getLimitText(300), '准限制');
        expect(lflist.getLimitText(99999), '无限制');
      });
    });

    group('toJson/fromJson', () {
      test('roundtrips correctly', () {
        final original = LflistInfo(
          name: '2024.01 OCG',
          date: '2024-01-01',
          entries: [
            const LflistEntry(code: 100, limit: 0),
            const LflistEntry(code: 200, limit: 1),
          ],
        );

        final restored = LflistInfo.fromJson(original.toJson());

        expect(restored.name, original.name);
        expect(restored.date, original.date);
        expect(restored.entries.length, original.entries.length);
        expect(restored.entries[0].code, 100);
        expect(restored.entries[0].limit, 0);
      });
    });
  });
}
