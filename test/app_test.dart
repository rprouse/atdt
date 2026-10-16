import 'package:atdt/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots inside a ProviderScope', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AtdtApp()));

    expect(find.text('ATDT'), findsOneWidget);
  });
}
