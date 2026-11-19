import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 화면의 "이메일 저장" 체크박스 값을 보관합니다(Challenge).
///
/// shared_preferences는 평문 저장소라 **이메일만** 저장합니다. 비밀번호와 토큰은 저장하지 않습니다
/// (토큰은 [SecureTokenStorage]가 맡습니다).
class EmailPreference {
  EmailPreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _savedEmailKey = 'saved_login_email';

  final SharedPreferencesAsync _preferences;

  /// 저장된 이메일입니다. 없으면 null입니다.
  Future<String?> read() => _preferences.getString(_savedEmailKey);

  Future<void> save(String email) => _preferences.setString(_savedEmailKey, email.trim());

  /// 체크를 해제한 채 로그인하면 저장된 이메일을 지웁니다.
  Future<void> clear() => _preferences.remove(_savedEmailKey);
}
