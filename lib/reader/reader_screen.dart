import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../download/download_controller.dart';
import '../layout/reading_position.dart';
import '../layout/text_block.dart';
import '../library/library_providers.dart';
import '../search/search_query.dart';
import '../sections/section_parser.dart';
import '../storage/archive_database.dart';
import 'crt_effect.dart';
import 'debug_overlay.dart';
import 'reader_font.dart';
import 'reader_settings.dart';
import 'reader_theme.dart';
import 'reader_view.dart';
import 'volume_keys.dart';

/// Reads one stored phile, with chrome overlaid on the text.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    required this.phileId,
    this.title,
    this.revealLine,
    this.highlight,
    super.key,
  });

  final int phileId;

  /// Shown while the text loads; the stored title once it has.
  final String? title;

  /// From a search result: open at this line, with the query's matches
  /// highlighted, instead of at the saved position.
  final int? revealLine;
  final SearchQuery? highlight;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _diagnostics = ValueNotifier<ReaderDiagnostics?>(null);
  bool _chromeVisible = true;

  /// Fonts whose coverage notice was dismissed for this phile.
  final _dismissedNotices = <String>{};

  // Reading position: saved shortly after scrolling stops, when the reader
  // closes, and when the app goes to the background (it may be killed
  // there without warning).
  // Read eagerly: ref cannot be used in dispose, where the last save runs.
  late final ArchiveDatabase _db;
  late final AppLifecycleListener _lifecycle;
  Timer? _saveTimer;
  ReadingPosition? _unsaved;

  @override
  void initState() {
    super.initState();
    _db = ref.read(archiveDatabaseProvider);
    _lifecycle = AppLifecycleListener(onInactive: _savePosition);

    // Orientation and keep-awake apply while the reader is open, following
    // changes made from its chrome.
    final settings = ref.read(readerSettingsProvider);
    _applyOrientation(settings.orientation);
    _applyKeepAwake(settings.keepAwake);
    _applyVolumePaging(settings.volumePaging);
    VolumeKeys.listen(_page);
    ref
      ..listenManual(
        readerSettingsProvider.select((s) => s.orientation),
        (_, mode) => _applyOrientation(mode),
      )
      ..listenManual(
        readerSettingsProvider.select((s) => s.keepAwake),
        (_, on) => _applyKeepAwake(on),
      )
      ..listenManual(
        readerSettingsProvider.select((s) => s.volumePaging),
        (_, on) => _applyVolumePaging(on),
      );
  }

  void _applyVolumePaging(bool on) =>
      unawaited(VolumeKeys.setEnabled(on && isAndroid));

  void _page(int direction) =>
      unawaited(_readerKey.currentState?.page(direction));

  // Forcing landscape or portrait works with the system rotation lock on,
  // which is the point of the control.
  void _applyOrientation(OrientationMode mode) =>
      unawaited(SystemChrome.setPreferredOrientations(mode.orientations));

  void _applyKeepAwake(bool on) =>
      unawaited(WakelockPlus.toggle(enable: on).catchError((Object _) {}));

  final _readerKey = GlobalKey<ReaderViewState>();
  final _selection = ValueNotifier<LineBlock?>(null);

  Future<void> _copySelection(List<String> lines) async {
    final block = _selection.value;
    if (block == null) return;
    await Clipboard.setData(ClipboardData(text: block.textOf(lines)));
    _selection.value = null;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${block.length} ${block.length == 1 ? 'line' : 'lines'}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onPosition(ReadingPosition position) {
    _unsaved = position;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _savePosition);
  }

  void _savePosition() {
    _saveTimer?.cancel();
    final position = _unsaved;
    if (position == null) return;
    _unsaved = null;
    unawaited(
      _db
          .saveReadingPosition(widget.phileId, position, at: DateTime.now())
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _savePosition();
    _lifecycle.dispose();
    _diagnostics.dispose();
    _selection.dispose();
    // The library rotates freely, and only reading keeps the screen on.
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    VolumeKeys.stopListening();
    unawaited(VolumeKeys.setEnabled(false));
    // Leaving the reader with the chrome hidden must not strand the app in
    // immersive mode.
    if (!_chromeVisible) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  void _setChromeVisible(bool visible) {
    // With a screen reader the chrome stays: its buttons must be reachable,
    // and nobody taps the page to bring them back.
    if (!visible && MediaQuery.accessibleNavigationOf(context)) return;
    if (visible == _chromeVisible) return;
    setState(() => _chromeVisible = visible);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
      ),
    );
  }

  /// From the jump list: the heading goes to the top line, and the chrome
  /// hides so nothing covers it.
  void _jumpTo(int line) {
    _readerKey.currentState?.jumpToLine(line);
    _setChromeVisible(false);
  }

  /// Scrolling travel in the current direction: positive reads on.
  double _scrollTravel = 0;

  /// Reading on hides the chrome almost at once. Bringing it back takes a
  /// deliberate scroll up: a finger resting at the end of a drag drifts a
  /// few pixels back, and showing the chrome on any upward movement made it
  /// flicker back while reading.
  void _onVerticalUserScroll(double delta) {
    if (delta.sign != _scrollTravel.sign) _scrollTravel = 0;
    _scrollTravel += delta;
    if (_scrollTravel >= chromeHideScroll) {
      _setChromeVisible(false);
    } else if (_scrollTravel <= -chromeShowScroll) {
      _setChromeVisible(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final theme = ref.watch(currentThemeProvider);
    final font = ref.watch(currentFontProvider);
    final phile = ref.watch(storedPhileProvider(widget.phileId));
    final title = phile.value?.meta.title ?? widget.title ?? '';

    final Widget body = switch (phile) {
      AsyncData(:final value) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        // A visual convenience; to a screen reader it would be one unlabelled
        // button over every line.
        excludeFromSemantics: true,
        onTap: () {
          // A tap clears a selection before it toggles the chrome.
          if (_selection.value != null) {
            _selection.value = null;
          } else {
            _setChromeVisible(!_chromeVisible);
          }
        },
        // Keeps the first line off the screen's edge, which curves away on
        // edge-display phones held in landscape. The same with the chrome
        // shown or hidden, so no line moves when it toggles.
        child: Padding(
          padding: const EdgeInsets.only(top: readerTopInset),
          child: ReaderView(
            key: _readerKey,
            text: value.text,
            font: font,
            foreground: theme.foreground,
            onVerticalUserScroll: _onVerticalUserScroll,
            diagnostics: _diagnostics,
            onPositionChanged: _onPosition,
            initialPosition: value.position ?? const ReadingPosition.top(),
            selection: _selection,
            selectionColor: theme.selection,
            revealLine: widget.revealLine,
            highlight: widget.highlight,
          ),
        ),
      ),
      AsyncError(:final error) => Center(
        child: Text('$error', style: TextStyle(color: theme.foreground)),
      ),
      _ => Center(child: CircularProgressIndicator(color: theme.accent)),
    };

    return Scaffold(
      backgroundColor: theme.background,
      // The text never resizes for system UI; chrome floats on top.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // The CRT effect covers the text only; the chrome stays crisp.
          Positioned.fill(
            child: CrtEffect(tint: theme.foreground, child: body),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              key: const ValueKey('chrome-gate'),
              ignoring: !_chromeVisible,
              // Slid off screen, its buttons must not be found by touch
              // exploration either.
              child: ExcludeSemantics(
                excluding: !_chromeVisible,
                child: AnimatedSlide(
                  offset: _chromeVisible ? Offset.zero : const Offset(0, -1),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: _TopBar(
                    title: title,
                    theme: theme,
                    diagnostics: _diagnostics,
                    sections: phile.value?.sections ?? const [],
                    onJump: _jumpTo,
                  ),
                ),
              ),
            ),
          ),
          if (phile case AsyncData(:final value))
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: ValueListenableBuilder<LineBlock?>(
                  valueListenable: _selection,
                  builder: (context, block, _) => block == null
                      ? const SizedBox.shrink()
                      : _CopyBar(
                          block: block,
                          theme: theme,
                          onCopy: () => _copySelection(value.text.lines),
                          onCancel: () => _selection.value = null,
                        ),
                ),
              ),
            ),
          if (phile case AsyncData(:final value)
              when !_dismissedNotices.contains(font.id) &&
                  !font.coverage.coversAll(value.text.inventory))
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: _CoverageNotice(
                  font: font,
                  missing: font.coverage.missing(value.text.inventory).length,
                  alternative: ref
                      .read(fontRegistryProvider)
                      .firstCovering(value.text.inventory),
                  theme: theme,
                  onDismiss: () =>
                      setState(() => _dismissedNotices.add(font.id)),
                ),
              ),
            ),
          if (settings.showDebugOverlay)
            Positioned(
              left: 8,
              bottom: 8,
              child: IgnorePointer(
                child: SafeArea(
                  child: DebugOverlay(
                    diagnostics: _diagnostics,
                    theme: theme,
                    fontFamily: ref
                        .read(fontRegistryProvider)
                        .defaultFont
                        .family,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.title,
    required this.theme,
    required this.diagnostics,
    required this.sections,
    required this.onJump,
  });

  final String title;
  final ReaderTheme theme;
  final ValueNotifier<ReaderDiagnostics?> diagnostics;
  final List<Section> sections;
  final ValueChanged<int> onJump;

  Future<void> _showSections(BuildContext context) async {
    final top = diagnostics.value?.position.topLineIndex ?? 0;
    final line = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.background,
      builder: (context) => _SectionsSheet(
        sections: sections,
        current: currentSection(sections, top),
        theme: theme,
      ),
    );
    if (line != null) onJump(line);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final registry = ref.watch(fontRegistryProvider);
    final font = ref.watch(currentFontProvider);

    return Material(
      key: const ValueKey('chrome'),
      color: theme.background,
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: IconTheme(
          data: IconThemeData(color: theme.accent),
          child: Row(
            children: [
              const BackButton(),
              Expanded(
                child: Text(
                  title,
                  key: const ValueKey('reader-title'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.foreground, fontSize: 16),
                ),
              ),
              ValueListenableBuilder<ReaderDiagnostics?>(
                valueListenable: diagnostics,
                builder: (context, d, _) => Text(
                  d == null ? '' : '${(d.progress * 100).round()}%',
                  key: const ValueKey('reader-progress'),
                  style: TextStyle(color: theme.dim, fontSize: 14),
                ),
              ),
              if (sections.isNotEmpty)
                IconButton(
                  key: const ValueKey('sections'),
                  tooltip: 'Sections',
                  icon: const Icon(Icons.toc),
                  onPressed: () => _showSections(context),
                ),
              _Menu<String>(
                tooltip: 'Font',
                icon: Icons.text_fields,
                selected: font.id,
                items: {for (final f in registry.fonts) f.id: f.displayName},
                onSelected: notifier.setFont,
              ),
              _Menu<String>(
                tooltip: 'Theme',
                icon: Icons.palette_outlined,
                selected: theme.id,
                items: {
                  for (final t in ref.watch(allThemesProvider))
                    t.id: t.displayName,
                },
                onSelected: notifier.setTheme,
              ),
              _Menu<OrientationMode>(
                tooltip: 'Orientation',
                icon: Icons.screen_rotation,
                selected: settings.orientation,
                items: {for (final m in OrientationMode.values) m: m.label},
                onSelected: notifier.setOrientation,
              ),
              IconButton(
                tooltip: 'Debug overlay',
                icon: Icon(
                  settings.showDebugOverlay
                      ? Icons.bug_report
                      : Icons.bug_report_outlined,
                ),
                onPressed: notifier.toggleDebugOverlay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionsSheet extends StatefulWidget {
  const _SectionsSheet({
    required this.sections,
    required this.current,
    required this.theme,
  });

  final List<Section> sections;
  final int? current;
  final ReaderTheme theme;

  @override
  State<_SectionsSheet> createState() => _SectionsSheetState();
}

class _SectionsSheetState extends State<_SectionsSheet> {
  final _currentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Long outlines (70/4 has 44 headings) open at the current section.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = _currentKey.currentContext;
      if (current != null && current.mounted) {
        Scrollable.ensureVisible(current, alignment: 0.3);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => ListView.builder(
        key: const ValueKey('sections-list'),
        controller: controller,
        itemCount: widget.sections.length,
        itemBuilder: (context, i) {
          final s = widget.sections[i];
          final current = i == widget.current;
          final tile = ListTile(
            key: ValueKey('section-${s.line}'),
            dense: true,
            visualDensity: VisualDensity.compact,
            minTileHeight: 40,
            selected: current,
            selectedTileColor: theme.selection,
            contentPadding: EdgeInsets.only(
              left: 16 + 20.0 * s.level,
              right: 16,
            ),
            // One line per heading: outlines run to 40-odd entries.
            title: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${s.number}  ',
                    style: TextStyle(color: current ? theme.accent : theme.dim),
                  ),
                  TextSpan(text: s.title),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: current ? theme.accent : theme.foreground,
              ),
            ),
            onTap: () => Navigator.of(context).pop(s.line),
          );
          return current ? KeyedSubtree(key: _currentKey, child: tile) : tile;
        },
      ),
    );
  }
}

class _Menu<T> extends StatelessWidget {
  const _Menu({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.items,
    required this.onSelected,
  });

  final String tooltip;
  final IconData icon;
  final T? selected;
  final Map<T, String> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    tooltip: tooltip,
    icon: Icon(icon),
    initialValue: selected,
    onSelected: onSelected,
    itemBuilder: (context) => [
      for (final MapEntry(:key, :value) in items.entries)
        CheckedPopupMenuItem<T>(
          value: key,
          checked: key == selected,
          child: Text(value),
        ),
    ],
  );
}

/// Offered when the phile uses characters the current font cannot draw.
/// Floats over the text like the chrome, so it never moves a line.
class _CoverageNotice extends ConsumerWidget {
  const _CoverageNotice({
    required this.font,
    required this.missing,
    required this.alternative,
    required this.theme,
    required this.onDismiss,
  });

  final ReaderFont font;
  final int missing;
  final ReaderFont? alternative;
  final ReaderTheme theme;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = String.fromCharCode(font.coverage.placeholder);
    final what = missing == 1
        ? '1 character in this phile; it shows'
        : '$missing characters in this phile; they show';
    return Material(
      key: const ValueKey('coverage-notice'),
      color: theme.background,
      elevation: 4,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.dim),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${font.displayName} has no glyph for $what as $placeholder.',
              style: TextStyle(color: theme.foreground),
            ),
            // Wraps rather than overflowing with long font names or large
            // system text.
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  style: TextButton.styleFrom(foregroundColor: theme.dim),
                  child: const Text('Dismiss'),
                ),
                if (alternative != null)
                  TextButton(
                    onPressed: () => ref
                        .read(readerSettingsProvider.notifier)
                        .setFont(alternative!.id),
                    style: TextButton.styleFrom(foregroundColor: theme.accent),
                    child: Text('Use ${alternative!.displayName}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Offered after a long press selects a block of lines.
class _CopyBar extends StatelessWidget {
  const _CopyBar({
    required this.block,
    required this.theme,
    required this.onCopy,
    required this.onCancel,
  });

  final LineBlock block;
  final ReaderTheme theme;
  final VoidCallback onCopy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('copy-bar'),
    color: theme.background,
    elevation: 4,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: theme.accent),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${block.length} ${block.length == 1 ? 'line' : 'lines'} '
              'selected',
              style: TextStyle(color: theme.foreground),
            ),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(foregroundColor: theme.dim),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: onCopy,
            style: TextButton.styleFrom(foregroundColor: theme.accent),
            child: const Text('Copy'),
          ),
        ],
      ),
    ),
  );
}

/// Scrolling down this far hides the chrome; scrolling up [chromeShowScroll]
/// brings it back (logical pixels, in one direction without reversing).
const double chromeHideScroll = 8;
const double chromeShowScroll = 64;

/// Space above the first line of text, in logical pixels.
const double readerTopInset = 12;

/// Volume-button paging is Android-only (spec): iOS gives apps no such hook.
bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
