import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';
import '../widgets/movielog_input_field.dart';

/// 프로필 수정 화면입니다. 이메일은 읽기 전용이고 닉네임만 고칠 수 있습니다.
///
/// - 저장 성공: Snackbar → 마이페이지로 복귀(새 닉네임은 이미 반영되어 있습니다).
/// - 입력·중복 오류: 화면에 남아 필드 아래에 오류를 보여주고 입력값을 유지합니다.
/// - 401: 세션 정리 후 Router가 로그인 화면으로 보냅니다.
/// - 저장하지 않은 변경이 있을 때 뒤로가기를 누르면 확인 Dialog를 보여줍니다(Challenge).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _controller;
  late final TextEditingController _emailController;

  /// 저장했거나 변경을 버리기로 한 뒤에는 PopScope가 막지 않도록 합니다.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final member = context.read<AuthViewModel>().member;
    _controller = TextEditingController(text: member?.nickname ?? '');
    _emailController = TextEditingController(text: member?.email ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// PopScope의 canPop을 풀고 다음 프레임에 화면을 닫습니다(같은 프레임에 pop하면 아직 막혀 있습니다).
  void _leave() {
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/my');
      }
    });
  }

  Future<void> _submit() async {
    final viewModel = context.read<EditProfileViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    FocusScope.of(context).unfocus();
    final success = await viewModel.save(_controller.text);
    if (!mounted) return;

    if (success) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(behavior: SnackBarBehavior.floating, content: Text('프로필을 수정했어요.')),
        );
      _leave(); // 저장이 끝났으므로 변경 확인 없이 닫습니다.
    } else if (viewModel.message != null) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(viewModel.message!)),
        );
    }
  }

  /// 뒤로가기를 눌렀을 때 호출됩니다. 변경이 없으면 바로 나가고, 있으면 확인합니다.
  Future<void> _handleBack(EditProfileViewModel viewModel) async {
    if (viewModel.isSaving) return;
    final leave = !viewModel.hasChanges(_controller.text) || await _confirmDiscard();
    if (!mounted || !leave) return;
    _leave();
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.33),
      builder: (_) => const _DiscardChangesDialog(),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditProfileViewModel>(
      builder: (context, viewModel, _) {
        final saving = viewModel.isSaving;
        return ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            // 저장 중에는 뒤로가기를 막고, 변경이 있을 때는 시스템 뒤로가기도 확인 Dialog를 거칩니다.
            final canLeaveFreely =
                _leaving || (!saving && !viewModel.hasChanges(_controller.text));
            return PopScope(
              canPop: canLeaveFreely,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _handleBack(viewModel);
              },
              child: Scaffold(
                appBar: CommonAppBar(
                  title: '프로필 수정',
                  centerTitle: true,
                  titleStyle: AppTextStyles.subScreenTitle,
                  onBack: () => _handleBack(viewModel),
                ),
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                    child: Column(
                      children: [
                        MovieLogInputField(
                          label: '이메일 (변경할 수 없습니다)',
                          controller: _emailController,
                          readOnlyStyle: true,
                        ),
                        const SizedBox(height: 11),
                        MovieLogInputField(
                          label: '닉네임',
                          controller: _controller,
                          enabled: !saving,
                          maxLength: 12,
                          showCounter: true,
                          textInputAction: TextInputAction.done,
                          errorText: viewModel.nicknameError,
                          onChanged: (_) => viewModel.onNicknameChanged(),
                          onSubmitted: (_) {
                            if (!saving) _submit();
                          },
                        ),
                        const Spacer(),
                        MovieLogButton(
                          label: '저장',
                          width: double.infinity,
                          isLoading: saving,
                          onPressed: saving ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 저장하지 않은 변경이 있을 때 뒤로가기를 누르면 보여주는 확인 Dialog입니다.
/// "나가기"는 `true`(변경을 버리고 마이페이지로), "계속 수정"은 `false`(현재 화면에 머무름)를 돌려줍니다.
class _DiscardChangesDialog extends StatelessWidget {
  const _DiscardChangesDialog();

  // W8 Figma: 제목 20 / Regular, 본문 14 / Regular, 버튼 14 / Bold.
  static const _titleStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 28 / 20,
    letterSpacing: 0,
    color: AppColors.black,
  );

  static const _bodyStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 19 / 14,
    letterSpacing: 0,
    color: AppColors.textMuted,
  );

  static const _buttonStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 19 / 14,
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 38, 16, 38),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('변경 내용을 버릴까요?', textAlign: TextAlign.center, style: _titleStyle),
            const SizedBox(height: 28),
            const Text(
              '저장하지 않은 내용은 사라집니다.',
              textAlign: TextAlign.center,
              style: _bodyStyle,
            ),
            const SizedBox(height: 56),
            Row(
              children: [
                Expanded(
                  child: MovieLogButton(
                    label: '계속 수정',
                    buttonHeight: 44,
                    borderRadius: 14,
                    backgroundColor: AppColors.editFill,
                    foregroundColor: AppColors.violet,
                    labelStyle: _buttonStyle,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: MovieLogButton(
                    label: '나가기',
                    buttonHeight: 44,
                    borderRadius: 14,
                    labelStyle: _buttonStyle,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
