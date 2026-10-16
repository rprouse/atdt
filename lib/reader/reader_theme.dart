import 'package:flutter/material.dart';

/// Reader colours. Stage F grows this into the full theme system.
class ReaderTheme {
  const ReaderTheme({
    required this.id,
    required this.displayName,
    required this.background,
    required this.foreground,
    required this.accent,
    required this.dim,
    required this.brightness,
  });

  final String id;
  final String displayName;
  final Color background;
  final Color foreground;
  final Color accent;
  final Color dim;
  final Brightness brightness;

  ThemeData toThemeData() => ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: background,
      onSurface: foreground,
    ),
  );
}

const readerThemes = [
  ReaderTheme(
    id: 'green_phosphor',
    displayName: 'Green phosphor',
    background: Color(0xFF0A120A),
    foreground: Color(0xFF41FF63),
    accent: Color(0xFF2BD94C),
    dim: Color(0xFF1F7A30),
    brightness: Brightness.dark,
  ),
  ReaderTheme(
    id: 'paper',
    displayName: 'Paper',
    background: Color(0xFFF4EFE1),
    foreground: Color(0xFF26231E),
    accent: Color(0xFF8A5A2B),
    dim: Color(0xFF8C8577),
    brightness: Brightness.light,
  ),
];

ReaderTheme readerThemeById(String id) => readerThemes.firstWhere(
  (t) => t.id == id,
  orElse: () => readerThemes.first,
);
