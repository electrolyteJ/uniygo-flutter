/// MyCard 账号模型（SSO 回调载荷反序列化而来）。
///
/// 字段与 moecube accounts 的 SSO payload 一一对应
/// （参照 neos-ts `stores/accountStore.ts` 的 User）。
library;

class MyCardAccount {
  const MyCardAccount({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.token,
    required this.externalId,
    this.avatarUrl = '',
  });

  /// 账号 id（moecube 内部主键）。
  final int id;

  /// 登录名（对决服务器与匹配 API 的用户名）。
  ///
  /// 注意：登录接口（/accounts/signin）真实响应的 user 只有 id 与
  /// username 两个字段，其 username 即对决服用户名；name/email/
  /// external_id/avatar_url 可能缺失（由默认值兜底）。
  final String username;

  /// 展示名。
  final String name;

  /// 邮箱。
  final String email;

  /// SSO 会话令牌（Bearer，调 sapi 的 authUser 等接口用）。
  final String token;

  /// 外部用户 id（匹配认证的可选密钥之一，见 u16Secret）。
  final int externalId;

  /// 头像 URL。
  final String avatarUrl;

  /// 展示用名字：真实登录响应不含 name 时回退 username。
  String get displayName => name.isNotEmpty ? name : username;

  factory MyCardAccount.fromJson(Map<String, dynamic> json) => MyCardAccount(
    id: _toInt(json['id']) ?? 0,
    username: json['username'] as String? ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    token: json['token'] as String? ?? '',
    externalId: _toInt(json['external_id']) ?? 0,
    avatarUrl: json['avatar_url'] as String? ?? '',
  );

  /// SSO 载荷是 URL 查询串（全是字符串），sapi JSON 是数值——两者兼容。
  static int? _toInt(Object? v) => switch (v) {
    num n => n.toInt(),
    String s => int.tryParse(s),
    _ => null,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'name': name,
    'email': email,
    'token': token,
    'external_id': externalId,
    'avatar_url': avatarUrl,
  };
}
