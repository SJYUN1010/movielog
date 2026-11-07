import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_text_styles.dart';
import '../view_models/movie_list_view_model.dart';
import '../widgets/genre_filter_chips.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_retry_dialog.dart';
import '../widgets/movie_list_loading.dart';

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('영화', style: AppTextStyles.appBarTitle),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.search),
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<MovieListViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.status == MovieListLoadStatus.error && viewModel.genres.isEmpty) {
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
                      enabled: !viewModel.isLoading,
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

class _ListBody extends StatefulWidget {
  const _ListBody({required this.viewModel});

  final MovieListViewModel viewModel;

  @override
  State<_ListBody> createState() => _ListBodyState();
}

class _ListBodyState extends State<_ListBody> {
  /// 이미 Dialog를 띄운 실패 횟수입니다. 같은 실패에 Dialog가 두 번 뜨지 않게 합니다.
  int _handledErrorCount = 0;

  void _showRetryDialogIfNeeded() {
    final viewModel = widget.viewModel;
    if (viewModel.status != MovieListLoadStatus.error ||
        viewModel.errorCount == _handledErrorCount) {
      return;
    }
    _handledErrorCount = viewModel.errorCount;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final retry = await MovieListRetryDialog.show(context);
      if (!mounted) return;

      final viewModel = context.read<MovieListViewModel>();
      if (retry) {
        viewModel.retry();
      } else {
        viewModel.cancelRetry();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _showRetryDialogIfNeeded();
    final viewModel = widget.viewModel;

    switch (viewModel.status) {
      case MovieListLoadStatus.idle:
      case MovieListLoadStatus.loading:
        return const MovieListLoading();
      case MovieListLoadStatus.error:
        // 최근 성공한 목록이 있으면 Dialog 뒤에 그대로 보여주고, 없으면 Error 화면을 보여줍니다.
        if (viewModel.movies.isNotEmpty) {
          return MovieGrid(
            movies: viewModel.movies,
            subtitleOf: viewModel.subtitleOf,
          );
        }
        return MovieListError(onRetry: viewModel.retry);
      case MovieListLoadStatus.empty:
        return const MovieListEmpty();
      case MovieListLoadStatus.success:
        return MovieGrid(
          movies: viewModel.movies,
          subtitleOf: viewModel.subtitleOf,
        );
    }
  }
}
