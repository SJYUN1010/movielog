import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_with_movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movielog_button.dart';
import '../widgets/rating_card.dart';
import '../widgets/rating_delete_dialog.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/rating_write_guard.dart';

/// 마이페이지 위에 열리는 자식 화면입니다. 하단 NavigationBar 없이 뒤로가기만 둡니다.
/// 이번 로그인 세션에서 등록한 평점의 조회·수정·삭제는 이 화면에서만 합니다.
/// v7에는 토큰 기반 "내 평점 전체 GET"이 없어, 앱을 다시 켜면 이전 평점을 복원하지 않습니다.
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  void _goBack(BuildContext context, MyRatingsViewModel viewModel) {
    // 요청이 진행 중일 때는 화면을 벗어나지 못하게 합니다.
    if (viewModel.isBusy) return;
    if (context.canPop()) {
      Navigator.of(context).maybePop();
    } else {
      context.go('/my');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MyRatingsViewModel>(
      builder: (context, viewModel, _) {
        return PopScope(
          canPop: !viewModel.isBusy,
          // 오버레이는 앱바까지 덮어야 삭제하는 동안 어디도 누를 수 없습니다(W7-05 Figma).
          child: LoadingOverlay(
            isLoading: viewModel.isDeletingSelected,
            child: Scaffold(
              appBar: CommonAppBar(
                title: '내가 등록한 평점',
                centerTitle: true,
                titleStyle: AppTextStyles.subScreenTitle,
                onBack: () => _goBack(context, viewModel),
              ),
              body: SafeArea(child: _Body(viewModel: viewModel)),
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isEmpty) {
      return const MovieListEmpty(
        message: '이번 로그인에서 등록한 평점이 없습니다.\n영화 상세에서 평점을 남기면 여기에 표시돼요.',
      );
    }
    return _RatingList(viewModel: viewModel);
  }
}

class _RatingList extends StatelessWidget {
  const _RatingList({required this.viewModel});

  final MyRatingsViewModel viewModel;

  void _showSnackBar(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
  }

  Future<void> _edit(BuildContext context, RatingWithMovie entry) async {
    final rating = entry.rating;
    final viewModel = context.read<MyRatingsViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = await RatingDialog.show(
      context,
      title: '평점을 수정해주세요',
      initialScore: rating.score,
      initialComment: rating.comment,
      // 400·네트워크 실패는 Dialog 안에, 403·404는 Snackbar로 안내합니다. 401이면 로그인 화면으로 이동합니다.
      onSubmit: (score, comment) => guardRatingWrite(
        messenger,
        () => viewModel.updateRating(
          ratingId: rating.ratingId,
          score: score,
          comment: comment,
        ),
      ),
    );
    if (!context.mounted || saved != true) return;
    _showSnackBar(context, '평점을 수정했습니다.');
  }

  Future<void> _delete(BuildContext context, RatingWithMovie entry) async {
    final viewModel = context.read<MyRatingsViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await RatingDeleteDialog.show(
      context,
      // 단일 삭제는 삭제하는 동안 Dialog를 유지합니다.
      onConfirm: () => guardRatingWrite(
        messenger,
        () => viewModel.deleteRating(entry.rating.ratingId),
      ),
    );
    if (!context.mounted || deleted != true) return;
    _showSnackBar(context, '평점을 삭제했습니다.');
  }

  Future<void> _deleteSelected(BuildContext context) async {
    // 다중 삭제는 확인 Dialog를 바로 닫고, 삭제 중 로딩은 화면의 오버레이가 맡습니다.
    final confirmed = await RatingDeleteDialog.show(context);
    if (!context.mounted || confirmed != true) return;

    final result = await context.read<MyRatingsViewModel>().deleteSelectedRatings();
    if (!context.mounted) return;
    if (result.hasPartialFailure) {
      _showSnackBar(
        context,
        '${result.failed}개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.',
      );
    } else if (result.deleted > 0) {
      _showSnackBar(context, '선택한 평점을 삭제했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = viewModel.message;
    final ratings = viewModel.ratings;
    final selecting = viewModel.isSelectionMode;
    final selectedCount = viewModel.selectedRatingIds.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
          child: _Header(viewModel: viewModel),
        ),
        const SizedBox(height: 25),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: ratings.length + (notice == null ? 0 : 1),
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              if (notice != null && index == 0) {
                return Text(notice, style: AppTextStyles.statLabel);
              }
              final entry = ratings[notice == null ? index : index - 1];
              if (selecting) {
                return RatingSelectCard(
                  entry: entry,
                  selected: viewModel.selectedRatingIds.contains(entry.rating.ratingId),
                  onToggle: () => context
                      .read<MyRatingsViewModel>()
                      .toggleSelection(entry.rating.ratingId),
                );
              }
              return RatingCard(
                entry: entry,
                onEdit: () => _edit(context, entry),
                onDelete: () => _delete(context, entry),
              );
            },
          ),
        ),
        if (selecting)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            child: MovieLogButton(
              label: '선택한 $selectedCount개 삭제',
              width: double.infinity,
              buttonHeight: 49,
              borderRadius: 24.5,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 20 / 15,
                letterSpacing: 0,
              ),
              onPressed: selectedCount > 0 && !viewModel.isDeletingSelected
                  ? () => _deleteSelected(context)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// 목록 위 한 줄입니다. 평소에는 오른쪽에 "편집", 다중 선택 중에는 왼쪽에 선택 개수, 오른쪽에 "취소"를 둡니다.
class _Header extends StatelessWidget {
  const _Header({required this.viewModel});

  final MyRatingsViewModel viewModel;

  static const _textStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 19 / 14,
    letterSpacing: 0,
    color: AppColors.violet,
  );

  @override
  Widget build(BuildContext context) {
    final selecting = viewModel.isSelectionMode;

    return SizedBox(
      height: 19,
      child: Row(
        children: [
          if (selecting)
            Text('${viewModel.selectedRatingIds.length}개 선택됨', style: _textStyle),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: viewModel.isBusy
                ? null
                : () {
                    final model = context.read<MyRatingsViewModel>();
                    selecting ? model.cancelSelectionMode() : model.enterSelectionMode();
                  },
            child: Text(selecting ? '취소' : '편집', style: _textStyle),
          ),
        ],
      ),
    );
  }
}
