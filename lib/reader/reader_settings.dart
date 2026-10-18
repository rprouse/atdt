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
    this.themeId,
    this.orientation = OrientationMode.auto,
    this.showDebugOverlay = false,
    this.keepAwake = true,
    this.volumePaging = false,
  });

  /// Null means the manifest's default font.
  final String? fontId;

  /// Null means the first built-in theme.
  final String? themeId;
  final OrientationMode orientation;
  final bool showDebugOverlay;

  /// Keep the screen on while the reader is open.
  final bool keepAwake;

  /// Page with the volume buttons (Android only).
  final bool volumePaging;

  ReaderSettings copyWith({
    String? fontId,
    String? themeId,
    OrientationMode? orientation,
    bool? showDebugOverlay,
    bool? keepAwake,
    bool? volumePaging,
  }) => ReaderSettings(
    fontId: fontId ?? this.fontId,
    themeId: themeId ?? this.themeId,
    orientation: orientation ?? this.orientation,
    showDebugOverlay: showDebugOverlay ?? this.showDebugOverlay,
    keepAwake: keepAwake ?? this.keepAwake,
    volumePaging: volumePaging ?? this.volumePaging,
  );
}

/// Keys of persisted choices in the database's settings table.
const fontSettingKey = 'reader.font';
const themeSettingKey = 'reader.theme';
const orientationSettingKey = 'reader.orientation';
const keepAwakeSettingKey = 'reader.keepAwake';
const volumePagingSettingKey = 'reader.volumePaging';
const customThemesSettingKey = 'themes.custom';

Future<void> _save(Ref ref, String key, String value) => ref
    .read(archiveDatabaseProvider)
    .setSetting(key, value)
    .catchError((Object e) {
      developer.log('could not save $key: $e', name: 'atdt.settings');
    });

class ReaderSettingsNotifier extends Notifier<ReaderSettings> {
  /// Completes once saved choices are loaded. `main` waits for it so the
  /// first frame already has the right theme.
  late Future<void> restored;

  @override
  ReaderSettings build() {
    restored = _restore();
    return const ReaderSettings();
  }

  /// Every reader preference persists across launches.
  Future<void> _restore() async {
    try {
      final db = ref.read(archiveDatabaseProvider);
      final font = await db.setting(fontSettingKey);
      final theme = await db.setting(themeSettingKey);
      final orientation = await db.setting(orientationSettingKey);
      final keepAwake = await db.setting(keepAwakeSettingKey);
      final volumePaging = await db.setting(volumePagingSettingKey);
      // A choice made while restoring wins (null leaves a field alone).
      state = state.copyWith(
        fontId: state.fontId == null ? font : null,
        themeId: state.themeId == null ? theme : null,
        orientation: OrientationMode.values
            .where((m) => m.name == orientation)
            .firstOrNull,
        keepAwake: keepAwake == null ? null : keepAwake == 'true',
        volumePaging: volumePaging == null ? null : volumePaging == 'true',
      );
    } on Object catch (e) {
      developer.log('could not restore settings: $e', name: 'atdt.settings');
    }
  }

  void setFont(String id) {
    state = state.copyWith(fontId: id);
    unawaited(_save(ref, fontSettingKey, id));
  }

  void setTheme(String id) {
    state = state.copyWith(themeId: id);
    unawaited(_save(ref, themeSettingKey, id));
  }

  void toggleDebugOverlay() =>
      state = state.copyWith(showDebugOverlay: !state.showDebugOverlay);

  /// Applied by the reader while it is open (see ReaderScreen); the
  /// library always rotates freely.
  void setOrientation(OrientationMode mode) {
    state = state.copyWith(orientation: mode);
    unawaited(_save(ref, orientationSettingKey, mode.name));
  }

  void setKeepAwake(bool on) {
    state = state.copyWith(keepAwake: on);
    unawaited(_save(ref, keepAwakeSettingKey, '$on'));
  }

  void setVolumePaging(bool on) {
    state = state.copyWith(volumePaging: on);
    unawaited(_save(ref, volumePagingSettingKey, '$on'));
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

/// The reader's own themes, saved in the settings table.
class CustomThemesNotifier extends Notifier<List<ReaderTheme>> {
  /// Completes once saved themes are loaded.
  late Future<void> loaded;

  @override
  List<ReaderTheme> build() {
    loaded = _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final json = await ref
          .read(archiveDatabaseProvider)
          .setting(customThemesSettingKey);
      if (json != null) state = decodeThemes(json);
    } on Object catch (e) {
      developer.log('could not load themes: $e', name: 'atdt.settings');
    }
  }

  /// Adds [theme], or replaces the custom theme with the same id.
  void save(ReaderTheme theme) {
    final index = state.indexWhere((t) => t.id == theme.id);
    state = index < 0
        ? [...state, theme]
        : [...state.take(index), theme, ...state.skip(index + 1)];
    unawaited(_save(ref, customThemesSettingKey, encodeThemes(state)));
  }

  void delete(String id) {
    state = [
      for (final t in state)
        if (t.id != id) t,
    ];
    unawaited(_save(ref, customThemesSettingKey, encodeThemes(state)));
  }
}

final customThemesProvider =
    NotifierProvider<CustomThemesNotifier, List<ReaderTheme>>(
      CustomThemesNotifier.new,
    );

/// Built-in themes first, then the reader's own.
final allThemesProvider = Provider<List<ReaderTheme>>(
  (ref) => [...builtInThemes, ...ref.watch(customThemesProvider)],
);

/// The theme in use: the chosen one, or the first built-in if nothing is
/// chosen or the chosen custom theme was deleted.
final currentThemeProvider = Provider<ReaderTheme>((ref) {
  final id = ref.watch(readerSettingsProvider.select((s) => s.themeId));
  final themes = ref.watch(allThemesProvider);
  return themes.firstWhere(
    (t) => t.id == id,
    orElse: () => builtInThemes.first,
  );
});

/// Waits (briefly) for saved settings and themes, so the first frame is
/// already in the reader's theme. Never blocks startup on storage errors.
Future<void> restoreSavedSettings(ProviderContainer container) async {
  try {
    await Future.wait([
      container.read(readerSettingsProvider.notifier).restored,
      container.read(customThemesProvider.notifier).loaded,
    ]).timeout(const Duration(seconds: 2));
  } on Object catch (e) {
    developer.log(
      'settings not restored before launch: $e',
      name: 'atdt.settings',
    );
  }
}
