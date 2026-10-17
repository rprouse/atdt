import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/library_providers.dart';
import 'debug_overlay.dart';
import 'reader_font.dart';
import 'reader_settings.dart';
import 'reader_theme.dart';
import 'reader_view.dart';

/// Reads one stored phile, with chrome overlaid on the text.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.phileId, this.title, super.key});

  final int phileId;

  /// Shown while the text loads; the stored title once it has.
  final String? title;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _diagnostics = ValueNotifier<ReaderDiagnostics?>(null);
  bool _chromeVisible = true;

  /// Fonts whose coverage notice was dismissed for this phile.
  final _dismissedNotices = <String>{};

  @override
  void dispose() {
    _diagnostics.dispose();
    // Leaving the reader with the chrome hidden must not strand the app in
    // immersive mode.
    if (!_chromeVisible) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  void _setChromeVisible(bool visible) {
    if (visible == _chromeVisible) return;
    setState(() => _chromeVisible = visible);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
      ),
    );
  }

  void _onVerticalUserScroll(ScrollDirection direction) {
    // reverse: content moving up, i.e. reading further down.
    _setChromeVisible(direction == ScrollDirection.forward);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final theme = settings.theme;
    final font = ref.watch(currentFontProvider);
    final phile = ref.watch(storedPhileProvider(widget.phileId));
    final title = phile.value?.meta.title ?? widget.title ?? '';

    final Widget body = switch (phile) {
      AsyncData(:final value) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _setChromeVisible(!_chromeVisible),
        child: ReaderView(
          key: const ValueKey('reader'),
          text: value.text,
          font: font,
          foreground: theme.foreground,
          onVerticalUserScroll: _onVerticalUserScroll,
          diagnostics: _diagnostics,
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
          Positioned.fill(child: body),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              key: const ValueKey('chrome-gate'),
              ignoring: !_chromeVisible,
              child: AnimatedSlide(
                offset: _chromeVisible ? Offset.zero : const Offset(0, -1),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: _TopBar(title: title, theme: theme),
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
  const _TopBar({required this.title, required this.theme});

  final String title;
  final ReaderTheme theme;

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
                selected: settings.themeId,
                items: {for (final t in readerThemes) t.id: t.displayName},
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
