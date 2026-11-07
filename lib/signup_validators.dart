abstract final class SignUpValidators {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _lower = RegExp(r'[a-z]');
  static final _upper = RegExp(r'[A-Z]');
  static final _digit = RegExp(r'[0-9]');
  static final _special = RegExp(r'[!@#$%^&*]');

  static const nicknameMaxLength = 12;
  static const passwordMinLength = 8;

  /// 닉네임은 2~12자입니다.
  static String? nickname(String? value) {
    final nickname = value?.trim() ?? '';
    if (nickname.isEmpty) return '닉네임을 입력해주세요.';
    if (nickname.length < 2) return '닉네임은 2자 이상이어야 합니다.';
    if (nickname.length > nicknameMaxLength) return '닉네임은 12자 이하여야 합니다.';
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return '이메일을 입력해주세요.';
    if (!_emailPattern.hasMatch(email)) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  /// 8자 이상, 소문자·대문자·숫자·`!@#$%^&*` 중 특수문자를 각각 하나 이상 포함해야 합니다.
  /// 클라이언트 검증은 빠른 안내용이며 서버 검증을 대체하지 않습니다.
  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '비밀번호를 입력해주세요.';
    if (password.length < passwordMinLength) return '비밀번호는 8자 이상이어야 합니다.';
    final hasAll =
        _lower.hasMatch(password) &&
        _upper.hasMatch(password) &&
        _digit.hasMatch(password) &&
        _special.hasMatch(password);
    if (!hasAll) {
      return '비밀번호는 대문자·소문자·숫자·특수문자(!@#\$%^&*)를 모두 포함해야 합니다.';
    }
    return null;
  }
}
