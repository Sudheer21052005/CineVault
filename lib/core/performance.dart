import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' show FramePhase;

import 'package:flutter/scheduler.dart';

import 'performance_marks_stub.dart'
    if (dart.library.js_interop) 'performance_marks_web.dart';

enum PerfEvent {
  startupFirstFrame,
  startupShell,
  libraryOpen,
  searchInput,
  searchResults,
  searchDiscovery,
  navigation,
  scroll,
  scrollFrames,
  tmdbRequest,
  tmdbCacheHit,
  tmdbDiskHit,
  tmdbJoined,
  artworkReady,
}

enum PerfArea {
  home,
  nowPlaying,
  tv,
  search,
  library,
  stats,
  browse,
  title,
  entity,
  configuration,
  popular,
  trending,
  discover,
  tvFeed,
  textSearch,
  titleDetails,
  similar,
  recommendations,
  genres,
  releaseFeed,
  discoverHub,
  movies,
  poster,
  backdrop,
}

enum PerfOutcome { success, failure, cancelled }

/// Fixed fields only. No URL, query text, titles, IDs or user data.
class PerfSample {
  const PerfSample(
    this.event,
    this.elapsed, {
    this.area,
    this.outcome,
    this.bytes,
    this.attempts,
    this.frames,
    this.slowFrames,
    this.buildP95Us,
    this.rasterP95Us,
  });

  final PerfEvent event;
  final Duration elapsed;
  final PerfArea? area;
  final PerfOutcome? outcome;
  final int? bytes;
  final int? attempts;
  final int? frames;
  final int? slowFrames;
  final int? buildP95Us;
  final int? rasterP95Us;

  Map<String, Object> get fields => {
    'event': event.name,
    'elapsed_us': elapsed.inMicroseconds,
    if (area != null) 'area': area!.name,
    if (outcome != null) 'outcome': outcome!.name,
    'bytes': ?bytes,
    'attempts': ?attempts,
    'frames': ?frames,
    'slow_frames': ?slowFrames,
    'build_p95_us': ?buildP95Us,
    'raster_p95_us': ?rasterP95Us,
  };
}

class AppPerformance {
  AppPerformance({this._sink});

  static const enabled = bool.fromEnvironment('CINEVAULT_PERF');
  final void Function(PerfSample)? _sink;
  bool get collecting => enabled || _sink != null;

  void record(PerfSample sample) {
    _sink?.call(sample);
    if (enabled) {
      final name = 'cinevault.${sample.event.name}';
      final fields = sample.fields;
      developer.Timeline.instantSync(name, arguments: fields);
      markBrowserPerformance(name, fields);
    }
  }
}

/// Measures a scroll interaction and counts timed frames over a 60 Hz budget.
/// Flutter Web may supply no FrameTiming callbacks. In that case the interaction
/// span is still emitted and frame counts remain absent.
class ScrollProbe {
  ScrollProbe(this.performance);

  final AppPerformance performance;
  Stopwatch? _watch;
  PerfArea? _area;
  final _build = <int>[];
  final _raster = <int>[];
  int _slow = 0;
  int? _beginUs;
  int? _endUs;
  Timer? _flushTimer;
  bool _listening = false;

  void start(PerfArea area) {
    if (!performance.collecting) return;
    _flush();
    _area = area;
    _beginUs = developer.Timeline.now;
    _watch = Stopwatch()..start();
    if (!_listening) {
      SchedulerBinding.instance.addTimingsCallback(_onFrames);
      _listening = true;
    }
  }

  void end() {
    final watch = _watch;
    if (watch == null || !watch.isRunning) return;
    watch.stop();
    _endUs = developer.Timeline.now;
    performance.record(
      PerfSample(PerfEvent.scroll, watch.elapsed, area: _area),
    );
    // The engine batches native FrameTiming reports, including after scroll end.
    _flushTimer = Timer(const Duration(milliseconds: 1100), _flush);
  }

  void _onFrames(List<FrameTiming> timings) {
    for (final frame in timings) {
      final start = frame.timestampInMicroseconds(FramePhase.buildStart);
      if (start < (_beginUs ?? 0) || start > (_endUs ?? start)) continue;
      if (_build.length >= 2400) break;
      final build = frame.buildDuration.inMicroseconds;
      final raster = frame.rasterDuration.inMicroseconds;
      _build.add(build);
      _raster.add(raster);
      if (build > 16667 || raster > 16667) _slow++;
    }
  }

  void _flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final watch = _watch;
    if (watch != null && _build.isNotEmpty) {
      _build.sort();
      _raster.sort();
      final index = (_build.length * .95).ceil() - 1;
      performance.record(
        PerfSample(
          PerfEvent.scrollFrames,
          watch.elapsed,
          area: _area,
          frames: _build.length,
          slowFrames: _slow,
          buildP95Us: _build[index],
          rasterP95Us: _raster[index],
        ),
      );
    }
    _watch = null;
    _beginUs = null;
    _endUs = null;
    _build.clear();
    _raster.clear();
    _slow = 0;
    if (_listening) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrames);
      _listening = false;
    }
  }

  void dispose() => _flush();
}
