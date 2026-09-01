/// 平台条件导出：native 用 IOClient（可对白名单镜像关闭证书验证），
/// Web 用标准 Client（浏览器管理证书）。
export 'http_client_factory_stub.dart'
    if (dart.library.io) 'http_client_factory_io.dart';
