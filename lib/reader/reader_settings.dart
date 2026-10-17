import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reader_font.dart';
import 'reader_theme.dart';

enum OrientationMode {
  auto('Auto', DeviceOrientation.values),
  portrait('Portrait', [DeviceOrientation.portraitUp]),
  landscape('Landscape', [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  const OrientationMode(this.label, this.orientations);

  final String label;
  final List<DeviceOrientation> orientations;
}

class ReaderSettings {
  const ReaderSettings({
    this.fontId = 'jetbrains_mono',
    this.themeId = 'green_phosphor',
    this.orientation = OrientationMode.auto,
    this.showDebugOverlay = false,
  });

  final String fontId;
  final String themeId;
  final OrientationMode orientation;
  final bool showDebugOverlay;

  ReaderFont get font => readerFontById(fontId);
  ReaderTheme get theme => readerThemeById(themeId);

  ReaderSettings copyWith({
    String? fontId,
    String? themeId,
    OrientationMode? orientation,
    bool? showDebugOverlay,
  }) => ReaderSettings(
    fontId: fontId ?? this.fontId,
    themeId: themeId ?? this.themeId,
    orientation: orientation ?? this.orientation,
    showDebugOverlay: showDebugOverlay ?? this.showDebugOverlay,
  );
}

class ReaderSettingsNotifier extends Notifier<ReaderSettings> {
  @override
  ReaderSettings build() => const ReaderSettings();

  void setFont(String id) => state = state.copyWith(fontId: id);

  void setTheme(String id) => state = state.copyWith(themeId: id);

  void toggleDebugOverlay() =>
      state = state.copyWith(showDebugOverlay: !state.showDebugOverlay);

  void setOrientation(OrientationMode mode) {
    state = state.copyWith(orientation: mode);
    // Works with the system rotation lock on, which is the point of it.
    unawaited(SystemChrome.setPreferredOrientations(mode.orientations));
  }
}

final readerSettingsProvider =
    NotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
      ReaderSettingsNotifier.new,
    );
