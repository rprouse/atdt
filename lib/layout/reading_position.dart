/// A reading position independent of font size and viewport.
///
/// Pixel offsets change with every metrics change; this tuple does not, so
/// it is what we store and restore. See "Virtualisation and position" in
/// docs/atdt-initial-spec.md.
library;

// A fraction this close to 1 is the next line, not the end of this one.
// Without it, (450 + 0.0) * h / h can come back as 449.9999 and a restore
// lands one line early.
const double _epsilon = 1e-6;

class ReadingPosition {
  const ReadingPosition({
    required this.topLineIndex,
    required this.fractionIntoLine,
    required this.columnOffset,
  });

  const ReadingPosition.top()
    : topLineIndex = 0,
      fractionIntoLine = 0,
      columnOffset = 0;

  factory ReadingPosition.fromOffsets({
    required double verticalOffset,
    required double horizontalOffset,
    required double lineHeight,
    required double glyphAdvance,
  }) {
    final lines = verticalOffset <= 0 ? 0.0 : verticalOffset / lineHeight;
    var top = lines.floor();
    var fraction = lines - top;
    if (fraction > 1 - _epsilon) {
      top += 1;
      fraction = 0;
    } else if (fraction < _epsilon) {
      fraction = 0;
    }
    final columns = horizontalOffset <= 0
        ? 0.0
        : horizontalOffset / glyphAdvance;
    return ReadingPosition(
      topLineIndex: top,
      fractionIntoLine: fraction,
      columnOffset: columns,
    );
  }

  /// Index of the line at the top edge of the viewport.
  final int topLineIndex;

  /// How far that line is scrolled past the top edge, in [0, 1).
  final double fractionIntoLine;

  /// Horizontal scroll, in columns (may be fractional).
  final double columnOffset;

  double verticalOffset(double lineHeight) =>
      (topLineIndex + fractionIntoLine) * lineHeight;

  double horizontalOffset(double glyphAdvance) => columnOffset * glyphAdvance;

  @override
  bool operator ==(Object other) =>
      other is ReadingPosition &&
      other.topLineIndex == topLineIndex &&
      other.fractionIntoLine == fractionIntoLine &&
      other.columnOffset == columnOffset;

  @override
  int get hashCode => Object.hash(topLineIndex, fractionIntoLine, columnOffset);

  @override
  String toString() =>
      'ReadingPosition($topLineIndex + $fractionIntoLine, col $columnOffset)';
}
