import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npq_music/cupertino_navigation.dart';

void main() {
  testWidgets('Nested song pages pop one at a time, including repeated songs', (
    tester,
  ) async {
    final history = ['tabs'];
    late StateSetter update;
    await tester.pumpWidget(CupertinoApp(
      home: StatefulBuilder(builder: (context, setState) {
        update = setState;
        return CupertinoNavigation(
          routeKey: ValueKey(history.last),
          onBack: () => update(() => history.removeLast()),
          child: Center(child: Text(history.last)),
        );
      }),
    ));
    for (final entry in ['song:A:1', 'song:B:2', 'song:A:3']) {
      update(() => history.add(entry));
      await tester.pumpAndSettle();
      expect(find.text(entry), findsOneWidget);
    }
    for (final previous in ['song:B:2', 'song:A:1', 'tabs']) {
      Navigator.of(tester.element(find.text(history.last))).pop();
      await tester.pumpAndSettle();
      expect(history.last, previous);
      expect(find.text(previous), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cupertino push, cancelled swipe, completed swipe and back', (
    tester,
  ) async {
    var current = 'tabs';
    var backs = 0;
    late StateSetter update;
    await tester.pumpWidget(CupertinoApp(
      home: StatefulBuilder(builder: (context, setState) {
        update = setState;
        return CupertinoNavigation(
          routeKey: ValueKey(current),
          onBack: () {
            backs++;
            update(() => current = 'tabs');
          },
          child: ColoredBox(
            color: CupertinoColors.white,
            child: Center(child: Text(current)),
          ),
        );
      }),
    ));
    update(() => current = 'detail');
    await tester.pumpAndSettle();
    final route = ModalRoute.of(tester.element(find.text('detail')))!;
    expect(route, isA<CupertinoRouteTransitionMixin<void>>());
    expect(route.popGestureEnabled, isTrue);

    var gesture = await tester.startGesture(const Offset(1, 300));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(current, 'detail');
    expect(backs, 0);

    gesture = await tester.startGesture(const Offset(1, 300));
    await gesture.moveBy(const Offset(650, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(current, 'tabs');
    expect(backs, 1);

    update(() => current = 'detail');
    await tester.pumpAndSettle();
    update(() => current = 'tabs');
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsNothing);
    expect(backs, 1);
    expect(tester.takeException(), isNull);
  });
}
