import 'package:http/http.dart' as http;

/// Web 端默认实现：浏览器自行管理 TLS 证书，无法（也无需）在客户端
/// 绕过验证。返回标准 [http.Client]。
http.Client createDeckHttpClient() => http.Client();
