import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/create_member_request.dart';
import '../data/services/sign_up_service.dart';
import '../signup_validators.dart';

enum CheckStatus { idle, checking, available, duplicated, error }

enum SubmitStatus { idle, submitting, success, error }

const duplicatedNicknameMessage = '이미 사용 중인 닉네임입니다.';
const duplicatedEmailMessage = '이미 사용 중인 이메일입니다.';
const checkFailedMessage = '중복 확인에 실패했습니다. 다시 시도해 주세요.';
const unknownSignUpResultMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';

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

  final SignUpService _service;
  final _CheckField _nickname;
  final _CheckField _email;
  bool _disposed = false;

  SubmitStatus submitStatus = SubmitStatus.idle;

  /// 가입 성공 응답의 result에서 읽은 실제 memberId입니다.
  int? createdMemberId;

  /// 비밀번호 형식 위반으로 확인된 400은 입력칸에 바로 붙일 수 있는 필드 단위 오류입니다.
  String? passwordErrorText;

  /// 다른 400과 409(중복)는 어느 입력칸에도 붙지 않는 화면 단위 오류입니다.
  String? snackbarMessage;

  CheckStatus get nicknameCheckStatus => _nickname.status;
  String? get nicknameErrorText => _nickname.errorText;
  bool get canCheckNickname => _nickname.canCheck;

  CheckStatus get emailCheckStatus => _email.status;
  String? get emailErrorText => _email.errorText;
  bool get canCheckEmail => _email.canCheck;

  bool get isSubmitting => submitStatus == SubmitStatus.submitting;

  /// 닉네임·이메일 모두 서버에서 사용 가능하다고 확인된 상태입니다.
  bool get bothAvailable =>
      _nickname.status == CheckStatus.available &&
      _email.status == CheckStatus.available;

  void onNicknameChanged(String value) {
    _clearSubmitError();
    _onChanged(_nickname, value);
  }

  void onEmailChanged(String value) {
    _clearSubmitError();
    _onChanged(_email, value);
  }

  /// 비밀번호를 고치면 서버가 거부했던 값에 대한 오류를 지웁니다.
  void onPasswordChanged() {
    if (passwordErrorText == null) return;
    passwordErrorText = null;
    _notify();
  }

  Future<void> checkNickname(String value) {
    return _check(_nickname, value, _service.checkNickname);
  }

  Future<void> checkEmail(String value) {
    return _check(_email, value, _service.checkEmail);
  }

  /// 제출 중에는 다시 호출해도 무시합니다(중복 탭 방지).
  /// 확인 true와 최종 가입 409는 다릅니다. 확인 직후에도 다른 사용자가 같은 값을 등록할 수 있어
  /// POST의 409가 최종 중복 결과입니다.
  Future<void> submit(CreateMemberRequest request) async {
    if (submitStatus == SubmitStatus.submitting) return;
    submitStatus = SubmitStatus.submitting;
    createdMemberId = null;
    passwordErrorText = null;
    snackbarMessage = null;
    _notify();

    try {
      final response = await _service.signUp(request);
      if (_disposed) return;
      final id = response.result?.memberId;
      if (id == null) throw StateError('회원가입 결과에 memberId가 없습니다.');
      createdMemberId = id;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      final message = writeSignUpErrorMessage(error);
      if (error.response?.statusCode == 400 && message.contains('비밀번호')) {
        passwordErrorText = message;
      } else {
        snackbarMessage = message;
      }
    } catch (error) {
      // memberId가 없는 응답(StateError)이나 형식이 다른 응답은 가입 완료로 표시하지 않습니다.
      if (_disposed) return;
      debugPrint('회원가입 결과 처리 실패: ${error.runtimeType}');
      submitStatus = SubmitStatus.error;
      snackbarMessage = unknownSignUpResultMessage;
    }
    _notify();
  }

  /// 화면이 snackbarMessage를 한 번 보여준 뒤 비웁니다.
  void consumeSnackbarMessage() {
    snackbarMessage = null;
  }

  /// 닉네임·이메일을 바꾸면 이전 제출 오류도 함께 무효화합니다.
  void _clearSubmitError() {
    if (submitStatus == SubmitStatus.error) {
      submitStatus = SubmitStatus.idle;
      snackbarMessage = null;
    }
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
