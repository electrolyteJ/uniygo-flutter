import 'package:service_loader/service_loader.dart';

import 'puzzle_catalog.dart';

/// 残局目录服务契约 —— 供 UI 层通过 [ServiceFactory] 获取残局列表/详情。
abstract class IPuzzleService implements IService {
  /// 枚举全部残局（仅路径/分类/文件名）。
  Future<List<PuzzleInfo>> listPuzzles();

  /// 读取脚本全文并解析说明/解法。
  Future<PuzzleInfo?> puzzleDetail(PuzzleInfo info);
}

/// 残局目录服务实现 —— 基于 [PuzzleCatalog]（vendor/Puzzles 残局合集）。
@Service(IPuzzleService)
class PuzzleService extends PuzzleCatalog implements IPuzzleService {
  @override
  Future<List<PuzzleInfo>> listPuzzles() => list();

  @override
  Future<PuzzleInfo?> puzzleDetail(PuzzleInfo info) => detail(info);
}
