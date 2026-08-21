import 'dart:convert';
import 'package:http/http.dart' as http;

class MatchResult {
  final String address;
  final int port;
  final String password;

  const MatchResult({
    required this.address,
    required this.port,
    required this.password,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      address: json['address'] as String,
      port: (json['port'] as num).toInt(),
      password: json['password'] as String,
    );
  }
}

class MatchService {
  final String _baseUrl = 'https://sapi.moecube.com:444';
  final http.Client _client = http.Client();

  /// [secret] 为 MyCard 认证密钥：登录态下传 u16Secret（时间轮换密钥，
  /// 见 account_mycard），其值即 [MyCardAccountApi.fetchU16Secret] 的
  /// 返回值字符串化。
  Future<MatchResult> match({
    required String arena,
    required String username,
    required String secret,
  }) async {
    final auth = base64Encode(utf8.encode('$username:$secret'));
    final uri = Uri.parse('$_baseUrl/ygopro/match?arena=$arena');
    final response = await _client.post(
      uri,
      headers: {'Authorization': 'Basic $auth'},
    );
    if (response.statusCode == 200) {
      return MatchResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Match failed: ${response.statusCode} ${response.body}');
  }

  void dispose() => _client.close();
}
