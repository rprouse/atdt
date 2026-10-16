import 'package:flutter/material.dart';

/// Root widget. Stage A replaces [_PlaceholderScreen] with the reader.
class AtdtApp extends StatelessWidget {
  const AtdtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ATDT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF33FF33),
          brightness: Brightness.dark,
        ),
      ),
      home: const _PlaceholderScreen(),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('ATDT', style: TextStyle(fontFamily: 'monospace')),
      ),
    );
  }
}
