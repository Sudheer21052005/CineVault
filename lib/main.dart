import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';

import 'app/application.dart';
import 'catalogue/catalogue_repository.dart';
import 'core/material.dart';
import 'core/network/tmdb_transport.dart';
import 'core/network/catalogue_cache.dart';
import 'core/performance.dart';
import 'library/hive_library_store.dart';
import 'library/library_repository.dart';
import 'library/personal_library.dart';
import 'providers/watchlist_provider.dart';

void main() {
  final startup = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache
    ..maximumSize = 180
    ..maximumSizeBytes = 64 * 1024 * 1024;
  Future<void>? hiveStart;
  Future<void> initializeHive() => hiveStart ??= Hive.initFlutter();
  final performance = AppPerformance();
  final catalogue = CatalogueRepository(
    TmdbTransport(
      credential: _credential(),
      performance: performance,
      durableCache: HiveCatalogueCache(
        initialize: initializeHive,
        maxBytes: (kIsWeb ? 15 : 40) * 1024 * 1024,
      ),
    ),
  );
  final watchlist = WatchlistProvider(
    LibraryRepository(HiveLibraryStore(initializeHive: initializeHive)),
    performance,
  );
  runApp(
    CineVaultApp(
      catalogue: catalogue,
      watchlist: watchlist,
      performance: performance,
      startupWatch: startup,
      personal: PersonalLibrary(HivePersonalStore(initialize: initializeHive)),
    ),
  );
}

Future<String> Function() _credential() {
  Future<String>? value;
  return () => value ??= _loadCredential();
}

Future<String> _loadCredential() async {
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
    return dotenv.env['TMDB_API_KEY'] ?? '';
  } catch (_) {
    return '';
  }
}
