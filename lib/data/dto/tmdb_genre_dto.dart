class TmdbGenreDto {
  const TmdbGenreDto({required this.id, required this.name});

  factory TmdbGenreDto.fromJson(Map<String, dynamic> json) {
    return TmdbGenreDto(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
    );
  }

  final int id;
  final String name;
}
