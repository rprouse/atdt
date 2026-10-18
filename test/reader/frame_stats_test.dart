import 'package:atdt/reader/frame_stats.dart';
import 'package:flutter_test/flutter_test.dart';

Duration _ms(num ms) => Duration(microseconds: (ms * 1000).round());

void main() {
  test('p90 and dropped frames over the recent window', () {
    final stats = FrameStats(budget: _ms(16.7), window: 10);
    for (var i = 1; i <= 10; i++) {
      stats.add(build: _ms(i), raster: _ms(i * 2));
    }
    expect(stats.frames, 10);
    expect(stats.buildP90, _ms(9));
    expect(stats.rasterP90, _ms(18));
    // Rasters of 18 and 20 ms miss a 16.7 ms budget.
    expect(stats.overBudget, 2);
  });

  test('only the last window counts', () {
    final stats = FrameStats(budget: _ms(16.7), window: 4);
    for (var i = 0; i < 4; i++) {
      stats.add(build: _ms(1), raster: _ms(40));
    }
    for (var i = 0; i < 4; i++) {
      stats.add(build: _ms(1), raster: _ms(5));
    }
    expect((stats.frames, stats.overBudget), (4, 0));
    expect(stats.rasterP90, _ms(5));
  });

  test('a slow build drops a frame as surely as a slow raster', () {
    final stats = FrameStats(budget: _ms(16.7))
      ..add(build: _ms(30), raster: _ms(2));
    expect(stats.overBudget, 1);
  });

  test('empty until something is drawn', () {
    final stats = FrameStats(budget: _ms(16.7));
    expect(
      (stats.frames, stats.buildP90, stats.overBudget),
      (0, Duration.zero, 0),
    );
  });
}
