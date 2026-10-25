import 'package:shared_preferences/shared_preferences.dart';

class GenrePreference {
  GenrePreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _selectedGenreIdKey = 'selected_genre_id';

  final SharedPreferencesAsync _preferences;

  /// 저장된 TMDB 장르 id. null이면 "전체"입니다.
  Future<int?> read() => _preferences.getInt(_selectedGenreIdKey);

  Future<void> save(int? genreId) async {
    if (genreId == null) {
      await _preferences.remove(_selectedGenreIdKey);
    } else {
      await _preferences.setInt(_selectedGenreIdKey, genreId);
    }
  }
}
