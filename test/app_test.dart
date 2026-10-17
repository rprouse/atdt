import 'package:atdt/app.dart';
import 'package:atdt/library/issues_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/archive_harness.dart';

void main() {
  testWidgets('app boots into the library inside a ProviderScope', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(overrides: archiveOverrides(), child: const AtdtApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IssuesScreen), findsOneWidget);
  });
}
