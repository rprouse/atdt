import 'dart:convert';

import 'package:flutter/material.dart';

import '../themes/contrast.dart';

/// A colour theme for the reader and the whole app.
class ReaderTheme {
  const ReaderTheme({
    required this.id,
    required this.displayName,
    required this.background,
    required this.foreground,
    required this.selection,
    required this.accent,
    required this.dim,
    this.builtIn = false,
  });

  /// Reads a custom theme saved by [toJson]. Returns null for anything
  /// malformed, so one bad entry cannot break the theme list.
  static ReaderTheme? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final name = json['name'];
    final colours = [for (final key in _colourKeys) _parseHex(json[key])];
    if (id is! String || name is! String || colours.contains(null)) {
      return null;
    }
    return ReaderTheme(
      id: id,
      displayName: name,
      background: colours[0]!,
      foreground: colours[1]!,
      selection: colours[2]!,
      accent: colours[3]!,
      dim: colours[4]!,
    );
  }

  final String id;
  final String displayName;

  /// The page behind the text.
  final Color background;

  /// The text itself.
  final Color foreground;

  /// Behind selected text (copy, Stage G).
  final Color selection;

  /// Chrome, titles, buttons and highlights.
  final Color accent;

  /// Secondary text, such as authors and dates in lists.
  final Color dim;

  /// Shipped with the app (and contrast-checked); custom themes are not.
  final bool builtIn;

  Brightness get brightness => relativeLuminance(background.toARGB32()) < 0.5
      ? Brightness.dark
      : Brightness.light;

  ReaderTheme copyWith({
    String? id,
    String? displayName,
    Color? background,
    Color? foreground,
    Color? selection,
    Color? accent,
    Color? dim,
  }) => ReaderTheme(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    background: background ?? this.background,
    foreground: foreground ?? this.foreground,
    selection: selection ?? this.selection,
    accent: accent ?? this.accent,
    dim: dim ?? this.dim,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': displayName,
    for (final (i, key) in _colourKeys.indexed)
      key: colourToHex([background, foreground, selection, accent, dim][i]),
  };

  /// The theme for the whole app, so lists and chrome match the reader.
  ThemeData toThemeData() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          onPrimary: background,
          secondary: accent,
          onSecondary: background,
          surface: background,
          onSurface: foreground,
          onSurfaceVariant: dim,
          outline: dim,
          outlineVariant: dim.withValues(alpha: 0.4),
          surfaceContainerHighest: Color.lerp(background, foreground, 0.12),
        );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: accent,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        textColor: foreground,
        iconColor: accent,
        subtitleTextStyle: TextStyle(color: dim),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: selection,
        cursorColor: accent,
        selectionHandleColor: accent,
      ),
      dividerTheme: DividerThemeData(color: dim.withValues(alpha: 0.4)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderTheme &&
      other.id == id &&
      other.displayName == displayName &&
      other.background == background &&
      other.foreground == foreground &&
      other.selection == selection &&
      other.accent == accent &&
      other.dim == dim &&
      other.builtIn == builtIn;

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    background,
    foreground,
    selection,
    accent,
    dim,
    builtIn,
  );
}

const _colourKeys = ['background', 'foreground', 'selection', 'accent', 'dim'];

/// `#RRGGBB`; themes are opaque.
String colourToHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Color? _parseHex(Object? value) {
  if (value is! String) return null;
  return parseHexColour(value);
}

/// Parses `#RRGGBB` or `RRGGBB` (case-insensitive); null otherwise.
Color? parseHexColour(String text) {
  final hex = text.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex, radix: 16));
}

/// Built-in themes. Each pair that carries text meets WCAG AA (4.5:1);
/// test/themes/built_in_themes_test.dart checks it.
const builtInThemes = [
  ReaderTheme(
    id: 'green_phosphor',
    displayName: 'Green phosphor',
    background: Color(0xFF0A120A),
    foreground: Color(0xFF41FF63),
    selection: Color(0xFF1E4D28),
    accent: Color(0xFF2BD94C),
    dim: Color(0xFF2E9E45),
    builtIn: true,
  ),
  ReaderTheme(
    id: 'amber_phosphor',
    displayName: 'Amber phosphor',
    background: Color(0xFF130D02),
    foreground: Color(0xFFFFB000),
    selection: Color(0xFF553700),
    accent: Color(0xFFFF9E1A),
    dim: Color(0xFFB37A12),
    builtIn: true,
  ),
  ReaderTheme(
    id: 'paper',
    displayName: 'Paper',
    background: Color(0xFFF4EFE1),
    foreground: Color(0xFF26231E),
    selection: Color(0xFFD9CBA8),
    accent: Color(0xFF7A4A1C),
    dim: Color(0xFF645C4E),
    builtIn: true,
  ),
  ReaderTheme(
    id: 'high_contrast',
    displayName: 'High contrast',
    background: Color(0xFF000000),
    foreground: Color(0xFFFFFFFF),
    selection: Color(0xFF1F4FA8),
    accent: Color(0xFFFFFF00),
    dim: Color(0xFFC8C8C8),
    builtIn: true,
  ),
  ReaderTheme(
    id: 'vga_blue',
    displayName: 'VGA blue',
    background: Color(0xFF0000AA),
    foreground: Color(0xFFFFFFFF),
    selection: Color(0xFF008080),
    accent: Color(0xFFFFFF55),
    dim: Color(0xFFAAAAAA),
    builtIn: true,
  ),
];

/// Encodes custom themes for the settings table.
String encodeThemes(List<ReaderTheme> themes) =>
    jsonEncode([for (final t in themes) t.toJson()]);

/// Decodes [encodeThemes] output, skipping anything malformed.
List<ReaderTheme> decodeThemes(String json) {
  try {
    final list = jsonDecode(json);
    if (list is! List<Object?>) return const [];
    return [for (final entry in list) ?ReaderTheme.fromJson(entry)];
  } on FormatException {
    return const [];
  }
}
