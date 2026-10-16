import 'package:atdt/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches on device', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('ATDT'), findsOneWidget);
  });
}
