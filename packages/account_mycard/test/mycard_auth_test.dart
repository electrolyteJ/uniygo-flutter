/// account_mycard 测试：账号密码直登（/accounts/signin）、u16Secret、
/// 用户信息查询、登录态仓库的持久化往返。
///
/// mock 请求/响应形态以 YGOMobile-cn-ko-en 源码核实的 MyCard API 规范为准：
///  - 登录请求体：{"account": ..., "password": ...}；
///  - 登录成功：{"token": ..., "success": true, "user": {id, username}}；
///  - u16Secret：{"u16Secret": int}（0 为无效）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:account_mycard/account_mycard.dart';

void main() {
  group('signInWithPassword', () {
    test('成功：真实形态（根级 token + success + user 包装）', () async {
      final mock = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, '/accounts/signin');
        expect(req.headers['Content-Type'], 'application/json');
        final body = jsonDecode(req.body) as Map;
        // 权威规范：字段名是 account，不是 username。
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
      final service = MyCardAuthService(httpClient: mock);
      final account = await service.signInWithPassword('kai', 'pw123');
      expect(account.id, 42);
      expect(account.username, 'kai');
      expect(account.token, 'tok123');
      // 真实形态只有 id/username，其余字段按默认值兜底。
      expect(account.name, '');
      expect(account.email, '');
      expect(account.externalId, 0);
      expect(account.avatarUrl, '');
    });

    test('成功：兼容根级用户对象 + authentication_token 别名', () async {
      final mock = MockClient((req) async {
        final body = jsonDecode(req.body) as Map;
        expect(body['account'], 'kai');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'id': 7,
              'username': 'kai',
              'name': '凯',
              'authentication_token': 'tokABC',
              'external_id': '88',
              'avatar': {'url': 'https://a/c.png'},
            }),
          ),
          200,
        );
      });
      final service = MyCardAuthService(httpClient: mock);
      final account = await service.signInWithPassword('kai', 'pw');
      expect(account.id, 7);
      expect(account.token, 'tokABC');
      expect(account.externalId, 88);
      expect(account.avatarUrl, 'https://a/c.png');
    });

    test('成功：user 包装缺 username 时回退输入用户名', () async {
      final mock = MockClient((req) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({'token': 't', 'success': true, 'user': {'id': 1}})),
          200,
        );
      });
      final service = MyCardAuthService(httpClient: mock);
      final account = await service.signInWithPassword('kai', 'pw');
      expect(account.username, 'kai');
    });

    test('success == false → 用户名或密码错误（即便 HTTP 200）', () async {
      final mock = MockClient((req) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({'success': false})),
          200,
        );
      });
      final service = MyCardAuthService(httpClient: mock);
      expect(
        () => service.signInWithPassword('kai', 'bad'),
        throwsA(
          isA<MyCardAuthException>().having(
            (e) => e.message,
            'message',
            contains('用户名或密码错误'),
          ),
        ),
      );
    });

    test('401/403/422 → 用户名或密码错误', () async {
      for (final code in [401, 403, 422]) {
        final mock = MockClient((req) async => http.Response('x', code));
        final service = MyCardAuthService(httpClient: mock);
        expect(
          () => service.signInWithPassword('kai', 'bad'),
          throwsA(
            isA<MyCardAuthException>().having(
              (e) => e.message,
              'message',
              contains('用户名或密码错误'),
            ),
          ),
        );
      }
    });

    test('500 → HTTP 错误', () async {
      final mock = MockClient((req) async => http.Response('x', 500));
      final service = MyCardAuthService(httpClient: mock);
      expect(
        () => service.signInWithPassword('kai', 'pw'),
        throwsA(
          isA<MyCardAuthException>().having(
            (e) => e.message,
            'message',
            contains('500'),
          ),
        ),
      );
    });

    test('响应缺 token → 抛异常', () async {
      final mock = MockClient(
        (req) async => http.Response.bytes(
          utf8.encode(jsonEncode({'success': true, 'user': {'id': 1, 'username': 'kai'}})),
          200,
        ),
      );
      final service = MyCardAuthService(httpClient: mock);
      expect(
        () => service.signInWithPassword('kai', 'pw'),
        throwsA(
          isA<MyCardAuthException>().having(
            (e) => e.message,
            'message',
            contains('token'),
          ),
        ),
      );
    });

    test('响应非 JSON → 抛异常', () async {
      final mock = MockClient((req) async => http.Response('<html>', 200));
      final service = MyCardAuthService(httpClient: mock);
      expect(
        () => service.signInWithPassword('kai', 'pw'),
        throwsA(isA<MyCardAuthException>()),
      );
    });

    test('网络错误 → 抛异常（消息含网络错误）', () async {
      final mock = MockClient((req) async => throw Exception('socket closed'));
      final service = MyCardAuthService(httpClient: mock);
      expect(
        () => service.signInWithPassword('kai', 'pw'),
        throwsA(
          isA<MyCardAuthException>().having(
            (e) => e.message,
            'message',
            contains('网络错误'),
          ),
        ),
      );
    });
  });

  group('u16Secret', () {
    test('Bearer 请求并解析', () async {
      final mock = MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer tok123');
        return http.Response.bytes(
          utf8.encode(jsonEncode({'u16Secret': 123456})),
          200,
        );
      });
      final service = MyCardAuthService(httpClient: mock);
      expect(await service.fetchU16Secret('tok123'), 123456);
    });

    test('u16Secret 为 0 → 按无效处理（抛异常）', () async {
      final mock = MockClient(
        (req) async =>
            http.Response.bytes(utf8.encode(jsonEncode({'u16Secret': 0})), 200),
      );
      final service = MyCardAuthService(httpClient: mock);
      expect(
        () => service.fetchU16Secret('tok123'),
        throwsA(
          isA<MyCardAuthException>().having(
            (e) => e.message,
            'message',
            contains('无效'),
          ),
        ),
      );
    });

    test('非 200 抛异常', () async {
      final mock = MockClient((req) async => http.Response('x', 401));
      final service = MyCardAuthService(httpClient: mock);
      expect(
        () => service.fetchU16Secret('bad'),
        throwsA(isA<MyCardAuthException>()),
      );
    });

    test('空 token 直接抛异常（不发请求）', () async {
      var called = false;
      final mock = MockClient((req) async {
        called = true;
        return http.Response('{}', 200);
      });
      final service = MyCardAuthService(httpClient: mock);
      expect(
        () => service.fetchU16Secret(''),
        throwsA(isA<MyCardAuthException>()),
      );
      expect(called, isFalse);
    });
  });

  group('fetchUserInfo', () {
    test('解析 user 包装；路径参数 URL 编码；不存在返回 null', () async {
      final mock = MockClient((req) async {
        if (req.url.path.contains('ghost')) return http.Response('x', 404);
        // 路径参数应被 URL 编码。
        expect(req.url.path, '/accounts/users/kai.json');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'user': {'id': 7, 'username': 'kai', 'name': '凯'},
            }),
          ),
          200,
        );
      });
      final service = MyCardAuthService(httpClient: mock);
      final user = await service.fetchUserInfo('kai');
      expect(user?.username, 'kai');
      expect(await service.fetchUserInfo('ghost'), isNull);
    });
  });

  group('MyCardAccountStore', () {
    test('登录/登出通知与持久化往返', () {
      final store = MyCardAccountStore();
      expect(store.isLoggedIn, isFalse);

      var notified = 0;
      store.addListener(() => notified++);
      const account = MyCardAccount(
        id: 1,
        username: 'kai',
        name: '凯',
        email: 'k@x.com',
        token: 'tok',
        externalId: 99,
      );
      store.signIn(account);
      expect(store.isLoggedIn, isTrue);
      expect(notified, 1);

      // 持久化 → 重建
      final restored = MyCardAccountStore(
        persistedJson: store.toPersistedJson(),
      );
      expect(restored.account?.username, 'kai');
      expect(restored.account?.token, 'tok');

      store.signOut();
      expect(store.isLoggedIn, isFalse);
      expect(store.toPersistedJson(), isNull);
      expect(notified, 2);
    });

    test('损坏的持久化数据按未登录处理', () {
      final store = MyCardAccountStore(persistedJson: '{broken');
      expect(store.isLoggedIn, isFalse);
    });
  });
}
