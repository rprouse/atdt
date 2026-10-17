import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../archive/archive_downloader.dart';
import '../download/download_controller.dart';
import '../download/download_screen.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_screen.dart';
import '../storage/archive_database.dart';
import 'issue_screen.dart';
import 'library_providers.dart';

/// Home: every issue, newest first. With nothing stored it is the
/// first-launch flow: it explains the download and starts it on request.
class IssuesScreen extends ConsumerWidget {
  const IssuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(libraryIssuesProvider);
    final progress = ref.watch(downloadControllerProvider);
    final running = progress != null && !progress.isFinished;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phrack'),
        actions: [
          IconButton(
            tooltip: 'Archive',
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: () => _push(context, const DownloadScreen()),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _push(context, const SettingsScreen()),
          ),
        ],
      ),
      body: switch (issues) {
        AsyncData(value: final list) when list.isEmpty && !running =>
          const _FirstLaunch(),
        AsyncData(value: final list) => Column(
          children: [
            if (running) _DownloadBanner(progress: progress),
            if (ref.watch(lastReadProvider).value case final last?)
              _ContinueReading(last: last),
            Expanded(child: _IssueList(issues: list)),
          ],
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

class _IssueList extends StatelessWidget {
  const _IssueList({required this.issues});

  final List<LibraryIssue> issues;

  @override
  Widget build(BuildContext context) {
    final dim = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return ListView.builder(
      key: const PageStorageKey('issues'),
      itemCount: issues.length,
      itemBuilder: (context, i) {
        final issue = issues[i];
        final date = issue.releaseDate == null
            ? null
            : formatReleaseDate(issue.releaseDate!);
        final detail = issue.downloaded
            ? '${issue.phileCount} philes'
            : 'Not downloaded';
        return ListTile(
          key: ValueKey('issue-${issue.number}'),
          title: Text(
            'Issue ${issue.number}',
            style: issue.downloaded ? null : TextStyle(color: dim),
          ),
          subtitle: Text([?date, detail].join(' · ')),
          trailing: issue.downloaded
              ? null
              : Icon(Icons.cloud_off_outlined, color: dim),
          onTap: () => _push(
            context,
            issue.downloaded
                ? IssueScreen(issue: issue.number)
                : const DownloadScreen(),
          ),
        );
      },
    );
  }
}

class _DownloadBanner extends ConsumerWidget {
  const _DownloadBanner({required this.progress});

  final DownloadProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = progress;
    final label = p.issue == null
        ? 'Checking the archive…'
        : 'Downloading issue ${p.issue} (${p.completed + 1} of ${p.total})';
    return Material(
      key: const ValueKey('download-banner'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => _push(context, const DownloadScreen()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: p.total == 0 ? null : p.completed / p.total,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstLaunch extends ConsumerWidget {
  const _FirstLaunch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final last = ref.watch(downloadControllerProvider);
    return ListView(
      key: const ValueKey('first-launch'),
      padding: const EdgeInsets.all(24),
      children: [
        Text('Welcome to ATDT', style: textTheme.headlineSmall),
        const SizedBox(height: 16),
        const Text(
          'ATDT reads every issue of Phrack, from 1985 to today, exactly as '
          'it was published: 80 columns of fixed-width text.',
        ),
        const SizedBox(height: 12),
        const Text(
          'The archive is downloaded once from archives.phrack.org, about '
          '$archiveDownloadMegabytes MB, and then works offline. Issues are '
          'fetched one at a time, and an interrupted download picks up '
          'where it stopped.',
        ),
        if (last?.phase == DownloadPhase.failed) ...[
          const SizedBox(height: 12),
          Text(
            last!.error ?? 'The download failed.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () =>
              ref.read(downloadControllerProvider.notifier).start(),
          child: Text(
            last?.phase == DownloadPhase.failed
                ? 'Try again'
                : 'Download the archive',
          ),
        ),
      ],
    );
  }
}

/// Returns to the last phile read, at the line where reading stopped.
class _ContinueReading extends StatelessWidget {
  const _ContinueReading({required this.last});

  final LastRead last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('continue-reading'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: scheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(Icons.bookmark_outline, color: scheme.primary),
        title: Text(last.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'Continue reading · Issue ${last.issue} · ${last.percent}%',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _push(
          context,
          ReaderScreen(phileId: last.phileId, title: last.title),
        ),
      ),
    );
  }
}
