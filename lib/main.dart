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
  // The optional path isolates native verification from the installed library.
  const storage = String.fromEnvironment('CINEVAULT_QA_STORAGE');
  Future<void> initializeHive() =>
      hiveStart ??= Hive.initFlutter(storage.isEmpty ? null : storage);
  final performance = AppPerformance();
  final catalogue = CatalogueRepository(
    TmdbTransport(
      credential: () async => const String.fromEnvironment('TMDB_API_KEY'),
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
