import '../core/material.dart';
import '../models/media.dart';
import 'route_contract.dart';

class CineNavigation extends InheritedWidget {
  const CineNavigation({
    required this.open,
    required this.select,
    required this.updateSearch,
    required this.back,
    required super.child,
    super.key,
  });

  final void Function(
    BuildContext,
    CineRoute, {
    Media? summary,
    String? heroTag,
    String? label,
  })
  open;
  final void Function(BuildContext, AppTab) select;
  final void Function(BuildContext, TabRoute) updateSearch;
  final void Function(BuildContext) back;

  static CineNavigation of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CineNavigation>()!;

  void openTitle(BuildContext context, Media media, {String? heroTag}) =>
      open(context, TitleRoute(media.ref), summary: media, heroTag: heroTag);

  @override
  bool updateShouldNotify(CineNavigation oldWidget) => false;
}
