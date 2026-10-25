import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_text_styles.dart';
import '../view_models/movie_home_view_model.dart';
import '../widgets/hero_movie_card.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/popular_movie_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MovieLog', style: AppTextStyles.wordmark),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.search),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('오늘은 어떤\n영화를 볼까요?', style: AppTextStyles.screenGreeting),
            const SizedBox(height: 16),
            Consumer<MovieHomeViewModel>(
              builder: (context, viewModel, _) => _HomeBody(viewModel: viewModel),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.viewModel});

  final MovieHomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    switch (viewModel.status) {
      case MovieHomeLoadStatus.idle:
      case MovieHomeLoadStatus.loading:
        return const SizedBox(height: 360, child: MovieListLoading());
      case MovieHomeLoadStatus.error:
        return SizedBox(
          height: 360,
          child: MovieListError(onRetry: () => context.read<MovieHomeViewModel>().load()),
        );
      case MovieHomeLoadStatus.empty:
        return const SizedBox(
          height: 360,
          child: MovieListEmpty(message: '표시할 인기 영화가 없습니다.'),
        );
      case MovieHomeLoadStatus.success:
        final popular = viewModel.popularMovies;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroMovieCard(movie: popular.first),
            const SizedBox(height: 24),
            const Text('인기 영화', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: popular.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    PopularMovieCard(rank: index + 1, movie: popular[index]),
              ),
            ),
          ],
        );
    }
  }
}
