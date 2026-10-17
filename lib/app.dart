import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'download/download_controller.dart';
import 'library/issues_screen.dart';
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
    final theme = ref.watch(readerSettingsProvider.select((s) => s.theme));
    return MaterialApp(
      title: 'ATDT',
      debugShowCheckedModeBanner: false,
      theme: theme.toThemeData(),
      home: const IssuesScreen(),
    );
  }
}
