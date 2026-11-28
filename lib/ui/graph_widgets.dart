import 'package:url_launcher/url_launcher.dart';

import '../app/navigation_scope.dart';
import '../app/route_contract.dart';
import '../catalogue/artwork_policy.dart';
import '../catalogue/entity_ref.dart';
import '../catalogue/knowledge_models.dart';
import '../core/material.dart';
import 'artwork.dart';
import 'artwork_gallery.dart';
import 'catalogue_widgets.dart';
import 'design_system.dart';

class GraphPanel extends StatelessWidget {
  const GraphPanel({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: surface,
      border: Border.all(color: outline),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class GraphHeader extends StatefulWidget {
  const GraphHeader({
    required this.title,
    required this.category,
    this.image,
    this.artKind = ArtworkKind.poster,
    this.subtitle,
    this.heroTag,
    this.actions = const [],
    super.key,
  });
  final String title;
  final String category;
  final String? image;
  final ArtworkKind artKind;
  final String? subtitle;
  final String? heroTag;
  final List<Widget> actions;

  @override
  State<GraphHeader> createState() => _GraphHeaderState();
}

class _GraphHeaderState extends State<GraphHeader> {
  final _tone = ValueNotifier<Color>(const Color(0xFF344D73));

  @override
  void dispose() {
    _tone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (CineLayout.widthOf(context) == CineWidth.compact)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: BackButton(
            onPressed: () => CineNavigation.of(context).back(context),
          ),
        ),
      ValueListenableBuilder<Color>(
        valueListenable: _tone,
        builder: (context, tone, child) => AnimatedContainer(
          duration: cineMotion(context, 280),
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: outline),
            gradient: LinearGradient(
              colors: [
                Color.alphaBlend(tone.withValues(alpha: .30), surface),
                surface,
              ],
            ),
          ),
          child: child,
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final artKind = widget.artKind;
            final image = widget.image;
            final logo = artKind == ArtworkKind.logo;
            final landscape = artKind == ArtworkKind.still;
            final compact = box.maxWidth < 490;
            final width = landscape
                ? (compact ? box.maxWidth : 305.0)
                : (compact ? 86.0 : 132.0);
            final artwork = SizedBox(
              width: width,
              height: width * (landscape || logo ? 9 / 16 : 1.38),
              child: sharedArt(
                context,
                widget.heroTag,
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CineArt(
                    path: image,
                    kind: artKind,
                    fit: logo ? BoxFit.contain : BoxFit.cover,
                    onPalette: (color) => _tone.value = color,
                  ),
                ),
              ),
            );
            final cover = image != null && !logo
                ? Semantics(
                    button: true,
                    label: 'View ${widget.title} artwork',
                    child: GestureDetector(
                      onTap: () => openArtworkStill(
                        context,
                        image,
                        widget.title,
                        artKind,
                      ),
                      child: artwork,
                    ),
                  )
                : artwork;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category.toUpperCase(),
                  style: cineLabel(color: gold),
                ),
                const SizedBox(height: 7),
                Text(widget.title, style: cineDisplay(compact ? 30 : 45)),
                if (widget.subtitle case final subtitle?) ...[
                  const SizedBox(height: 8),
                  Text(subtitle, style: const TextStyle(color: muted)),
                ],
                if (widget.actions.isNotEmpty) ...[
                  const SizedBox(height: 13),
                  Wrap(spacing: 8, runSpacing: 8, children: widget.actions),
                ],
              ],
            );
            if (image == null) return copy;
            if (landscape && compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [cover, const SizedBox(height: 14), copy],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cover,
                const SizedBox(width: 16),
                Expanded(child: copy),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class GraphLink extends StatelessWidget {
  const GraphLink(this.label, this.route, {this.icon, super.key});
  final String label;
  final CineRoute route;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon ?? Icons.arrow_outward_rounded, size: 15, color: blue),
    label: Text(label),
    onPressed: () =>
        CineNavigation.of(context).open(context, route, label: label),
  );
}

class ExternalLink extends StatelessWidget {
  const ExternalLink(this.label, this.uri, {super.key});
  final String label;
  final Uri uri;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.open_in_new_rounded, size: 17),
    label: Text(label),
    onPressed: () async {
      var opened = false;
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // A missing browser is handled in the same way as a declined launch.
      }
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link.')),
        );
      }
    },
  );
}

typedef GraphLoader<T> = Future<T> Function({required bool refresh});
typedef GraphBuilder<T> = Widget Function(BuildContext context, T result);

class GraphLoad<T> extends StatefulWidget {
  const GraphLoad({
    required this.load,
    required this.builder,
    this.fullPage = false,
    this.loading,
    super.key,
  });
  final GraphLoader<T> load;
  final GraphBuilder<T> builder;
  final bool fullPage;
  final WidgetBuilder? loading;

  @override
  State<GraphLoad<T>> createState() => _GraphLoadState<T>();
}

class _GraphLoadState<T> extends State<GraphLoad<T>> {
  late Future<T> _request = widget.load(refresh: false);

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _request,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _status(
          MessageState(
            message: catalogueError(snapshot.error),
            onRetry: () {
              final retry = widget.load(refresh: true);
              setState(() {
                _request = retry;
              });
            },
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        if (widget.loading case final loading?) return loading(context);
        return _status(const CineSkeleton(height: 92, radius: 13));
      }
      return widget.builder(context, snapshot.data as T);
    },
  );

  Widget _status(Widget child) => !widget.fullPage
      ? child
      : CinePage(
          slivers: [
            CineSliver(
              top: 23,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (CineLayout.widthOf(context) == CineWidth.compact)
                    BackButton(
                      onPressed: () => CineNavigation.of(context).back(context),
                    ),
                  child,
                ],
              ),
            ),
          ],
        );
}

class GraphSection extends StatefulWidget {
  const GraphSection({
    required this.title,
    required this.icon,
    required this.builder,
    super.key,
  });
  final String title;
  final IconData icon;
  final WidgetBuilder builder;

  @override
  State<GraphSection> createState() => _GraphSectionState();
}

class _GraphSectionState extends State<GraphSection> {
  bool _opened = false;
  bool? _initial;

  Object? get _storageId =>
      widget.key == null ? null : ('section expanded', widget.key);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final identifier = _storageId;
    if (identifier == null || _initial != null) return;
    _initial =
        PageStorage.maybeOf(context)
            ?.readState(context, identifier: identifier) ==
        true;
    _opened = _initial!;
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: outline),
      ),
      child: ExpansionTile(
        initiallyExpanded: _initial ?? false,
        leading: Icon(widget.icon, color: blue, size: 20),
        title: Text(widget.title, style: cineLabel(color: ink, size: 15)),
        maintainState: true,
        onExpansionChanged: (value) {
          if (_storageId case final identifier?) {
            PageStorage.maybeOf(context)
                ?.writeState(context, value, identifier: identifier);
          }
          if (value && !_opened) setState(() => _opened = true);
        },
        childrenPadding: const EdgeInsets.fromLTRB(16, 11, 16, 16),
        children: [if (_opened) Builder(builder: widget.builder)],
      ),
    ),
  );
}

class GraphMessage extends StatelessWidget {
  const GraphMessage(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(message, style: const TextStyle(color: muted)),
  );
}

String entityLabel(EntityKind kind) => switch (kind) {
  EntityKind.movie => 'Movie',
  EntityKind.tv => 'TV show',
  EntityKind.person => 'Person',
  EntityKind.collection => 'Collection',
  EntityKind.company => 'Company',
  EntityKind.network => 'TV network',
  EntityKind.keyword => 'Keyword',
};

class EntityResultCard extends StatelessWidget {
  const EntityResultCard({
    required this.link,
    this.route,
    this.heroTag,
    super.key,
  });
  final EntityLink link;
  final CineRoute? route;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final kind = link.ref.kind;
    final logo = kind == EntityKind.company || kind == EntityKind.network;
    final portrait = kind == EntityKind.person ? link.image : null;
    final flight = portrait == null
        ? null
        : heroTag ?? 'person-result-${link.ref.id}';
    void open() => CineNavigation.of(context).open(
      context,
      route ?? TitleRoute(link.ref),
      label: link.name,
      heroTag: flight,
      artwork: portrait,
    );
    final label = switch (route) {
      SeasonRoute() => 'Season',
      EpisodeRoute() => 'Episode',
      _ => entityLabel(kind),
    };
    return Semantics(
      button: true,
      label: '${link.name} · $label',
      excludeSemantics: true,
      onTap: open,
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: sharedArt(
                  context,
                  flight,
                  link.image == null
                      ? ColoredBox(
                          color: elevated,
                          child: Center(
                            child: Icon(
                              switch (kind) {
                                EntityKind.person =>
                                  Icons.person_outline_rounded,
                                EntityKind.company => Icons.apartment_rounded,
                                EntityKind.keyword => Icons.tag_rounded,
                                _ => Icons.movie_creation_outlined,
                              },
                              color: blue,
                              size: 35,
                            ),
                          ),
                        )
                      : CineArt(
                          path: link.image,
                          kind: switch (kind) {
                            EntityKind.person => ArtworkKind.profile,
                            EntityKind.company ||
                            EntityKind.network => ArtworkKind.logo,
                            _ => ArtworkKind.poster,
                          },
                          fit: logo ? BoxFit.contain : BoxFit.cover,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 8, 9, 0),
                child: Text(
                  link.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 4, 9, 0),
                child: Text(
                  link.caption ?? label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: cineLabel(color: blue, size: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String creditLabel(CreditRole role) =>
    role.episodes == null ? role.role : '${role.role} (${role.episodes} ep)';

class CreditPeople extends StatefulWidget {
  const CreditPeople({
    required this.people,
    this.showRoleFilters = true,
    super.key,
  });
  final List<PersonCredit>? people;
  final bool showRoleFilters;

  @override
  State<CreditPeople> createState() => _CreditPeopleState();
}

class _CreditPeopleState extends State<CreditPeople> {
  static const _pageSize = 16;
  bool? _cast;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final people = widget.people;
    if (people == null) {
      return const GraphMessage('Credit metadata is unavailable.');
    }
    if (people.isEmpty) {
      return const GraphMessage('TMDB lists no credits here.');
    }
    final visible = [
      for (final entry in people)
        if (entry.roles.any((role) => _cast == null || role.cast == _cast))
          entry,
    ];
    final offset = _page * _pageSize;
    final batch = visible.skip(offset).take(_pageSize).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showRoleFilters)
          Wrap(
            spacing: 7,
            runSpacing: 5,
            children: [
              for (final (filter, label) in <(bool?, String)>[
                (null, 'All credits'),
                (true, 'Cast'),
                (false, 'Crew'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _cast == filter,
                  onSelected: (_) => setState(() {
                    _cast = filter;
                    _page = 0;
                  }),
                ),
            ],
          ),
        if (visible.isEmpty) const GraphMessage('No credits match this view.'),
        if (batch.isNotEmpty)
          LayoutBuilder(
            builder: (context, size) {
              final width = size.maxWidth >= 750
                  ? (size.maxWidth - 16) / 2
                  : size.maxWidth;
              return Wrap(
                spacing: 16,
                children: [
                  for (final entry in batch)
                    SizedBox(width: width, child: _tile(context, entry)),
                ],
              );
            },
          ),
        if (visible.length > _pageSize)
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
                child: const Text('Previous credits'),
              ),
              Text(
                '${offset + 1}–${offset + batch.length} of ${visible.length}',
              ),
              TextButton(
                onPressed: offset + batch.length < visible.length
                    ? () => setState(() => _page++)
                    : null,
                child: const Text('Next credits'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _tile(BuildContext context, PersonCredit entry) {
    final flight = entry.person.image == null
        ? null
        : 'credit-${identityHashCode(this)}-${entry.person.ref.id}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      leading: SizedBox(
        width: 40,
        height: 52,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: sharedArt(
            context,
            flight,
            CineArt(path: entry.person.image, kind: ArtworkKind.profile),
          ),
        ),
      ),
      title: Text(entry.person.name),
      subtitle: Text(
        [
          for (final role in entry.roles)
            if (_cast == null || role.cast == _cast) creditLabel(role),
        ].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: blue, size: 18),
      onTap: () => CineNavigation.of(context).open(
        context,
        TitleRoute(entry.person.ref),
        label: entry.person.name,
        heroTag: flight,
        artwork: entry.person.image,
      ),
    );
  }
}
