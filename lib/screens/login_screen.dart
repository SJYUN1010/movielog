import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../email_preference.dart';
import '../signup_validators.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';
import '../widgets/movielog_input_field.dart';

/// 로그인 화면입니다. 버튼은 [AuthViewModel.login]만 호출하고 직접 화면을 이동하지 않습니다.
/// 성공하면 인증 상태가 signedIn으로 바뀌고 Router가 홈으로 보냅니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  late final AuthViewModel _auth;
  late final EmailPreference _emailPreference;

  bool _saveEmail = false;

  /// 입력 형식 검사 결과입니다. 제출을 눌렀을 때만 보여줍니다.
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthViewModel>();
    _emailPreference = context.read<EmailPreference>();
    _auth.addListener(_showSessionExpired);
    // 이미 만료된 상태로 로그인 화면이 처음 열리는 경우도 처리합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSessionExpired());
    _restoreSavedEmail();
  }

  Future<void> _restoreSavedEmail() async {
    try {
      final saved = await _emailPreference.read();
      if (!mounted || saved == null || saved.isEmpty) return;
      setState(() {
        _emailController.text = saved;
        _saveEmail = true;
      });
    } catch (_) {
      // 저장된 이메일을 못 읽어도 로그인은 계속할 수 있습니다.
    }
  }

  /// 만료로 이동해 온 경우 이유를 한 번만 알립니다. 직접 로그아웃·로그인 실패에서는 켜지지 않는 플래그입니다.
  void _showSessionExpired() {
    if (!mounted || !_auth.sessionExpired) return;
    _auth.consumeSessionExpired();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('로그인이 만료됐어요. 다시 로그인해 주세요.'),
        ),
      );
  }

  @override
  void dispose() {
    _auth.removeListener(_showSessionExpired);
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _emailError = email.isEmpty
          ? '이메일을 입력해 주세요.'
          : SignUpValidators.email(email);
      _passwordError = password.isEmpty ? '비밀번호를 입력해 주세요.' : null;
    });
    if (_emailError != null || _passwordError != null) return;

    FocusScope.of(context).unfocus();
    final saveEmail = _saveEmail;
    await _auth.login(email, password);
    // 로그인에 성공했을 때만 이메일 저장 여부를 반영합니다. 비밀번호는 저장하지 않습니다.
    if (_auth.status == AuthStatus.signedIn) {
      try {
        if (saveEmail) {
          await _emailPreference.save(email);
        } else {
          await _emailPreference.clear();
        }
      } catch (_) {
        // 이메일 저장 실패가 로그인을 막지 않습니다.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final loading = auth.status == AuthStatus.authenticating;
    final enabled = !loading && !auth.storageCleanupInProgress;

    return Scaffold(
      appBar: CommonAppBar(
        title: '로그인',
        centerTitle: true,
        titleStyle: AppTextStyles.subScreenTitle,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 70, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: SvgPicture.asset(
                      'assets/logos/movielog_logo.svg',
                      width: 72,
                      height: 72,
                      semanticsLabel: 'MovieLog 로고',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'MovieLog에 로그인',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      height: 30 / 22,
                      letterSpacing: 0,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 36),
                  MovieLogInputField(
                    label: '이메일',
                    controller: _emailController,
                    enabled: enabled,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    errorText: _emailError,
                    onChanged: (_) {
                      if (_emailError != null) setState(() => _emailError = null);
                      _auth.clearMessage();
                    },
                    onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  ),
                  const SizedBox(height: 11),
                  // 로그인 실패(AUTH401_1)는 Figma처럼 비밀번호 입력창 아래에 보여줍니다.
                  MovieLogInputField(
                    label: '비밀번호',
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    enabled: enabled,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    errorText: _passwordError ?? auth.message,
                    onChanged: (_) {
                      if (_passwordError != null) setState(() => _passwordError = null);
                      _auth.clearMessage(); // 고치기 시작하면 이전 로그인 실패 문구를 지웁니다.
                    },
                    onSubmitted: (_) {
                      if (enabled) _submit();
                    },
                  ),
                  _SaveEmailRow(
                    value: _saveEmail,
                    onChanged: enabled ? (value) => setState(() => _saveEmail = value) : null,
                  ),
                  const SizedBox(height: 32),
                  MovieLogButton(
                    label: '로그인',
                    width: double.infinity,
                    isLoading: loading,
                    onPressed: enabled ? _submit : null,
                  ),
                  const SizedBox(height: 18),
                  _SignUpPrompt(onPressed: enabled ? () => context.go('/signup') : null),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveEmailRow extends StatelessWidget {
  const _SaveEmailRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged == null ? null : (checked) => onChanged!(checked ?? false),
            activeColor: AppColors.violet,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: const Text(
            '이메일 저장',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 18 / 13,
              letterSpacing: 0,
              color: AppColors.black,
            ),
          ),
        ),
      ],
    );
  }
}

class _SignUpPrompt extends StatelessWidget {
  const _SignUpPrompt({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '계정이 없나요?',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 16 / 12,
            letterSpacing: 0,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '회원가입',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 16 / 12,
                letterSpacing: 0,
                color: AppColors.violet,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
