import 'package:flutter/foundation.dart';

import '../data/services/member_check_service.dart';
import '../signup_validators.dart';

enum CheckStatus { idle, checking, available, duplicated, error }

const duplicatedNicknameMessage = '이미 사용 중인 닉네임입니다.';
const duplicatedEmailMessage = '이미 사용 중인 이메일입니다.';
const checkFailedMessage = '중복 확인에 실패했습니다. 다시 시도해 주세요.';

/// 입력란 하나의 중복 확인 상태입니다. 닉네임과 이메일이 서로 영향을 주지 않도록 필드마다 따로 둡니다.
class _CheckField {
  _CheckField({required this.validator, required this.duplicatedMessage});

  final String? Function(String?) validator;
  final String duplicatedMessage;

  CheckStatus status = CheckStatus.idle;
  String? errorText;

  /// 서버가 "중복"이라고 마지막으로 응답한 값입니다. 같은 문자열을 다시 입력하면 서버에 묻지 않고 복원합니다.
  String? duplicatedValue;
  String current = '';

  /// 입력이 바뀌거나 새 요청이 시작되면 올립니다. 이전 요청의 응답을 무효화하는 기준입니다.
  int version = 0;

  bool get canCheck =>
      status != CheckStatus.checking &&
      status != CheckStatus.duplicated &&
      validator(current) == null;
}

class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service)
    : _nickname = _CheckField(
        validator: SignUpValidators.nickname,
        duplicatedMessage: duplicatedNicknameMessage,
      ),
      _email = _CheckField(
        validator: SignUpValidators.email,
        duplicatedMessage: duplicatedEmailMessage,
      );

  final MemberCheckService _service;
  final _CheckField _nickname;
  final _CheckField _email;
  bool _disposed = false;

  CheckStatus get nicknameCheckStatus => _nickname.status;
  String? get nicknameErrorText => _nickname.errorText;
  bool get canCheckNickname => _nickname.canCheck;

  CheckStatus get emailCheckStatus => _email.status;
  String? get emailErrorText => _email.errorText;
  bool get canCheckEmail => _email.canCheck;

  /// 닉네임·이메일 모두 서버에서 사용 가능하다고 확인된 상태입니다.
  bool get bothAvailable =>
      _nickname.status == CheckStatus.available &&
      _email.status == CheckStatus.available;

  void onNicknameChanged(String value) => _onChanged(_nickname, value);
  void onEmailChanged(String value) => _onChanged(_email, value);

  Future<void> checkNickname(String value) {
    return _check(_nickname, value, _service.checkNickname);
  }

  Future<void> checkEmail(String value) {
    return _check(_email, value, _service.checkEmail);
  }

  void _onChanged(_CheckField field, String value) {
    final trimmed = value.trim();
    field.current = trimmed;
    field.version++; // 기다리던 이전 응답을 무시합니다.

    if (field.duplicatedValue != null && trimmed == field.duplicatedValue) {
      field.status = CheckStatus.duplicated;
      field.errorText = field.duplicatedMessage;
    } else {
      field.status = CheckStatus.idle;
      field.errorText = null;
    }
    _notify();
  }

  Future<void> _check(
    _CheckField field,
    String value,
    Future<bool> Function(String) request,
  ) async {
    final requested = value.trim();
    if (requested.isEmpty || requested != field.current || !field.canCheck) {
      return;
    }

    final version = ++field.version;
    field.status = CheckStatus.checking;
    field.errorText = null;
    _notify();

    try {
      final available = await request(requested);
      if (_isStale(field, version, requested)) return;
      field.status = available ? CheckStatus.available : CheckStatus.duplicated;
      field.errorText = available ? null : field.duplicatedMessage;
      if (!available) field.duplicatedValue = requested;
    } catch (error) {
      // 통신 실패(DioException)와 정상 중복 응답(available: false)은 다른 상태입니다.
      if (_isStale(field, version, requested)) return;
      debugPrint('중복 확인 실패: $error');
      field.status = CheckStatus.error;
      field.errorText = checkFailedMessage;
    }
    _notify();
  }

  bool _isStale(_CheckField field, int version, String requested) {
    return _disposed || version != field.version || field.current != requested;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _nickname.version++;
    _email.version++;
    super.dispose();
  }
}
