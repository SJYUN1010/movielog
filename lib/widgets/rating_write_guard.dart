import 'package:flutter/material.dart';

import '../view_models/rating_write_exception.dart';

/// Dialog의 저장·삭제 콜백이 던지면 Dialog가 값 없이 조용히 닫힙니다(`false`로 반환).
class RatingDialogDismiss implements Exception {
  const RatingDialogDismiss();
}

/// 이 Dialog 경로가 아직 화면에 살아 있을 때만 닫습니다.
///
/// 저장 중에 세션이 만료되면 Router가 먼저 로그인 화면으로 페이지를 교체하고, 그 과정에서 Dialog 경로가
/// 이미 정리됩니다. 그때 `Navigator.pop`을 다시 부르면 Dialog가 아니라 남은 마지막 페이지를 닫아
/// "no pages left to show" 오류와 빈 화면이 생깁니다.
void popDialogIfActive(BuildContext context, [bool? result]) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isActive) return;
  Navigator.of(context).pop(result);
}

/// 평점 쓰기 실패를 Dialog가 이해하는 형태로 바꿉니다.
///
/// - [RatingWriteKind.inline]: Dialog를 열어 둔 채 서버 message를 보여줍니다(입력 보존).
/// - [RatingWriteKind.notice]: Dialog를 닫고 [messenger]로 Snackbar를 띄웁니다. 로그인 상태는 유지합니다.
/// - [RatingWriteKind.dismissed]: Dialog만 닫습니다. 401이면 로그인 화면 이동과 만료 안내는 Router가 맡습니다.
Future<void> guardRatingWrite(
  ScaffoldMessengerState messenger,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on RatingWriteException catch (error) {
    switch (error.kind) {
      case RatingWriteKind.inline:
        throw StateError(error.message);
      case RatingWriteKind.notice:
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(behavior: SnackBarBehavior.floating, content: Text(error.message)),
          );
        throw const RatingDialogDismiss();
      case RatingWriteKind.dismissed:
        throw const RatingDialogDismiss();
    }
  }
}
