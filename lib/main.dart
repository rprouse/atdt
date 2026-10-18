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
  // the first frame, so every screen can use them synchronously. The theme
  // colours the whole app, so the saved one is loaded first too rather
  // than flashing the default. Neither needs the other, so they load
  // together: restoring settings reads only the database.
  late final FontRegistry fonts;
  final container = ProviderContainer(
    overrides: [fontRegistryProvider.overrideWith((ref) => fonts)],
  );
  await Future.wait([
    FontRegistry.loadFromBundle(rootBundle).then((f) => fonts = f),
    restoreSavedSettings(container),
  ]);
  registerFontLicences(fonts, rootBundle);
  runApp(
    UncontrolledProviderScope(container: container, child: const AtdtApp()),
  );
}
