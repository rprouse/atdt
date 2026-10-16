import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'reader/about.dart';

void main() {
  registerFontLicences();
  runApp(const ProviderScope(child: AtdtApp()));
}
