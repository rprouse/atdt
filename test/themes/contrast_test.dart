import 'package:atdt/themes/contrast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('black on white is 21:1, a colour against itself is 1:1', () {
    expect(contrastRatio(0xFF000000, 0xFFFFFFFF), closeTo(21, 1e-9));
    expect(contrastRatio(0xFF777777, 0xFF777777), closeTo(1, 1e-9));
  });

  test('order does not matter', () {
    expect(
      contrastRatio(0xFF0000AA, 0xFFAAAAAA),
      closeTo(contrastRatio(0xFFAAAAAA, 0xFF0000AA), 1e-12),
    );
  });

  test('matches published WCAG reference values', () {
    // #767676 on white is the classic "just passes AA" grey (4.54:1).
    expect(contrastRatio(0xFF767676, 0xFFFFFFFF), closeTo(4.54, 0.01));
    // Pure red on white is 4.0:1.
    expect(contrastRatio(0xFFFF0000, 0xFFFFFFFF), closeTo(4.0, 0.01));
  });

  test('alpha is ignored', () {
    expect(
      relativeLuminance(0x00FFFFFF),
      closeTo(relativeLuminance(0xFFFFFFFF), 1e-12),
    );
  });
}
