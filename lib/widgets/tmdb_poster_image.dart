import 'package:flutter/material.dart';

import '../core/network/tmdb_client.dart';
import '../theme/app_colors.dart';

class TmdbPosterImage extends StatelessWidget {
  const TmdbPosterImage({
    super.key,
    required this.posterPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String? posterPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = posterPath;
    if (path == null || path.isEmpty) {
      return _Placeholder(width: width, height: height, icon: Icons.movie_outlined);
    }

    return Image.network(
      '${TmdbClient.imageBaseUrl}$path',
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _Placeholder(width: width, height: height, icon: null);
      },
      errorBuilder: (context, error, stackTrace) => _Placeholder(
        width: width,
        height: height,
        icon: Icons.broken_image_outlined,
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.width, required this.height, required this.icon});

  final double? width;
  final double? height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.chipUnselected,
      alignment: Alignment.center,
      child: icon == null ? null : Icon(icon, color: AppColors.gray, size: 32),
    );
  }
}
