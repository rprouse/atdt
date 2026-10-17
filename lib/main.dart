import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'reader/about.dart';
import 'reader/reader_font.dart';
import 'reader/reader_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts come from assets/fonts/manifest.json and are registered before
  // the first frame, so every screen can use them synchronously.
  final fonts = await FontRegistry.loadFromBundle(rootBundle);
  registerFontLicences(fonts, rootBundle);

  final container = ProviderContainer(
    overrides: [fontRegistryProvider.overrideWithValue(fonts)],
  );
  // The theme colours the whole app, so load the saved one before the
  // first frame rather than flashing the default.
  await restoreSavedSettings(container);
  runApp(
    UncontrolledProviderScope(container: container, child: const AtdtApp()),
  );
}
