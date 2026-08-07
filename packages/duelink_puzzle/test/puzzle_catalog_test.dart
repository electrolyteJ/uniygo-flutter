import 'package:duelink_puzzle/duelink_puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('枚举 vendor/Puzzles 残局列表', () async {
    final catalog = PuzzleCatalog();
    final puzzles = await catalog.list();

    expect(puzzles, isNotEmpty, reason: 'ygo_puzzles（根 vendor/Puzzles）应包含残局脚本');
    expect(
      puzzles.every((p) => p.scriptName.startsWith('puzzle/')),
      isTrue,
      reason: 'scriptName 应以 puzzle/ 前缀开头',
    );
    expect(
      puzzles.any((p) => p.category == 'World Championship'),
      isTrue,
      reason: '应包含 World Championship 分类',
    );

    // 根目录的 Puzzle Creator.lua 是制作工具，不应被当作残局
    expect(
      puzzles.any((p) => p.fileName == 'Puzzle Creator'),
      isFalse,
    );

    print('共枚举到 ${puzzles.length} 个残局');
    final categories = puzzles.map((p) => p.category).toSet();
    print('分类: ${categories.join(', ')}');
  });

  test('解析残局元数据（WCS2006#01）', () async {
    final catalog = PuzzleCatalog();
    final puzzles = await catalog.list();
    final wcs01 = puzzles.firstWhere(
      (p) => p.fileName.contains('01_Warriors of Darkness'),
      orElse: () => throw StateError('缺少 [WCS2006]01 残局脚本'),
    );

    expect(wcs01.category, 'World Championship');
    expect(wcs01.scriptName,
        'puzzle/World Championship/[WCS2006]01_Warriors of Darkness.lua');

    final detail = await catalog.detail(wcs01);
    expect(detail, isNotNull);
    expect(detail!.description, isNotNull,
        reason: '脚本应含 --[[message]] 说明块');
    expect(detail.description, contains('Your Starting LP: 600'));
    expect(detail.solution, isNotNull, reason: '脚本应含 --[[Solution]] 解法块');
    expect(detail.solution, contains('Cheerful Coffin'));
  });

  test('PuzzleCatalog.parse 纯函数解析', () {
    const text = '''
Debug.SetAIName("test")
--[[message
Win this turn.
]]
Debug.AddCard(89631139,1,1,LOCATION_MZONE,1,POS_FACEUP_ATTACK)
--[[
Solution:
Just attack.
]]
''';
    final info = PuzzleCatalog.parse('puzzle/Misc/test_puzzle.lua', text);
    expect(info.category, 'Misc');
    expect(info.fileName, 'test_puzzle');
    expect(info.displayName, 'test puzzle');
    expect(info.description, 'Win this turn.');
    expect(info.solution, contains('Just attack.'));
  });
}
