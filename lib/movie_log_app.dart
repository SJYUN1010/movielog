import 'package:flutter/material.dart';
import 'package:movielog/rating_screen.dart';
import 'package:movielog/signup_screen.dart';
import 'package:movielog/theme/app_theme.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  static const _screen = String.fromEnvironment('SCREEN');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      home: _screen == 'rating' ? const RatingScreen() : const SignUpScreen(),
    );
  }
}
