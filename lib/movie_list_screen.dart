import 'package:flutter/material.dart';

import 'movie.dart';
import 'theme/app_text_styles.dart';
import 'widgets/genre_filter_chips.dart';
import 'widgets/movie_card.dart';

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  String _selectedGenre = GenreFilterChips.all;

  List<Movie> get _filteredMovies {
    if (_selectedGenre == GenreFilterChips.all) return movies;
    return movies.where((movie) => movie.genres.contains(_selectedGenre)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final genres = {for (final movie in movies) ...movie.genres}.toList();

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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GenreFilterChips(
                genres: genres,
                selected: _selectedGenre,
                onSelected: (genre) => setState(() => _selectedGenre = genre),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredMovies.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.52,
                ),
                itemBuilder: (context, index) =>
                    MovieCard(movie: _filteredMovies[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
