import 'dart:math' as math;

// Keep the SDK's interactive iOS back gesture on the supported Flutter versions.
// ignore: deprecated_member_use
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

import '../core/material.dart';

const canvas = Color(0xFF090D16);
const surface = Color(0xFF121B2A);
const elevated = Color(0xFF1B273A);
const outline = Color(0xFF2F405A);
const ink = Color(0xFFF4F6FC);
const muted = Color(0xFFAAB6C9);
const blue = Color(0xFF81AEFF);
const primaryInk = Color(0xFF071426);
const gold = Color(0xFFF5CC83);
const watched = Color(0xFF70D8B1);
const watching = Color(0xFFFFB767);
const danger = Color(0xFFFF9C9F);

Duration cineMotion(BuildContext context, [int milliseconds = 190]) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

class CineStateIcon extends StatelessWidget {
  const CineStateIcon(this.icon, {required this.size, super.key});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: cineMotion(context, 190),
    switchInCurve: Curves.easeOutBack,
    transitionBuilder: (child, animation) =>
        ScaleTransition(scale: animation, child: child),
    child: Icon(icon, size: size, key: ValueKey(icon)),
  );
}

enum CineWidth { compact, medium, expanded }

abstract final class CineLayout {
  static CineWidth widthOf(BuildContext context) =>
      widthFor(MediaQuery.sizeOf(context).width);

  static CineWidth widthFor(double width) => switch (width) {
    < 600 => CineWidth.compact,
    < 1024 => CineWidth.medium,
    _ => CineWidth.expanded,
  };

  static double gutterOf(BuildContext context) => switch (widthOf(context)) {
    CineWidth.compact => 16,
    CineWidth.medium => 28,
    CineWidth.expanded => 40,
  };
}

TextStyle cineDisplay(double size, {double weight = 700, Color color = ink}) =>
    TextStyle(
      fontFamily: 'Space Grotesk',
      fontWeight: FontWeight.values[(weight ~/ 100).clamp(1, 9) - 1],
      fontVariations: [FontVariation('wght', weight)],
      fontSize: size,
      color: color,
      height: 1.02,
      letterSpacing: -size * .038,
    );

TextStyle cineLabel({Color color = muted, double size = 12}) => TextStyle(
  fontWeight: FontWeight.w800,
  fontSize: size,
  letterSpacing: 1.25,
  color: color,
);

ThemeData cineTheme() {
  const scheme = ColorScheme.dark(
    primary: blue,
    onPrimary: primaryInk,
    secondary: gold,
    onSecondary: primaryInk,
    surface: surface,
    onSurface: ink,
    onSurfaceVariant: muted,
    outline: outline,
    error: danger,
  );
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: canvas,
    canvasColor: surface,
    visualDensity: VisualDensity.standard,
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: outline),
  );
  return theme.copyWith(
    textTheme: theme.textTheme.copyWith(
      displayLarge: cineDisplay(64),
      headlineLarge: cineDisplay(44),
      headlineMedium: cineDisplay(32),
      titleLarge: cineDisplay(25),
      titleMedium: const TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.6, color: ink),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.55, color: muted),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: blue, width: 1.6),
      ),
      hintStyle: const TextStyle(color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        foregroundColor: ink,
        side: const BorderSide(color: outline),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: buttonShape,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: blue.withValues(alpha: .17),
      side: const BorderSide(color: outline),
      labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w700),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: canvas,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      modalBarrierColor: Color(0xB0090C13),
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: outline, space: 1),
    cardTheme: const CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: surface,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _CineTransition(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: _CineTransition(),
        TargetPlatform.windows: _CineTransition(),
        TargetPlatform.linux: _CineTransition(),
        TargetPlatform.fuchsia: _CineTransition(),
      },
    ),
  );
}

class _CineTransition extends PageTransitionsBuilder {
  const _CineTransition();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 245);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return SlideTransition(
      position: animation.drive(
        Tween(
          begin: const Offset(0, .012),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
      ),
      child: ColoredBox(color: canvas, child: child),
    );
  }
}

class CinePanel extends StatelessWidget {
  const CinePanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 18,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: outline),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class CinePage extends StatelessWidget {
  const CinePage({
    required this.slivers,
    this.controller,
    this.scrollKey,
    this.onRefresh,
    super.key,
  });

  final List<Widget> slivers;
  final ScrollController? controller;
  final PageStorageKey<String>? scrollKey;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scroll = CustomScrollView(
      key: scrollKey,
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 38)),
      ],
    );
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: LayoutBuilder(
            builder: (_, viewport) => CineViewport(
              width: viewport.maxWidth,
              child: onRefresh == null
                  ? scroll
                  : RefreshIndicator(onRefresh: onRefresh!, child: scroll),
            ),
          ),
        ),
      ),
    );
  }
}

class CineViewport extends InheritedWidget {
  const CineViewport({required this.width, required super.child, super.key});

  final double width;

  static double? maybeWidthOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CineViewport>()?.width;

  @override
  bool updateShouldNotify(CineViewport oldWidget) => width != oldWidget.width;
}

class CineSliver extends StatelessWidget {
  const CineSliver({
    required this.child,
    this.top = 0,
    this.bottom = 0,
    super.key,
  });
  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final gutter = CineLayout.gutterOf(context);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(gutter, top, gutter, bottom),
      sliver: SliverToBoxAdapter(child: child),
    );
  }
}

class CineHeading extends StatelessWidget {
  const CineHeading(this.title, {this.subtitle, this.action, super.key});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    runSpacing: 15,
    spacing: 20,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: cineDisplay(
                CineLayout.widthOf(context) == CineWidth.compact ? 39 : 52,
              ),
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
      ?action,
    ],
  );
}

class MessageState extends StatelessWidget {
  const MessageState({
    required this.message,
    this.icon = Icons.movie_filter_outlined,
    this.onRetry,
    super.key,
  });

  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 550),
      child: CinePanel(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: blue, size: 30),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Retry'),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class CineSkeleton extends StatelessWidget {
  const CineSkeleton({this.height, this.radius = 14, super.key});
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [elevated, surface],
      ),
    ),
  );
}

class CineIconButton extends StatelessWidget {
  const CineIconButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.overlay = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool overlay;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: label,
    icon: Icon(icon, size: 20),
    style: IconButton.styleFrom(
      backgroundColor: overlay ? canvas.withValues(alpha: .80) : surface,
      foregroundColor: ink,
      minimumSize: const Size.square(46),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: outline),
      ),
    ),
  );
}

class CineScore extends StatelessWidget {
  const CineScore(this.rating, {super.key});
  final double rating;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();
    final formatted = rating.toStringAsFixed(1);
    return Semantics(
      label: 'TMDB score $formatted out of 10',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: gold, size: 17),
          const SizedBox(width: 4),
          Text(
            formatted,
            style: const TextStyle(
              color: gold,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

int cineColumns(double width, double scale) {
  final minimum = 136 * math.min(scale, 1.5);
  return ((width + 14) / (minimum + 14)).floor().clamp(1, 7);
}

double cineCardHeight(double width, double scale) =>
    width * 1.5 + math.max(82, 70 * scale);
