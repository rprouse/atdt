import 'package:atdt/app.dart';
import 'package:atdt/reader/reader_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots into the reader inside a ProviderScope', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AtdtApp()));
    await tester.pumpAndSettle();

    expect(find.byType(ReaderView), findsOneWidget);
  });
}
