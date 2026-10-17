/// Minimal, defensive reader for gzipped tar archives (ustar, PAX and GNU
/// long names). Pure Dart; no Flutter imports.
///
/// It reads everything into memory: Phrack issue tarballs are at most
/// ~13 MB compressed. Anything malformed raises [ArchiveFormatException];
/// nothing is written to disk and links are reported, never followed.
library;

import 'dart:convert';
import 'dart:io' show GZipCodec;
import 'dart:typed_data';

class ArchiveFormatException implements Exception {
  const ArchiveFormatException(this.message);

  final String message;

  @override
  String toString() => 'ArchiveFormatException: $message';
}

enum TarEntryType { file, directory, symlink, other }

class TarEntry {
  const TarEntry({
    required this.name,
    required this.type,
    required this.data,
    required this.modified,
  });

  /// Path inside the archive, with any leading `./` removed.
  final String name;
  final TarEntryType type;

  /// File contents; empty for anything that is not a regular file.
  final Uint8List data;
  final DateTime modified;
}

const _block = 512;

/// Default ceiling for inflated data: well above the largest issue (~17 MB)
/// while refusing decompression bombs.
const int defaultMaxInflatedBytes = 256 * 1024 * 1024;

/// Inflates gzip data, refusing to produce more than [maxBytes].
Uint8List gunzip(List<int> bytes, {int maxBytes = defaultMaxInflatedBytes}) {
  final sink = _LimitedSink(maxBytes);
  try {
    GZipCodec().decoder.startChunkedConversion(sink)
      ..add(bytes)
      ..close();
  } on ArchiveFormatException {
    rethrow;
  } on Object catch (e) {
    throw ArchiveFormatException('not valid gzip data ($e)');
  }
  final out = sink.bytes.takeBytes();
  // The decoder accepts a truncated stream silently, so check the trailer:
  // its last four bytes are the inflated size mod 2^32 (RFC 1952 ISIZE).
  if (bytes.length < 18) {
    throw const ArchiveFormatException('gzip data is truncated');
  }
  final n = bytes.length;
  final isize =
      bytes[n - 4] |
      bytes[n - 3] << 8 |
      bytes[n - 2] << 16 |
      bytes[n - 1] << 24;
  if (isize != out.length & 0xFFFFFFFF) {
    throw const ArchiveFormatException('gzip data is truncated');
  }
  return out;
}

class _LimitedSink implements Sink<List<int>> {
  _LimitedSink(this._maxBytes);

  final BytesBuilder bytes = BytesBuilder(copy: false);
  final int _maxBytes;

  @override
  void add(List<int> chunk) {
    if (bytes.length + chunk.length > _maxBytes) {
      throw ArchiveFormatException('inflated data exceeds $_maxBytes bytes');
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}

List<TarEntry> readTar(Uint8List tar) {
  final entries = <TarEntry>[];
  String? nextName; // from a PAX 'path' record or a GNU 'L' entry
  var offset = 0;
  var ended = tar.isEmpty;
  while (offset + _block <= tar.length) {
    final header = Uint8List.sublistView(tar, offset, offset + _block);
    if (header.every((b) => b == 0)) {
      ended = true; // end-of-archive marker
      break;
    }
    _verifyChecksum(header, offset);

    final size = _readSize(header, offset);
    final type = String.fromCharCode(header[156]);
    final dataStart = offset + _block;
    final dataEnd = dataStart + size;
    if (dataEnd > tar.length) {
      throw ArchiveFormatException('entry at $offset is truncated');
    }
    final data = Uint8List.sublistView(tar, dataStart, dataEnd);
    offset = dataStart + (size + _block - 1) ~/ _block * _block;

    switch (type) {
      case 'x': // PAX extended header for the next entry
        nextName = _paxPath(data) ?? nextName;
        continue;
      case 'g': // PAX global header: nothing we need
        continue;
      case 'L': // GNU long name for the next entry
        nextName = _cString(data);
        continue;
    }

    var name = nextName ?? _headerName(header);
    nextName = null;
    while (name.startsWith('./')) {
      name = name.substring(2);
    }
    if (name == '.') name = '';

    final entryType = switch (type) {
      '0' || '\x00' || '7' => TarEntryType.file,
      '5' => TarEntryType.directory,
      '2' => TarEntryType.symlink,
      _ => TarEntryType.other,
    };
    entries.add(
      TarEntry(
        name: name,
        type: entryType,
        data: entryType == TarEntryType.file
            ? Uint8List.fromList(data)
            : Uint8List(0),
        modified: DateTime.fromMillisecondsSinceEpoch(
          _readOctal(header, 136, 12, offset) * 1000,
          isUtc: true,
        ),
      ),
    );
  }
  // Running out of data before the zero-block marker means a cut-short
  // download, not a short archive.
  if (!ended) {
    throw const ArchiveFormatException('archive ends without its end marker');
  }
  return entries;
}

void _verifyChecksum(Uint8List header, int offset) {
  var sum = 0;
  for (var i = 0; i < _block; i++) {
    sum += (i >= 148 && i < 156) ? 0x20 : header[i];
  }
  if (_readOctal(header, 148, 8, offset) != sum) {
    throw ArchiveFormatException('bad header checksum at $offset');
  }
}

int _readSize(Uint8List header, int offset) {
  // GNU base-256 encoding for sizes over 8 GB; not expected, but legal.
  if (header[124] & 0x80 != 0) {
    var size = header[124] & 0x7F;
    for (var i = 125; i < 136; i++) {
      size = size << 8 | header[i];
    }
    return size;
  }
  return _readOctal(header, 124, 12, offset);
}

int _readOctal(Uint8List header, int start, int length, int offset) {
  final text = ascii
      .decode(header.sublist(start, start + length), allowInvalid: true)
      .replaceAll('\x00', ' ')
      .trim();
  if (text.isEmpty) return 0;
  final value = int.tryParse(text, radix: 8);
  if (value == null || value < 0) {
    throw ArchiveFormatException('bad numeric field at ${offset + start}');
  }
  return value;
}

String _headerName(Uint8List header) {
  final name = _cString(Uint8List.sublistView(header, 0, 100));
  final isUstar =
      ascii.decode(header.sublist(257, 262), allowInvalid: true) == 'ustar';
  final prefix = isUstar
      ? _cString(Uint8List.sublistView(header, 345, 500))
      : '';
  return prefix.isEmpty ? name : '$prefix/$name';
}

String _cString(Uint8List bytes) {
  final end = bytes.indexOf(0);
  return utf8.decode(
    end < 0 ? bytes : Uint8List.sublistView(bytes, 0, end),
    allowMalformed: true,
  );
}

/// The `path` value from PAX records (`"<len> <key>=<value>\n"` ...).
String? _paxPath(Uint8List data) {
  var pos = 0;
  while (pos < data.length) {
    final space = data.indexOf(0x20, pos);
    if (space < 0) break;
    final length = int.tryParse(ascii.decode(data.sublist(pos, space)));
    if (length == null || length <= 0 || pos + length > data.length) break;
    final record = utf8.decode(
      data.sublist(space + 1, pos + length - 1),
      allowMalformed: true,
    );
    final eq = record.indexOf('=');
    if (eq > 0 && record.substring(0, eq) == 'path') {
      return record.substring(eq + 1);
    }
    pos += length;
  }
  return null;
}
