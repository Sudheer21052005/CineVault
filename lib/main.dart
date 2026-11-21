import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/watchlist_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  final watchlist = WatchlistProvider();
  await watchlist.initialize();
  runApp(ChangeNotifierProvider.value(value: watchlist, child: const CineVaultApp()));
}
