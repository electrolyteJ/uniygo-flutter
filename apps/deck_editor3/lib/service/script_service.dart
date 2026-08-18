import 'dart:io';
import 'package:path_provider/path_provider.dart';

class EffectType {
  final String name;
  final String description;
  final String animationType;

  const EffectType({
    required this.name,
    required this.description,
    required this.animationType,
  });
}

class ScriptService {
  static ScriptService? _instance;
  final Map<int, String> _scriptCache = {};
  final Map<int, List<EffectType>> _effectCache = {};
  String? _scriptDir;

  ScriptService._();

  factory ScriptService() {
    _instance ??= ScriptService._();
    return _instance!;
  }

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _scriptDir = '${dir.path}/scripts';
    await _ensureScriptDir();
  }

  Future<void> _ensureScriptDir() async {
    if (_scriptDir == null) return;
    final dir = Directory(_scriptDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<String?> getScript(int code) async {
    if (_scriptCache.containsKey(code)) {
      return _scriptCache[code];
    }

    if (_scriptDir == null) await init();

    final scriptFile = File('${_scriptDir!}/c$code.lua');
    if (await scriptFile.exists()) {
      final content = await scriptFile.readAsString();
      _scriptCache[code] = content;
      return content;
    }

    return null;
  }

  Future<List<EffectType>> getEffects(int code) async {
    if (_effectCache.containsKey(code)) {
      return _effectCache[code]!;
    }

    final script = await getScript(code);
    if (script == null) {
      _effectCache[code] = [];
      return [];
    }

    final effects = _parseEffects(script);
    _effectCache[code] = effects;
    return effects;
  }

  List<EffectType> _parseEffects(String script) {
    final effects = <EffectType>[];
    final lines = script.split('\n');
    String currentEffect = '';
    bool inEffectBlock = false;

    for (final line in lines) {
      if (line.contains('Effect.CreateEffect')) {
        if (inEffectBlock && currentEffect.isNotEmpty) {
          final effect = _parseEffectBlock(currentEffect);
          if (effect != null) effects.add(effect);
        }
        inEffectBlock = true;
        currentEffect = '$line\n';
      } else if (inEffectBlock) {
        if (line.contains('c:RegisterEffect') || line.contains('return true')) {
          currentEffect += '$line\n';
          final effect = _parseEffectBlock(currentEffect);
          if (effect != null) effects.add(effect);
          inEffectBlock = false;
          currentEffect = '';
        } else {
          currentEffect += '$line\n';
        }
      }
    }

    if (inEffectBlock && currentEffect.isNotEmpty) {
      final effect = _parseEffectBlock(currentEffect);
      if (effect != null) effects.add(effect);
    }

    return effects;
  }

  EffectType? _parseEffectBlock(String block) {
    String effectName = '';
    String effectType = 'effect';
    String animationType = 'default';

    if (block.contains('EFFECT_TYPE_SINGLE')) {
      effectType = '单体效果';
      animationType = 'glow';
    } else if (block.contains('EFFECT_TYPE_FIELD')) {
      effectType = '场地效果';
      animationType = 'field';
    } else if (block.contains('EFFECT_TYPE_IGNITION')) {
      effectType = '起动效果';
      animationType = 'ignition';
    } else if (block.contains('EFFECT_TYPE_TRIGGER')) {
      effectType = '触发效果';
      animationType = 'trigger';
    } else if (block.contains('EFFECT_TYPE_CONTINUOUS')) {
      effectType = '永续效果';
      animationType = 'continuous';
    } else if (block.contains('EFFECT_TYPE_QUICK')) {
      effectType = '速攻效果';
      animationType = 'quick';
    } else if (block.contains('EFFECT_TYPE_COUNTER')) {
      effectType = '反击效果';
      animationType = 'counter';
    } else {
      effectType = '效果';
      animationType = 'default';
    }

    if (block.contains('EFFECT_SPSUMMON_CONDITION') ||
        block.contains('EFFECT_SPSUMMON_PROC')) {
      effectName = '特殊召唤';
      animationType = 'spsummon';
    } else if (block.contains('CATEGORY_DESTROY')) {
      effectName = '破坏';
      animationType = 'destroy';
    } else if (block.contains('CATEGORY_TOGRAVE')) {
      effectName = '送入墓地';
      animationType = 'tograve';
    } else if (block.contains('CATEGORY_DRAW')) {
      effectName = '抽卡';
      animationType = 'draw';
    } else if (block.contains('CATEGORY_SPECIAL_SUMMON')) {
      effectName = '特殊召唤';
      animationType = 'spsummon';
    } else if (block.contains('CATEGORY_REMOVE')) {
      effectName = '除外';
      animationType = 'remove';
    } else if (block.contains('CATEGORY_TOHAND')) {
      effectName = '返回手牌';
      animationType = 'tohand';
    } else if (block.contains('CATEGORY_POSITION_CHANGE')) {
      effectName = '改变表示';
      animationType = 'position';
    } else if (block.contains('CATEGORY_ATKCHANGE') ||
        block.contains('EFFECT_SET_ATTACK')) {
      effectName = '攻击力变化';
      animationType = 'atkchange';
    } else if (block.contains('CATEGORY_DEFCHANGE') ||
        block.contains('EFFECT_SET_DEFENSE')) {
      effectName = '防御力变化';
      animationType = 'defchange';
    } else if (block.contains('CATEGORY_NEGATE')) {
      effectName = '无效效果';
      animationType = 'negate';
    } else if (block.contains('CATEGORY_DISABLE')) {
      effectName = '无效化';
      animationType = 'negate';
    } else if (block.contains('CATEGORY_RECOVER')) {
      effectName = '回复';
      animationType = 'recover';
    } else if (block.contains('CATEGORY_DAMAGE')) {
      effectName = '伤害';
      animationType = 'damage';
    } else if (block.contains('CATEGORY_SEARCH')) {
      effectName = '检索';
      animationType = 'search';
    } else if (block.contains('CATEGORY_DECKDES')) {
      effectName = '卡组破坏';
      animationType = 'deckdes';
    } else if (block.contains('CATEGORY_SUMMON')) {
      effectName = '召唤';
      animationType = 'summon';
    } else {
      effectName = effectType;
    }

    if (effectName.isEmpty) effectName = effectType;

    return EffectType(
      name: effectName,
      description: _extractDescription(block),
      animationType: animationType,
    );
  }

  String _extractDescription(String block) {
    final lines = block.split('\n');
    for (final line in lines) {
      final match = RegExp(r'SetDescription\((.+?)\)').firstMatch(line);
      if (match != null) {
        return match.group(1)!.trim().replaceAll('"', '').replaceAll("'", '');
      }
      final commentMatch = RegExp(r'--(.+)').firstMatch(line);
      if (commentMatch != null) {
        return commentMatch.group(1)!.trim();
      }
    }
    return '';
  }

  String getAnimationType(int code) {
    return _effectCache[code]?.firstOrNull?.animationType ?? 'default';
  }
}