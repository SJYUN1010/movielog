/// 닉네임·이메일 중복 확인 응답입니다. v5는 공통 Wrapper 없이 `{ "available": true }`를 그대로 내려줍니다.
class CheckResult {
  const CheckResult({required this.available});

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    return CheckResult(available: json['available'] as bool);
  }

  final bool available;
}
