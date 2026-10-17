/// WCAG 2.x contrast for 32-bit ARGB colours. Pure Dart; no Flutter imports.
///
/// Used to keep the built-in themes legible. Custom themes are personal and
/// are not checked: the reader picks their colours for themselves.
library;

import 'dart:math' as math;

/// WCAG AA minimum for normal-size text.
const double wcagAaNormalText = 4.5;

/// Relative luminance of an opaque ARGB colour (alpha is ignored).
double relativeLuminance(int argb) {
  double channel(int shift) {
    final c = ((argb >> shift) & 0xFF) / 255;
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}

/// Contrast ratio between two colours, from 1 (none) to 21 (black/white).
double contrastRatio(int a, int b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final light = math.max(la, lb);
  final dark = math.min(la, lb);
  return (light + 0.05) / (dark + 0.05);
}
