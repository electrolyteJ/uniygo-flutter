// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String helloWorldOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Hello World on $dateString';
  }

  @override
  String get phase_dp => '抽卡阶段';

  @override
  String get phase_sp => '准备阶段';

  @override
  String get phase_m1 => '主要阶段 1';

  @override
  String get phase_bp => '战斗阶段';

  @override
  String get phase_m2 => '主要阶段 2';

  @override
  String get phase_ep => '结束阶段';
}
