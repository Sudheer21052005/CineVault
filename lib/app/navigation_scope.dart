import '../core/material.dart';
import '../models/media.dart';
import 'route_contract.dart';

class CineNavigation extends InheritedWidget {
  const CineNavigation({
    required this.open,
    required this.select,
    required this.selectDestination,
    required this.openSearch,
    required this.updateSearch,
    required this.replace,
    required this.back,
    required this.searchRequests,
    required super.child,
    super.key,
  });

  final void Function(
    BuildContext,
    CineRoute, {
    Media? summary,
    String? heroTag,
    String? artwork,
    String? label,
  })
  open;
  final void Function(BuildContext, AppTab) select;
  final void Function(BuildContext, AppTab) selectDestination;
  final void Function(BuildContext) openSearch;
  final void Function(BuildContext, TabRoute) updateSearch;
  final void Function(BuildContext, CineRoute) replace;
  final void Function(BuildContext) back;
  final ValueNotifier<int> searchRequests;

  void focusSearch(BuildContext context) {
    openSearch(context);
    // The first search screen mounts when the route change is drawn.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) searchRequests.value++;
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  static CineNavigation of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CineNavigation>()!;

  void openTitle(BuildContext context, Media media, {String? heroTag}) =>
      open(context, TitleRoute(media.ref), summary: media, heroTag: heroTag);

  @override
  bool updateShouldNotify(CineNavigation oldWidget) => false;
}
