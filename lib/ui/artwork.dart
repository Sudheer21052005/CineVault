import 'package:provider/provider.dart';

import '../catalogue/artwork_policy.dart';
import '../core/material.dart';
import '../core/performance.dart';
import 'design_system.dart';

class CineArt extends StatelessWidget {
  const CineArt({
    required this.path,
    this.kind = ArtworkKind.poster,
    this.alignment = Alignment.center,
    this.onReady,
    super.key,
  });

  final String? path;
  final ArtworkKind kind;
  final Alignment alignment;
  final VoidCallback? onReady;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    if (path == null || path.isEmpty) return _fallback;
    final policy = context.watch<ArtworkPolicy>();
    policy.loadConfiguration();
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.hasBoundedWidth ? box.maxWidth : 180.0;
        final provider = policy.provider(
          path,
          kind,
          width,
          MediaQuery.devicePixelRatioOf(context),
        );
        return _ProgressiveArt(
          key: ValueKey(provider),
          provider: provider,
          kind: kind,
          alignment: alignment,
          onReady: onReady,
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
    required this.onReady,
    super.key,
  });

  final ImageProvider<Object> provider;
  final ArtworkKind kind;
  final Alignment alignment;
  final VoidCallback? onReady;

  @override
  State<_ProgressiveArt> createState() => _ProgressiveArtState();
}

class _ProgressiveArtState extends State<_ProgressiveArt> {
  final _elapsed = Stopwatch()..start();
  bool _seen = false;

  @override
  Widget build(BuildContext context) => Image(
    image: widget.provider,
    fit: BoxFit.cover,
    alignment: widget.alignment,
    gaplessPlayback: true,
    filterQuality: FilterQuality.low,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => CineArt._fallback,
    frameBuilder: (context, child, frame, synchronous) {
      if (frame != null && !_seen) {
        _seen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _elapsed.stop();
          context.read<AppPerformance>().record(
            PerfSample(
              PerfEvent.artworkReady,
              _elapsed.elapsed,
              area: widget.kind.area,
              outcome: PerfOutcome.success,
            ),
          );
          widget.onReady?.call();
        });
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
