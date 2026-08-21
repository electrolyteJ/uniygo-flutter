/// MyCardAccountApi 统一门面测试：登录写 store、退出清 store、注册/资料
/// 网页 URL 常量、SSO 登出 URL 构造、fetchU16Secret 用当前登录态 token。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:account_mycard/account_mycard.dart';

MockClient _signInOkMock() => MockClient((req) async {
  expect(req.method, 'POST');
  expect(req.url.path, '/accounts/signin');
  final body = jsonDecode(req.body) as Map;
  expect(body['account'], 'kai');
  expect(body['password'], 'pw123');
  return http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'token': 'tok123',
        'success': true,
        'user': {'id': 42, 'username': 'kai'},
      }),
    ),
    200,
  );
});

void main() {
  group('signIn / signOut', () {
    test('登录成功：写入登录态并通知监听者', () async {
      final api = MyCardAccountApi(
        authService: MyCardAuthService(httpClient: _signInOkMock()),
      );
      var notified = 0;
      api.addListener(() => notified++);

      expect(api.isLoggedIn, isFalse);
      final account = await api.signIn('kai', 'pw123');

      expect(account.token, 'tok123');
      expect(api.isLoggedIn, isTrue);
      expect(api.account?.username, 'kai');
      expect(notified, 1);
      api.dispose();
    });

    test('登录失败：登录态不变且抛 MyCardAuthException', () async {
      final api = MyCardAccountApi(
        authService: MyCardAuthService(
          httpClient: MockClient((req) async => http.Response('x', 401)),
        ),
      );
      var notified = 0;
      api.addListener(() => notified++);

      expect(
        () => api.signIn('kai', 'bad'),
        throwsA(isA<MyCardAuthException>()),
      );
      await pumpEventQueue();
      expect(api.isLoggedIn, isFalse);
      expect(notified, 0);
      api.dispose();
    });

    test('退出登录：清空登录态并通知监听者', () async {
      final api = MyCardAccountApi(
        authService: MyCardAuthService(httpClient: _signInOkMock()),
      );
      await api.signIn('kai', 'pw123');
      var notified = 0;
      api.addListener(() => notified++);

      api.signOut();
      expect(api.isLoggedIn, isFalse);
      expect(api.account, isNull);
      expect(api.toPersistedJson(), isNull);
      expect(notified, 1);
      api.dispose();
    });

    test('持久化：构造时恢复登录态，登录后可序列化', () async {
      final store = MyCardAccountStore();
      store.signIn(
        const MyCardAccount(
          id: 1,
          username: 'kai',
          name: '',
          email: '',
          token: 'tok',
          externalId: 0,
        ),
      );
      final api = MyCardAccountApi(persistedJson: store.toPersistedJson());
      expect(api.isLoggedIn, isTrue);
      expect(api.account?.username, 'kai');
      expect(api.account?.displayName, 'kai'); // name 缺失回退 username
      api.dispose();
    });
  });

  group('注册 / 资料（网页流程常量）', () {
    test('signUpUrl / userProfileUrl 为已核实常量', () {
      expect(MyCardAccountApi.signUpUrl, 'https://accounts.moecube.com/signup');
      expect(
        MyCardAccountApi.userProfileUrl,
        'https://accounts.moecube.com/profiles',
      );
    });
  });

  group('getSsoLogoutUrl', () {
    test('默认 homeUrl：sso 参数解码后为 return_sso_url=urlencode(home)', () {
      final url = MyCardAccountApi.getSsoLogoutUrl();
      final uri = Uri.parse(url);
      expect(uri.scheme, 'https');
      expect(uri.host, 'accounts.moecube.com');
      expect(uri.path, '/signin');
      final sso = uri.queryParameters['sso'];
      expect(sso, isNotNull);
      expect(
        utf8.decode(base64Decode(sso!)),
        'return_sso_url=https%3A%2F%2Fmycard.world%2Fmobile%2F',
      );
    });

    test('自定义 homeUrl', () {
      final url = MyCardAccountApi.getSsoLogoutUrl(
        homeUrl: 'https://example.com/home',
      );
      final sso = Uri.parse(url).queryParameters['sso']!;
      expect(
        utf8.decode(base64Decode(sso)),
        'return_sso_url=https%3A%2F%2Fexample.com%2Fhome',
      );
    });
  });

  group('fetchU16Secret / fetchProfile', () {
    test('fetchU16Secret 使用当前登录态 token（Bearer 头）', () async {
      final mock = MockClient((req) async {
        if (req.url.path == '/accounts/signin') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'token': 'tok123',
                'success': true,
                'user': {'id': 42, 'username': 'kai'},
              }),
            ),
            200,
          );
        }
        expect(req.url.path, '/accounts/authUser');
        expect(req.headers['Authorization'], 'Bearer tok123');
        return http.Response.bytes(
          utf8.encode(jsonEncode({'u16Secret': 999})),
          200,
        );
      });
      final api = MyCardAccountApi(
        authService: MyCardAuthService(httpClient: mock),
      );
      await api.signIn('kai', 'pw123');
      expect(await api.fetchU16Secret(), 999);
      api.dispose();
    });

    test('未登录 fetchU16Secret 直接抛异常（不发请求）', () async {
      var called = false;
      final api = MyCardAccountApi(
        authService: MyCardAuthService(
          httpClient: MockClient((req) async {
            called = true;
            return http.Response('{}', 200);
          }),
        ),
      );
      expect(() => api.fetchU16Secret(), throwsA(isA<MyCardAuthException>()));
      expect(called, isFalse);
      api.dispose();
    });

    test('fetchProfile 代理公开信息查询；不存在返回 null', () async {
      final mock = MockClient((req) async {
        if (req.url.path.contains('ghost')) return http.Response('x', 404);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'user': {'id': 7, 'username': 'kai', 'name': '凯'},
            }),
          ),
          200,
        );
      });
      final api = MyCardAccountApi(
        authService: MyCardAuthService(httpClient: mock),
      );
      expect((await api.fetchProfile('kai'))?.username, 'kai');
      expect(await api.fetchProfile('ghost'), isNull);
      api.dispose();
    });
  });
}
