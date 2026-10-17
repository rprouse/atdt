import 'dart:async';
import 'dart:io';

import 'package:atdt/archive/archive_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// A loopback server standing in for archives.phrack.org and phrack.org.
class _Server {
  late HttpServer server;
  final requests = <HttpRequest>[];
  final userAgents = <String?>[];
  Completer<void>? stall;

  Uri get base => Uri.parse('http://127.0.0.1:${server.port}/');

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request);
      userAgents.add(request.headers.value(HttpHeaders.userAgentHeader));
      final res = request.response;
      switch (request.uri.path) {
        case '/tgz/':
          res.write(
            '<a href="phrack2.tar.gz">phrack2.tar.gz</a> '
            '<a href="phrack1.tar.gz">phrack1.tar.gz</a> '
            '<a href="phrack10.tar.gz">phrack10.tar.gz</a> '
            '<a href="phrack1.tar.gz">again</a>',
          );
        case '/tgz/phrack1.tar.gz':
          res.contentLength = 3000;
          for (var i = 0; i < 3; i++) {
            res.add(List.filled(1000, i));
            await res.flush();
          }
        case '/tgz/phrack9.tar.gz':
          res.headers.contentLength = 10;
          res.add([1, 2]);
          await res.flush();
          await stall?.future; // never finishes unless released
        case '/issues/1/1':
          res.write(
            '<meta http-equiv="refresh" '
            'content="0; url=/issues/1/introduction.html">',
          );
        case '/issues/1/introduction.html':
          res.write(
            '<select id="issue-jump"><option>Issue 1 (1985-11-17)</option>'
            '<option selected="selected">Issue 72 (2025-08-19)</option>',
          );
        default:
          res.statusCode = HttpStatus.notFound;
      }
      await res.close();
    });
  }
}

void main() {
  late _Server server;
  late HttpArchiveSource source;

  setUp(() async {
    server = _Server();
    await server.start();
    source = HttpArchiveSource(
      archiveBase: server.base.resolve('tgz/'),
      siteBase: server.base,
      idleTimeout: const Duration(milliseconds: 500),
    );
  });

  tearDown(() async {
    server.stall?.complete();
    source.close();
    await server.server.close(force: true);
  });

  test('lists issues from the directory index, sorted and unique', () async {
    expect(await source.availableIssues(), [1, 2, 10]);
  });

  test('sends an identifying user agent', () async {
    await source.availableIssues();
    expect(server.userAgents.single, contains('ATDT'));
    expect(server.userAgents.single, contains('github.com/rprouse/atdt'));
  });

  test('downloads an issue and reports progress', () async {
    final progress = <(int, int?)>[];
    final bytes = await source.fetchIssue(
      1,
      onProgress: (r, t) => progress.add((r, t)),
    );
    expect(bytes, hasLength(3000));
    // Loopback may coalesce writes, so only the final report is certain.
    expect(progress.last, (3000, 3000));
  });

  test('a missing issue is an HTTP error, not a network error', () async {
    await expectLater(
      source.fetchIssue(5),
      throwsA(
        isA<ArchiveHttpException>().having((e) => e.statusCode, 'status', 404),
      ),
    );
  });

  test('follows the redirect stub to read release dates', () async {
    expect(await source.releaseDates(), {
      1: DateTime.utc(1985, 11, 17),
      72: DateTime.utc(2025, 8, 19),
    });
  });

  test('release dates are best effort', () async {
    final noSite = HttpArchiveSource(
      archiveBase: server.base.resolve('tgz/'),
      siteBase: server.base.resolve('nowhere/'),
    );
    addTearDown(noSite.close);
    expect(await noSite.releaseDates(), isEmpty);
  });

  test('an unreachable server is a network error', () async {
    final port = server.server.port;
    await server.server.close(force: true);
    final offline = HttpArchiveSource(
      archiveBase: Uri.parse('http://127.0.0.1:$port/tgz/'),
    );
    addTearDown(offline.close);
    await expectLater(
      offline.availableIssues(),
      throwsA(isA<ArchiveNetworkException>()),
    );
    // Restart so tearDown has a server to close.
    await server.start();
  });

  test('a stalled download times out as a network error', () async {
    server.stall = Completer<void>();
    await expectLater(
      source.fetchIssue(9),
      throwsA(isA<ArchiveNetworkException>()),
    );
  });

  test('cancelling aborts an in-flight download', () async {
    server.stall = Completer<void>();
    final cancel = CancelToken();
    final future = source.fetchIssue(9, cancel: cancel);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    cancel.cancel();
    await expectLater(future, throwsA(isA<CancelledException>()));
  });

  group('parsers', () {
    test('meta refresh target', () {
      expect(
        parseMetaRefresh(
          '<meta http-equiv="refresh" content="0; url=/issues/1/x.html">',
        ),
        '/issues/1/x.html',
      );
      expect(parseMetaRefresh('<p>no refresh</p>'), isNull);
    });

    test('release dates ignore unrelated text', () {
      expect(parseReleaseDates('Issue X (soon) Issue 3 (1986-02-01)'), {
        3: DateTime.utc(1986, 2, 1),
      });
    });
  });
}
