import 'package:flutter/material.dart';

import '../data/dto/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/movie_action_bar.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId, this.movie});

  /// 이후 평점 저장 API에 사용할 TMDB 영화 id입니다.
  final int movieId;
  final TmdbMovieDto? movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;
  double? _myRating;

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(_isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.'),
        ),
      );
  }

  Future<void> _openRatingDialog() async {
    final rating = await showDialog<double>(
      context: context,
      builder: (dialogContext) => RatingDialog(initialRating: _myRating ?? 0),
    );
    if (rating == null) return;

    setState(() => _myRating = rating);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('평점 ${rating.toStringAsFixed(1)}점을 저장했습니다.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;

    if (movie == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(
          child: Text('영화를 찾을 수 없어요.', style: AppTextStyles.bodyDescription),
        ),
      );
    }

    final year = movie.releaseYear;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: TmdbPosterImage(posterPath: movie.posterPath),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, style: AppTextStyles.detailTitle),
                  if (year != null) ...[
                    const SizedBox(height: 8),
                    Text('$year', style: AppTextStyles.detailMeta),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StarRow(rating: movie.fiveStarRating),
                      const SizedBox(width: 12),
                      Text(
                        movie.fiveStarRating.toStringAsFixed(1),
                        style: AppTextStyles.ratingNumber,
                      ),
                      const SizedBox(width: 6),
                      Text('(${movie.voteCount})', style: AppTextStyles.voteCount),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('시놉시스', style: AppTextStyles.synopsisHeading),
                  const SizedBox(height: 12),
                  Text(
                    movie.overview.isEmpty ? '등록된 줄거리가 없습니다.' : movie.overview,
                    style: AppTextStyles.synopsisBody,
                  ),
                  if (_myRating != null) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.violet),
                        const SizedBox(width: 8),
                        Text(
                          '내 평점 ${_myRating!.toStringAsFixed(1)}',
                          style: AppTextStyles.tagChip,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MovieActionBar(
        isFavorite: _isFavorite,
        onFavoriteToggle: _toggleFavorite,
        onRatePressed: _openRatingDialog,
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = rating - index;
        final IconData icon;
        if (filled >= 1) {
          icon = Icons.star_rounded;
        } else if (filled >= 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: 20, color: AppColors.violet);
      }),
    );
  }
}
