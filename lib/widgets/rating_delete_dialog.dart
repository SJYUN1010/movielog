import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'movielog_button.dart';

/// 평점 삭제 확인 Dialog입니다. 되돌릴 수 없는 동작이라 확인 없이 바로 실행하지 않습니다.
///
/// - 취소하면 `false`를 돌려주고 삭제 요청을 보내지 않습니다.
/// - [onConfirm]이 있으면(단일 삭제) 삭제하는 동안 Dialog를 유지하며 버튼을 로딩 상태로 두고,
///   성공하면 `true`로 닫습니다. 실패하면 열린 채로 오류 문구를 보여줍니다.
/// - [onConfirm]이 없으면(다중 삭제) 확인 즉시 `true`로 닫습니다. 이후 로딩은 화면이 맡습니다.
class RatingDeleteDialog extends StatefulWidget {
  const RatingDeleteDialog({super.key, this.onConfirm});

  final Future<void> Function()? onConfirm;

  static Future<bool?> show(
    BuildContext context, {
    Future<void> Function()? onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.33),
      builder: (_) => RatingDeleteDialog(onConfirm: onConfirm),
    );
  }

  @override
  State<RatingDeleteDialog> createState() => _RatingDeleteDialogState();
}

class _RatingDeleteDialogState extends State<RatingDeleteDialog> {
  bool _isDeleting = false;
  String? _errorMessage;

  Future<void> _confirm() async {
    final onConfirm = widget.onConfirm;
    if (onConfirm == null) {
      Navigator.of(context).pop(true);
      return;
    }
    if (_isDeleting) return;

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });
    try {
      await onConfirm();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _errorMessage = error is StateError ? error.message : '삭제에 실패했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: Dialog(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 31),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 36, 18, 37),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('평점을 삭제할까요?', textAlign: TextAlign.center, style: _titleStyle),
              const SizedBox(height: 19),
              const Text(
                '삭제한 평점은 복구할 수 없습니다.',
                textAlign: TextAlign.center,
                style: _bodyStyle,
              ),
              // 오류 문구가 나타나도 버튼이 움직이지 않도록 고정 높이로 둡니다.
              SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _errorMessage ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _errorStyle,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: MovieLogButton(
                      label: '취소',
                      buttonHeight: 44,
                      borderRadius: 22,
                      backgroundColor: AppColors.editFill,
                      foregroundColor: AppColors.violet,
                      labelStyle: _buttonStyle,
                      onPressed: _isDeleting
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: MovieLogButton(
                      label: '삭제',
                      buttonHeight: 44,
                      borderRadius: 22,
                      labelStyle: _buttonStyle,
                      isLoading: _isDeleting,
                      onPressed: _confirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // W7-REQ Figma: 제목 21 / Bold, 본문 14 / Regular, 버튼 14 / Bold.
  static const _titleStyle = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    height: 29 / 21,
    letterSpacing: 0,
    color: AppColors.black,
  );

  static const _bodyStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 19 / 14,
    letterSpacing: 0,
    color: AppColors.commentText,
  );

  static const _errorStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 16 / 12,
    letterSpacing: 0,
    color: AppColors.error,
  );

  static const _buttonStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 19 / 14,
    letterSpacing: 0,
  );
}
