import 'dart:ui';

import 'package:atdt/reader/reader_theme.dart';
import 'package:atdt/themes/contrast.dart';
import 'package:flutter_test/flutter_test.dart';

double _ratio(Color a, Color b) => contrastRatio(a.toARGB32(), b.toARGB32());

void main() {
  group('built-in themes meet WCAG AA', () {
    // Custom themes are personal and deliberately unchecked; the shipped
    // ones are what everyone starts with.
    for (final t in builtInThemes) {
      test(t.id, () {
        for (final (name, colour, against) in [
          ('text', t.foreground, t.background),
          ('accent', t.accent, t.background),
          ('dim', t.dim, t.background),
          ('selected text', t.foreground, t.selection),
        ]) {
          expect(
            _ratio(colour, against),
            greaterThanOrEqualTo(wcagAaNormalText),
            reason: '${t.id}: $name',
          );
        }
      });
    }

    test('high contrast reaches AAA (7:1)', () {
      final t = builtInThemes.singleWhere((t) => t.id == 'high_contrast');
      expect(_ratio(t.foreground, t.background), greaterThanOrEqualTo(7));
    });
  });

  test('the spec built-ins are all present, with unique ids', () {
    final ids = [for (final t in builtInThemes) t.id];
    expect(
      ids,
      containsAll([
        'green_phosphor',
        'amber_phosphor',
        'paper',
        'high_contrast',
      ]),
    );
    expect(ids.toSet(), hasLength(ids.length));
    expect(builtInThemes.every((t) => t.builtIn), isTrue);
  });

  test('brightness follows the background', () {
    expect(
      builtInThemes.firstWhere((t) => t.id == 'paper').brightness,
      Brightness.light,
    );
    expect(builtInThemes.first.brightness, Brightness.dark);
  });

  group('saving custom themes', () {
    const custom = ReaderTheme(
      id: 'custom-1',
      displayName: 'Mine',
      background: Color(0xFF102030),
      foreground: Color(0xFFE0E0E0),
      selection: Color(0xFF305070),
      accent: Color(0xFFFF8800),
      dim: Color(0xFF8899AA),
    );

    test('round-trips through JSON', () {
      final decoded = decodeThemes(encodeThemes([custom]));
      expect(decoded, [custom]);
      expect(decoded.single.builtIn, isFalse);
      expect(custom.toJson()['background'], '#102030');
    });

    test('malformed entries are skipped, not fatal', () {
      final json =
          '[${encodeThemes([custom]).replaceAll('[', '').replaceAll(']', '')},'
          '{"id": "x", "name": "Broken", "background": "#zzzzzz"}, 42]';
      expect(decodeThemes(json), [custom]);
      expect(decodeThemes('not json'), isEmpty);
      expect(decodeThemes('{}'), isEmpty);
    });

    test('hex parsing', () {
      expect(parseHexColour('#ffB000'), const Color(0xFFFFB000));
      expect(parseHexColour('00ff00'), const Color(0xFF00FF00));
      expect(parseHexColour('#fff'), isNull);
      expect(parseHexColour('#gggggg'), isNull);
    });
  });
}
