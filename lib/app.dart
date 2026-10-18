import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'download/download_controller.dart';
import 'library/issues_screen.dart';
import 'library/search_providers.dart';
import 'reader/reader_settings.dart';

class AtdtApp extends ConsumerStatefulWidget {
  const AtdtApp({super.key});

  @override
  ConsumerState<AtdtApp> createState() => _AtdtAppState();
}

class _AtdtAppState extends ConsumerState<AtdtApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_resume()));
    // The search index follows the archive for the app's whole life; listen
    // rather than watch, so progress never rebuilds the app.
    ref.listenManual(searchIndexerProvider, (_, _) {});
  }

  /// Picks up a download the app was killed during.
  Future<void> _resume() async {
    try {
      await ref.read(downloadControllerProvider.notifier).resumeIfInterrupted();
    } on Object catch (e, s) {
      developer.log(
        'could not resume download',
        name: 'atdt.download',
        error: e,
        stackTrace: s,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    return MaterialApp(
      title: 'ATDT',
      debugShowCheckedModeBanner: false,
      theme: theme.toThemeData(),
      home: const IssuesScreen(),
    );
  }
}
