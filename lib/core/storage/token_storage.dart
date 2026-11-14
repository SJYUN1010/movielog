import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// accessToken을 저장·조회·삭제하는 규칙을 한곳에 모읍니다.
///
/// 로그인·로그아웃·요청 인증 코드가 FlutterSecureStorage 같은 구체적인 저장소에 직접 의존하지 않게 해서,
/// 저장 방식을 바꾸거나 테스트용 저장소로 대체해도 인증 로직을 그대로 둘 수 있습니다.
/// 비밀번호는 어떤 저장소에도 저장하지 않습니다.
abstract interface class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<String?> readAccessToken();
  Future<void> deleteAccessToken();
}

/// iOS Keychain·Android Keystore 같은 운영체제 보안 영역을 쓰는 구현입니다.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  static const _accessTokenKey = 'movielog.access_token';

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  @override
  Future<void> deleteAccessToken() {
    return _storage.delete(key: _accessTokenKey);
  }
}
