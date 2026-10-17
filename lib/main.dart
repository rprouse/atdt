import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'reader/about.dart';
import 'reader/reader_font.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts come from assets/fonts/manifest.json and are registered before
  // the first frame, so every screen can use them synchronously.
  final fonts = await FontRegistry.loadFromBundle(rootBundle);
  registerFontLicences(fonts, rootBundle);
  runApp(
    ProviderScope(
      overrides: [fontRegistryProvider.overrideWithValue(fonts)],
      child: const AtdtApp(),
    ),
  );
}
