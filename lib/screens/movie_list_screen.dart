import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_text_styles.dart';
import '../view_models/load_phase.dart';
import '../view_models/movie_list_view_model.dart';
import '../widgets/genre_filter_chips.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/movie_page_footer.dart';

/// 영화 목록 화면입니다. 첫 page만 보여주고 "더 보기"로 다음 page를 이어서 불러옵니다.
/// AppBar 오른쪽 검색 아이콘으로 영화 검색 화면(`/movies/search`)에 들어갑니다.
class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('영화', style: AppTextStyles.appBarTitle),
        actions: [
          IconButton(
            tooltip: '영화 검색',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/movies/search'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Consumer<MovieListViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.phase == LoadPhase.error && viewModel.genres.isEmpty) {
              return MovieListError(onRetry: viewModel.retry);
            }

            return Column(
              children: [
                if (viewModel.genres.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: GenreFilterChips(
                      genres: viewModel.genres,
                      selectedGenreId: viewModel.selectedGenreId,
                      // 요청 중에도 바꿀 수 있습니다. 이전 장르의 늦은 응답은 ViewModel이 무시합니다.
                      enabled: true,
                      onSelected: (genreId) =>
                          context.read<MovieListViewModel>().selectGenre(genreId),
                    ),
                  ),
                Expanded(child: _ListBody(viewModel: viewModel)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ListBody extends StatelessWidget {
  const _ListBody({required this.viewModel});

  final MovieListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    switch (viewModel.phase) {
      case LoadPhase.idle:
      case LoadPhase.loading:
        return const MovieListLoading();
      case LoadPhase.error:
        return MovieListError(
          title: viewModel.paged.errorMessage ?? '영화를 불러오지 못했습니다.',
          onRetry: viewModel.retry,
        );
      case LoadPhase.empty:
        return const MovieListEmpty();
      case LoadPhase.ready:
        final movies = viewModel.paged.movies;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.52,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final movie = movies[index];
                    return MovieCard(movie: movie, subtitle: viewModel.subtitleOf(movie));
                  },
                  childCount: movies.length,
                ),
              ),
            ),
            SliverToBoxAdapter(child: MoviePageFooter(vm: viewModel.paged)),
          ],
        );
    }
  }
}
