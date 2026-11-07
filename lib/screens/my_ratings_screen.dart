import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_with_movie.dart';
import '../data/services/rating_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/movielog_button.dart';
import '../widgets/rating_card.dart';
import '../widgets/rating_delete_dialog.dart';
import '../widgets/rating_dialog.dart';

/// 쓰기 요청의 DioException을 Dialog가 보여줄 서버 message로 바꿉니다.
/// 같은 COMMON404라도 수정·삭제에서는 "평점"을 가리키므로 문구를 새로 만들지 않고 서버 message를 씁니다.
Future<void> _asDialogError(Future<void> Function() action) async {
  try {
    await action();
  } on DioException catch (error) {
    throw StateError(writeErrorMessage(error));
  }
}

/// 마이페이지 위에 열리는 자식 화면입니다. 하단 NavigationBar 없이 뒤로가기만 둡니다.
/// 평점 조회·수정·삭제는 이 화면에서만 합니다.
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
    switch (viewModel.status) {
      case MyRatingsLoadStatus.idle:
      case MyRatingsLoadStatus.loading:
        return const MovieListLoading(message: '평점을 불러오는 중이에요...');
      case MyRatingsLoadStatus.empty:
        return const MovieListEmpty(message: '등록된 평점이 없습니다.');
      case MyRatingsLoadStatus.error:
        // 저장은 성공했는데 GET만 실패한 경우 "조회만 다시 시도"로 안내합니다.
        final warning = viewModel.refreshWarning;
        final transient = warning == null && viewModel.message == ratingsLoadFailedMessage;
        return MovieListError(
          title: warning ?? viewModel.message ?? ratingsLoadFailedMessage,
          message: transient ? '네트워크 상태를 확인한 뒤 다시 시도해주세요.' : null,
          onRetry: context.read<MyRatingsViewModel>().retry,
        );
      case MyRatingsLoadStatus.success:
        return _RatingList(viewModel: viewModel);
    }
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
    final saved = await RatingDialog.show(
      context,
      title: '평점을 수정해주세요',
      initialScore: rating.score,
      initialComment: rating.comment,
      onSubmit: (score, comment) => _asDialogError(
        () => context.read<MyRatingsViewModel>().updateRating(
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
    final deleted = await RatingDeleteDialog.show(
      context,
      // 단일 삭제는 삭제하는 동안 Dialog를 유지합니다.
      onConfirm: () => _asDialogError(
        () => context.read<MyRatingsViewModel>().deleteRating(entry.rating.ratingId),
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
