import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../performance.dart';

enum TmdbErrorKind {
  configuration,
  unauthorized,
  notFound,
  rateLimited,
  offline,
  timeout,
  server,
  invalidResponse,
  rejected,
}

class TmdbException implements Exception {
  const TmdbException(this.kind, {this.statusCode, this.retryAfter});

  final TmdbErrorKind kind;
  final int? statusCode;
  final Duration? retryAfter;

  @override
  String toString() => switch (kind) {
    TmdbErrorKind.configuration =>
      'Add your TMDB API key to the local .env file.',
    TmdbErrorKind.unauthorized => 'TMDB rejected the configured credentials.',
    TmdbErrorKind.notFound => 'This title could not be found.',
    TmdbErrorKind.rateLimited => 'TMDB is busy. Please try again shortly.',
    TmdbErrorKind.offline =>
      'Unable to connect to TMDB. Check your connection and retry.',
    TmdbErrorKind.timeout => 'TMDB took too long to respond. Please retry.',
    TmdbErrorKind.server => 'TMDB is temporarily unavailable. Please retry.',
    TmdbErrorKind.invalidResponse => 'TMDB returned an unreadable response.',
    TmdbErrorKind.rejected => 'TMDB could not complete this request.',
  };
}

class TmdbTransport {
  TmdbTransport({
    required this._credential,
    required this._performance,
    http.Client? client,
    DateTime Function()? now,
    Future<void> Function(Duration)? sleep,
    double Function()? random,
    this.maxEntries = 150,
    this.maxBytes = 12 * 1024 * 1024,
    this.maxConcurrent = 4,
    this.requestTimeout = const Duration(seconds: 4),
    this.requestBudget = const Duration(seconds: 8),
  }) : assert(maxConcurrent > 0 && maxEntries > 0 && maxBytes > 0),
       _client = client ?? http.Client(),
       _now = now ?? DateTime.now,
       _sleep = sleep ?? Future<void>.delayed,
       _random = random ?? Random().nextDouble;

  final Future<String> Function() _credential;
  final AppPerformance _performance;
  final http.Client _client;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _sleep;
  final double Function() _random;
  final int maxEntries;
  final int maxBytes;
  final int maxConcurrent;
  final Duration requestTimeout;
  final Duration requestBudget;
  final _cache = <String, _CacheEntry>{};
  final _inFlight = <String, Future<Map<String, dynamic>>>{};
  final _queue = Queue<void Function()>();
  int _cacheBytes = 0;
  int _active = 0;
  DateTime? _cooldownUntil;

  Future<Map<String, dynamic>> get(
    String path, {
    required PerfArea operation,
    Map<String, String> query = const {},
    Duration ttl = const Duration(minutes: 15),
    bool refresh = false,
  }) {
    final parameters = SplayTreeMap<String, String>.of({
      'language': 'en-US',
      ...query,
    })..remove('api_key');
    final key = Uri(path: path, queryParameters: parameters).toString();
    final pending = _inFlight[key];
    if (pending != null) {
      _performance.record(
        PerfSample(PerfEvent.tmdbJoined, Duration.zero, area: operation),
      );
      return pending;
    }
    final cached = _cache.remove(key);
    if (cached != null) {
      if (_now().isBefore(cached.expires)) {
        _cache[key] = cached;
        if (!refresh) {
          _performance.record(
            PerfSample(
              PerfEvent.tmdbCacheHit,
              Duration.zero,
              area: operation,
              bytes: cached.bytes,
            ),
          );
          return Future.value(cached.data);
        }
      } else {
        _cacheBytes -= cached.bytes;
      }
    }

    final result = Completer<Map<String, dynamic>>();
    final watch = Stopwatch()..start();
    _inFlight[key] = result.future;
    _queue.add(() async {
      try {
        result.complete(
          await _fetch(path, parameters, key, operation, ttl, watch),
        );
      } catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        _inFlight.remove(key);
        _active--;
        _drain();
      }
    });
    _drain();
    return result.future;
  }

  void _drain() {
    while (_active < maxConcurrent && _queue.isNotEmpty) {
      _active++;
      _queue.removeFirst()();
    }
  }

  Future<Map<String, dynamic>> _fetch(
    String path,
    Map<String, String> parameters,
    String key,
    PerfArea operation,
    Duration ttl,
    Stopwatch watch,
  ) async {
    var attempts = 0;
    int? bytes;
    var outcome = PerfOutcome.failure;
    try {
      final credential = (await _credential()).trim();
      if (credential.isEmpty || credential == 'YOUR_TMDB_API_KEY') {
        throw const TmdbException(TmdbErrorKind.configuration);
      }
      final uri = Uri.https('api.themoviedb.org', '/3$path', {
        ...parameters,
        'api_key': credential,
      });
      for (;;) {
        final remaining = requestBudget - watch.elapsed;
        final cooldown = _cooldownUntil?.difference(_now()) ?? Duration.zero;
        if (cooldown > Duration.zero) {
          // Keep rate-limited requests queued behind one shared window.
          if (cooldown >= remaining) {
            throw TmdbException(
              TmdbErrorKind.rateLimited,
              retryAfter: cooldown,
            );
          }
          await _sleep(cooldown);
          // Production time advances during the wait. A test clock may advance
          // by exactly the requested duration.
          continue;
        }
        if (remaining <= Duration.zero) {
          throw const TmdbException(TmdbErrorKind.timeout);
        }
        attempts++;
        TmdbException failure;
        try {
          final timeout = remaining < requestTimeout
              ? remaining
              : requestTimeout;
          final response = await _send(uri, timeout);
          final status = response.statusCode;
          if (status >= 200 && status < 300) {
            bytes = response.bodyBytes.length;
            try {
              final data = jsonDecode(utf8.decode(response.bodyBytes));
              if (data is! Map<String, dynamic>) throw const FormatException();
              final frozen = Map<String, dynamic>.unmodifiable(data);
              _put(key, _CacheEntry(frozen, _now().add(ttl), bytes));
              outcome = PerfOutcome.success;
              return frozen;
            } on FormatException {
              throw const TmdbException(TmdbErrorKind.invalidResponse);
            }
          }
          final kind = switch (status) {
            401 || 403 => TmdbErrorKind.unauthorized,
            404 => TmdbErrorKind.notFound,
            429 => TmdbErrorKind.rateLimited,
            >= 500 => TmdbErrorKind.server,
            _ => TmdbErrorKind.rejected,
          };
          final retryAfter = status == 429
              ? _retryAfter(_retryAfterHeader(response.headers)) ??
                    _backoff(attempts)
              : null;
          if (retryAfter != null) {
            final until = _now().add(retryAfter);
            if (_cooldownUntil == null || until.isAfter(_cooldownUntil!)) {
              _cooldownUntil = until;
            }
          }
          failure = TmdbException(
            kind,
            statusCode: status,
            retryAfter: retryAfter,
          );
        } on TimeoutException {
          failure = const TmdbException(TmdbErrorKind.timeout);
        } on http.ClientException {
          // Client exceptions can carry the credential-bearing URI.
          failure = const TmdbException(TmdbErrorKind.offline);
        }
        final retryable = switch (failure.kind) {
          TmdbErrorKind.offline ||
          TmdbErrorKind.timeout ||
          TmdbErrorKind.rateLimited ||
          TmdbErrorKind.server => true,
          _ => false,
        };
        if (!retryable || attempts >= 3) throw failure;
        final delay = failure.retryAfter ?? _backoff(attempts);
        if (delay >= requestBudget - watch.elapsed) throw failure;
        if (failure.retryAfter == null) await _sleep(delay);
      }
    } finally {
      _performance.record(
        PerfSample(
          PerfEvent.tmdbRequest,
          watch.elapsed,
          area: operation,
          outcome: outcome,
          bytes: bytes,
          attempts: attempts,
        ),
      );
    }
  }

  Duration _backoff(int attempt) => Duration(
    milliseconds: (200 * (1 << (attempt - 1)) * (.75 + _random() * .5)).round(),
  );

  Future<http.Response> _send(Uri uri, Duration timeout) {
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'GET',
      uri,
      abortTrigger: abort.future,
    );
    return _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(
          timeout,
          onTimeout: () {
            abort.complete();
            throw TimeoutException('TMDB request timed out.');
          },
        );
  }

  String? _retryAfterHeader(Map<String, String> headers) => headers.entries
      .where((header) => header.key.toLowerCase() == 'retry-after')
      .firstOrNull
      ?.value;

  Duration? _retryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
    final match = RegExp(
      r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
    ).firstMatch(value);
    if (match == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months.indexOf(match[2]!);
    if (month < 0) return null;
    final date = DateTime.utc(
      int.parse(match[3]!),
      month + 1,
      int.parse(match[1]!),
      int.parse(match[4]!),
      int.parse(match[5]!),
      int.parse(match[6]!),
    );
    final delay = date.difference(_now());
    return delay.isNegative ? Duration.zero : delay;
  }

  void _put(String key, _CacheEntry entry) {
    _cacheBytes -= _cache.remove(key)?.bytes ?? 0;
    if (entry.bytes > maxBytes) return;
    _cache[key] = entry;
    _cacheBytes += entry.bytes;
    while (_cache.length > maxEntries || _cacheBytes > maxBytes) {
      _cacheBytes -= _cache.remove(_cache.keys.first)!.bytes;
    }
  }

  void close() => _client.close();
}

class _CacheEntry {
  const _CacheEntry(this.data, this.expires, this.bytes);

  final Map<String, dynamic> data;
  final DateTime expires;
  final int bytes;
}
