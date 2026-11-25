/// 人机对决的 AI 偏好：来源（本地 / 233 服）与本地推理模型。
///
/// 设置页「AI 设置」写入，人机对决开局时读取。
library;

import 'package:shared_preferences/shared_preferences.dart';

/// AI 来源设置的持久化键（false = 本地 AI，true = 233 服 AI）。
const String kAiServer233Key = 'home_settings.ai_server_233';

/// 本地推理模型的持久化键（0 端侧 / 1 规则 / 2 远端）。
const String kAiModelKey = 'home_settings.ai_model';

/// 本地推理模型：端侧 ygo-agent / 规则 AI / 远端 HTTP predict。
enum AiModel {
  onDevice('端侧模型'),
  rule('规则 AI'),
  remote('远端模型');

  const AiModel(this.label);

  final String label;
}

/// AI 偏好。
class AiSettings {
  const AiSettings({this.useServer233 = false, this.model = AiModel.onDevice});

  final bool useServer233;
  final AiModel model;

  /// 传给 [RoomOptions.agent]：-1 规则 AI / 0 端侧 / 1 远端。
  int get agent => switch (model) {
    AiModel.rule => -1,
    AiModel.remote => 1,
    AiModel.onDevice => 0,
  };

  AiSettings copyWith({bool? useServer233, AiModel? model}) => AiSettings(
    useServer233: useServer233 ?? this.useServer233,
    model: model ?? this.model,
  );
}

/// 读取偏好（缺省：本地 + 端侧模型）。
Future<AiSettings> loadAiSettings() async {
  final prefs = await SharedPreferences.getInstance();
  final model = (prefs.getInt(kAiModelKey) ?? 0).clamp(0, 2);
  return AiSettings(
    useServer233: prefs.getBool(kAiServer233Key) ?? false,
    model: AiModel.values[model],
  );
}

/// 保存偏好。
Future<void> saveAiSettings(AiSettings settings) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kAiServer233Key, settings.useServer233);
  await prefs.setInt(kAiModelKey, settings.model.index);
}
