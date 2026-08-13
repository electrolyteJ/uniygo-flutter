// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String helloWorldOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Hello World on $dateString';
  }

  @override
  String get phase_dp => 'Draw Phase';

  @override
  String get phase_sp => 'Standby Phase';

  @override
  String get phase_m1 => 'Main Phase 1';

  @override
  String get phase_bp => 'Battle Phase';

  @override
  String get phase_m2 => 'Main Phase 2';

  @override
  String get phase_ep => 'End Phase';
}
