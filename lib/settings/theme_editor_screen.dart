import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reader/reader_font.dart';
import '../reader/reader_settings.dart';
import '../reader/reader_theme.dart';
import 'colour_picker.dart';

enum ThemeRole {
  background('Background'),
  foreground('Text'),
  selection('Selection'),
  accent('Accent'),
  dim('Dim');

  const ThemeRole(this.label);

  final String label;

  Color of(ReaderTheme t) => switch (this) {
    background => t.background,
    foreground => t.foreground,
    selection => t.selection,
    accent => t.accent,
    dim => t.dim,
  };

  ReaderTheme apply(ReaderTheme t, Color c) => switch (this) {
    background => t.copyWith(background: c),
    foreground => t.copyWith(foreground: c),
    selection => t.copyWith(selection: c),
    accent => t.copyWith(accent: c),
    dim => t.copyWith(dim: c),
  };
}

/// Creates or edits a custom theme, with a live preview. Custom themes are
/// personal, so there is no contrast check: the colours are the reader's
/// call.
class ThemeEditorScreen extends ConsumerStatefulWidget {
  const ThemeEditorScreen({
    required this.base,
    this.editing = false,
    super.key,
  });

  /// The theme being edited, or the starting point for a new one.
  final ReaderTheme base;

  /// True to edit [base] in place; false to create a new theme from it.
  final bool editing;

  @override
  ConsumerState<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends ConsumerState<ThemeEditorScreen> {
  late ReaderTheme _draft = widget.editing
      ? widget.base
      : widget.base.copyWith(
          id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
          displayName: 'My ${widget.base.displayName}',
        );
  late final _name = TextEditingController(text: _draft.displayName);
  ThemeRole _role = ThemeRole.background;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final theme = _draft.copyWith(
      displayName: name.isEmpty ? 'Untitled theme' : name,
    );
    ref.read(customThemesProvider.notifier).save(theme);
    ref.read(readerSettingsProvider.notifier).setTheme(theme.id);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_draft.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(customThemesProvider.notifier).delete(_draft.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final font = ref.watch(currentFontProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Edit theme' : 'New theme'),
        actions: [
          if (widget.editing)
            IconButton(
              tooltip: 'Delete theme',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ThemePreview(theme: _draft, font: font),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('theme-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in ThemeRole.values)
                ChoiceChip(
                  key: ValueKey('role-${role.name}'),
                  avatar: CircleAvatar(backgroundColor: role.of(_draft)),
                  label: Text(role.label),
                  selected: role == _role,
                  onSelected: (_) => setState(() => _role = role),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ColourPicker(
            colour: _role.of(_draft),
            onChanged: (c) => setState(() => _draft = _role.apply(_draft, c)),
          ),
        ],
      ),
    );
  }
}

/// A sample of every colour in a theme, as the app would use it.
class ThemePreview extends StatelessWidget {
  const ThemePreview({required this.theme, required this.font, super.key});

  final ReaderTheme theme;

  /// The reader font; samples use its placeholder for glyphs it lacks, as
  /// the reader does, rather than a system fallback.
  final ReaderFont font;

  @override
  Widget build(BuildContext context) {
    String sample(String s) => font.coverage.substitute(s);
    final text = TextStyle(
      fontFamily: font.family,
      fontFeatures: readerFontFeatures,
      color: theme.foreground,
      fontSize: 13,
      height: 1.4,
    );
    return Container(
      key: const ValueKey('theme-preview'),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border.all(color: theme.dim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dim)),
            ),
            child: Text(
              "Hacker's Manifesto",
              style: TextStyle(color: theme.accent, fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sample('              ==Phrack Inc.=='), style: text),
                Text.rich(
                  TextSpan(
                    style: text,
                    children: [
                      TextSpan(text: sample('This is our world now... ')),
                      TextSpan(
                        text: sample('the world'),
                        style: TextStyle(backgroundColor: theme.selection),
                      ),
                    ],
                  ),
                ),
                Text(sample('╔══════════════╗  ->  !=  =='), style: text),
                const SizedBox(height: 4),
                Text(
                  'The Mentor · 8 Jan 1986',
                  style: TextStyle(color: theme.dim, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
