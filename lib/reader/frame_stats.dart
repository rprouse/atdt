/// One frame at 60 fps: the spec's target (Stage J), whatever the display's
/// refresh rate. A 120 Hz phone has 8.3 ms per refresh but still meets the
/// target at 16.7 ms.
const sixtyFpsBudget = Duration(microseconds: 16667);

/// Recent frame times, for the debug overlay's 60 fps check.
///
/// Frames are only produced while something changes, so the window always
/// describes the last scroll or zoom, not idle time.
class FrameStats {
  FrameStats({required this.budget, this.window = 60});

  /// Frames slower than this fall short of the target (normally
  /// [sixtyFpsBudget]).
  final Duration budget;
  final int window;

  final _build = <Duration>[];
  final _raster = <Duration>[];

  int get frames => _raster.length;

  void add({required Duration build, required Duration raster}) {
    _build.add(build);
    _raster.add(raster);
    if (_raster.length > window) {
      _build.removeAt(0);
      _raster.removeAt(0);
    }
  }

  Duration get buildP90 => _p90(_build);
  Duration get rasterP90 => _p90(_raster);

  /// Frames in the window where building or rasterising took longer than
  /// the budget: each one is a dropped frame.
  int get overBudget {
    var n = 0;
    for (var i = 0; i < _raster.length; i++) {
      if (_build[i] > budget || _raster[i] > budget) n++;
    }
    return n;
  }

  static Duration _p90(List<Duration> values) {
    if (values.isEmpty) return Duration.zero;
    final sorted = [...values]..sort();
    return sorted[((sorted.length - 1) * 0.9).round()];
  }
}
