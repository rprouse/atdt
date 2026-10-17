import 'dart:convert';
import 'dart:io';

import 'package:atdt/fonts/font_manifest.dart';
import 'package:atdt/fonts/glyph_coverage.dart';
import 'package:flutter_test/flutter_test.dart';

FontManifest _bundled() =>
    FontManifest.parse(File('assets/fonts/manifest.json').readAsStringSync());

String _manifestWith(Map<String, Object?> entry) => jsonEncode({
  'fonts': [entry],
});

Map<String, Object?> _valid() => {
  'id': 'x',
  'displayName': 'X',
  'family': 'XFamily',
  'files': ['files/x.ttf'],
  'lineHeightRatio': 1.2,
  'licence': {'name': 'L', 'url': 'https://l', 'file': 'licences/x.txt'},
  'attribution': 'by X',
};

void main() {
  group('the bundled manifest', () {
    test('parses, with four to six fonts', () {
      expect(_bundled().fonts.length, inInclusiveRange(4, 6));
    });

    test('every font file and licence exists and the font is readable', () {
      for (final font in _bundled().fonts) {
        for (final file in font.files) {
          final f = File('assets/fonts/$file');
          expect(f.existsSync(), isTrue, reason: file);
          expect(
            GlyphCoverage.fromFontBytes(f.readAsBytesSync()).codePoints,
            isNotEmpty,
          );
        }
        expect(File('assets/fonts/${font.licenceFile}').existsSync(), isTrue);
        expect(Uri.parse(font.licenceUrl).isAbsolute, isTrue);
        expect(font.attribution, isNotEmpty);
      }
    });

    test('every file in the font folders is used by the manifest', () {
      final fonts = _bundled().fonts;
      final used = {
        for (final f in fonts) ...f.files,
        for (final f in fonts) f.licenceFile,
      };
      for (final dir in ['files', 'licences']) {
        for (final file in Directory('assets/fonts/$dir').listSync()) {
          final path = '$dir/${file.uri.pathSegments.last}';
          expect(used, contains(path), reason: 'unused $path');
        }
      }
    });
  });

  group('adding a font needs no code changes', () {
    test('pubspec bundles the font folders, not individual fonts', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/fonts/manifest.json'));
      expect(pubspec, contains('- assets/fonts/files/'));
      expect(pubspec, contains('- assets/fonts/licences/'));
      expect(pubspec, isNot(contains(RegExp(r'^\s+fonts:', multiLine: true))));
    });

    test('no Dart code names a specific font', () {
      final fonts = _bundled().fonts;
      final names = [
        for (final f in fonts) ...[f.id, f.family],
      ];
      final offenders = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        for (final name in names) {
          if (source.contains("'$name'") || source.contains('"$name"')) {
            offenders.add('${file.path}: $name');
          }
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('validation', () {
    test('reports every problem at once', () {
      final bad = _valid()
        ..remove('family')
        ..['lineHeightRatio'] = -1
        ..['integerScale'] = true;
      expect(
        () => FontManifest.parse(_manifestWith(bad)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('family'),
              contains('lineHeightRatio'),
              contains('cellWidthPx'),
            ),
          ),
        ),
      );
    });

    test('duplicate ids are rejected', () {
      final json = jsonEncode({
        'fonts': [
          _valid(),
          {..._valid(), 'family': 'Other'},
        ],
      });
      expect(() => FontManifest.parse(json), throwsFormatException);
    });

    test('an empty or malformed manifest is rejected', () {
      expect(() => FontManifest.parse('{"fonts": []}'), throwsFormatException);
      expect(() => FontManifest.parse('not json'), throwsFormatException);
    });

    test('a valid entry parses', () {
      final font = FontManifest.parse(_manifestWith(_valid())).fonts.single;
      expect(
        (font.id, font.family, font.lineHeightRatio),
        ('x', 'XFamily', 1.2),
      );
      expect(font.integerScale, isFalse);
    });
  });
}
