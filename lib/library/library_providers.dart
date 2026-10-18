import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../download/download_controller.dart';
import '../ingest/phile_text.dart';
import '../layout/reading_position.dart';
import '../sections/section_parser.dart';
import '../storage/archive_database.dart';

/// Every known issue, newest first; updates as issues download.
final libraryIssuesProvider = StreamProvider<List<LibraryIssue>>(
  (ref) => ref.watch(archiveDatabaseProvider).watchLibraryIssues(),
);

final issuePhilesProvider = StreamProvider.family<List<Phile>, int>(
  (ref, issue) => ref.watch(archiveDatabaseProvider).watchPhiles(issue),
);

class StoredPhile {
  const StoredPhile({
    required this.meta,
    required this.text,
    this.position,
    this.sections = const [],
  });

  final Phile meta;
  final PhileText text;

  /// Where the reader left off, if they have opened it before.
  final ReadingPosition? position;

  /// Headings for the jump list; empty when none were recognised.
  final List<Section> sections;
}

/// A phile's text, loaded whole for the reader. Disposed when the reader
/// closes, so a 16 MB phile does not stay in memory.
final storedPhileProvider = FutureProvider.autoDispose.family<StoredPhile, int>(
  (ref, phileId) async {
    final db = ref.watch(archiveDatabaseProvider);
    final meta = await db.phileById(phileId);
    if (meta == null) throw StateError('No phile with id $phileId');
    final lines = await db.readAllLines(phileId);
    return StoredPhile(
      meta: meta,
      position: await db.readingPosition(phileId),
      sections: parseSections(lines),
      text: PhileText(
        lines: lines,
        longestLineColumns: meta.longestLine,
        encoding: encodingFromLabel(meta.encoding),
        inventory: unpackUint32(meta.inventory),
      ),
    );
  },
);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "19 Aug 2025". Release dates are UTC calendar dates; never localise.
String formatReleaseDate(DateTime date) {
  final d = date.toUtc();
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// The most recently read phile, for "continue reading".
final lastReadProvider = StreamProvider<LastRead?>(
  (ref) => ref.watch(archiveDatabaseProvider).watchLastRead(),
);
