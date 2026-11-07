import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/theme/app_colors.dart';
import 'package:movielog/widgets/movielog_button.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      // 부모가 최대 300까지만 허용하는 느슨한 제약입니다. 정확히 300으로 고정하면
      // 자식의 width 값과 관계없이 항상 300이 되어 차이를 볼 수 없습니다.
      body: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: child,
        ),
      ),
    ),
  );
}

ElevatedButton _elevated(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton));

void main() {
  group('MovieLogButton states', () {
    testWidgets('default: enabled, shows the label and runs onPressed', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _host(MovieLogButton(label: '중복 확인', onPressed: () => pressed++)),
      );

      expect(find.text('중복 확인'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_elevated(tester).onPressed, isNotNull);

      await tester.tap(find.byType(ElevatedButton));
      expect(pressed, 1);
    });

    testWidgets('loading: indicator only, label hidden, disabled even with onPressed', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        _host(MovieLogButton(label: '중복 확인', isLoading: true, onPressed: () => pressed++)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('중복 확인'), findsNothing);
      expect(_elevated(tester).onPressed, isNull);

      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      expect(pressed, 0);
    });

    testWidgets('loading is gray while a missing condition is light violet', (tester) async {
      await tester.pumpWidget(
        _host(MovieLogButton(label: '확인', isLoading: true, onPressed: () {})),
      );
      final loadingColor = _elevated(tester).style!.backgroundColor!.resolve({
        WidgetState.disabled,
      });
      expect(loadingColor, AppColors.gray);

      await tester.pumpWidget(_host(const MovieLogButton(label: '확인', onPressed: null)));
      final disabledColor = _elevated(tester).style!.backgroundColor!.resolve({
        WidgetState.disabled,
      });
      expect(disabledColor, AppColors.buttonDisabled);
    });

    testWidgets('disabled: null onPressed keeps the label and does nothing', (tester) async {
      await tester.pumpWidget(_host(const MovieLogButton(label: '가입하기', onPressed: null)));

      expect(find.text('가입하기'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_elevated(tester).onPressed, isNull);
    });
  });

  group('MovieLogButton width', () {
    testWidgets('null uses a content-based size', (tester) async {
      await tester.pumpWidget(_host(MovieLogButton(label: '확인', onPressed: () {})));
      final shortWidth = tester.getSize(find.byType(MovieLogButton)).width;

      await tester.pumpWidget(
        _host(MovieLogButton(label: '아주 긴 라벨의 버튼입니다', onPressed: () {})),
      );
      final longWidth = tester.getSize(find.byType(MovieLogButton)).width;

      expect(shortWidth, lessThan(300));
      expect(longWidth, greaterThan(shortWidth));
      expect(longWidth, lessThan(300));
    });

    testWidgets('double.infinity fills the width the parent allows', (tester) async {
      await tester.pumpWidget(
        _host(MovieLogButton(label: '가입하기', width: double.infinity, onPressed: () {})),
      );

      expect(tester.getSize(find.byType(MovieLogButton)).width, 300);
    });

    testWidgets('a fixed value keeps that width regardless of the label', (tester) async {
      await tester.pumpWidget(
        _host(MovieLogButton(label: '확인', width: 96, onPressed: () {})),
      );
      expect(tester.getSize(find.byType(MovieLogButton)).width, 96);

      await tester.pumpWidget(
        _host(MovieLogButton(label: '아주 긴 라벨', width: 96, onPressed: () {})),
      );
      expect(tester.getSize(find.byType(MovieLogButton)).width, 96);
    });

    testWidgets('height is always 44', (tester) async {
      await tester.pumpWidget(_host(MovieLogButton(label: '확인', onPressed: () {})));

      expect(tester.getSize(find.byType(MovieLogButton)).height, 44);
    });
  });
}
