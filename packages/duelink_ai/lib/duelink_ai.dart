library duelink_ai;

export 'src/ai_connection.dart';
export 'src/ai_service_impl.dart';

import 'package:duelink/duelink.dart';
import 'package:duelink_ai/src/ocgcore_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:ocgcore/ocgcore.dart';
import 'package:service_loader/service_loader.dart';
import 'src/ai_connection.dart';
import 'src/ai_service_impl.dart';

/// 注册AI连接到工厂
void registerAiService() {
  ServiceFactory.register(ServiceType.duelink_ai, () => AiDuelServiceImpl());
}

final OcgcoreService _ocgcoreService = OcgcoreService();

Future<void> _initOcgcore() async {
  try {
    await _ocgcoreService.init();
  } catch (e) {
    debugPrint('ocgcore 初始化失败: $e');
  }
}

Future<void> _executeCardScript(CardData card) async {
  try {
    _ocgcoreService.cacheCard(card);
    final result = await _ocgcoreService.executeCardScript(card.code);
  } catch (e) {
  } finally {}
}
