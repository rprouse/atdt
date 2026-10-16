/// Turns one downloaded issue tarball into normalised philes with metadata.
/// Pure Dart; no Flutter imports.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../ingest/phile_text.dart';
import 'tar_reader.dart';

class ImportedPhile {
  const ImportedPhile({
    required this.number,
    required this.title,
    required this.text,
    this.author,
  });

  final int number;

  /// From the archive's front matter, or "Phile N" when absent.
  final String title;

  /// From the front matter; null when absent or empty. Never guessed.
  final String? author;
  final PhileText text;
}

class ImportedIssue {
  const ImportedIssue({
    required this.number,
    required this.philes,
    required this.sourceChecksum,
  });

  final int number;

  /// Philes in numeric order.
  final List<ImportedPhile> philes;

  /// SHA-256 of the downloaded tarball, hex.
  final String sourceChecksum;
}

final _phileName = RegExp(r'^(\d+)\.txt$', caseSensitive: false);

/// Throws [ArchiveFormatException] for anything that is not a readable
/// gzipped tar.
ImportedIssue importIssueArchive(int issue, Uint8List gzipped) {
  final philes = <ImportedPhile>[];
  for (final entry in readTar(gunzip(gzipped))) {
    if (entry.type != TarEntryType.file) continue;
    final match = _phileName.firstMatch(entry.name);
    if (match == null) continue; // PDFs, readmes, nested or odd names
    final number = int.parse(match.group(1)!);
    final text = PhileText.fromBytes(entry.data);
    final title = text.frontMatter['title']?.trim() ?? '';
    final author = text.frontMatter['author']?.trim() ?? '';
    philes.add(
      ImportedPhile(
        number: number,
        title: title.isEmpty ? 'Phile $number' : title,
        author: author.isEmpty ? null : author,
        text: text,
      ),
    );
  }
  if (philes.isEmpty) {
    throw ArchiveFormatException('issue $issue archive has no philes');
  }
  philes.sort((a, b) => a.number.compareTo(b.number));
  return ImportedIssue(
    number: issue,
    philes: List.unmodifiable(philes),
    sourceChecksum: sha256.convert(gzipped).toString(),
  );
}
