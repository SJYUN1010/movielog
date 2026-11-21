/// [values]를 [convert]로 바꾸되, 동시에 진행하는 작업을 [concurrency]개로 제한합니다.
///
/// 즐겨찾기가 100개여도 TMDB 영화 정보 요청이 한꺼번에 100개 나가지 않게 합니다.
/// 결과는 입력과 같은 순서입니다. [convert]가 던지면 전체가 실패하므로, 카드별 실패를
/// 호출부에서 결과 값으로 바꿔서 돌려주세요.
Future<List<R>> mapBounded<T, R>(
  Iterable<T> values,
  int concurrency,
  Future<R> Function(T value) convert,
) async {
  final input = values.toList(growable: false);
  if (input.isEmpty) return <R>[];
  if (concurrency <= 0) {
    throw ArgumentError.value(concurrency, 'concurrency', 'must be positive');
  }
  final output = List<R?>.filled(input.length, null);
  var next = 0;

  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= input.length) return;
      output[index] = await convert(input[index]);
    }
  }

  final workers = List.generate(concurrency.clamp(1, input.length), (_) => worker());
  await Future.wait(workers);
  return output.cast<R>();
}
