import 'package:flutter/material.dart';

import 'app.dart';

/// 应用入口只负责挂载 [App]；启动期的异步初始化（服务注册、账号/音效偏好、
/// 横屏与系统 UI 等）在 app.dart 的 App.initState 中完成。
void main() => runApp(const App());
