import 'package:flutter/material.dart';

/// The issue and phile lists: half Material's gap between rows.
///
/// A two-line Material 3 row pads 44 dp of text out to a 72 dp minimum,
/// leaving 28 dp between rows' text. Dropping the minimum and padding 7 dp
/// above and below leaves 14 dp (58 dp rows). Rows never go below 48 dp,
/// the Android tap-target size.
class CompactListTiles extends StatelessWidget {
  const CompactListTiles({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListTileTheme.merge(
    minVerticalPadding: 7,
    minTileHeight: 48,
    child: child,
  );
}
