import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'signup_validators.dart';
import 'theme/app_text_styles.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/login_prompt.dart';
import 'widgets/movielog_text_form_field.dart';
import 'widgets/submit_button.dart';
import 'widgets/terms_checkbox.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _agreedToTerms = false;

  bool get _canSubmit =>
      SignUpValidators.nickname(_nicknameController.text) == null &&
      SignUpValidators.email(_emailController.text) == null &&
      SignUpValidators.password(_passwordController.text) == null &&
      _agreedToTerms;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(
        title: '회원가입',
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxFormWidth = constraints.maxWidth >= 700 ? 560.0 : double.infinity;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxFormWidth),
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                '환영합니다!\n간단한 정보만 입력하고 시작해보세요.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyDescription,
                              ),
                              const SizedBox(height: 48),
                              MovieLogTextFormField(
                                label: '닉네임',
                                hint: '닉네임을 입력해주세요',
                                controller: _nicknameController,
                                focusNode: _nicknameFocusNode,
                                validator: SignUpValidators.nickname,
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => _refresh(),
                                onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                              ),
                              const SizedBox(height: 16),
                              MovieLogTextFormField(
                                label: '이메일',
                                hint: '이메일 주소를 입력해주세요',
                                controller: _emailController,
                                focusNode: _emailFocusNode,
                                validator: SignUpValidators.email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => _refresh(),
                                onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                              ),
                              const SizedBox(height: 16),
                              MovieLogTextFormField(
                                label: '비밀번호',
                                hint: '비밀번호를 입력해주세요',
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                validator: SignUpValidators.password,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onChanged: (_) => _refresh(),
                                onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                              ),
                              const Spacer(),
                              const SizedBox(height: 24),
                              TermsCheckbox(
                                value: _agreedToTerms,
                                onChanged: (value) {
                                  setState(() => _agreedToTerms = value);
                                },
                              ),
                              const SizedBox(height: 24),
                              SubmitButton(
                                label: '가입하기',
                                onPressed: _canSubmit ? _submit : null,
                              ),
                              const SizedBox(height: 40),
                              LoginPrompt(
                                onLoginPressed: () {
                                  debugPrint('로그인 링크를 눌렀습니다.');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
