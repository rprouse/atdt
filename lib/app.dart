import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reader/reader_screen.dart';
import 'reader/reader_settings.dart';

class AtdtApp extends ConsumerWidget {
  const AtdtApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(readerSettingsProvider.select((s) => s.theme));
    return MaterialApp(
      title: 'ATDT',
      debugShowCheckedModeBanner: false,
      theme: theme.toThemeData(),
      home: const ReaderScreen(),
    );
  }
}
