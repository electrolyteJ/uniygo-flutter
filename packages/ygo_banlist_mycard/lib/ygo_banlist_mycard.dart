import 'package:service_loader/service_loader.dart';
import 'src/banlist_service.dart';

export 'src/parse_lf_table.dart';
export 'src/deck_validator.dart';
export 'src/banlist_service.dart';

@OnServiceRegister()
onServiceRegister() {
  preloadBanlist(
    'https://cdn02.moecube.com:444/ygopro-database/zh-CN/lflist.conf',
  );
}
