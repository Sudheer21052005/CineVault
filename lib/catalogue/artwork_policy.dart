import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../core/network/tmdb_transport.dart';
import '../core/performance.dart';

enum ArtworkKind {
  poster('poster_sizes', PerfArea.poster, [92, 154, 185, 342, 500, 780]),
  backdrop('backdrop_sizes', PerfArea.backdrop, [300, 780, 1280]),
  profile('profile_sizes', PerfArea.poster, [45, 185]),
  still('still_sizes', PerfArea.backdrop, [92, 185, 300]);

  const ArtworkKind(this.field, this.area, this.fallback);
  final String field;
  final PerfArea area;
  final List<int> fallback;
}

class ArtworkPolicy extends ChangeNotifier {
  ArtworkPolicy(this._transport);

  final TmdbTransport _transport;
  static const _defaultBase = 'https://image.tmdb.org/t/p/';
  String _base = _defaultBase;
  Map<ArtworkKind, List<int>> _sizes = const {};
  Future<void>? _loading;
  bool _disposed = false;

  void loadConfiguration() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final config = await _transport.get(
        '/configuration',
        operation: PerfArea.configuration,
        ttl: const Duration(days: 7),
      );
      final images = config['images'];
      if (images is! Map<String, dynamic> || _disposed) return;
      if (images['secure_base_url'] case final String base) {
        final uri = Uri.tryParse(base);
        if (uri != null &&
            uri.scheme == 'https' &&
            uri.host == 'image.tmdb.org') {
          _base = base.endsWith('/') ? base : '$base/';
        }
      }
      _sizes = {
        for (final kind in ArtworkKind.values)
          if (images[kind.field] case final List<dynamic> values)
            kind: <int>[
              for (final value in values.whereType<String>())
                if (value.startsWith('w'))
                  if (int.tryParse(value.substring(1)) case final int width
                      when width > 0)
                    width,
            ]..sort(),
      };
      notifyListeners();
    } catch (_) {
      // Known safe variants remain available when configuration is offline.
    }
  }

  int width(ArtworkKind kind, double logicalWidth, double ratio) {
    final source = _sizes[kind];
    final sizes = source == null || source.isEmpty ? kind.fallback : source;
    final wanted = (logicalWidth * ratio.clamp(1, 2)).ceil();
    return sizes.firstWhere((size) => size >= wanted, orElse: () => sizes.last);
  }

  ImageProvider<Object> provider(
    String path,
    ArtworkKind kind,
    double logicalWidth,
    double ratio,
  ) {
    final variant = width(kind, logicalWidth, ratio);
    final image = NetworkImage(
      '${_base}w$variant${path.startsWith('/') ? path : '/$path'}',
    );
    if (kIsWeb) return image;
    // Bucket decoded sizes with the CDN variant so equal artwork shares cache keys.
    final decodeWidth = math.min(
      variant,
      kind == ArtworkKind.backdrop ? 1280 : 780,
    );
    return ResizeImage.resizeIfNeeded(decodeWidth, null, image);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
