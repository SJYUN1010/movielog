import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_text_styles.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/rating_card.dart';

/// 마이페이지 위에 열리는 자식 화면입니다. 하단 NavigationBar 없이 뒤로가기만 둡니다.
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '내가 등록한 평점',
        centerTitle: true,
        titleStyle: AppTextStyles.subScreenTitle,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/my');
          }
        },
      ),
      body: SafeArea(
        child: Consumer<MyRatingsViewModel>(
          builder: (context, viewModel, _) {
            switch (viewModel.status) {
              case MyRatingsLoadStatus.idle:
              case MyRatingsLoadStatus.loading:
                return const MovieListLoading(message: '평점을 불러오는 중이에요...');
              case MyRatingsLoadStatus.empty:
                return const MovieListEmpty(message: '등록된 평점이 없습니다.');
              case MyRatingsLoadStatus.error:
                final transient = viewModel.message == ratingsLoadFailedMessage;
                return MovieListError(
                  title: viewModel.message ?? ratingsLoadFailedMessage,
                  message: transient ? '네트워크 상태를 확인한 뒤 다시 시도해주세요.' : null,
                  onRetry: context.read<MyRatingsViewModel>().retry,
                );
              case MyRatingsLoadStatus.success:
                return _RatingList(viewModel: viewModel);
            }
          },
        ),
      ),
    );
  }
}

class _RatingList extends StatelessWidget {
  const _RatingList({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final notice = viewModel.message;
    final ratings = viewModel.ratings;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 24),
      itemCount: ratings.length + (notice == null ? 0 : 1),
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (notice != null && index == 0) {
          return Text(notice, style: AppTextStyles.statLabel);
        }
        return RatingCard(entry: ratings[notice == null ? index : index - 1]);
      },
    );
  }
}
