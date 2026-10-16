/// Byte decoding: strict UTF-8 first, then a heuristic choice between CP437
/// and the Latin-1 family for older philes.
library;

import 'dart:convert';

import 'code_pages.dart';
import 'phile_text.dart';

class DecodeResult {
  const DecodeResult({
    required this.text,
    required this.encoding,
    this.ambiguous = false,
    this.cp437Votes = 0,
    this.latinVotes = 0,
  });

  /// Decoded text. Control characters are left in place for normalisation.
  final String text;
  final TextEncoding encoding;
  final bool ambiguous;
  final int cp437Votes;
  final int latinVotes;
}

// Windows-1252 punctuation that shows up in prose: … ‘ ’ “ ” • – — ™
const _cp1252Punctuation = {
  0x85, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x99, //
};

bool _isAsciiLetter(int b) => (b | 0x20) >= 0x61 && (b | 0x20) <= 0x7A;
bool _isCp437Graphic(int b) => b >= 0xB0 && b <= 0xDF;

DecodeResult decodeBytes(List<int> bytes) {
  try {
    var text = utf8.decode(bytes);
    if (text.startsWith('﻿')) text = text.substring(1);
    return DecodeResult(text: text, encoding: TextEncoding.utf8);
  } on FormatException {
    // Not UTF-8: a single-byte code page.
  }

  // Box-drawing and shade bytes (0xB0-0xDF) outside words suggest CP437;
  // in Latin-1 that range is mostly capital accented letters, which sit
  // inside words. Accented lower-case (0xE0-0xFF) next to letters suggests
  // Latin-1. Evidence on both sides of a byte counts double.
  var cp437 = 0;
  var latin = 0;
  var c1 = 0;
  var c1Punctuation = 0;
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    if (b < 0x80) continue;
    final prev = i > 0 ? bytes[i - 1] : 0x20;
    final next = i + 1 < bytes.length ? bytes[i + 1] : 0x20;
    final letters =
        (_isAsciiLetter(prev) ? 1 : 0) + (_isAsciiLetter(next) ? 1 : 0);
    if (_isCp437Graphic(b) && letters < 2) {
      cp437 += _isCp437Graphic(prev) || _isCp437Graphic(next) ? 2 : 1;
    } else if (b >= 0xC0 && letters > 0) {
      latin += letters;
    } else if (b < 0xA0) {
      c1++;
      if (_cp1252Punctuation.contains(b)) c1Punctuation++;
    }
  }

  final TextEncoding encoding;
  final bool ambiguous;
  if (cp437 > latin) {
    encoding = TextEncoding.cp437;
    ambiguous = latin > 0 && cp437 < 2 * latin;
  } else if (latin > cp437) {
    encoding = c1 > 0 ? TextEncoding.windows1252 : TextEncoding.latin1;
    ambiguous = cp437 > 0 && latin < 2 * cp437;
  } else if (c1 > 0 && c1 == c1Punctuation) {
    // Only curly quotes and dashes: almost certainly Windows-1252.
    encoding = TextEncoding.windows1252;
    ambiguous = false;
  } else {
    // No clear evidence (e.g. CP437 accented letters 0x80-0xA5). Phrack's
    // early years were DOS-heavy, so lean CP437 and flag it.
    encoding = TextEncoding.cp437;
    ambiguous = true;
  }

  return DecodeResult(
    text: _decodeSingleByte(bytes, encoding),
    encoding: encoding,
    ambiguous: ambiguous,
    cp437Votes: cp437,
    latinVotes: latin,
  );
}

String _decodeSingleByte(List<int> bytes, TextEncoding encoding) {
  final b = StringBuffer();
  for (final byte in bytes) {
    if (byte < 0x80) {
      b.writeCharCode(byte);
    } else if (encoding == TextEncoding.cp437) {
      b.write(cp437High[byte - 0x80]);
    } else if (encoding == TextEncoding.windows1252 && byte < 0xA0) {
      b.write(windows1252C1[byte - 0x80]);
    } else {
      b.writeCharCode(byte);
    }
  }
  return b.toString();
}
