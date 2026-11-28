import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:provider/provider.dart';

import '../catalogue/artwork_policy.dart';
import '../core/material.dart';
import '../core/performance.dart';
import 'design_system.dart';

Widget sharedArt(BuildContext context, String? tag, Widget child) {
  if (tag == null || MediaQuery.disableAnimationsOf(context)) return child;
  return Hero(
    tag: tag,
    transitionOnUserGestures: true,
    flightShuttleBuilder: (_, _, direction, from, to) =>
        ((direction == HeroFlightDirection.push ? from : to).widget as Hero)
            .child,
    child: child,
  );
}

class CineArt extends StatelessWidget {
  const CineArt({
    required this.path,
    this.kind = ArtworkKind.poster,
    this.alignment = Alignment.center,
    this.fit = BoxFit.cover,
    this.onReady,
    this.onPalette,
    super.key,
  });

  final String? path;
  final ArtworkKind kind;
  final Alignment alignment;
  final BoxFit fit;
  final VoidCallback? onReady;
  final ValueChanged<Color>? onPalette;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    if (path == null || path.isEmpty) return _fallback;
    context.read<ArtworkPolicy>().loadConfiguration();
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.hasBoundedWidth ? box.maxWidth : 180.0;
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final provider = context.select<ArtworkPolicy, ImageProvider<Object>>(
          (policy) => policy.provider(path, kind, width, ratio),
        );
        return _ProgressiveArt(
          key: ValueKey(provider),
          provider: provider,
          kind: kind,
          alignment: alignment,
          fit: fit,
          onReady: onReady,
          onPalette: onPalette,
        );
      },
    );
  }

  static const _fallback = ColoredBox(
    color: elevated,
    child: Center(
      child: ExcludeSemantics(
        child: Icon(Icons.movie_creation_outlined, color: muted, size: 26),
      ),
    ),
  );
}

class _ProgressiveArt extends StatefulWidget {
  const _ProgressiveArt({
    required this.provider,
    required this.kind,
    required this.alignment,
    required this.fit,
    required this.onReady,
    required this.onPalette,
    super.key,
  });

  final ImageProvider<Object> provider;
  final ArtworkKind kind;
  final Alignment alignment;
  final BoxFit fit;
  final VoidCallback? onReady;
  final ValueChanged<Color>? onPalette;

  @override
  State<_ProgressiveArt> createState() => _ProgressiveArtState();
}

class _ProgressiveArtState extends State<_ProgressiveArt> {
  Stopwatch? _elapsed;
  bool _seen = false;
  ImageStream? _paletteStream;
  ImageStreamListener? _paletteListener;
  bool _sampling = false;
  static final _palettes = <ImageProvider<Object>, Color>{};

  @override
  void initState() {
    super.initState();
    if (context.read<AppPerformance>().collecting) {
      _elapsed = Stopwatch()..start();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.onPalette == null || _sampling) return;
    _sampling = true;
    if (_palettes[widget.provider] case final color?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPalette?.call(color);
      });
      return;
    }
    _paletteStream = widget.provider.resolve(
      createLocalImageConfiguration(context),
    );
    _paletteListener = ImageStreamListener((info, _) {
      _detach();
      _readPalette(info);
    }, onError: (_, _) => _detach());
    _paletteStream!.addListener(_paletteListener!);
  }

  void _detach() {
    if (_paletteListener case final listener?) {
      _paletteStream?.removeListener(listener);
    }
    _paletteListener = null;
    _paletteStream = null;
  }

  Future<void> _readPalette(ImageInfo info) async {
    const size = 20;
    try {
      final source = info.image;
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        source,
        Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
        const Rect.fromLTWH(0, 0, 20, 20),
        ui.Paint()..filterQuality = FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      final ui.Image small;
      try {
        small = await picture.toImage(size, size);
      } finally {
        picture.dispose();
      }
      final ByteData? bytes;
      try {
        bytes = await small.toByteData();
      } finally {
        small.dispose();
      }
      if (bytes == null || !mounted) return;
      final scores = List<double>.filled(12, 0);
      final data = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      for (var i = 0; i < data.length; i += 4) {
        if (data[i + 3] < 160) continue;
        final hsl = HSLColor.fromColor(
          Color.fromARGB(255, data[i], data[i + 1], data[i + 2]),
        );
        if (hsl.saturation < .2 || hsl.lightness < .10 || hsl.lightness > .88) {
          continue;
        }
        scores[(hsl.hue / 30).floor().clamp(0, 11)] +=
            hsl.saturation * (.25 + hsl.lightness);
      }
      var winner = 0;
      for (var i = 1; i < scores.length; i++) {
        if (scores[i] > scores[winner]) winner = i;
      }
      if (scores[winner] < 2) return;
      final color = HSLColor.fromAHSL(1, winner * 30 + 15, .57, .48).toColor();
      if (_palettes.length >= 32) _palettes.remove(_palettes.keys.first);
      _palettes[widget.provider] = color;
      widget.onPalette?.call(color);
    } catch (_) {
      // Keep the default tone if a renderer cannot read an image's pixels.
    } finally {
      info.dispose();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Image(
    image: widget.provider,
    fit: widget.fit,
    alignment: widget.alignment,
    gaplessPlayback: true,
    filterQuality: FilterQuality.low,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => CineArt._fallback,
    frameBuilder: (context, child, frame, synchronous) {
      if (frame != null && !_seen) {
        _seen = true;
        if (_elapsed != null || widget.onReady != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_elapsed case final elapsed?) {
              elapsed.stop();
              context.read<AppPerformance>().record(
                PerfSample(
                  PerfEvent.artworkReady,
                  elapsed.elapsed,
                  area: widget.kind.area,
                  outcome: PerfOutcome.success,
                ),
              );
            }
            widget.onReady?.call();
          });
        }
      }
      if (synchronous ||
          widget.kind != ArtworkKind.backdrop ||
          MediaQuery.disableAnimationsOf(context)) {
        return frame == null ? const CineSkeleton(radius: 0) : child;
      }
      if (frame == null) {
        return const CineSkeleton(
          key: ValueKey('image-placeholder'),
          radius: 0,
        );
      }
      return _Reveal(child: child);
    },
  );
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: const Duration(milliseconds: 160),
    tween: Tween(begin: .7, end: 1),
    curve: Curves.easeOut,
    child: child,
    builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
  );
}
