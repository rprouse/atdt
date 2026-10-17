/// `assets/fonts/manifest.json`: every reader font, its files, metrics,
/// licence and attribution. Adding a font is a file plus an entry here.
/// Pure Dart; no Flutter imports.
library;

import 'dart:convert';

class FontSpec {
  const FontSpec({
    required this.id,
    required this.displayName,
    required this.family,
    required this.files,
    required this.lineHeightRatio,
    required this.licenceName,
    required this.licenceUrl,
    required this.licenceFile,
    required this.attribution,
    this.integerScale = false,
    this.cellWidthPx,
    this.nativeSizePx,
  });

  final String id;
  final String displayName;

  /// The family name the font is registered under at runtime.
  final String family;

  /// Font files, relative to `assets/fonts/`.
  final List<String> files;
  final double lineHeightRatio;
  final bool integerScale;
  final int? cellWidthPx;
  final int? nativeSizePx;
  final String licenceName;
  final String licenceUrl;

  /// The licence text shipped with the font, relative to `assets/fonts/`.
  final String licenceFile;
  final String attribution;
}

class FontManifest {
  const FontManifest(this.fonts);

  /// Parses and validates the manifest, reporting every problem at once.
  factory FontManifest.parse(String json) {
    final Object? root;
    try {
      root = jsonDecode(json);
    } on FormatException catch (e) {
      throw FormatException('Font manifest is not valid JSON: ${e.message}');
    }
    final entries = root is Map<String, Object?> ? root['fonts'] : null;
    if (entries is! List<Object?> || entries.isEmpty) {
      throw const FormatException('Font manifest needs a non-empty "fonts"');
    }

    final problems = <String>[];
    final fonts = <FontSpec>[];
    for (final (index, entry) in entries.indexed) {
      final where = 'fonts[$index]';
      if (entry is! Map<String, Object?>) {
        problems.add('$where is not an object');
        continue;
      }
      T? field<T>(
        String name, {
        Map<String, Object?>? from,
        bool optional = false,
      }) {
        final value = (from ?? entry)[name];
        if (value is T) return value;
        if (!(optional && value == null)) {
          problems.add('$where.$name must be a ${T.toString().toLowerCase()}');
        }
        return null;
      }

      final licence = field<Map<String, Object?>>('licence');
      final files = field<List<Object?>>('files');
      final spec = (
        id: field<String>('id'),
        name: field<String>('displayName'),
        family: field<String>('family'),
        lineHeight: field<num>('lineHeightRatio'),
        integerScale: field<bool>('integerScale', optional: true) ?? false,
        cellWidth: field<int>('cellWidthPx', optional: true),
        nativeSize: field<int>('nativeSizePx', optional: true),
        attribution: field<String>('attribution'),
        licenceName: licence == null
            ? null
            : field<String>('name', from: licence),
        licenceUrl: licence == null
            ? null
            : field<String>('url', from: licence),
        licenceFile: licence == null
            ? null
            : field<String>('file', from: licence),
      );
      if (files != null && (files.isEmpty || files.any((f) => f is! String))) {
        problems.add('$where.files must be a non-empty list of paths');
      }
      if (spec.integerScale &&
          ((spec.cellWidth ?? 0) <= 0 || (spec.nativeSize ?? 0) <= 0)) {
        problems.add(
          '$where: integerScale fonts need cellWidthPx and nativeSizePx',
        );
      }
      if (spec.lineHeight != null && spec.lineHeight! <= 0) {
        problems.add('$where.lineHeightRatio must be positive');
      }
      if ([
        spec.id,
        spec.name,
        spec.family,
        spec.lineHeight,
        spec.attribution,
        spec.licenceName,
        spec.licenceUrl,
        spec.licenceFile,
        files,
      ].contains(null)) {
        continue;
      }
      fonts.add(
        FontSpec(
          id: spec.id!,
          displayName: spec.name!,
          family: spec.family!,
          files: List.unmodifiable(files!.cast<String>()),
          lineHeightRatio: spec.lineHeight!.toDouble(),
          integerScale: spec.integerScale,
          cellWidthPx: spec.cellWidth,
          nativeSizePx: spec.nativeSize,
          licenceName: spec.licenceName!,
          licenceUrl: spec.licenceUrl!,
          licenceFile: spec.licenceFile!,
          attribution: spec.attribution!,
        ),
      );
    }

    for (final key in ['id', 'family']) {
      final seen = <String>{};
      for (final f in fonts) {
        final value = key == 'id' ? f.id : f.family;
        if (!seen.add(value)) problems.add('duplicate $key "$value"');
      }
    }
    if (problems.isNotEmpty) {
      throw FormatException('Font manifest: ${problems.join('; ')}');
    }
    return FontManifest(List.unmodifiable(fonts));
  }

  /// In display order; the first is the default.
  final List<FontSpec> fonts;
}
