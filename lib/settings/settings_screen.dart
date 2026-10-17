import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reader/about.dart';
import '../reader/reader_font.dart';
import '../reader/reader_settings.dart';
import '../reader/reader_theme.dart';
import 'credits_screen.dart';
import 'theme_editor_screen.dart';

/// Reader preferences. Stage E/F/G grow this; for now it carries over the
/// spike's font, theme and orientation menus. Not yet persisted (Stage G).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final registry = ref.watch(fontRegistryProvider);
    final currentFont = ref.watch(currentFontProvider);
    final currentTheme = ref.watch(currentThemeProvider);
    final heading = Theme.of(context).textTheme.titleSmall
        ?.copyWith(color: Theme.of(context).colorScheme.primary);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(title, style: heading),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          section('Font'),
          RadioGroup<String>(
            groupValue: currentFont.id,
            onChanged: (id) => id == null ? null : notifier.setFont(id),
            child: Column(
              children: [
                for (final font in registry.fonts)
                  RadioListTile<String>(
                    key: ValueKey('font-${font.id}'),
                    value: font.id,
                    title: Text(font.displayName),
                    subtitle: Text(
                      '+---[ Phrack Inc. ]---+ -> != ==',
                      style: TextStyle(
                        fontFamily: font.family,
                        fontFeatures: readerFontFeatures,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          section('Theme'),
          RadioGroup<String>(
            groupValue: currentTheme.id,
            onChanged: (id) => id == null ? null : notifier.setTheme(id),
            child: Column(
              children: [
                for (final theme in ref.watch(allThemesProvider))
                  RadioListTile<String>(
                    key: ValueKey('theme-${theme.id}'),
                    value: theme.id,
                    title: Text(theme.displayName),
                    subtitle: theme.builtIn ? null : const Text('Custom'),
                    secondary: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Swatch(
                          theme: theme,
                          family: registry.defaultFont.family,
                        ),
                        if (!theme.builtIn)
                          IconButton(
                            key: ValueKey('edit-${theme.id}'),
                            tooltip: 'Edit ${theme.displayName}',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                _openEditor(context, theme, editing: true),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            key: const ValueKey('new-theme'),
            leading: const Icon(Icons.add),
            title: const Text('New theme'),
            subtitle: Text('Starts from ${currentTheme.displayName}'),
            onTap: () => _openEditor(context, currentTheme, editing: false),
          ),
          section('Orientation'),
          RadioGroup<OrientationMode>(
            groupValue: settings.orientation,
            onChanged: (m) => m == null ? null : notifier.setOrientation(m),
            child: Column(
              children: [
                for (final mode in OrientationMode.values)
                  RadioListTile<OrientationMode>(
                    key: ValueKey('orientation-${mode.name}'),
                    value: mode,
                    title: Text(mode.label),
                  ),
              ],
            ),
          ),
          section('Developer'),
          SwitchListTile(
            title: const Text('Layout debug overlay'),
            subtitle: const Text('Font size, scale, line height, position'),
            value: settings.showDebugOverlay,
            onChanged: (_) => notifier.toggleDebugOverlay(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Credits'),
            subtitle: const Text('Phrack, and every font with its licence'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CreditsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About ATDT'),
            subtitle: const Text('Version and licences'),
            onTap: () => showAtdtAbout(context, registry),
          ),
        ],
      ),
    );
  }
}

void _openEditor(
  BuildContext context,
  ReaderTheme theme, {
  required bool editing,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => ThemeEditorScreen(base: theme, editing: editing),
  ),
);

class _Swatch extends StatelessWidget {
  const _Swatch({required this.theme, required this.family});

  final ReaderTheme theme;
  final String family;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: theme.background,
      border: Border.all(color: theme.dim),
    ),
    child: Text(
      'ATDT',
      style: TextStyle(
        color: theme.foreground,
        fontFamily: family,
        fontSize: 12,
      ),
    ),
  );
}
