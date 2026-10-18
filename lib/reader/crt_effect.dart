import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'frame_stats.dart';
import 'reader_settings.dart';

/// Why the CRT effect is not drawn, or null when it is.
enum CrtBlock {
  /// The reader has not turned it on.
  off,

  /// Needs Impeller (`ImageFilter.shader`); older Android falls back to Skia.
  unsupported,

  /// Reduced motion, reduced transparency or high contrast is on.
  accessibility,

  /// It cost this device its frame rate, so it switched itself off.
  tooSlow,
}

CrtBlock? crtBlock({
  required ReaderSettings settings,
  required bool supported,
  required bool accessibility,
}) {
  if (!settings.crt) {
    return settings.crtTooSlow ? CrtBlock.tooSlow : CrtBlock.off;
  }
  if (!supported) return CrtBlock.unsupported;
  if (accessibility) return CrtBlock.accessibility;
  return null;
}

/// The accessibility settings that switch the effect off. Scanlines and
/// tint lower contrast, and a moving texture is motion.
bool crtAccessibilityBlocks(
  BuildContext context, {
  required bool reduceTransparency,
}) {
  final features = View.of(context).platformDispatcher.accessibilityFeatures;
  return MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.highContrastOf(context) ||
      features.reduceMotion ||
      reduceTransparency;
}

/// Decides, from raster times, whether this device keeps up with the
/// effect: in each window of [window] frames, more than [slowShare] of
/// them over [budget] means no.
///
/// Spec Stage J: the effect ships disabled on devices that fail a quick
/// benchmark. This is that benchmark, run on the device while the effect is
/// first used, instead of a guess from a model list.
class FrameBudgetGuard {
  FrameBudgetGuard({
    required this.budget,
    this.window = 120,
    this.slowShare = 0.25,
  });

  final Duration budget;
  final int window;
  final double slowShare;

  int _frames = 0;
  int _slow = 0;

  /// Adds one frame's raster time; true once a window has failed.
  bool add(Duration raster) {
    _frames++;
    if (raster > budget) _slow++;
    if (_frames < window) return false;
    final failed = _slow > window * slowShare;
    _frames = 0;
    _slow = 0;
    return failed;
  }
}

/// The compiled shader, or null where `ImageFilter.shader` is unavailable.
final crtProgramProvider = FutureProvider<ui.FragmentProgram?>((ref) async {
  if (!ui.ImageFilter.isShaderFilterSupported) return null;
  try {
    return await ui.FragmentProgram.fromAsset('shaders/crt.frag');
  } on Object catch (e) {
    developer.log('CRT shader unavailable: $e', name: 'atdt.crt');
    return null;
  }
});

/// iOS Reduce Transparency, which Flutter does not report. Re-read when
/// the app returns to the foreground; Android has no such setting.
class ReduceTransparencyNotifier extends Notifier<bool> {
  static const _channel = MethodChannel('org.prouse.atdt/accessibility');

  @override
  bool build() {
    final listener = AppLifecycleListener(onResume: _query);
    ref.onDispose(listener.dispose);
    unawaited(_query());
    return false;
  }

  Future<void> _query() async {
    try {
      final on = await _channel.invokeMethod<bool>('reduceTransparency');
      if (ref.mounted) state = on ?? false;
    } on MissingPluginException {
      // Android, tests: no such setting.
    } on PlatformException catch (e) {
      developer.log('reduce transparency: $e', name: 'atdt.crt');
    }
  }
}

final reduceTransparencyProvider =
    NotifierProvider<ReduceTransparencyNotifier, bool>(
      ReduceTransparencyNotifier.new,
    );

/// The CRT effect over [child] (the reader, never the chrome), tinted with
/// [tint].
class CrtEffect extends ConsumerStatefulWidget {
  const CrtEffect({
    required this.child,
    required this.tint,
    this.guardFrames = kProfileMode || kReleaseMode,
    super.key,
  });

  final Widget child;
  final Color tint;

  /// Watch frame times and switch the effect off if the device cannot keep
  /// up. Off in debug builds, which are always slow.
  final bool guardFrames;

  @override
  ConsumerState<CrtEffect> createState() => CrtEffectState();
}

class CrtEffectState extends ConsumerState<CrtEffect> {
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  FrameBudgetGuard? _guard;

  @override
  void dispose() {
    _stopGuard();
    _shader?.dispose();
    super.dispose();
  }

  // Judged against 60 fps, not the display's rate: a 120 Hz phone that
  // holds 60 fps with the effect meets the spec and keeps it.
  void _startGuard() {
    if (!widget.guardFrames || _guard != null) return;
    _guard = FrameBudgetGuard(budget: sixtyFpsBudget);
    SchedulerBinding.instance.addTimingsCallback(onTimings);
  }

  void _stopGuard() {
    if (_guard == null) return;
    SchedulerBinding.instance.removeTimingsCallback(onTimings);
    _guard = null;
  }

  /// Raster times from the engine (public for tests).
  void onTimings(List<ui.FrameTiming> timings) {
    final guard = _guard;
    if (guard == null || !mounted) return;
    for (final t in timings) {
      if (guard.add(t.rasterDuration)) {
        _stopGuard();
        ref.read(readerSettingsProvider.notifier).markCrtTooSlow();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'CRT effect turned off: this device could not keep up with it.',
            ),
          ),
        );
        return;
      }
    }
  }

  ui.FragmentShader _shaderFor(ui.FragmentProgram program) {
    if (!identical(program, _program)) {
      _shader?.dispose();
      _program = program;
      _shader = program.fragmentShader();
    }
    return _shader!;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final program = ref.watch(crtProgramProvider).value;
    final block = crtBlock(
      settings: settings,
      supported: program != null,
      accessibility: crtAccessibilityBlocks(
        context,
        reduceTransparency: ref.watch(reduceTransparencyProvider),
      ),
    );
    if (block != null) {
      _stopGuard();
      return widget.child;
    }
    _startGuard();

    // Uniforms after u_size (0-1, set by the engine): intensity, tint, dpr.
    final shader = _shaderFor(program!)
      ..setFloat(2, settings.crtIntensity)
      ..setFloat(3, widget.tint.r)
      ..setFloat(4, widget.tint.g)
      ..setFloat(5, widget.tint.b)
      ..setFloat(6, MediaQuery.devicePixelRatioOf(context));
    return ImageFiltered(
      key: const ValueKey('crt'),
      imageFilter: ui.ImageFilter.shader(shader),
      child: widget.child,
    );
  }
}
