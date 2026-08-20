// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku_app/main.dart';

void main() {
  testWidgets('SudokuApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SudokuApp());
    await tester.pumpAndSettle();

    // Verify title and difficulty panel
    expect(find.text('Sudoku Game'), findsOneWidget);
    expect(find.textContaining('레벨 1'), findsWidgets);
    expect(find.textContaining('9×9 보드 채워진 숫자: 62개'), findsOneWidget);
  });
}
