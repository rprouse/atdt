import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../download/download_controller.dart';
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
    this.fontId,
    this.themeId = 'green_phosphor',
    this.orientation = OrientationMode.auto,
    this.showDebugOverlay = false,
  });

  /// Null means the manifest's default font.
  final String? fontId;
  final String themeId;
  final OrientationMode orientation;
  final bool showDebugOverlay;

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

/// Key of the persisted font choice in the database's settings table.
const fontSettingKey = 'reader.font';

class ReaderSettingsNotifier extends Notifier<ReaderSettings> {
  @override
  ReaderSettings build() {
    unawaited(_restoreFont());
    return const ReaderSettings();
  }

  /// The font choice persists across launches (Stage E); theme and
  /// orientation follow in Stages F and G.
  Future<void> _restoreFont() async {
    try {
      final id = await ref
          .read(archiveDatabaseProvider)
          .setting(fontSettingKey);
      // A choice made while restoring wins.
      if (id != null && state.fontId == null) {
        state = state.copyWith(fontId: id);
      }
    } on Object catch (e) {
      developer.log('could not restore font: $e', name: 'atdt.settings');
    }
  }

  void setFont(String id) {
    state = state.copyWith(fontId: id);
    unawaited(
      ref
          .read(archiveDatabaseProvider)
          .setSetting(fontSettingKey, id)
          .catchError((Object e) {
            developer.log('could not save font: $e', name: 'atdt.settings');
          }),
    );
  }

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

/// The font the reader uses: the chosen one, or the manifest default if
/// nothing is chosen or the choice is no longer bundled.
final currentFontProvider = Provider<ReaderFont>((ref) {
  final registry = ref.watch(fontRegistryProvider);
  final id = ref.watch(readerSettingsProvider.select((s) => s.fontId));
  return id == null ? registry.defaultFont : registry.byId(id);
});
