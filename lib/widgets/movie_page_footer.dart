import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import 'movielog_button.dart';

/// 목록 맨 아래에 붙는 "더 보기" 영역입니다(W9 Figma).
///
/// 더 보기 · 추가 로딩(버튼 비활성 + 인디케이터, 기존 카드 유지) · 다음 page 오류(같은 page 재시도) ·
/// 마지막 page(더 보기 숨김)를 한 곳에서 구분합니다.
class MoviePageFooter extends StatelessWidget {
  const MoviePageFooter({super.key, required this.vm, this.moreLabel = '더 보기'});

  final PagedMoviesViewModel vm;

  /// 검색 결과에서는 "검색 결과 더 보기"를 씁니다.
  final String moreLabel;

  static const _messageStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    letterSpacing: 0,
    color: AppColors.textMuted,
  );

  @override
  Widget build(BuildContext context) {
    if (!vm.hasMore && !vm.isLoadingMore && vm.loadMoreError == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Text('모든 영화를 확인했습니다.', textAlign: TextAlign.center, style: _messageStyle),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          if (vm.loadMoreError != null) ...[
            Text(vm.loadMoreError!, textAlign: TextAlign.center, style: _messageStyle),
            const SizedBox(height: 12),
          ],
          MovieLogButton(
            width: double.infinity,
            label: vm.loadMoreError == null ? moreLabel : '다음 페이지 다시 시도',
            isLoading: vm.isLoadingMore,
            onPressed: vm.phase == LoadPhase.ready ? vm.loadNextPage : null,
          ),
        ],
      ),
    );
  }
}
