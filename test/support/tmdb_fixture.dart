import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class TmdbFixture {
  final data = jsonDecode(
    File('test/fixtures/tmdb_catalogue.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final paths = <String>[];

  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    paths.add(path);
    final movies = (data['movies'] as List)
        .whereType<Map<String, dynamic>>()
        .toList();
    final tv = (data['tv'] as List).whereType<Map<String, dynamic>>().toList();
    final entities = [...movies, ...tv];
    final parts = request.url.pathSegments;
    if (parts.length > 2 && parts[1] == 'genre') {
      return _json({'genres': data['genres'][parts[2]]});
    }
    if (path.endsWith('/similar')) {
      return _page(
        parts[1] == 'tv'
            ? []
            : movies.where((item) => '${item['id']}' != parts[2]).take(1),
      );
    }
    if (path.endsWith('/recommendations')) return _page(movies.skip(2));
    if (parts.length == 3 && int.tryParse(parts[2]) != null) {
      final match = entities
          .where(
            (entity) =>
                '${entity['id']}' == parts[2] &&
                entity['media_type'] == parts[1],
          )
          .firstOrNull;
      return match == null ? http.Response('{}', 404) : _json(match);
    }
    if (parts.length > 2 && parts[1] == 'search') {
      final query = request.url.queryParameters['query']!.toLowerCase();
      return _page(
        entities.where((entity) {
          final name = (entity['title'] ?? entity['name']) as String;
          return (parts[2] == 'multi' || parts[2] == entity['media_type']) &&
              name.toLowerCase().contains(query);
        }),
      );
    }
    return _page(path.contains('/tv') ? tv : movies);
  }

  http.Response _page(Iterable<Map<String, dynamic>> items) => _json({
    'page': 1,
    'total_pages': 1,
    'total_results': items.length,
    'results': items.toList(),
  });

  http.Response _json(Object data) => http.Response(
    jsonEncode(data),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
