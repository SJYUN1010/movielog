import 'package:flutter/material.dart';

import 'genre_preference.dart';
import 'movie.dart';
import 'movie_service.dart';
import 'theme/app_text_styles.dart';
import 'widgets/genre_filter_chips.dart';
import 'widgets/movie_grid.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';

class MovieListInitialData {
  const MovieListInitialData({required this.movies, required this.selectedGenre});

  final List<Movie> movies;
  final String selectedGenre;
}

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({
    super.key,
    this.service = const FakeMovieService(),
    this.genrePreference,
    this.initialMode,
  });

  final FakeMovieService service;
  final GenrePreference? genrePreference;
  final MovieLoadMode? initialMode;

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  late final GenrePreference _genrePreference =
      widget.genrePreference ?? GenrePreference();
  late MovieLoadMode _mode = widget.initialMode ?? movieLoadModeFromEnvironment();
  late Future<MovieListInitialData> _initialFuture;
  String _selectedGenre = GenrePreference.defaultGenre;

  @override
  void initState() {
    super.initState();
    _initialFuture = _loadInitialData();
  }

  // TODO(5주차 유저별 평점 조회 API): FakeMovieService를 실제 API Service로 교체
  Future<MovieListInitialData> _loadInitialData() async {
    final results = await Future.wait([
      widget.service.fetchMovies(mode: _mode),
      _genrePreference.read(),
    ]);
    final movieList = results[0] as List<Movie>;
    final savedGenre = results[1] as String;
    final genres = {for (final movie in movieList) ...movie.genres};

    _selectedGenre = genres.contains(savedGenre)
        ? savedGenre
        : GenrePreference.defaultGenre;

    return MovieListInitialData(movies: movieList, selectedGenre: _selectedGenre);
  }

  void _retry() {
    setState(() {
      _mode = MovieLoadMode.success;
      _initialFuture = _loadInitialData();
    });
  }

  Future<void> _selectGenre(String genre) async {
    setState(() => _selectedGenre = genre);

    try {
      await _genrePreference.save(genre);
    } catch (error) {
      debugPrint('장르 저장 실패: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('선택한 장르를 저장하지 못했어요.'),
          ),
        );
    }
  }

  List<Movie> _filter(List<Movie> source) {
    if (_selectedGenre == GenrePreference.defaultGenre) return source;
    return source.where((movie) => movie.genres.contains(_selectedGenre)).toList();
  }

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
        child: FutureBuilder<MovieListInitialData>(
          future: _initialFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MovieListLoading();
            }
            if (snapshot.hasError) {
              return MovieListError(onRetry: _retry);
            }

            final data = snapshot.data;
            if (data == null || data.movies.isEmpty) {
              return const MovieListEmpty();
            }

            final genres = {for (final movie in data.movies) ...movie.genres}.toList();
            final visibleMovies = _filter(data.movies);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: GenreFilterChips(
                    genres: genres,
                    selected: _selectedGenre,
                    onSelected: _selectGenre,
                  ),
                ),
                Expanded(
                  child: visibleMovies.isEmpty
                      ? const MovieListEmpty()
                      : MovieGrid(movies: visibleMovies),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
