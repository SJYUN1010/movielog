import 'package:flutter/foundation.dart';

/// 화면이 사라진(dispose) 뒤에 `notifyListeners()`를 호출하지 않도록 막는 mixin입니다.
///
/// 서버 응답은 늦게 도착할 수 있어서, 그 사이 화면을 벗어났다면 이미 dispose된 ViewModel에 알림을 보내
/// 오류가 납니다. ViewModel에 `with SafeNotify`를 붙이고, `notifyListeners()` 대신 [notifyIfAlive]를,
/// 결과를 반영하기 전에는 [isDisposed]를 확인합니다. dispose는 Provider가 호출합니다.
mixin SafeNotify on ChangeNotifier {
  bool _disposed = false;
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }
}
