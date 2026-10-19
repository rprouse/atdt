import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reader/reader_font.dart';
import '../reader/reader_screen.dart';
import 'compact_list.dart';
import 'library_providers.dart';

/// One issue's philes, in order. Kept alive under the reader, so going back
/// returns to the same scroll position.
class IssueScreen extends ConsumerWidget {
  const IssueScreen({required this.issue, super.key});

  final int issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final philes = ref.watch(issuePhilesProvider(issue));
    final numberFont = ref.watch(fontRegistryProvider).defaultFont.family;
    return Scaffold(
      appBar: AppBar(title: Text('Issue $issue')),
      body: switch (philes) {
        AsyncData(value: final list) => CompactListTiles(
          child: ListView.builder(
            key: PageStorageKey('philes-$issue'),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final phile = list[i];
              return ListTile(
                key: ValueKey('phile-${phile.number}'),
                leading: Text(
                  phile.number.toString().padLeft(2),
                  style: TextStyle(
                    fontFamily: numberFont,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                title: Text(phile.title),
                subtitle: phile.author == null ? null : Text(phile.author!),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ReaderScreen(phileId: phile.id, title: phile.title),
                  ),
                ),
              );
            },
          ),
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
