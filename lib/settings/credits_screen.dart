import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reader/about.dart';
import '../reader/reader_font.dart';

/// Every bundled font with its attribution and licence, from the manifest.
class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(fontRegistryProvider);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Credits')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const ListTile(title: Text('Phrack'), subtitle: Text(phrackCredit)),
          ListTile(
            key: const ValueKey('licences'),
            title: const Text('Licences'),
            subtitle: const Text('Every open-source package and font licence'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showAtdtLicences(context),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Fonts', style: textTheme.titleSmall),
          ),
          for (final font in registry.fonts)
            ListTile(
              key: ValueKey('font-credit-${font.id}'),
              title: Text(
                font.displayName,
                style: TextStyle(
                  fontFamily: font.family,
                  fontFeatures: readerFontFeatures,
                ),
              ),
              subtitle: Text(
                '${font.spec.attribution}\n'
                'Licence: ${font.spec.licenceName} (${font.spec.licenceUrl})',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _LicenceText(font: font),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LicenceText extends StatelessWidget {
  const _LicenceText({required this.font});

  final ReaderFont font;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(font.spec.licenceName)),
    body: FutureBuilder<String>(
      future: rootBundle.loadString(FontRegistry.licencePath(font)),
      builder: (context, snapshot) => switch (snapshot) {
        AsyncSnapshot(:final data?) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            data,
            key: const ValueKey('licence-text'),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        AsyncSnapshot(:final error?) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    ),
  );
}
