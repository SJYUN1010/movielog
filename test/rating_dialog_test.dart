import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/widgets/rating_dialog.dart';
import 'package:movielog/widgets/rating_delete_dialog.dart';

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

class _Host {
  bool? result;
  bool closed = false;
}

Future<_Host> _openRatingDialog(
  WidgetTester tester, {
  required Future<void> Function(int score, String? comment) onSubmit,
  int initialScore = 0,
  String? initialComment,
}) async {
  _useMobileViewport(tester);
  final host = _Host();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              host.result = await RatingDialog.show(
                context,
                onSubmit: onSubmit,
                initialScore: initialScore,
                initialComment: initialComment,
              );
              host.closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return host;
}

/// 화면 안의 모든 PopScope입니다(제네릭 타입과 관계없이 찾습니다).
List<PopScope> _popScopes(WidgetTester tester) =>
    tester.widgetList(find.byWidgetPredicate((widget) => widget is PopScope)).cast<PopScope>().toList();

ElevatedButton _confirm(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '확인'));

Future<void> _tapStar(WidgetTester tester, int index) async {
  await tester.tap(find.byIcon(Icons.star_border).at(index));
  await tester.pump();
}

void main() {
  group('RatingDialog', () {
    testWidgets('shows the comment field under the stars, and confirm needs a star', (tester) async {
      await _openRatingDialog(tester, onSubmit: (score, comment) async {});

      expect(find.text('평점을 남겨주세요'), findsOneWidget);
      expect(find.text('코멘트 (선택, 최대 500자)'), findsOneWidget);
      expect(find.text('이 영화의 인상적인 장면은...'), findsOneWidget);
      expect(_confirm(tester).onPressed, isNull);

      // 코멘트만 입력해서는 활성화되지 않습니다.
      await tester.enterText(find.byType(TextField), '좋았어요');
      await tester.pump();
      expect(_confirm(tester).onPressed, isNull);

      await _tapStar(tester, 3);
      expect(_confirm(tester).onPressed, isNotNull);
    });

    testWidgets('sends a whole-number score and the trimmed comment, then closes with true', (
      tester,
    ) async {
      int? sentScore;
      String? sentComment = 'unset';
      final host = await _openRatingDialog(
        tester,
        onSubmit: (score, comment) async {
          sentScore = score;
          sentComment = comment;
        },
      );

      await _tapStar(tester, 3); // 별 4개
      await tester.enterText(find.byType(TextField), '  인상적이었어요  ');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();

      expect(sentScore, 4);
      expect(sentComment, '인상적이었어요');
      expect(host.result, isTrue);
      expect(find.byType(RatingDialog), findsNothing);
    });

    testWidgets('an empty or blank comment is sent as null', (tester) async {
      String? sentComment = 'unset';
      await _openRatingDialog(
        tester,
        onSubmit: (score, comment) async => sentComment = comment,
      );

      await _tapStar(tester, 1);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();

      expect(sentComment, isNull);
    });

    testWidgets('the comment is limited to 500 characters', (tester) async {
      await _openRatingDialog(tester, onSubmit: (score, comment) async {});

      await tester.enterText(find.byType(TextField), 'a' * 600);
      await tester.pump();

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text.length, 500);
    });

    testWidgets('cancel returns false and never calls onSubmit', (tester) async {
      var calls = 0;
      final host = await _openRatingDialog(
        tester,
        onSubmit: (score, comment) async => calls++,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, '취소'));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(host.result, isFalse);
    });

    testWidgets('while saving: loading button, locked inputs, no cancel and no back', (tester) async {
      final completer = Completer<void>();
      final host = await _openRatingDialog(
        tester,
        onSubmit: (score, comment) => completer.future,
      );
      await _tapStar(tester, 2);
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pump();

      // 저장 중에는 글자 대신 인디케이터만 그리고, 버튼은 눌리지 않습니다.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('확인'), findsNothing);
      final loadingButton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(loadingButton.onPressed, isNull);
      expect(
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '취소')).onPressed,
        isNull,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(_popScopes(tester).any((scope) => !scope.canPop), isTrue);

      // 바깥을 눌러도 닫히지 않습니다(barrierDismissible: false).
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(RatingDialog), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
      expect(host.result, isTrue);
    });

    testWidgets('a second tap while saving does not send a second request', (tester) async {
      final completer = Completer<void>();
      var calls = 0;
      await _openRatingDialog(
        tester,
        onSubmit: (score, comment) {
          calls++;
          return completer.future;
        },
      );
      await _tapStar(tester, 4);

      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pump();
      // 저장 중에는 버튼이 로딩 상태라 다시 눌러도 요청이 나가지 않습니다.
      await tester.tap(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pump();

      expect(calls, 1);
      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a failed save keeps the dialog, the input and the message, and unlocks the button', (
      tester,
    ) async {
      var attempt = 0;
      final host = await _openRatingDialog(
        tester,
        onSubmit: (score, comment) async {
          attempt++;
          if (attempt == 1) throw StateError('이미 이 영화에 평점을 남기셨습니다.');
        },
      );
      await _tapStar(tester, 3);
      await tester.enterText(find.byType(TextField), '지켜져야 하는 후기');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(host.closed, isFalse);
      expect(find.text('이미 이 영화에 평점을 남기셨습니다.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '지켜져야 하는 후기');
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_confirm(tester).onPressed, isNotNull);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);

      // 같은 값으로 다시 시도하면 성공하고, 이전 오류 문구는 사라집니다.
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();
      expect(host.result, isTrue);
    });

    testWidgets('edit mode starts with the saved score and comment', (tester) async {
      int? sentScore;
      await _openRatingDialog(
        tester,
        initialScore: 2,
        initialComment: '예전 후기',
        onSubmit: (score, comment) async => sentScore = score,
      );

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '예전 후기');
      expect(_confirm(tester).onPressed, isNotNull);

      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();
      expect(sentScore, 2);
    });
  });

  group('RatingDeleteDialog', () {
    Future<_Host> open(
      WidgetTester tester, {
      Future<void> Function()? onConfirm,
    }) async {
      _useMobileViewport(tester);
      final host = _Host();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  host.result = await RatingDeleteDialog.show(context, onConfirm: onConfirm);
                  host.closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return host;
    }

    testWidgets('asks before deleting and cancel returns false without any request', (tester) async {
      var calls = 0;
      final host = await open(tester, onConfirm: () async => calls++);

      expect(find.text('평점을 삭제할까요?'), findsOneWidget);
      expect(find.text('삭제한 평점은 복구할 수 없습니다.'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, '취소'));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(host.result, isFalse);
    });

    testWidgets('with onConfirm it stays open while deleting and then closes with true', (tester) async {
      final completer = Completer<void>();
      final host = await open(tester, onConfirm: () => completer.future);

      await tester.tap(find.widgetWithText(ElevatedButton, '삭제'));
      await tester.pump();

      expect(find.byType(RatingDeleteDialog), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '취소')).onPressed,
        isNull,
      );

      completer.complete();
      await tester.pumpAndSettle();
      expect(host.result, isTrue);
    });

    testWidgets('without onConfirm (multi delete) it closes immediately with true', (tester) async {
      final host = await open(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, '삭제'));
      await tester.pumpAndSettle();

      expect(host.result, isTrue);
      expect(find.byType(RatingDeleteDialog), findsNothing);
    });

    testWidgets('a failed delete keeps the dialog open with the server message and can retry', (
      tester,
    ) async {
      var attempt = 0;
      final host = await open(
        tester,
        onConfirm: () async {
          attempt++;
          if (attempt == 1) throw StateError('존재하지 않는 평점입니다.');
        },
      );

      await tester.tap(find.widgetWithText(ElevatedButton, '삭제'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDeleteDialog), findsOneWidget);
      expect(find.text('존재하지 않는 평점입니다.'), findsOneWidget);
      expect(host.closed, isFalse);

      await tester.tap(find.widgetWithText(ElevatedButton, '삭제'));
      await tester.pumpAndSettle();
      expect(host.result, isTrue);
    });
  });
}
