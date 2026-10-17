/// Where issues come from: the Phrack archive over HTTPS. Pure Dart.
///
/// URL patterns verified 2026-10-16 (docs/decisions.md): issue tarballs at
/// `https://archives.phrack.org/tgz/phrack<N>.tar.gz`, listed in that
/// folder's index; release dates in the issue picker on phrack.org pages.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Offline, DNS, TLS or timeout: nothing will work until the network does.
class ArchiveNetworkException implements Exception {
  const ArchiveNetworkException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'ArchiveNetworkException: $message ($cause)';
}

/// The server answered, but not with the issue (e.g. 404, 500).
class ArchiveHttpException implements Exception {
  const ArchiveHttpException(this.statusCode, this.uri);

  final int statusCode;
  final Uri uri;

  @override
  String toString() => 'HTTP $statusCode for $uri';
}

class CancelledException implements Exception {
  const CancelledException();
}

class CancelToken {
  bool _cancelled = false;
  final _listeners = <void Function()>[];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  void Function() _onCancel(void Function() listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void throwIfCancelled() {
    if (_cancelled) throw const CancelledException();
  }
}

typedef ProgressCallback = void Function(int received, int? total);

abstract interface class ArchiveSource {
  /// Issue numbers available for download, ascending.
  Future<List<int>> availableIssues({CancelToken? cancel});

  /// Release dates by issue. Best effort: an empty map if unavailable.
  Future<Map<int, DateTime>> releaseDates({CancelToken? cancel});

  Future<Uint8List> fetchIssue(
    int issue, {
    ProgressCallback? onProgress,
    CancelToken? cancel,
  });
}

class HttpArchiveSource implements ArchiveSource {
  HttpArchiveSource({
    HttpClient? client,
    Uri? archiveBase,
    Uri? siteBase,
    this.userAgent = defaultUserAgent,
    this.idleTimeout = const Duration(seconds: 30),
  }) : _client = client ?? HttpClient(),
       archiveBase =
           archiveBase ?? Uri.parse('https://archives.phrack.org/tgz/'),
       siteBase = siteBase ?? Uri.parse('https://phrack.org/') {
    _client.connectionTimeout = const Duration(seconds: 15);
  }

  static const defaultUserAgent =
      'ATDT/1.0 (offline Phrack reader; +https://github.com/rprouse/atdt)';

  final HttpClient _client;
  final Uri archiveBase;
  final Uri siteBase;
  final String userAgent;
  final Duration idleTimeout;

  @override
  Future<List<int>> availableIssues({CancelToken? cancel}) async {
    final html = utf8.decode(
      await _get(archiveBase, cancel: cancel),
      allowMalformed: true,
    );
    final issues = parseIssueListing(html);
    if (issues.isEmpty) {
      throw ArchiveHttpException(HttpStatus.noContent, archiveBase);
    }
    return issues;
  }

  @override
  Future<Map<int, DateTime>> releaseDates({CancelToken? cancel}) async {
    try {
      // /issues/1/1 is a redirect stub to the slugged page that carries
      // the issue picker; issue 1 always exists.
      var page = siteBase.resolve('issues/1/1');
      var html = utf8.decode(
        await _get(page, cancel: cancel),
        allowMalformed: true,
      );
      final refresh = parseMetaRefresh(html);
      if (refresh != null) {
        page = page.resolve(refresh);
        html = utf8.decode(
          await _get(page, cancel: cancel),
          allowMalformed: true,
        );
      }
      return parseReleaseDates(html);
    } on CancelledException {
      rethrow;
    } on Object {
      return const {}; // dates are "if known"
    }
  }

  @override
  Future<Uint8List> fetchIssue(
    int issue, {
    ProgressCallback? onProgress,
    CancelToken? cancel,
  }) => _get(
    archiveBase.resolve('phrack$issue.tar.gz'),
    onProgress: onProgress,
    cancel: cancel,
  );

  Future<Uint8List> _get(
    Uri uri, {
    ProgressCallback? onProgress,
    CancelToken? cancel,
  }) async {
    cancel?.throwIfCancelled();
    HttpClientRequest? request;
    final removeListener = cancel?._onCancel(() => request?.abort());
    try {
      request = await _client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      cancel?.throwIfCancelled();
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>().catchError((_) {});
        throw ArchiveHttpException(response.statusCode, uri);
      }
      final total = response.contentLength >= 0 ? response.contentLength : null;
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(idleTimeout)) {
        cancel?.throwIfCancelled();
        bytes.add(chunk);
        onProgress?.call(bytes.length, total);
      }
      cancel?.throwIfCancelled();
      return bytes.takeBytes();
    } on CancelledException {
      rethrow;
    } on ArchiveHttpException {
      rethrow;
    } on Object catch (e) {
      if (cancel?.isCancelled ?? false) throw const CancelledException();
      if (e is SocketException ||
          e is HandshakeException ||
          e is TlsException ||
          e is HttpException ||
          e is TimeoutException) {
        throw ArchiveNetworkException(
          "Can't reach the Phrack archive. Check your connection and try again.",
          e,
        );
      }
      rethrow;
    } finally {
      removeListener?.call();
    }
  }

  void close() => _client.close(force: true);
}

final _listing = RegExp(r'phrack(\d+)\.tar\.gz');
final _metaRefresh = RegExp(
  r'''<meta[^>]+http-equiv=["']?refresh["']?[^>]+content=["'][^"']*url=([^"'>\s]+)''',
  caseSensitive: false,
);
final _picker = RegExp(r'Issue (\d+) \((\d{4})-(\d{2})-(\d{2})\)');

List<int> parseIssueListing(String html) =>
    {for (final m in _listing.allMatches(html)) int.parse(m.group(1)!)}.toList()
      ..sort();

String? parseMetaRefresh(String html) =>
    _metaRefresh.firstMatch(html)?.group(1);

Map<int, DateTime> parseReleaseDates(String html) => {
  for (final m in _picker.allMatches(html))
    int.parse(m.group(1)!): DateTime.utc(
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
    ),
};
