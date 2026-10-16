import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../download/download_screen.dart';
import 'about.dart';
import 'debug_overlay.dart';
import 'reader_font.dart';
import 'reader_settings.dart';
import 'reader_theme.dart';
import 'reader_view.dart';

/// The Stage A spike's only screen: the reader plus a debug chrome.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _diagnostics = ValueNotifier<ReaderDiagnostics?>(null);
  bool _chromeVisible = true;

  @override
  void dispose() {
    _diagnostics.dispose();
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
    final path = ref.watch(currentDocumentPathProvider).value;
    final document = path == null ? null : ref.watch(documentProvider(path));

    final Widget body = switch (document) {
      null => const SizedBox.expand(),
      AsyncData(:final value) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _setChromeVisible(!_chromeVisible),
        child: ReaderView(
          key: const ValueKey('reader'),
          text: value,
          font: settings.font,
          foreground: theme.foreground,
          onVerticalUserScroll: _onVerticalUserScroll,
          diagnostics: _diagnostics,
        ),
      ),
      AsyncError(:final error) => Center(
        child: Text('$error', style: TextStyle(color: theme.foreground)),
      ),
      _ => const SizedBox.expand(),
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
                child: _TopBar(path: path, theme: theme),
              ),
            ),
          ),
          if (settings.showDebugOverlay)
            Positioned(
              left: 8,
              bottom: 8,
              child: IgnorePointer(
                child: SafeArea(
                  child: DebugOverlay(diagnostics: _diagnostics, theme: theme),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.path, required this.theme});

  final String? path;
  final ReaderTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final docs = ref.watch(availableDocumentsProvider).value ?? const [];
    final name = path?.split('/').last ?? 'ATDT';

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
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.foreground, fontSize: 16),
                ),
              ),
              _Menu<String>(
                tooltip: 'File',
                icon: Icons.description_outlined,
                selected: path,
                items: {for (final d in docs) d: d.split('/').last},
                onSelected: notifier.setDocument,
              ),
              _Menu<String>(
                tooltip: 'Font',
                icon: Icons.text_fields,
                selected: settings.fontId,
                items: {for (final f in readerFonts) f.id: f.displayName},
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
              IconButton(
                tooltip: 'Archive',
                icon: const Icon(Icons.cloud_download_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DownloadScreen(),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'About',
                icon: const Icon(Icons.info_outline),
                onPressed: () => showAtdtAbout(context),
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
