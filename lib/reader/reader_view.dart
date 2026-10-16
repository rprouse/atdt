import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../ingest/spike_text.dart';
import '../layout/layout_calculator.dart';
import '../layout/reading_position.dart';
import 'reader_font.dart';

const double readerHorizontalPadding = 8;

/// What the debug overlay shows. Updated as the reader lays out and scrolls.
@immutable
class ReaderDiagnostics {
  const ReaderDiagnostics({
    required this.layout,
    required this.position,
    required this.advanceRatio,
  });

  final ReaderLayout layout;
  final ReadingPosition position;
  final double advanceRatio;
}

/// The 80-column reader.
///
/// Scroll structure: a horizontal scroll view wrapping a fixed-width,
/// fixed-extent vertical list, so every line scrolls sideways as one block
/// and line index maps to scroll offset by arithmetic. Whenever the layout
/// changes (rotation, font, insets) the scroll controllers are rebuilt with
/// initial offsets taken from the stored [ReadingPosition], so the first
/// frame at the new metrics is already in place.
class ReaderView extends StatefulWidget {
  const ReaderView({
    required this.text,
    required this.font,
    required this.foreground,
    super.key,
    this.onVerticalUserScroll,
    this.diagnostics,
    this.initialPosition = const ReadingPosition.top(),
  });

  final PhileText text;
  final ReaderFont font;
  final Color foreground;

  /// Called with the direction of user-driven vertical scrolling.
  final ValueChanged<ScrollDirection>? onVerticalUserScroll;

  /// Receives layout and position updates for the debug overlay.
  final ValueNotifier<ReaderDiagnostics?>? diagnostics;
  final ReadingPosition initialPosition;

  @override
  State<ReaderView> createState() => ReaderViewState();
}

@visibleForTesting
class ReaderViewState extends State<ReaderView> {
  late ReadingPosition _position = widget.initialPosition;
  ReaderLayout? _layout;
  Object? _epoch;
  ScrollController? _vertical;
  ScrollController? _horizontal;

  ReadingPosition get position => _position;
  ReaderLayout? get layout => _layout;
  ScrollController? get verticalController => _vertical;
  ScrollController? get horizontalController => _horizontal;

  @override
  void didUpdateWidget(ReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.text, widget.text)) {
      _position = const ReadingPosition.top();
      _epoch = null;
    }
  }

  @override
  void dispose() {
    _vertical?.dispose();
    _horizontal?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final insets = stableHorizontalInsets(mediaQuery, constraints.maxWidth);
        final viewport = ViewportMetrics(
          logicalWidth: constraints.maxWidth,
          devicePixelRatio: mediaQuery.devicePixelRatio,
          safeAreaLeft: insets.left,
          safeAreaRight: insets.right,
          horizontalPadding: readerHorizontalPadding,
        );
        if (viewport.availableWidth <= 0 || constraints.maxHeight <= 0) {
          return const SizedBox.expand();
        }

        final advanceRatio = measureAdvanceRatio(widget.font);
        final layout = computeLayout(
          viewport: viewport,
          font: widget.font.metrics(advanceRatio),
          longestLineColumns: widget.text.longestLineColumns,
        );
        _ensureControllers(layout, constraints, advanceRatio);

        // At fit the content is exactly the viewport; overflow columns add
        // their width on the right.
        final contentWidth =
            constraints.maxWidth +
            (layout.contentColumns - fitColumns) * layout.glyphAdvance;

        return MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          removeLeft: true,
          removeRight: true,
          child: NotificationListener<UserScrollNotification>(
            onNotification: _onUserScroll,
            child: SingleChildScrollView(
              key: ValueKey(('h', _epoch)),
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight,
                child: ListView.builder(
                  key: ValueKey(('v', _epoch)),
                  controller: _vertical,
                  // Explicit zero padding: the default adds MediaQuery
                  // padding, which changes when the status bar hides.
                  padding: EdgeInsets.zero,
                  itemExtent: layout.lineHeight,
                  itemCount: widget.text.lines.length,
                  itemBuilder: (context, index) =>
                      _line(widget.text.lines[index], layout),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _line(String text, ReaderLayout layout) {
    final height = layout.lineHeight / layout.fontSize;
    return Padding(
      padding: EdgeInsets.only(left: layout.textLeft),
      child: Text(
        text,
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.visible,
        textScaler: TextScaler.noScaling,
        // inherit: false: an ancestor's letter spacing, weight or decoration
        // must never reach the reader and change column widths.
        style: TextStyle(
          inherit: false,
          fontFamily: widget.font.family,
          fontSize: layout.fontSize,
          fontWeight: FontWeight.normal,
          fontStyle: FontStyle.normal,
          letterSpacing: 0,
          wordSpacing: 0,
          textBaseline: TextBaseline.alphabetic,
          height: height,
          leadingDistribution: TextLeadingDistribution.even,
          color: widget.foreground,
          fontFeatures: readerFontFeatures,
        ),
        // Forcing the strut stops fallback glyphs from a taller font
        // stretching a row past its fixed extent.
        strutStyle: StrutStyle(
          fontFamily: widget.font.family,
          fontSize: layout.fontSize,
          height: height,
          leadingDistribution: TextLeadingDistribution.even,
          forceStrutHeight: true,
        ),
      ),
    );
  }

  void _ensureControllers(
    ReaderLayout layout,
    BoxConstraints constraints,
    double advanceRatio,
  ) {
    final epoch = (
      layout.lineHeight,
      layout.glyphAdvance,
      layout.textLeft,
      layout.contentColumns,
      constraints.maxWidth,
      widget.font.id,
      identityHashCode(widget.text),
    );
    _layout = layout;
    if (epoch == _epoch && _vertical != null) {
      _publish(advanceRatio);
      return;
    }
    _epoch = epoch;

    if (layout.usedFallback) {
      developer.log(
        '${widget.font.displayName} cannot fit 80 columns at integer '
        'scale 1; using fit size ${layout.fontSize.toStringAsFixed(2)}',
        name: 'atdt.reader',
        level: 900,
      );
    }

    final maxVertical = math.max(
      0,
      widget.text.lines.length * layout.lineHeight - constraints.maxHeight,
    );
    final maxHorizontal =
        (layout.contentColumns - fitColumns) * layout.glyphAdvance;

    final oldVertical = _vertical;
    final oldHorizontal = _horizontal;
    _vertical = ScrollController(
      keepScrollOffset: false,
      initialScrollOffset: _position
          .verticalOffset(layout.lineHeight)
          .clamp(0, maxVertical)
          .toDouble(),
    )..addListener(_onScroll);
    _horizontal = ScrollController(
      keepScrollOffset: false,
      initialScrollOffset: _position
          .horizontalOffset(layout.glyphAdvance)
          .clamp(0, maxHorizontal)
          .toDouble(),
    )..addListener(_onScroll);

    // The old scroll views detach during this frame; dispose afterwards.
    if (oldVertical != null || oldHorizontal != null) {
      oldVertical?.removeListener(_onScroll);
      oldHorizontal?.removeListener(_onScroll);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldVertical?.dispose();
        oldHorizontal?.dispose();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _publish(advanceRatio));
  }

  void _onScroll() {
    final layout = _layout;
    final v = _vertical;
    final h = _horizontal;
    if (layout == null || v == null || h == null) return;
    if (!v.hasClients || !h.hasClients) return;
    _position = ReadingPosition.fromOffsets(
      verticalOffset: v.offset,
      horizontalOffset: h.offset,
      lineHeight: layout.lineHeight,
      glyphAdvance: layout.glyphAdvance,
    );
    _publish(measureAdvanceRatio(widget.font));
  }

  void _publish(double advanceRatio) {
    final layout = _layout;
    if (layout == null || widget.diagnostics == null || !mounted) return;
    widget.diagnostics!.value = ReaderDiagnostics(
      layout: layout,
      position: _position,
      advanceRatio: advanceRatio,
    );
  }

  bool _onUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical &&
        notification.direction != ScrollDirection.idle) {
      widget.onVerticalUserScroll?.call(notification.direction);
    }
    return false;
  }
}

/// Horizontal insets that do not change when system bars show or hide.
///
/// On Android the navigation bar can sit on the left or right in landscape,
/// and it disappears in immersive mode; following `viewPadding` would move
/// every line when the chrome toggles. Display cutouts never hide, so they
/// are what we avoid. iOS safe areas do not change with the status bar.
EdgeInsets stableHorizontalInsets(MediaQueryData mediaQuery, double width) {
  if (!kIsWeb && Platform.isIOS) {
    return EdgeInsets.only(
      left: mediaQuery.viewPadding.left,
      right: mediaQuery.viewPadding.right,
    );
  }
  var left = 0.0;
  var right = 0.0;
  for (final feature in mediaQuery.displayFeatures) {
    if (feature.type != DisplayFeatureType.cutout) continue;
    final bounds = feature.bounds;
    if (bounds.left <= 1) left = math.max(left, bounds.right);
    if (bounds.right >= width - 1) right = math.max(right, width - bounds.left);
  }
  return EdgeInsets.only(left: left, right: right);
}
