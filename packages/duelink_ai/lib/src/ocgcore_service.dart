import 'package:flutter/services.dart';
import 'package:ocgcore/ocgcore.dart';
import 'package:path_provider/path_provider.dart';

class OcgcoreService {
  static OcgcoreService? _instance;
  OcgCore? _ocgCore;
  int? _duel;
  final Map<int, CardData> _cardCache = {};
  bool _initialized = false;

  OcgcoreService._();

  factory OcgcoreService() {
    _instance ??= OcgcoreService._();
    return _instance!;
  }

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    _ocgCore = await createOcgCore();
    if (_ocgCore == null) {
      throw Exception('不支持当前平台');
    }
    _ocgCore!.setScriptReader(_scriptReader as ScriptReader?);
    _ocgCore!.setCardReader(_cardReader as CardReader?);

    _initialized = true;
  }
  Uint8List? _scriptReader(String scriptName, List<int> len)  {
    var name = scriptName;
    if (name.startsWith('./script/')) {
      name = name.substring('./script/'.length);
    }
    rootBundle.load('assets/scripts/$name').then((byteData) {
      return byteData.buffer.asUint8List();
    }).catchError((e) {
      print('Failed to load script $name: $e');
    });
    return null;
  }

  int _cardReader(int code, dynamic data) {
    if (_cardCache.containsKey(code)) {
      return OPERATION_SUCCESS;
    }
    return OPERATION_SUCCESS;
  }

  void cacheCard(CardData card) {
    _cardCache[card.code] = card;
  }
  Future<String> executeCardScript(int code) async {
    if (!_initialized) {
      await init();
    }

    if (_ocgCore == null) {
      return 'ocgcore 未初始化';
    }

    try {
      _duel = _ocgCore!.createDuel(0);
      _ocgCore!.setPlayerInfo(_duel!, 0, 8000, 5, 1);
      _ocgCore!.setPlayerInfo(_duel!, 1, 8000, 5, 1);
      
      _ocgCore!.preloadScript(_duel!, 'constant.lua');
      _ocgCore!.preloadScript(_duel!, 'utility.lua');
      _ocgCore!.preloadScript(_duel!, 'procedure.lua');
      
      await _ocgCore!.preloadCardAsync(code);
      await _ocgCore!.preloadScriptAsync('c${code}.lua');
      
      // 将卡片加入手牌以供测试 (LOCATION_HAND = 0x02)
      _ocgCore!.newCard(_duel!, code, 0, 0, LOCATION_HAND, 0, POS_FACEDOWN);
      print('创建卡片 handle: $_duel, code: $code');
      
      _ocgCore!.startDuel(_duel!, DUEL_TEST_MODE);
      
      int result;
      int status;
      String statusText = '';
      int lastReadLen = 0;

      while (true) {
        result = _ocgCore!.process(_duel!);
        status = result & PROCESSOR_FLAG;
        final msgLen = result & PROCESSOR_BUFFER_LEN;

        if (status == PROCESSOR_WAITING) {
          statusText = '等待中';
        } else if (status == PROCESSOR_END) {
          statusText = '决斗结束';
        } else if (status == PROCESSOR_NONE) {
          statusText = '正常 (消息长度: $msgLen)';
        } else {
          statusText = '未知 ($result)';
        }

        print('process 返回值: $result (状态: $statusText)');

        if (msgLen > 0) {
          final msgBuffer = Uint8List(msgLen);
          lastReadLen = _ocgCore!.getMessage(_duel!, msgBuffer);
          if (lastReadLen > 0) {
            _handleMessage(msgBuffer, lastReadLen);
          }
        }

        if (status == PROCESSOR_END || status == PROCESSOR_WAITING) {
          break;
        }
      }
      
      final logMsg = _ocgCore!.getLogMessage(_duel!);
      if (logMsg.isNotEmpty) {
        print('日志消息: $logMsg');
      }

      _ocgCore!.endDuel(_duel!);
      _duel = null;
      return '脚本执行成功，最终状态: $statusText';
    } catch (e) {
      if (_duel != null) {
        try {
          _ocgCore!.endDuel(_duel!);
        } catch (_) {}
        _duel = null;
      }
      return '脚本执行失败: $e';
    }
  }

  void _handleMessage(Uint8List msgBuffer, int readLen) {
    final ret = msgBuffer[0];
    switch (ret) {
      case MSG_RETRY:
        print('游戏消息: 重试');
        break;
      case MSG_HINT:
        print('游戏消息: 提示');
        break;
      case MSG_WIN:
        final winner = msgBuffer[1];
        final reason = msgBuffer[2];
        print('游戏消息: 胜利 (获胜玩家: $winner, 原因: $reason)');
        break;
      case MSG_SELECT_BATTLECMD:
        print('游戏消息: 选择战斗命令');
        break;
      case MSG_SELECT_IDLECMD:
        print('游戏消息: 选择空闲命令');
        break;
      case MSG_SELECT_EFFECTYN:
        print('游戏消息: 选择效果是否发动');
        break;
      case MSG_SELECT_YESNO:
        print('游戏消息: 选择是/否');
        break;
      case MSG_SELECT_OPTION:
        print('游戏消息: 选择选项');
        break;
      case MSG_SELECT_CARD:
        print('游戏消息: 选择卡牌');
        break;
      case MSG_SELECT_CHAIN:
        print('游戏消息: 选择连锁');
        break;
      case MSG_SELECT_PLACE:
        print('游戏消息: 选择位置');
        break;
      case MSG_SELECT_POSITION:
        print('游戏消息: 选择表示位置');
        break;
      case MSG_SELECT_TRIBUTE:
        print('游戏消息: 选择祭品');
        break;
      case MSG_SELECT_COUNTER:
        print('游戏消息: 选择计数器');
        break;
      case MSG_SELECT_SUM:
        print('游戏消息: 选择召唤方式');
        break;
      case MSG_SELECT_DISFIELD:
        print('游戏消息: 选择场地');
        break;
      case MSG_SORT_CARD:
        print('游戏消息: 排序卡牌');
        break;
      case MSG_SELECT_UNSELECT_CARD:
        print('游戏消息: 选择/取消选择卡牌');
        break;
      case MSG_CONFIRM_DECKTOP:
        print('游戏消息: 确认卡组顶部');
        break;
      case MSG_CONFIRM_CARDS:
        print('游戏消息: 确认卡牌');
        break;
      case MSG_SHUFFLE_DECK:
        print('游戏消息: 洗卡组');
        break;
      case MSG_SHUFFLE_HAND:
        print('游戏消息: 洗手牌');
        break;
      case MSG_SWAP_GRAVE_DECK:
        print('游戏消息: 交换墓地和卡组');
        break;
      case MSG_SHUFFLE_SET_CARD:
        print('游戏消息: 洗牌组设定卡');
        break;
      case MSG_REVERSE_DECK:
        print('游戏消息: 反转卡组');
        break;
      case MSG_DECK_TOP:
        print('游戏消息: 卡组顶部');
        break;
      case MSG_SHUFFLE_EXTRA:
        print('游戏消息: 洗额外卡组');
        break;
      case MSG_NEW_TURN:
        print('游戏消息: 新回合 (玩家: ${msgBuffer[1]})');
        break;
      case MSG_NEW_PHASE:
        print('游戏消息: 新阶段 (阶段: ${msgBuffer[1]})');
        break;
      case MSG_CONFIRM_EXTRATOP:
        print('游戏消息: 确认额外卡组顶部');
        break;
      case MSG_MOVE:
        print('游戏消息: 移动');
        break;
      case MSG_POS_CHANGE:
        print('游戏消息: 表示形式变更');
        break;
      case MSG_SET:
        print('游戏消息: 放置');
        break;
      case MSG_SWAP:
        print('游戏消息: 交换');
        break;
      case MSG_FIELD_DISABLED:
        print('游戏消息: 场地无效');
        break;
      case MSG_SUMMONING:
        print('游戏消息: 召唤中');
        break;
      case MSG_SUMMONED:
        print('游戏消息: 已召唤');
        break;
      case MSG_SPSUMMONING:
        print('游戏消息: 特殊召唤中');
        break;
      case MSG_SPSUMMONED:
        print('游戏消息: 已特殊召唤');
        break;
      case MSG_FLIPSUMMONING:
        print('游戏消息: 反转召唤中');
        break;
      case MSG_FLIPSUMMONED:
        print('游戏消息: 已反转召唤');
        break;
      case MSG_CHAINING:
        print('游戏消息: 连锁中');
        break;
      case MSG_CHAINED:
        print('游戏消息: 已连锁');
        break;
      case MSG_CHAIN_SOLVING:
        print('游戏消息: 连锁处理中');
        break;
      case MSG_CHAIN_SOLVED:
        print('游戏消息: 连锁处理完毕');
        break;
      case MSG_CHAIN_END:
        print('游戏消息: 连锁结束');
        break;
      case MSG_CHAIN_NEGATED:
        print('游戏消息: 连锁被无效');
        break;
      case MSG_CHAIN_DISABLED:
        print('游戏消息: 连锁无效化');
        break;
      case MSG_RANDOM_SELECTED:
        print('游戏消息: 随机选择');
        break;
      case MSG_BECOME_TARGET:
        print('游戏消息: 成为目标');
        break;
      case MSG_DRAW:
        print('游戏消息: 抽卡 (玩家: ${msgBuffer[1]}, 数量: ${msgBuffer[2]})');
        break;
      case MSG_DAMAGE:
        print('游戏消息: 伤害 (玩家: ${msgBuffer[1]}, 数值: ${msgBuffer[2]})');
        break;
      case MSG_RECOVER:
        print('游戏消息: 回复');
        break;
      case MSG_EQUIP:
        print('游戏消息: 装备');
        break;
      case MSG_LPUPDATE:
        print('游戏消息: 生命值更新 (玩家: ${msgBuffer[1]}, 当前生命值: ${msgBuffer[2]})');
        break;
      case MSG_CARD_TARGET:
        print('游戏消息: 卡牌目标');
        break;
      case MSG_CANCEL_TARGET:
        print('游戏消息: 取消目标');
        break;
      case MSG_PAY_LPCOST:
        print('游戏消息: 支付生命值');
        break;
      case MSG_ADD_COUNTER:
        print('游戏消息: 添加计数器');
        break;
      case MSG_REMOVE_COUNTER:
        print('游戏消息: 移除计数器');
        break;
      case MSG_ATTACK:
        print('游戏消息: 攻击');
        break;
      case MSG_BATTLE:
        print('游戏消息: 战斗');
        break;
      case MSG_ATTACK_DISABLED:
        print('游戏消息: 攻击无效');
        break;
      case MSG_DAMAGE_STEP_START:
        print('游戏消息: 伤害步骤开始');
        break;
      case MSG_DAMAGE_STEP_END:
        print('游戏消息: 伤害步骤结束');
        break;
      case MSG_MISSED_EFFECT:
        print('游戏消息: 错过效果时机');
        break;
      case MSG_TOSS_COIN:
        print('游戏消息: 投掷硬币');
        break;
      case MSG_TOSS_DICE:
        print('游戏消息: 投掷骰子');
        break;
      case MSG_ROCK_PAPER_SCISSORS:
        print('游戏消息: 猜拳');
        break;
      case MSG_HAND_RES:
        print('游戏消息: 手牌结果');
        break;
      case MSG_ANNOUNCE_RACE:
        print('游戏消息: 宣言种族');
        break;
      case MSG_ANNOUNCE_ATTRIB:
        print('游戏消息: 宣言属性');
        break;
      case MSG_ANNOUNCE_CARD:
        print('游戏消息: 宣言卡牌');
        break;
      case MSG_ANNOUNCE_NUMBER:
        print('游戏消息: 宣言数值');
        break;
      case MSG_CARD_HINT:
        print('游戏消息: 卡牌提示');
        break;
      case MSG_TAG_SWAP:
        print('游戏消息: 双人对战切换');
        break;
      case MSG_RELOAD_FIELD:
        print('游戏消息: 重新加载场地');
        break;
      case MSG_AI_NAME:
        print('游戏消息: AI 名称');
        break;
      case MSG_SHOW_HINT:
        print('游戏消息: 显示提示');
        break;
      case MSG_PLAYER_HINT:
        print('游戏消息: 玩家提示');
        break;
      case MSG_MATCH_KILL:
        print('游戏消息: 一击必杀');
        break;
      case MSG_CUSTOM_MSG:
        print('游戏消息: 自定义消息');
        break;
      default:
        print('未知游戏消息类型: $ret');
    }
    print('收到游戏消息，长度: $readLen, 数据: ${msgBuffer.sublist(0, readLen)}');
  }
}
