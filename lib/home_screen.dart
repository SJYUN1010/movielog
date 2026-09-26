import 'package:flutter/material.dart';

import 'movie.dart';
import 'theme/app_text_styles.dart';
import 'widgets/hero_movie_card.dart';
import 'widgets/popular_movie_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final featured = movies.first;

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
            HeroMovieCard(movie: featured),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('인기 영화', style: AppTextStyles.sectionTitle),
                TextButton(
                  onPressed: () {},
                  child: const Text('전체보기 >', style: AppTextStyles.buttonLabel),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: popularMovies.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    PopularMovieCard(entry: popularMovies[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
