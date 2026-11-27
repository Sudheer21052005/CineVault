import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/application.dart';
import 'catalogue/catalogue_repository.dart';
import 'core/material.dart';
import 'core/network/tmdb_transport.dart';
import 'core/performance.dart';
import 'library/hive_library_store.dart';
import 'library/library_repository.dart';
import 'providers/watchlist_provider.dart';

void main() {
  final startup = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  final performance = AppPerformance();
  final catalogue = CatalogueRepository(
    TmdbTransport(credential: _credential(), performance: performance),
  );
  final watchlist = WatchlistProvider(
    LibraryRepository(HiveLibraryStore()),
    performance,
  );
  runApp(
    CineVaultApp(
      catalogue: catalogue,
      watchlist: watchlist,
      performance: performance,
      startupWatch: startup,
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
