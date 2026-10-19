import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../ingest/phile_text.dart';
import '../layout/layout_calculator.dart';
import '../layout/reading_position.dart';
import '../layout/text_block.dart';
import '../search/search_query.dart';
import 'reader_font.dart';

const double readerHorizontalPadding = 8;

/// What the debug overlay shows. Updated as the reader lays out and scrolls.
@immutable
class ReaderDiagnostics {
  const ReaderDiagnostics({
    required this.layout,
    required this.position,
    required this.advanceRatio,
    this.viewportHeight = 0,
    this.lineCount = 0,
  });

  final ReaderLayout layout;
  final ReadingPosition position;
  final double advanceRatio;
  final double viewportHeight;
  final int lineCount;

  /// How far through the phile the bottom of the screen is, 0 to 1.
  double get progress {
    if (lineCount == 0) return 1;
    final visible = viewportHeight / layout.lineHeight;
    final bottom = position.topLineIndex + position.fractionIntoLine + visible;
    return (bottom / lineCount).clamp(0, 1).toDouble();
  }
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
    this.onPositionChanged,
    this.initialPosition = const ReadingPosition.top(),
    this.selection,
    this.selectionColor,
    this.revealLine,
    this.highlight,
  });

  final PhileText text;
  final ReaderFont font;
  final Color foreground;

  /// Called with each movement of user-driven vertical scrolling (a drag,
  /// or the fling after it), in logical pixels: positive reads further
  /// down. Programmatic scrolling (paging, jumps) is not reported.
  final ValueChanged<double>? onVerticalUserScroll;

  /// Receives layout and position updates for the debug overlay.
  final ValueNotifier<ReaderDiagnostics?>? diagnostics;

  /// Called as the user scrolls, with the position to save.
  final ValueChanged<ReadingPosition>? onPositionChanged;
  final ReadingPosition initialPosition;

  /// The block a long press selected, for copying; null when none is.
  /// Supplying it turns long-press selection on.
  final ValueNotifier<LineBlock?>? selection;

  /// Behind selected lines and search matches.
  final Color? selectionColor;

  /// Opens with this line a third of the way down the screen, clear of the
  /// chrome, instead of at [initialPosition] (a search result).
  final int? revealLine;

  /// Matches of this query are highlighted on every line.
  final SearchQuery? highlight;

  @override
  State<ReaderView> createState() => ReaderViewState();
}

/// Pinch zoom stops here; beyond 4x the 80-column view is mostly scrolling.
const double maxReaderZoom = 4;

/// Public so the reader screen can page ([page]) and tests can inspect
/// layout and position.
class ReaderViewState extends State<ReaderView> {
  late ReadingPosition _position = widget.initialPosition;
  ReaderLayout? _layout;
  double _viewportHeight = 0;
  Object? _epoch;
  ScrollController? _vertical;
  ScrollController? _horizontal;

  // Zoom: committed when a pinch ends; previewed as a transform during it,
  // so the text is laid out once per pinch, not once per frame.
  double _zoom = 1;
  double? _pinch;
  double? _layoutWidth;
  double _pinchStartDistance = 0;
  final _pointers = <int, Offset>{};

  ReadingPosition get position => _position;
  ReaderLayout? get layout => _layout;
  double get zoom => _zoom;

  /// Zooms to [zoom] (clamped to fit..[maxReaderZoom]), keeping the top
  /// line and column. Pinches call this when they end.
  void setZoom(double zoom) =>
      setState(() => _zoom = zoom.clamp(1, maxReaderZoom).toDouble());

  /// Scrolls one screen down (1) or up (-1), keeping one line of overlap.
  Future<void> page(int direction) async {
    final layout = _layout;
    final v = _vertical;
    if (layout == null || v == null || !v.hasClients) return;
    final step = math.max(
      layout.lineHeight,
      _viewportHeight - layout.lineHeight,
    );
    final target = (v.offset + direction * step).clamp(
      0.0,
      v.position.maxScrollExtent,
    );
    await v.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  /// Puts [line] at the top of the screen (a section heading).
  void jumpToLine(int line) {
    final layout = _layout;
    final v = _vertical;
    if (layout == null || v == null || !v.hasClients) return;
    v.jumpTo((line * layout.lineHeight).clamp(0.0, v.position.maxScrollExtent));
  }

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

        // Zoom resets to fit on rotation (or any other width change).
        if (_layoutWidth != null && _layoutWidth != constraints.maxWidth) {
          _zoom = 1;
        }
        _layoutWidth = constraints.maxWidth;

        final advanceRatio = measureAdvanceRatio(widget.font);
        final layout = computeLayout(
          viewport: viewport,
          font: widget.font.metrics(advanceRatio),
          longestLineColumns: widget.text.longestLineColumns,
          zoom: _zoom,
        );
        // The text block plus its right margin; at fit that is exactly the
        // viewport, and zoom or long lines make it scroll sideways.
        final needed =
            layout.textLeft +
            layout.contentWidth +
            insets.right +
            readerHorizontalPadding;
        final contentWidth = needed - constraints.maxWidth < 0.5
            ? constraints.maxWidth
            : needed;
        _ensureControllers(
          layout,
          constraints,
          advanceRatio,
          maxHorizontal: contentWidth - constraints.maxWidth,
        );

        // Characters the font lacks are drawn as its own placeholder glyph,
        // never via system fallback, whose different width would shift
        // every column after it. Checked once against the phile's
        // inventory, so fully covered philes skip it entirely.
        final coverage = widget.font.coverage;
        final substitute = !coverage.coversAll(widget.text.inventory);

        // Two fingers on the text are a pinch, not a scroll.
        final physics = _pointers.length >= 2
            ? const NeverScrollableScrollPhysics()
            : null;
        final selection = widget.selection;

        Widget list() => ListView.builder(
          key: ValueKey(('v', _epoch)),
          controller: _vertical,
          physics: physics,
          // Explicit zero padding: the default adds MediaQuery padding,
          // which changes when the status bar hides.
          padding: EdgeInsets.zero,
          itemExtent: layout.lineHeight,
          itemCount: widget.text.lines.length,
          itemBuilder: (context, index) {
            final line = widget.text.lines[index];
            Widget row = _line(
              substitute ? coverage.substitute(line) : line,
              layout,
              index,
            );
            if (selection == null) return row;
            if (selection.value?.contains(index) ?? false) {
              row = ColoredBox(
                key: ValueKey('selected-$index'),
                color: widget.selectionColor ?? const Color(0x664488FF),
                child: row,
              );
            }
            return GestureDetector(
              onLongPress: () =>
                  selection.value = blockAround(widget.text.lines, index),
              child: row,
            );
          },
        );

        Widget content = SingleChildScrollView(
          key: ValueKey(('h', _epoch)),
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          physics: physics,
          child: SizedBox(
            width: contentWidth,
            height: constraints.maxHeight,
            child: selection == null
                ? list()
                : ValueListenableBuilder<LineBlock?>(
                    valueListenable: selection,
                    builder: (context, _, _) => list(),
                  ),
          ),
        );
        if (_pinch case final scale?) {
          // Preview anchored top-left, like the committed zoom, which
          // keeps the top line and column.
          content = Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: content,
          );
        }

        return MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          removeLeft: true,
          removeRight: true,
          child: Listener(
            onPointerDown: _pointerDown,
            onPointerMove: _pointerMove,
            onPointerUp: _pointerEnd,
            onPointerCancel: _pointerEnd,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: ClipRect(child: content),
            ),
          ),
        );
      },
    );
  }

  Widget _line(String text, ReaderLayout layout, int index) {
    final height = layout.lineHeight / layout.fontSize;
    // inherit: false: an ancestor's letter spacing, weight or decoration
    // must never reach the reader and change column widths.
    final style = TextStyle(
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
    );
    // Forcing the strut stops fallback glyphs from a taller font stretching
    // a row past its fixed extent.
    final strut = StrutStyle(
      fontFamily: widget.font.family,
      fontSize: layout.fontSize,
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
      forceStrutHeight: true,
    );
    const noWrap = TextOverflow.visible;

    final matches = widget.highlight?.highlights(text) ?? const [];
    if (matches.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(left: layout.textLeft),
        child: Text(
          text,
          softWrap: false,
          maxLines: 1,
          overflow: noWrap,
          textScaler: TextScaler.noScaling,
          style: style,
          strutStyle: strut,
        ),
      );
    }

    // A background on the matched spans paints behind the glyphs and never
    // changes their advance, so no column moves.
    final mark = TextStyle(
      backgroundColor: widget.selectionColor ?? const Color(0x664488FF),
    );
    var at = 0;
    final spans = <TextSpan>[
      for (final (start, end) in matches) ...[
        TextSpan(text: text.substring(at, start)),
        TextSpan(text: text.substring(start, at = end), style: mark),
      ],
      TextSpan(text: text.substring(at)),
    ];
    return Padding(
      key: ValueKey('match-$index'),
      padding: EdgeInsets.only(left: layout.textLeft),
      child: Text.rich(
        TextSpan(children: spans),
        softWrap: false,
        maxLines: 1,
        overflow: noWrap,
        textScaler: TextScaler.noScaling,
        style: style,
        strutStyle: strut,
      ),
    );
  }

  void _ensureControllers(
    ReaderLayout layout,
    BoxConstraints constraints,
    double advanceRatio, {
    required double maxHorizontal,
  }) {
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
    _viewportHeight = constraints.maxHeight;
    if (epoch == _epoch && _vertical != null) {
      // After the frame: listeners (the chrome's progress) rebuild, and
      // they must not be marked dirty while this widget is building.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _publish(advanceRatio),
      );
      return;
    }
    final firstLayout = _vertical == null;
    _epoch = epoch;
    if (firstLayout && widget.revealLine != null) {
      _position = _revealPosition(widget.revealLine!, layout, constraints);
    }

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

  /// The line a third of the way down; scrolled sideways only if its first
  /// match would be off the right edge (a line wider than 80 columns).
  ReadingPosition _revealPosition(
    int line,
    ReaderLayout layout,
    BoxConstraints constraints,
  ) {
    final visibleLines = constraints.maxHeight / layout.lineHeight;
    final top = math.max(0, line - (visibleLines / 3).floor());
    var column = 0.0;
    final text = line < widget.text.lines.length ? widget.text.lines[line] : '';
    final matches = widget.highlight?.highlights(text) ?? const [];
    if (matches.isNotEmpty) {
      final visibleColumns =
          (constraints.maxWidth - layout.textLeft - readerHorizontalPadding) /
          layout.glyphAdvance;
      final (start, end) = matches.first;
      if (end > visibleColumns) column = math.max(0, start - 8).toDouble();
    }
    return ReadingPosition(
      topLineIndex: top,
      fractionIntoLine: 0,
      columnOffset: column,
    );
  }

  double get _pointerSpread {
    final points = _pointers.values.take(2).toList();
    return (points[0] - points[1]).distance;
  }

  void _pointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      _pinchStartDistance = math.max(1, _pointerSpread);
      setState(() => _pinch = 1);
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (_pinch == null || _pointers.length < 2) return;
    final scale = (_pointerSpread / _pinchStartDistance).clamp(
      1 / _zoom,
      maxReaderZoom / _zoom,
    );
    setState(() => _pinch = scale.toDouble());
  }

  void _pointerEnd(PointerEvent event) {
    _pointers.remove(event.pointer);
    final scale = _pinch;
    if (scale == null || _pointers.length >= 2) {
      if (_pointers.length < 2) setState(() {});
      return;
    }
    setState(() {
      _pinch = null;
      _zoom = (_zoom * scale).clamp(1, maxReaderZoom).toDouble();
    });
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
    widget.onPositionChanged?.call(_position);
  }

  void _publish(double advanceRatio) {
    final layout = _layout;
    if (layout == null || widget.diagnostics == null || !mounted) return;
    widget.diagnostics!.value = ReaderDiagnostics(
      layout: layout,
      position: _position,
      advanceRatio: advanceRatio,
      viewportHeight: _viewportHeight,
      lineCount: widget.text.lines.length,
    );
  }

  /// Between a user scroll starting and going idle, every vertical scroll
  /// update is the user's (their drag or its fling).
  bool _userScrolling = false;

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is UserScrollNotification) {
      _userScrolling = notification.direction != ScrollDirection.idle;
    } else if (notification is ScrollUpdateNotification && _userScrolling) {
      final delta = notification.scrollDelta;
      if (delta != null && delta != 0) widget.onVerticalUserScroll?.call(delta);
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
  return _avoidVerticalHinge(
    mediaQuery,
    width,
    EdgeInsets.only(left: left, right: right),
  );
}

/// A hinge, or a fold that is half open, splitting the window left from
/// right would put the 80 columns across the gap. The text takes the larger
/// pane instead. A fold lying flat separates nothing and is ignored, as is
/// a horizontal one (tabletop): it crosses lines, it does not split them.
EdgeInsets _avoidVerticalHinge(
  MediaQueryData mediaQuery,
  double width,
  EdgeInsets insets,
) {
  for (final feature in mediaQuery.displayFeatures) {
    final separating =
        feature.type == DisplayFeatureType.hinge ||
        (feature.type == DisplayFeatureType.fold &&
            feature.state == DisplayFeatureState.postureHalfOpened);
    final bounds = feature.bounds;
    final vertical =
        bounds.height >= mediaQuery.size.height - 1 &&
        bounds.left > 1 &&
        bounds.right < width - 1;
    if (!separating || !vertical) continue;
    return bounds.left >= width - bounds.right
        ? insets.copyWith(right: math.max(insets.right, width - bounds.left))
        : insets.copyWith(left: math.max(insets.left, bounds.right));
  }
  return insets;
}
