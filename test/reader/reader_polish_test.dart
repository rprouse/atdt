// Stage G: position persistence, continue reading, progress, zoom, copy,
// volume paging and reader-scoped orientation.
import 'package:atdt/layout/reading_position.dart';
import 'package:atdt/library/issues_screen.dart';
import 'package:atdt/reader/reader_screen.dart';
import 'package:atdt/reader/reader_settings.dart';
import 'package:atdt/reader/reader_view.dart';
import 'package:atdt/reader/volume_keys.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/archive_harness.dart';
import '../helpers/reader_harness.dart';

const _portrait = Size(390, 844);
const _landscape = Size(844, 390);

class _Session {
  _Session(this.db);

  final ArchiveDatabase db;
  final platformCalls = <MethodCall>[];

  /// Every value sent to the native volume-key gate, in order.
  final volumeGate = <bool>[];
  late ProviderContainer container;
}

Future<_Session> _setUp(WidgetTester tester, {ArchiveDatabase? db}) async {
  setSurface(tester, _portrait);
  addTearDown(tester.view.reset);
  final session = _Session(db ?? memoryArchiveDatabase());
  if (db == null) addTearDown(session.db.close);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      session.platformCalls.add(call);
      return call.method == 'Clipboard.getData' ? <String, Object?>{} : null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    VolumeKeys.channel,
    (call) async {
      if (call.method == 'setEnabled') {
        session.volumeGate.add(call.arguments as bool);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      VolumeKeys.channel,
      null,
    ),
  );
  return session;
}

Future<void> _open(WidgetTester tester, _Session s, Widget home) async {
  s.container = ProviderContainer(overrides: archiveOverrides(database: s.db));
  addTearDown(s.container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: s.container,
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

ReaderViewState _reader(WidgetTester tester) =>
    tester.state<ReaderViewState>(find.byType(ReaderView));

void _scrollTo(WidgetTester tester, int line, double column) {
  final state = _reader(tester);
  final layout = state.layout!;
  state.verticalController!.jumpTo((line + 0.25) * layout.lineHeight);
  state.horizontalController!.jumpTo(column * layout.glyphAdvance);
}

void main() {
  setUpAll(loadReaderFonts);

  group('reading position', () {
    testWidgets('closing and reopening restores the exact line and column', (
      tester,
    ) async {
      final s = await _setUp(tester);
      final id = await seedPhile(s.db, 'ten_thousand_lines.txt', title: 'Big');
      await _open(tester, s, ReaderScreen(phileId: id));
      _scrollTo(tester, 4321, 17);
      await tester.pump();
      final before = _reader(tester).position;

      // Close the reader (saves on dispose), then open it again.
      await tester.pumpWidget(const SizedBox());
      expect(await s.db.readingPosition(id), before);
      await _open(tester, s, ReaderScreen(phileId: id));

      final after = _reader(tester).position;
      expect(after.topLineIndex, 4321);
      expect(after.fractionIntoLine, closeTo(0.25, 1e-6));
      expect(after.columnOffset, closeTo(17, 1e-6));
      expect(find.textContaining(RegExp('^04321 ')), findsOneWidget);
    });

    testWidgets('positions save shortly after scrolling stops', (tester) async {
      final s = await _setUp(tester);
      final id = await seedPhile(s.db, 'ten_thousand_lines.txt');
      await _open(tester, s, ReaderScreen(phileId: id));
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      final saved = await s.db.readingPosition(id);
      expect(saved, isNotNull);
      expect(saved!.topLineIndex, greaterThan(0));
    });

    testWidgets('continue reading returns to the last phile read', (
      tester,
    ) async {
      final s = await _setUp(tester);
      await seedLibrary(s.db);
      final id = (await s.db.phile(98, 7))!.id;
      await s.db.saveReadingPosition(
        id,
        const ReadingPosition(
          topLineIndex: 1,
          fractionIntoLine: 0,
          columnOffset: 0,
        ),
        at: DateTime.utc(2026),
      );
      await _open(tester, s, const IssuesScreen());

      final card = find.byKey(const ValueKey('continue-reading'));
      expect(card, findsOneWidget);
      expect(find.text('Phile title 7'), findsOneWidget);
      expect(
        find.textContaining('Continue reading · Issue 98'),
        findsOneWidget,
      );

      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(_reader(tester).position.topLineIndex, 1);
    });
  });

  testWidgets('the chrome shows how far through the phile the reader is', (
    tester,
  ) async {
    final s = await _setUp(tester);
    final id = await seedPhile(s.db, 'ten_thousand_lines.txt');
    await _open(tester, s, ReaderScreen(phileId: id));
    String progress() => tester
        .widget<Text>(find.byKey(const ValueKey('reader-progress')))
        .data!;

    expect(progress(), matches(RegExp(r'^\d%$')));
    _scrollTo(tester, 5000, 0);
    await tester.pump();
    await tester.pump();
    expect(progress(), anyOf('50%', '51%'));
  });

  group('zoom', () {
    testWidgets('zooming keeps the top line; scrolling keeps the zoom', (
      tester,
    ) async {
      final s = await _setUp(tester);
      final id = await seedPhile(s.db, 'ten_thousand_lines.txt');
      await _open(tester, s, ReaderScreen(phileId: id));
      _scrollTo(tester, 2000, 0);
      await tester.pump();
      final fitSize = _reader(tester).layout!.fontSize;

      _reader(tester).setZoom(2);
      await tester.pump();
      await tester.pump();
      expect(_reader(tester).layout!.fontSize, closeTo(fitSize * 2, 1e-6));
      expect(_reader(tester).position.topLineIndex, 2000);
      // Zoomed text is wider than the screen: sideways scrolling covers it.
      expect(
        _reader(tester).horizontalController!.position.maxScrollExtent,
        greaterThan(300),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(_reader(tester).zoom, 2);
    });

    testWidgets('rotation resets zoom to fit and holds the position', (
      tester,
    ) async {
      final s = await _setUp(tester);
      final id = await seedPhile(s.db, 'ten_thousand_lines.txt');
      await _open(tester, s, ReaderScreen(phileId: id));
      _scrollTo(tester, 3333, 0);
      await tester.pump();
      _reader(tester).setZoom(2.5);
      await tester.pump();
      await tester.pump();

      setSurface(tester, _landscape);
      await tester.pump();
      await tester.pump();

      expect(_reader(tester).zoom, 1);
      expect(_reader(tester).position.topLineIndex, 3333);
    });

    testWidgets('a two-finger pinch zooms in', (tester) async {
      final s = await _setUp(tester);
      final id = await seedPhile(s.db, 'ten_thousand_lines.txt');
      await _open(tester, s, ReaderScreen(phileId: id));

      final a = await tester.startGesture(const Offset(150, 400));
      final b = await tester.startGesture(const Offset(240, 400), pointer: 2);
      await tester.pump();
      await a.moveTo(const Offset(80, 400));
      await b.moveTo(const Offset(310, 400));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pumpAndSettle();

      // Spread from 90 to 230 logical pixels: about 2.56x.
      expect(_reader(tester).zoom, closeTo(230 / 90, 0.05));
    });
  });

  group('copy', () {
    testWidgets('long-press copies the exact block, leading spaces kept', (
      tester,
    ) async {
      final s = await _setUp(tester);
      final id = await seedPhile(s.db, 'tabs_code.txt');
      await _open(tester, s, ReaderScreen(phileId: id));
      // The first lines sit under the chrome; hide it to reach them.
      await tester.tapAt(const Offset(200, 600));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('        int i;'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('copy-bar')), findsOneWidget);
      expect(find.text('12 lines selected'), findsOneWidget);

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      final copied = s.platformCalls.lastWhere(
        (c) => c.method == 'Clipboard.setData',
      );
      final lines = fixture('tabs_code.txt').lines;
      expect(
        (copied.arguments as Map<Object?, Object?>)['text'],
        lines.sublist(2).join('\n'),
      );
      expect((copied.arguments as Map)['text'], startsWith('int main('));
      expect(find.byKey(const ValueKey('copy-bar')), findsNothing);
    });

    testWidgets('a tap clears the selection without copying', (tester) async {
      final s = await _setUp(tester);
      final id = await seedPhile(s.db, 'tabs_code.txt');
      await _open(tester, s, ReaderScreen(phileId: id));
      // The first lines sit under the chrome; hide it to reach them.
      await tester.tapAt(const Offset(200, 600));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('#include <stdio.h>'));
      await tester.pumpAndSettle();
      expect(find.text('1 line selected'), findsOneWidget);
      await tester.tapAt(const Offset(200, 600));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('copy-bar')), findsNothing);
      expect(
        s.platformCalls.where((c) => c.method == 'Clipboard.setData'),
        isEmpty,
      );
    });
  });

  group('volume buttons (Android)', () {
    // MainActivity consumes the keys while enabled and calls 'page'.
    Future<void> nativePage(WidgetTester tester, int direction) =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          VolumeKeys.channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('page', direction),
          ),
          (_) {},
        );

    testWidgets('the reader turns the native gate on and off', (tester) async {
      final s = await _setUp(tester);
      final id = await seedPhile(s.db, 'ten_thousand_lines.txt');
      await _open(tester, s, ReaderScreen(phileId: id));
      expect(s.volumeGate.last, isFalse, reason: 'off by default');

      s.container.read(readerSettingsProvider.notifier).setVolumePaging(true);
      await tester.pumpAndSettle();
      expect(s.volumeGate.last, isTrue);

      await tester.pumpWidget(const SizedBox());
      expect(s.volumeGate.last, isFalse, reason: 'released with the reader');
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a native page call pages, keeping one line', (tester) async {
      final s = await _setUp(tester);
      final id = await seedPhile(s.db, 'ten_thousand_lines.txt');
      await _open(tester, s, ReaderScreen(phileId: id));
      final layout = _reader(tester).layout!;
      double offset() => _reader(tester).verticalController!.offset;

      await nativePage(tester, 1);
      await tester.pumpAndSettle();
      expect(
        offset(),
        closeTo(844 - readerTopInset - layout.lineHeight, layout.lineHeight),
      );

      await nativePage(tester, -1);
      await tester.pumpAndSettle();
      expect(offset(), 0);
    });

    testWidgets('the gate stays off outside Android', (tester) async {
      final s = await _setUp(tester);
      final id = await seedPhile(s.db, 'ten_thousand_lines.txt');
      await _open(tester, s, ReaderScreen(phileId: id));
      s.container.read(readerSettingsProvider.notifier).setVolumePaging(true);
      await tester.pumpAndSettle();
      expect(s.volumeGate, everyElement(isFalse));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  testWidgets('the reader applies its orientation and releases it', (
    tester,
  ) async {
    final s = await _setUp(tester);
    final id = await seedPhile(s.db, 'ten_thousand_lines.txt');
    s.container = ProviderContainer(
      overrides: archiveOverrides(database: s.db),
    );
    addTearDown(s.container.dispose);
    s.container
        .read(readerSettingsProvider.notifier)
        .setOrientation(OrientationMode.landscape);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: s.container,
        child: MaterialApp(home: ReaderScreen(phileId: id)),
      ),
    );
    await tester.pumpAndSettle();
    List<Object?> lastOrientations() =>
        s.platformCalls
                .lastWhere(
                  (c) => c.method == 'SystemChrome.setPreferredOrientations',
                )
                .arguments
            as List<Object?>;

    expect(lastOrientations(), [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);

    await tester.pumpWidget(const SizedBox());
    expect(lastOrientations(), hasLength(4), reason: 'all orientations again');
  });
}
