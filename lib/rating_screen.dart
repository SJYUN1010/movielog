import 'package:flutter/material.dart';

import 'theme/app_text_styles.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/rating_input.dart';
import 'widgets/submit_button.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  double _rating = 0;

  bool get _hasRating => _rating > 0;

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('평점 ${_rating.toStringAsFixed(1)}점을 저장했어요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '평점 남기기',
        centerTitle: true,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/posters/poster_abyss_walker.jpg',
                        width: 160,
                        height: 240,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Abyss Walker',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.nickname,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '이 영화의 평점을 남겨주세요.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyDescription,
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: RatingInput(
                      rating: _rating,
                      onChanged: (value) => setState(() => _rating = value),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _hasRating
                        ? '${_rating.toStringAsFixed(1)} / 5.0'
                        : '별을 눌러 평점을 선택해주세요',
                    textAlign: TextAlign.center,
                    style: _hasRating
                        ? AppTextStyles.statValue
                        : AppTextStyles.bodyDescription,
                  ),
                  const SizedBox(height: 40),
                  SubmitButton(
                    label: '평점 저장',
                    onPressed: _hasRating ? _save : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
