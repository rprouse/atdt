import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ingest/phile_text.dart';
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
    this.documentPath,
  });

  final String fontId;
  final String themeId;
  final OrientationMode orientation;
  final bool showDebugOverlay;

  /// Asset path of the open file; null means the first available one.
  final String? documentPath;

  ReaderFont get font => readerFontById(fontId);
  ReaderTheme get theme => readerThemeById(themeId);

  ReaderSettings copyWith({
    String? fontId,
    String? themeId,
    OrientationMode? orientation,
    bool? showDebugOverlay,
    String? documentPath,
  }) => ReaderSettings(
    fontId: fontId ?? this.fontId,
    themeId: themeId ?? this.themeId,
    orientation: orientation ?? this.orientation,
    showDebugOverlay: showDebugOverlay ?? this.showDebugOverlay,
    documentPath: documentPath ?? this.documentPath,
  );
}

class ReaderSettingsNotifier extends Notifier<ReaderSettings> {
  @override
  ReaderSettings build() => const ReaderSettings();

  void setFont(String id) => state = state.copyWith(fontId: id);

  void setTheme(String id) => state = state.copyWith(themeId: id);

  void setDocument(String path) => state = state.copyWith(documentPath: path);

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

const _devPrefix = 'assets/dev/';
const _fixturePrefix = 'test/fixtures/';

/// Openable text files: real philes from assets/dev/ first, then fixtures.
final availableDocumentsProvider = FutureProvider<List<String>>((ref) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final txt = manifest.listAssets().where((p) => p.endsWith('.txt'));
  return [
    ...txt.where((p) => p.startsWith(_devPrefix)).toList()..sort(),
    ...txt.where((p) => p.startsWith(_fixturePrefix)).toList()..sort(),
  ];
});

final documentProvider = FutureProvider.family<PhileText, String>((
  ref,
  path,
) async {
  final data = await rootBundle.load(path);
  return PhileText.fromBytes(data.buffer.asUint8List());
});

const _defaultFixture = '${_fixturePrefix}ten_thousand_lines.txt';

/// The document to show: the chosen one, else the first real phile, else
/// the 10,000-line fixture used for rotation and scrolling checks.
final currentDocumentPathProvider = FutureProvider<String?>((ref) async {
  final chosen = ref.watch(readerSettingsProvider).documentPath;
  if (chosen != null) return chosen;
  final docs = await ref.watch(availableDocumentsProvider.future);
  if (docs.isEmpty) return null;
  if (docs.first.startsWith(_devPrefix)) return docs.first;
  return docs.contains(_defaultFixture) ? _defaultFixture : docs.first;
});
