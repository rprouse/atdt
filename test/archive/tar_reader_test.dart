import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:atdt/archive/tar_reader.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _fixture() =>
    File('test/archive/fixtures/phrack99.tar.gz').readAsBytesSync();

void main() {
  group('gunzip', () {
    test('inflates the fixture', () {
      final tar = gunzip(_fixture());
      expect(tar.length % 512, 0);
    });

    test('rejects data that is not gzip', () {
      expect(
        () => gunzip(Uint8List.fromList(utf8.encode('not gzip'))),
        throwsA(isA<ArchiveFormatException>()),
      );
    });

    test('detects a download cut short', () {
      final gz = _fixture();
      for (final keep in [gz.length - 1, gz.length - 9, gz.length ~/ 2]) {
        expect(
          () => gunzip(Uint8List.sublistView(gz, 0, keep)),
          throwsA(isA<ArchiveFormatException>()),
          reason: 'kept $keep of ${gz.length} bytes',
        );
      }
    });

    test('refuses to inflate past the size limit', () {
      expect(
        () => gunzip(_fixture(), maxBytes: 1024),
        throwsA(isA<ArchiveFormatException>()),
      );
    });
  });

  group('readTar', () {
    late List<TarEntry> entries;
    setUp(() => entries = readTar(gunzip(_fixture())));

    test('lists every entry with ./ stripped', () {
      expect(entries.map((e) => e.name), [
        '',
        '1.txt',
        '2.txt',
        '10.txt',
        'phrack-99.pdf',
        '${'x' * 120}.txt',
        '3.txt',
      ]);
    });

    test('reads PAX long names', () {
      expect(entries[5].name, hasLength(124));
      expect(utf8.decode(entries[5].data), contains('Long Name'));
    });

    test('types entries and never follows symlinks', () {
      expect(entries.first.type, TarEntryType.directory);
      expect(entries[1].type, TarEntryType.file);
      expect(entries.last.type, TarEntryType.symlink);
      expect(entries.last.data, isEmpty);
    });

    test('reads file contents and timestamps', () {
      expect(utf8.decode(entries[3].data), contains('ten'));
      expect(entries[2].data, hasLength(10));
      expect(
        entries[1].modified,
        DateTime.fromMillisecondsSinceEpoch(500000000 * 1000, isUtc: true),
      );
    });
  });

  group('malformed archives', () {
    test('a corrupted header fails its checksum', () {
      final tar = gunzip(_fixture());
      tar[512 + 10] ^= 0xFF; // inside the second header's name
      expect(() => readTar(tar), throwsA(isA<ArchiveFormatException>()));
    });

    test('truncated file data is an error', () {
      final tar = gunzip(_fixture());
      final cut = Uint8List.sublistView(tar, 0, 512 + 512 + 40);
      expect(() => readTar(cut), throwsA(isA<ArchiveFormatException>()));
    });

    test('a tar without its end marker is an error', () {
      final tar = gunzip(_fixture());
      // Cut exactly after a complete entry, so only the marker is missing.
      final cut = Uint8List.sublistView(tar, 0, 512 * 3);
      expect(() => readTar(cut), throwsA(isA<ArchiveFormatException>()));
    });

    test('an empty archive has no entries', () {
      expect(readTar(Uint8List(1024)), isEmpty);
      expect(readTar(Uint8List(0)), isEmpty);
    });

    test('a size field that is not octal is an error', () {
      final tar = gunzip(_fixture());
      // 1.txt's header (block 1, after the ./ entry); recompute the
      // checksum so only the size is wrong.
      const header = 512;
      tar.setRange(header + 124, header + 136, utf8.encode('zzzzzzzzzzz\x00'));
      _fixChecksum(tar, header);
      expect(() => readTar(tar), throwsA(isA<ArchiveFormatException>()));
    });
  });
}

void _fixChecksum(Uint8List tar, int header) {
  var sum = 0;
  for (var i = 0; i < 512; i++) {
    sum += (i >= 148 && i < 156) ? 0x20 : tar[header + i];
  }
  final field = '${sum.toRadixString(8).padLeft(6, '0')}\x00 ';
  tar.setRange(header + 148, header + 156, ascii.encode(field));
}
