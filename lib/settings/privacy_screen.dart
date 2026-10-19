import 'package:flutter/material.dart';

/// The privacy statement, as published in docs/privacy.md. Keep the two in
/// step (test/settings/privacy_test.dart checks they match).
const privacyStatement = [
  (
    'No personal data',
    'ATDT collects no personal data. There are no accounts, analytics, '
        'advertising, crash reports or tracking of any kind.',
  ),
  (
    'Network',
    'The app connects to two sites, and only while you download the '
        'archive: archives.phrack.org, for the issues, and phrack.org, for '
        'their release dates. Requests identify the app ("ATDT/1.0") and '
        'carry nothing about you. As with any web request, those sites see '
        'your IP address; their own policies apply.',
  ),
  (
    'On your device',
    'The archive, your reading positions, the search index and your '
        'settings stay in the app\'s private storage. They never leave the '
        'device and are excluded from cloud backups. Uninstalling the app '
        'deletes them.',
  ),
  ('Permissions', 'Internet access, to download the archive. Nothing else.'),
  ('Contact', 'Questions or concerns: https://github.com/rprouse/atdt/issues'),
];

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (heading, body) in privacyStatement) ...[
            Text(heading, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(body, style: text.bodyMedium),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
