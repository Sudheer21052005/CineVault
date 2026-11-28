import 'package:cinevault/catalogue/artwork_policy.dart';
import 'package:cinevault/core/material.dart';
import 'package:cinevault/core/network/tmdb_transport.dart';
import 'package:cinevault/core/performance.dart';
import 'package:cinevault/ui/artwork_gallery.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'fullscreen artwork supports keyboard, swipe, pinch and double-tap zoom',
    (tester) async {
      final performance = AppPerformance();
      final transport = TmdbTransport(
        credential: () async => 'fixture',
        performance: performance,
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      final policy = ArtworkPolicy(transport);
      addTearDown(transport.close);
      addTearDown(policy.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider.value(value: performance),
            ChangeNotifierProvider.value(value: policy),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Gallery(
                title: 'Fixture film',
                data: {
                  'backdrops': [
                    {'file_path': '/first.jpg'},
                    {'file_path': '/second.jpg'},
                    {'file_path': '/third.jpg'},
                  ],
                },
                groups: [('backdrops', 'Backdrops', ArtworkKind.backdrop)],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('View backdrops 1'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 3 · Backdrops'), findsOneWidget);
      expect(
        tester.getSize(find.byType(InteractiveViewer).first).width,
        greaterThan(700),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2 of 3 · Backdrops'), findsOneWidget);
      await tester.drag(
        find.byType(InteractiveViewer).first,
        const Offset(-515, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 of 3 · Backdrops'), findsOneWidget);

      final active = find.byType(InteractiveViewer).first;
      final center = tester.getCenter(active);
      final transform = tester
          .widget<InteractiveViewer>(active)
          .transformationController!;
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 90));
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(transform.value.getMaxScaleOnAxis(), greaterThan(2));
      await tester.tap(find.byTooltip('Fit image'));
      await tester.pumpAndSettle();
      expect(transform.value.getMaxScaleOnAxis(), 1);

      final left = await tester.startGesture(
        center - const Offset(48, 0),
        pointer: 21,
      );
      final right = await tester.startGesture(
        center + const Offset(48, 0),
        pointer: 22,
      );
      await left.moveBy(const Offset(-80, 0));
      await right.moveBy(const Offset(80, 0));
      await tester.pump();
      await left.up();
      await right.up();
      await tester.pumpAndSettle();
      expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
      final x = transform.value.getTranslation().x;
      await tester.drag(active, const Offset(38, 0));
      await tester.pumpAndSettle();
      expect(transform.value.getTranslation().x, isNot(x));
      await tester.tap(find.byTooltip('Fit image'));
      await tester.pumpAndSettle();
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -200),
        ),
      );
      await tester.pumpAndSettle();
      expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Fixture film'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
