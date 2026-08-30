library duelink_puzzle;

export 'src/puzzle_card_data_loader.dart';
export 'src/puzzle_catalog.dart';
export 'src/puzzle_connection.dart';
export 'src/puzzle_service.dart';

import 'package:applog/console.dart' as console;

import 'package:duelink/duelink.dart';
import 'package:service_loader/service_loader.dart';

import 'duelink_puzzle.dart';

/// 残局本地决斗服务实现 — 基于 ocgcore 包的 [DuelEngine] 残局模式，
/// 房间/协议流程由 [BaseDuelService] 承担。
///
/// 通过 `puzzle://<host>/<category>/<file>.lua` 形式的 URI 选择残局，
/// 见 [PuzzleConnection]。
///
/// [lib] 用于显式指定 ocgcore 动态库（测试环境传入；为 null 时按平台默认
/// 规则查找 libocgcore）。保持可无参构造以满足 `@Service` 注册要求。
@Service(PuzzleDuelService)
class PuzzleDuelService extends BaseDuelService {
  PuzzleDuelService({Object? lib})
      : super(PuzzleConnection(lib: lib));
}

@OnServiceRegister()
onServiceRegister() {
  console.log('duelink_ai_edo.dart onServiceRegister');
}
