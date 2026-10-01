import 'package:flutter/material.dart';

import 'movie.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';
import 'widgets/movie_action_bar.dart';
import 'widgets/rating_dialog.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  final int movieId;

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
    final movie = findMovieById(widget.movieId);

    if (movie == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(
          child: Text('영화를 찾을 수 없어요.', style: AppTextStyles.bodyDescription),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.white),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.share, color: AppColors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.asset(movie.posterAsset, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, style: AppTextStyles.detailTitle),
                  const SizedBox(height: 8),
                  Text(
                    '${movie.year} · ${movie.genreLabel} · ${movie.runtimeMinutes}분',
                    style: AppTextStyles.detailMeta,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StarRow(rating: movie.rating),
                      const SizedBox(width: 12),
                      Text(movie.rating.toStringAsFixed(1), style: AppTextStyles.ratingNumber),
                      const SizedBox(width: 6),
                      Text(
                        '(${movie.voteCount})',
                        style: AppTextStyles.voteCount,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in movie.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.chipUnselected,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(tag, style: AppTextStyles.tagChip),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('시놉시스', style: AppTextStyles.synopsisHeading),
                  const SizedBox(height: 12),
                  Text(movie.synopsis, style: AppTextStyles.synopsisBody),
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
        IconData icon;
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
