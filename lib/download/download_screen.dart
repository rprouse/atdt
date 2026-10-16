import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../archive/archive_downloader.dart';
import '../storage/archive_database.dart';
import 'download_controller.dart';

/// Download the archive, watch progress, and check for new issues.
/// Stage D folds this into the first-launch flow and the library.
class DownloadScreen extends ConsumerWidget {
  const DownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(downloadControllerProvider);
    final counts = ref.watch(archiveCountsProvider).value;
    final controller = ref.read(downloadControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Phrack archive')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              counts == null
                  ? 'Reading storage…'
                  : '${_plural(counts.issues, 'issue')}, '
                        '${_plural(counts.philes, 'phile')} stored',
              key: const ValueKey('counts'),
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ..._status(context, progress, counts),
            const SizedBox(height: 24),
            if (controller.isRunning)
              OutlinedButton(
                onPressed: controller.cancel,
                child: const Text('Cancel'),
              )
            else
              FilledButton(
                onPressed: controller.start,
                child: Text(_actionLabel(progress, counts)),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _status(
    BuildContext context,
    DownloadProgress? p,
    ArchiveCounts? counts,
  ) {
    if (p == null) {
      return [
        Text(
          (counts?.issues ?? 0) == 0
              ? 'ATDT downloads every issue of Phrack once, about '
                    '$archiveDownloadMegabytes MB, then reads it offline. '
                    'Issues are fetched one at a time from '
                    'archives.phrack.org.'
              : 'Check the archive for issues published since your last '
                    'download.',
        ),
      ];
    }
    return switch (p.phase) {
      DownloadPhase.checking => [
        const Text('Checking the archive…'),
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
      DownloadPhase.downloading || DownloadPhase.importing => [
        Text(
          '${p.phase == DownloadPhase.importing ? 'Storing' : 'Downloading'} '
          'issue ${p.issue} (${p.completed + 1} of ${p.total})',
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          key: const ValueKey('download-progress'),
          value: p.total == 0 ? null : _fraction(p),
        ),
        if (p.totalBytes != null && p.phase == DownloadPhase.downloading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_kb(p.receivedBytes)} of ${_kb(p.totalBytes!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
      DownloadPhase.done => [
        Text(
          p.total == 0
              ? 'Up to date.'
              : 'Stored ${_plural(p.completed, 'new issue')}.',
        ),
        if (p.failedIssues.isNotEmpty) _failed(p.failedIssues),
      ],
      DownloadPhase.cancelled => [
        Text(
          'Paused after ${p.completed} of ${p.total}. Finished issues are '
          'kept; resuming fetches only the rest.',
        ),
      ],
      DownloadPhase.failed => [
        Text(
          p.error ?? 'The download failed.',
          key: const ValueKey('download-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 8),
        Text(
          'Finished issues are kept; retrying fetches only the rest.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    };
  }

  Widget _failed(List<int> issues) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      "Couldn't fetch ${issues.length == 1 ? 'issue' : 'issues'} "
      '${issues.join(', ')}. Retry to try them again.',
    ),
  );

  String _actionLabel(DownloadProgress? p, ArchiveCounts? counts) {
    if (p?.phase == DownloadPhase.failed) return 'Retry';
    if (p?.phase == DownloadPhase.cancelled) return 'Resume';
    if (p?.failedIssues.isNotEmpty ?? false) return 'Retry';
    if ((counts?.issues ?? 0) == 0) return 'Download archive';
    return 'Check for new issues';
  }

  double _fraction(DownloadProgress p) {
    final partial = p.phase == DownloadPhase.importing
        ? 1.0
        : (p.totalBytes ?? 0) > 0
        ? p.receivedBytes / p.totalBytes!
        : 0.0;
    return ((p.completed + partial) / p.total).clamp(0, 1);
  }

  String _kb(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
}
