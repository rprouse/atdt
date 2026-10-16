import 'package:flutter/material.dart';

import 'reader_theme.dart';
import 'reader_view.dart';

/// Live layout numbers for checking the spike on a device.
class DebugOverlay extends StatelessWidget {
  const DebugOverlay({
    required this.diagnostics,
    required this.theme,
    super.key,
  });

  final ValueNotifier<ReaderDiagnostics?> diagnostics;
  final ReaderTheme theme;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReaderDiagnostics?>(
      valueListenable: diagnostics,
      builder: (context, d, _) {
        if (d == null) return const SizedBox.shrink();
        final l = d.layout;
        final p = d.position;
        final scale = switch ((l.integerScale, l.usedFallback)) {
          (final int s, _) => '${s}x',
          (null, true) => 'FALLBACK (fit)',
          _ => 'n/a (vector)',
        };
        final rows = {
          'font size': l.fontSize.toStringAsFixed(3),
          'scale': scale,
          'line height': l.lineHeight.toStringAsFixed(3),
          'advance':
              '${l.glyphAdvance.toStringAsFixed(3)} '
              '(ratio ${d.advanceRatio.toStringAsFixed(4)})',
          'top line':
              '${p.topLineIndex} + '
              '${p.fractionIntoLine.toStringAsFixed(2)}',
          'column offset': p.columnOffset.toStringAsFixed(2),
          'dpr': l.devicePixelRatio.toStringAsFixed(3),
          'available width': l.availableWidth.toStringAsFixed(2),
          'text left': l.textLeft.toStringAsFixed(2),
          'columns': '${l.contentColumns}',
        };
        return DecoratedBox(
          key: const ValueKey('debug-overlay'),
          decoration: BoxDecoration(
            color: theme.background.withValues(alpha: 0.88),
            border: Border.all(color: theme.dim),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: DefaultTextStyle(
              style: TextStyle(
                color: theme.foreground,
                fontSize: 11,
                fontFamily: 'JetBrainsMono',
                height: 1.3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final MapEntry(:key, :value) in rows.entries)
                    Text('${key.padRight(15)} $value'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
