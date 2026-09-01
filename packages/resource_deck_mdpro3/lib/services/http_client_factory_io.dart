import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// 已知证书链不完整的社区卡组广场镜像 host。
///
/// 这些镜像的 TLS 证书链缺中间证书（服务器只发叶子证书），Dart 的
/// HttpClient 用 BoringSSL 且不做 AIA 自动补链，严格验证会报
/// `CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate`。
/// 浏览器能正常打开是因为浏览器会通过 AIA 自动获取中间证书。
const Set<String> _insecureMirrorHosts = {
  'zgai.tech',
  'rarnu.xyz',
};

/// native（Android/iOS/macOS/Windows/Linux）实现：对白名单内的镜像 host
/// 关闭证书验证（卡组广场为公开数据，风险可接受）；其余 host 仍严格验证。
http.Client createDeckHttpClient() {
  final io = HttpClient()
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) =>
            _insecureMirrorHosts.contains(host);
  return IOClient(io);
}
