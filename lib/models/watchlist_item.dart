import 'package:hive/hive.dart';

enum WatchStatus { planToWatch, watching, watched }

WatchStatus watchStatusFromString(String value) => WatchStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => WatchStatus.planToWatch,
    );

class WatchlistItem {
  WatchlistItem({
    required this.id,
    required this.type,
    required this.title,
    this.posterPath,
    this.rating = 0,
    this.status = WatchStatus.planToWatch,
    this.userRating,
    this.notes = '',
    this.review = '',
    this.genres = const [],
    this.dateWatched,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  final int id;
  final String type;
  final String title;
  final String? posterPath;
  final double rating;
  WatchStatus status;
  double? userRating;
  String notes;
  String review;
  final List<String> genres;
  DateTime? dateWatched;
  final DateTime addedAt;

  String get key => '$type-$id';
}

class WatchlistItemAdapter extends TypeAdapter<WatchlistItem> {
  @override
  final int typeId = 1;

  @override
  WatchlistItem read(BinaryReader reader) {
    final id = reader.readInt();
    final type = reader.readString();
    final title = reader.readString();
    final posterPath = reader.readString();
    final rating = reader.readDouble();
    final status = reader.readString();
    final userRating = reader.read();
    final notes = reader.readString();
    final addedAt = reader.readInt();
    var review = '';
    var genres = <String>[];
    DateTime? dateWatched;
    if (reader.availableBytes > 0) review = reader.readString();
    if (reader.availableBytes > 0) {
      final rawGenres = reader.read();
      if (rawGenres is List) genres = rawGenres.whereType<String>().toList();
    }
    if (reader.availableBytes > 0) {
      final watchedAt = reader.read();
      if (watchedAt is int) dateWatched = DateTime.fromMillisecondsSinceEpoch(watchedAt);
    }
    return WatchlistItem(
      id: id,
      type: type,
      title: title,
      posterPath: posterPath.isEmpty ? null : posterPath,
      rating: rating,
      status: watchStatusFromString(status),
      userRating: (userRating as num?)?.toDouble(),
      notes: notes,
      addedAt: DateTime.fromMillisecondsSinceEpoch(addedAt),
      review: review,
      genres: genres,
      dateWatched: dateWatched,
    );
  }

  @override
  void write(BinaryWriter writer, WatchlistItem item) {
    writer
      ..writeInt(item.id)
      ..writeString(item.type)
      ..writeString(item.title)
      ..writeString(item.posterPath ?? '')
      ..writeDouble(item.rating)
      ..writeString(item.status.name)
      ..write(item.userRating)
      ..writeString(item.notes)
      ..writeInt(item.addedAt.millisecondsSinceEpoch)
      ..writeString(item.review)
      ..write(item.genres)
      ..write(item.dateWatched?.millisecondsSinceEpoch);
  }
}
