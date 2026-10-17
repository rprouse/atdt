import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reader/reader_screen.dart';
import 'library_providers.dart';

/// One issue's philes, in order. Kept alive under the reader, so going back
/// returns to the same scroll position.
class IssueScreen extends ConsumerWidget {
  const IssueScreen({required this.issue, super.key});

  final int issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final philes = ref.watch(issuePhilesProvider(issue));
    return Scaffold(
      appBar: AppBar(title: Text('Issue $issue')),
      body: switch (philes) {
        AsyncData(value: final list) => ListView.builder(
          key: PageStorageKey('philes-$issue'),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final phile = list[i];
            return ListTile(
              key: ValueKey('phile-${phile.number}'),
              leading: Text(
                phile.number.toString().padLeft(2),
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontFeatures: [FontFeature.tabularFigures()],
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
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
