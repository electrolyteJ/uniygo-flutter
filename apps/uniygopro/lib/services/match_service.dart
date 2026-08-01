import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';

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
  final String _baseUrl;
  final http.Client _client;

  MatchService({String? baseUrl, http.Client? client})
      : _baseUrl = baseUrl ?? EnvConfig.mycardApiBase,
        _client = client ?? http.Client();

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
      return MatchResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Match failed: ${response.statusCode} ${response.body}');
  }

  void dispose() => _client.close();
}
