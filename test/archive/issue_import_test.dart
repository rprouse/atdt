import 'dart:io';
import 'dart:typed_data';

import 'package:atdt/archive/issue_import.dart';
import 'package:atdt/archive/tar_reader.dart';
import 'package:atdt/ingest/phile_text.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _fixture() =>
    File('test/archive/fixtures/phrack99.tar.gz').readAsBytesSync();

void main() {
  late ImportedIssue issue;
  setUp(() => issue = importIssueArchive(99, _fixture()));

  test('imports numbered philes in numeric order', () {
    expect(issue.number, 99);
    expect(issue.philes.map((p) => p.number), [1, 2, 10]);
  });

  test('ignores non-phile files, odd names and symlinks', () {
    expect(issue.philes, hasLength(3));
  });

  test('takes title and author from front matter', () {
    final intro = issue.philes.first;
    expect(intro.title, 'Introduction');
    expect(intro.author, 'Synthetic Staff');
    expect(intro.text.lines.first, '                    ==Phrack Inc.==');
  });

  test('falls back to "Phile N" and no author, without guessing', () {
    final art = issue.philes[1];
    expect(art.title, 'Phile 2');
    expect(art.author, isNull);
    expect(art.text.encoding, TextEncoding.cp437);
    expect(art.text.lines, ['╔══╗', '╚══╝']);

    // An empty author value means unknown, not "".
    expect(issue.philes[2].author, isNull);
  });

  test('records the source checksum', () {
    expect(
      issue.sourceChecksum,
      '2192bf6a3deb03efcf22e50f000ef5ec2e64bdab15668e20cf261b17c7fb3c8b',
    );
  });

  test('a malformed archive raises ArchiveFormatException', () {
    final broken = Uint8List.fromList(_fixture().sublist(0, 100));
    expect(
      () => importIssueArchive(99, broken),
      throwsA(isA<ArchiveFormatException>()),
    );
  });
}
