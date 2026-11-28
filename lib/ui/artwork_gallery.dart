import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../catalogue/artwork_policy.dart';
import '../catalogue/knowledge_models.dart';
import '../core/material.dart';
import 'artwork.dart';
import 'design_system.dart';

class Gallery extends StatelessWidget {
  const Gallery({
    required this.data,
    required this.groups,
    this.title,
    super.key,
  });
  final Json data;
  final List<(String, String, ArtworkKind)> groups;
  final String? title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (field, label, kind) in groups)
        _ArtworkGroup(
          source: data[field],
          label: label,
          kind: kind,
          title: title ?? label,
        ),
    ],
  );
}

class _ArtworkImage {
  const _ArtworkImage(this.path, this.kind);
  final String path;
  final ArtworkKind kind;
  static final _path = RegExp(
    r'^/[A-Za-z0-9_-]+\.(jpg|jpeg|png|webp)$',
    caseSensitive: false,
  );

  static _ArtworkImage? from(Json row, ArtworkKind kind) {
    final path = text(row['file_path']);
    return path != null && _path.hasMatch(path)
        ? _ArtworkImage(path, kind)
        : null;
  }

  Uri get original => Uri.https('image.tmdb.org', '/t/p/original$path');
  bool get wide => kind == ArtworkKind.backdrop || kind == ArtworkKind.still;
}

class _ArtworkGroup extends StatelessWidget {
  const _ArtworkGroup({
    required this.source,
    required this.label,
    required this.kind,
    required this.title,
  });
  final Object? source;
  final String label, title;
  final ArtworkKind kind;

  @override
  Widget build(BuildContext context) {
    final images = [
      for (final row in objects(source)) ?_ArtworkImage.from(row, kind),
    ];
    if (images.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          source is List
              ? 'TMDB lists no ${label.toLowerCase()}.'
              : '$label metadata is unavailable.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = images.first.wide;
          final columns = (box.maxWidth / (wide ? 195 : 137)).floor().clamp(
            2,
            6,
          );
          final width = (box.maxWidth - 10 * (columns - 1)) / columns;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(label, style: cineDisplay(23)),
                  Text('${images.length}', style: cineLabel(color: muted)),
                  if (images.length > columns * 2)
                    TextButton.icon(
                      onPressed: () => _openArtwork(
                        context,
                        images,
                        title,
                        label,
                        grid: true,
                      ),
                      icon: const Icon(Icons.grid_view_rounded, size: 17),
                      label: const Text('View all artwork'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (
                    var index = 0;
                    index < images.length && index < columns * 2;
                    index++
                  )
                    SizedBox(
                      width: width,
                      height: width * (wide ? .63 : 1.4),
                      child: _ArtworkTile(
                        label: 'View ${label.toLowerCase()} ${index + 1}',
                        image: images[index],
                        open: () => _openArtwork(
                          context,
                          images,
                          title,
                          label,
                          index: index,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

void openArtworkStill(
  BuildContext context,
  String path,
  String title,
  ArtworkKind kind,
) {
  final image = _ArtworkImage.from({'file_path': path}, kind);
  if (image != null) _openArtwork(context, [image], title, 'Artwork');
}

class _ArtworkTile extends StatelessWidget {
  const _ArtworkTile({
    required this.label,
    required this.image,
    required this.open,
    this.selected = false,
  });
  final String label;
  final _ArtworkImage image;
  final VoidCallback open;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    selected: selected,
    excludeSemantics: true,
    onTap: open,
    child: Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? blue : outline,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: CineArt(path: image.path, kind: image.kind),
          ),
        ),
      ),
    ),
  );
}

void _openArtwork(
  BuildContext context,
  List<_ArtworkImage> images,
  String title,
  String label, {
  int index = 0,
  bool grid = false,
}) {
  final duration = cineMotion(context, 220);
  showGeneralDialog<void>(
    context: context,
    barrierColor: const Color(0xFF080B11),
    transitionDuration: duration,
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (_, _, _) => _ArtworkViewer(
      images: images,
      title: title,
      label: label,
      initial: index,
      grid: grid,
    ),
  );
}

class _ArtworkViewer extends StatefulWidget {
  const _ArtworkViewer({
    required this.images,
    required this.title,
    required this.label,
    required this.initial,
    required this.grid,
  });
  final List<_ArtworkImage> images;
  final String title, label;
  final int initial;
  final bool grid;

  @override
  State<_ArtworkViewer> createState() => _ArtworkViewerState();
}

class _ArtworkViewerState extends State<_ArtworkViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  final _thumbs = ScrollController();
  final _activeArt = GlobalKey<_ZoomArtworkState>();
  late int _index = widget.initial;
  late bool _grid = widget.grid;
  bool _zoomed = false, _original = false, _saving = false;
  String? _message;

  @override
  void dispose() {
    _pages.dispose();
    _thumbs.dispose();
    super.dispose();
  }

  void _jump(int index) {
    if (_grid) {
      setState(() {
        _grid = false;
        _index = index;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(index);
        _centerThumbnail();
      });
      return;
    }
    if (!_pages.hasClients || index == _index) return;
    _activeArt.currentState?.reset();
    final duration = cineMotion(context, 240);
    if ((index - _index).abs() != 1 || duration == Duration.zero) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _step(int direction) =>
      _jump((_index + direction) % widget.images.length);

  void _centerThumbnail() {
    if (!_thumbs.hasClients) return;
    final position = _thumbs.position;
    final offset = ((_index + .5) * 86 - position.viewportDimension / 2).clamp(
      0.0,
      position.maxScrollExtent,
    );
    final duration = cineMotion(context, 190);
    if (duration == Duration.zero) {
      _thumbs.jumpTo(offset);
    } else {
      _thumbs.animateTo(offset, duration: duration, curve: Curves.easeOutCubic);
    }
  }

  void _changed(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      _zoomed = false;
      _original = false;
      _message = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centerThumbnail();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final image = widget.images[_index];
    final client = http.Client();
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      const limit = 32 * 1024 * 1024;
      final response = await client
          .send(http.Request('GET', image.original))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || (response.contentLength ?? 0) > limit) {
        throw const FormatException();
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 15),
      )) {
        if (builder.length + chunk.length > limit) {
          throw const FormatException();
        }
        builder.add(chunk);
      }
      if (!mounted) return;
      final file = image.path.substring(1);
      final extension = file.split('.').last.toLowerCase();
      final saved = await FilePicker.saveFile(
        fileName: 'cinevault-$file',
        mimeType: extension == 'jpg' ? 'image/jpeg' : 'image/$extension',
        bytes: builder.takeBytes(),
      );
      if (mounted && saved != null) _message = 'Artwork saved';
    } catch (_) {
      if (mounted) _message = 'Download failed. Try again.';
    } finally {
      client.close();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    final image = widget.images[_index];
    final hasMany = widget.images.length > 1;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
        if (hasMany && !_grid) ...{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _step(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _step(1),
        },
        const SingleActivator(LogicalKeyboardKey.equal): () =>
            _activeArt.currentState?.zoom(1.4),
        const SingleActivator(LogicalKeyboardKey.minus): () =>
            _activeArt.currentState?.zoom(1 / 1.4),
        const SingleActivator(LogicalKeyboardKey.digit0): () =>
            _activeArt.currentState?.reset(),
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: const Color(0xFF080B11),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
                  child: Row(
                    children: [
                      const CloseButton(),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: cineDisplay(compact ? 19 : 25),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _grid
                                    ? '${widget.images.length} · ${widget.label}'
                                    : '${_index + 1} of ${widget.images.length} · ${widget.label}',
                                style: cineLabel(color: muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasMany)
                        IconButton(
                          tooltip: _grid ? 'Image viewer' : 'Browse artwork',
                          onPressed: () {
                            if (_grid) {
                              _jump(_index);
                            } else {
                              setState(() {
                                _grid = true;
                                _zoomed = false;
                                _original = false;
                              });
                            }
                          },
                          icon: Icon(
                            _grid
                                ? Icons.crop_free_rounded
                                : Icons.grid_view_rounded,
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
                if (_grid)
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(14),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: image.wide ? 310 : 200,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: image.wide ? 16 / 10 : 2 / 3,
                      ),
                      itemCount: widget.images.length,
                      itemBuilder: (_, index) => _ArtworkTile(
                        label:
                            'View ${widget.label.toLowerCase()} ${index + 1}',
                        image: widget.images[index],
                        open: () => _jump(index),
                      ),
                    ),
                  )
                else ...[
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      physics: _zoomed
                          ? const NeverScrollableScrollPhysics()
                          : const PageScrollPhysics(),
                      onPageChanged: _changed,
                      itemCount: widget.images.length,
                      itemBuilder: (_, index) => _ZoomArtwork(
                        key: index == _index ? _activeArt : ValueKey(index),
                        image: widget.images[index],
                        original: _original && index == _index,
                        onZoom: (zoomed) {
                          if (index == _index && _zoomed != zoomed) {
                            setState(() => _zoomed = zoomed);
                          }
                        },
                      ),
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (hasMany)
                        IconButton(
                          tooltip: 'Previous image',
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () => _step(-1),
                        ),
                      IconButton(
                        tooltip: 'Zoom out',
                        icon: const Icon(Icons.zoom_out_rounded),
                        onPressed: () => _activeArt.currentState?.zoom(1 / 1.4),
                      ),
                      IconButton(
                        tooltip: 'Zoom in',
                        icon: const Icon(Icons.zoom_in_rounded),
                        onPressed: () => _activeArt.currentState?.zoom(1.4),
                      ),
                      IconButton(
                        tooltip: 'Fit image',
                        icon: const Icon(Icons.fit_screen_outlined),
                        onPressed: () => _activeArt.currentState?.reset(),
                      ),
                      IconButton(
                        tooltip: _original
                            ? 'Use standard resolution'
                            : 'Load original resolution',
                        isSelected: _original,
                        icon: const Icon(Icons.hd_outlined),
                        onPressed: () => setState(() => _original = !_original),
                      ),
                      IconButton(
                        tooltip: 'Download image',
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_rounded),
                        onPressed: _saving ? null : _save,
                      ),
                      if (hasMany)
                        IconButton(
                          tooltip: 'Next image',
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () => _step(1),
                        ),
                    ],
                  ),
                  if (_message case final message?)
                    Semantics(liveRegion: true, child: Text(message)),
                  if (hasMany)
                    SizedBox(
                      height: compact ? 61 : 72,
                      child: ListView.builder(
                        controller: _thumbs,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemExtent: 86,
                        itemCount: widget.images.length,
                        itemBuilder: (_, index) => Padding(
                          padding: const EdgeInsets.fromLTRB(3, 2, 3, 7),
                          child: _ArtworkTile(
                            label: 'Thumbnail ${index + 1}',
                            image: widget.images[index],
                            selected: index == _index,
                            open: () => _jump(index),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomArtwork extends StatefulWidget {
  const _ZoomArtwork({
    required this.image,
    required this.original,
    required this.onZoom,
    super.key,
  });
  final _ArtworkImage image;
  final bool original;
  final ValueChanged<bool> onZoom;

  @override
  State<_ZoomArtwork> createState() => _ZoomArtworkState();
}

class _ZoomArtworkState extends State<_ZoomArtwork> {
  final _transform = TransformationController();
  Size _size = Size.zero;
  Offset? _tap;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_changed);
  }

  void _changed() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      setState(() => _zoomed = zoomed);
      widget.onZoom(zoomed);
    }
  }

  void reset() => _transform.value = Matrix4.identity();

  void zoom(double factor, {Offset? around}) {
    final scale = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      1.0,
      5.0,
    );
    if (scale == 1) {
      reset();
      return;
    }
    final anchor = around ?? _size.center(Offset.zero);
    final point = _transform.toScene(anchor);
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(
        (anchor.dx - point.dx * scale).clamp(_size.width * (1 - scale), 0.0),
        (anchor.dy - point.dy * scale).clamp(_size.height * (1 - scale), 0.0),
        0,
      );
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
    child: LayoutBuilder(
      builder: (_, box) {
        _size = box.biggest;
        return GestureDetector(
          onDoubleTapDown: (details) => _tap = details.localPosition,
          onDoubleTap: () => _zoomed ? reset() : zoom(2.35, around: _tap),
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 5,
            panEnabled: _zoomed,
            child: SizedBox.expand(
              child: widget.original
                  ? Image.network(
                      widget.image.original.toString(),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const Center(
                        child: Text('Original artwork is unavailable.'),
                      ),
                      frameBuilder: (_, child, frame, sync) =>
                          frame != null || sync
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                    )
                  : CineArt(
                      path: widget.image.path,
                      kind: widget.image.kind,
                      fit: BoxFit.contain,
                    ),
            ),
          ),
        );
      },
    ),
  );
}
