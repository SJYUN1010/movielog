import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_text_styles.dart';
import '../view_models/movie_list_view_model.dart';
import '../widgets/genre_filter_chips.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
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

class _ListBody extends StatelessWidget {
  const _ListBody({required this.viewModel});

  final MovieListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    switch (viewModel.status) {
      case MovieListLoadStatus.idle:
      case MovieListLoadStatus.loading:
        return const MovieListLoading();
      case MovieListLoadStatus.error:
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
