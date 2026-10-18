import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'frame_stats.dart';
import 'reader_theme.dart';
import 'reader_view.dart';

/// Live layout numbers and frame times, for checking the reader on a
/// device. Frame times are only meaningful in profile or release builds.
class DebugOverlay extends StatefulWidget {
  const DebugOverlay({
    required this.diagnostics,
    required this.theme,
    required this.fontFamily,
    super.key,
  });

  final ValueNotifier<ReaderDiagnostics?> diagnostics;
  final ReaderTheme theme;
  final String fontFamily;

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  final _stats = FrameStats(budget: sixtyFpsBudget);
  final _frames = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _frames.dispose();
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _stats.add(build: t.buildDuration, raster: t.rasterDuration);
    }
    if (mounted) _frames.value++;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.diagnostics, _frames]),
      builder: (context, _) {
        final d = widget.diagnostics.value;
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
          ..._frameRows(_stats, View.of(context).display.refreshRate),
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
                fontFamily: widget.fontFamily,
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

String _ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(1);

/// No frame over 16.7 ms means 60 fps or better, on any display.
Map<String, String> _frameRows(FrameStats stats, double refreshRate) {
  final display = {'display': '${refreshRate.round()} Hz'};
  if (stats.frames == 0) return {...display, 'frames': 'scroll to measure'};
  return {
    ...display,
    'build p90': '${_ms(stats.buildP90)} ms',
    'raster p90': '${_ms(stats.rasterP90)} ms',
    'over ${_ms(stats.budget)} ms':
        '${stats.overBudget} of last '
        '${stats.frames} (60 fps)',
  };
}
