import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/create_member_request.dart';
import '../signup_validators.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/login_prompt.dart';
import '../widgets/movielog_button.dart';
import '../widgets/movielog_text_form_field.dart';
import '../widgets/terms_checkbox.dart';

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

  /// 형식이 맞고, 닉네임·이메일이 서버에서 사용 가능하다고 확인되고, 약관에 동의했고,
  /// 제출 중이 아닐 때만 가입할 수 있습니다.
  bool _canSubmit(SignUpViewModel viewModel) =>
      SignUpValidators.nickname(_nicknameController.text) == null &&
      SignUpValidators.email(_emailController.text) == null &&
      SignUpValidators.password(_passwordController.text) == null &&
      viewModel.bothAvailable &&
      _agreedToTerms &&
      !viewModel.isSubmitting;

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

  void _goBack(SignUpViewModel viewModel) {
    // 제출 중에는 뒤로가기를 막습니다. 끝나면(성공이든 실패든) 다시 나갈 수 있습니다.
    if (viewModel.isSubmitting) return;
    if (context.canPop()) {
      Navigator.of(context).maybePop();
    } else {
      context.go('/start');
    }
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    final viewModel = context.read<SignUpViewModel>();
    await viewModel.submit(
      CreateMemberRequest(
        email: _emailController.text,
        password: _passwordController.text,
        nickname: _nicknameController.text,
      ),
    );
    if (!mounted) return;

    final memberId = viewModel.createdMemberId;
    if (viewModel.submitStatus == SubmitStatus.success && memberId != null) {
      // 가입 결과의 memberId를 학습용 세션에 보관해 이후 평점 요청에 사용합니다.
      context.read<LearningMemberSession>().setMemberId(memberId);
      context.go('/movies');
      return;
    }

    final message = viewModel.snackbarMessage;
    if (message != null) {
      viewModel.consumeSnackbarMessage();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SignUpViewModel>(
      builder: (context, viewModel, _) {
        return PopScope(
          canPop: !viewModel.isSubmitting,
          child: Scaffold(
            appBar: CommonAppBar(
              title: '회원가입',
              centerTitle: true,
              onBack: () => _goBack(viewModel),
              titleStyle: AppTextStyles.subScreenTitle,
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
                              padding: const EdgeInsets.fromLTRB(18, 48, 18, 43),
                              child: Form(
                                key: _formKey,
                                child: _buildForm(context, viewModel),
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
          ),
        );
      },
    );
  }

  Widget _buildForm(BuildContext context, SignUpViewModel viewModel) {
    final nicknameStatus = viewModel.nicknameCheckStatus;
    final emailStatus = viewModel.emailCheckStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _WelcomeText(),
        const SizedBox(height: 27),
        MovieLogTextFormField(
          label: '닉네임',
          hint: '닉네임을 입력해주세요',
          controller: _nicknameController,
          focusNode: _nicknameFocusNode,
          validator: SignUpValidators.nickname,
          textInputAction: TextInputAction.next,
          serverErrorText: viewModel.nicknameErrorText,
          reserveMessageSpace: true,
          showCheckWhenValid: nicknameStatus == CheckStatus.available,
          statusText: switch (nicknameStatus) {
            CheckStatus.available => '사용 가능한 닉네임입니다.',
            CheckStatus.checking => '닉네임 사용 가능 여부를 확인 중입니다.',
            _ => null,
          },
          statusColor: nicknameStatus == CheckStatus.available
              ? AppColors.success
              : AppColors.info,
          onChanged: viewModel.onNicknameChanged,
          onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
          trailing: MovieLogButton(
            label: '중복 확인',
            isLoading: nicknameStatus == CheckStatus.checking,
            onPressed: viewModel.canCheckNickname && !viewModel.isSubmitting
                ? () => viewModel.checkNickname(_nicknameController.text)
                : null,
            labelStyle: _checkButtonLabel,
          ),
        ),
        const SizedBox(height: 9),
        MovieLogTextFormField(
          label: '이메일',
          hint: '이메일 주소를 입력해주세요',
          controller: _emailController,
          focusNode: _emailFocusNode,
          validator: SignUpValidators.email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          serverErrorText: viewModel.emailErrorText,
          reserveMessageSpace: true,
          showCheckWhenValid: emailStatus == CheckStatus.available,
          statusText: switch (emailStatus) {
            CheckStatus.available => '사용 가능한 이메일입니다.',
            CheckStatus.checking => '이메일 사용 가능 여부를 확인 중입니다.',
            _ => null,
          },
          statusColor: emailStatus == CheckStatus.available
              ? AppColors.success
              : AppColors.info,
          onChanged: viewModel.onEmailChanged,
          onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
          trailing: MovieLogButton(
            label: '중복 확인',
            isLoading: emailStatus == CheckStatus.checking,
            onPressed: viewModel.canCheckEmail && !viewModel.isSubmitting
                ? () => viewModel.checkEmail(_emailController.text)
                : null,
            labelStyle: _checkButtonLabel,
          ),
        ),
        const SizedBox(height: 9),
        MovieLogTextFormField(
          label: '비밀번호',
          hint: '비밀번호를 입력해주세요',
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          validator: SignUpValidators.password,
          // 로컬 validator가 통과한 뒤에도 서버가 거부한 비밀번호면 계속 에러로 보입니다.
          serverErrorText: viewModel.passwordErrorText,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            viewModel.onPasswordChanged();
            _refresh();
          },
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
        MovieLogButton(
          label: '가입하기',
          width: double.infinity,
          isLoading: viewModel.isSubmitting,
          onPressed: _canSubmit(viewModel) ? _submit : null,
        ),
        const SizedBox(height: 54),
        LoginPrompt(
          onLoginPressed: () {
            debugPrint('로그인 링크를 눌렀습니다.');
          },
        ),
      ],
    );
  }

  // W6-01 Figma: 중복 확인 13 / Bold.
  static const _checkButtonLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 18 / 13,
    letterSpacing: 0,
  );
}

class _WelcomeText extends StatelessWidget {
  const _WelcomeText();

  // W6-01 Figma: 제목 16 / Bold, 설명 14 / Regular.
  static const _titleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 22 / 16,
    letterSpacing: 0,
    color: AppColors.black,
  );

  static const _descriptionStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 19 / 14,
    letterSpacing: 0,
    color: AppColors.black,
  );

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text('환영합니다!', textAlign: TextAlign.center, style: _titleStyle),
        SizedBox(height: 3),
        Text(
          '간단한 정보만 입력하고 시작해보세요.',
          textAlign: TextAlign.center,
          style: _descriptionStyle,
        ),
      ],
    );
  }
}
