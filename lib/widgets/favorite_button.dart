import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/favorite_detail_view_model.dart';

/// 영화 상세의 제목·정보 텍스트 오른쪽에 놓는 북마크 버튼입니다(W9 Figma).
///
/// - 서버 여부를 확인하는 중이거나 등록·해제 중에는 북마크 자리에만 인디케이터를 보여주고 누를 수 없습니다.
/// - 서버 성공을 확인한 뒤에만 아이콘이 바뀌고, 결과는 Snackbar로 안내합니다. 실패하면 이전 아이콘을 유지합니다.
/// - 처음 여부 조회에 실패하면 북마크 아래에 새로고침 버튼을 보여줍니다.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key});

  static const _labelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 15 / 11,
    letterSpacing: 0,
    color: AppColors.violet,
  );

  Future<void> _toggle(BuildContext context, FavoriteDetailViewModel vm) async {
    final messenger = ScaffoldMessenger.of(context);
    await vm.toggle();
    if (!context.mounted) return;
    final message =
        vm.errorMessage ?? (vm.isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoriteDetailViewModel>(
      builder: (context, vm, _) {
        final busy = vm.isLoading || vm.isSaving;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.cardBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: 62,
                height: 72,
                child: busy
                    ? const Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.violet),
                        ),
                      )
                    : IconButton(
                        tooltip: vm.isFavorite ? '즐겨찾기 해제' : '즐겨찾기 등록',
                        color: AppColors.violet,
                        onPressed: vm.hasLoadedStatus ? () => _toggle(context, vm) : null,
                        icon: Icon(
                          vm.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                          size: 30,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            const Text('즐겨찾기', style: _labelStyle),
            // 첫 여부 조회에 실패했을 때만 북마크와 같은 너비의 새로고침 버튼을 보여줍니다.
            if (!vm.hasLoadedStatus && !vm.isLoading)
              SizedBox(
                width: 62,
                child: IconButton(
                  tooltip: '여부 다시 확인',
                  color: AppColors.violet,
                  onPressed: vm.load,
                  icon: const Icon(Icons.refresh),
                ),
              ),
          ],
        );
      },
    );
  }
}
