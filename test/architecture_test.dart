import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Directories that must stay pure Dart (AGENTS.md hard rule 3), so their
/// logic can be unit-tested without a Flutter binding.
const _pureDartDirs = ['lib/layout', 'lib/ingest', 'lib/archive'];

final _forbiddenImport = RegExp(
  r'''^\s*(import|export)\s+['"](package:flutter/|package:flutter_riverpod/|dart:ui)''',
  multiLine: true,
);

void main() {
  for (final dir in _pureDartDirs) {
    test('$dir has no Flutter imports', () {
      final root = Directory(dir);
      if (!root.existsSync()) return;

      final offenders = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => _forbiddenImport.hasMatch(f.readAsStringSync()))
          .map((f) => f.path)
          .toList();

      expect(offenders, isEmpty, reason: 'Pure-Dart code imports Flutter');
    });
  }
}
