import 'dart:io';

import 'package:atdt/settings/privacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the in-app statement matches docs/privacy.md', () {
    final doc = File('docs/privacy.md').readAsStringSync();
    for (final (heading, body) in privacyStatement) {
      expect(doc, contains('## $heading\n\n$body\n'), reason: heading);
    }
  });

  testWidgets('the privacy screen shows every section', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));
    for (final (heading, _) in privacyStatement) {
      await tester.scrollUntilVisible(find.text(heading), 100);
      expect(find.text(heading), findsOneWidget);
    }
  });
}
