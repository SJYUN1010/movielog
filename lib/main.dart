import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/movie_log_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(isOptional: true);
  if ((dotenv.maybeGet('TMDB_ACCESS_TOKEN') ?? '').isEmpty) {
    debugPrint('TMDB_ACCESS_TOKEN이 비어 있습니다. .env 파일을 확인하세요.');
  }
  runApp(const MovieLogApp());
}
