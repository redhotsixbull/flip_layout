import 'package:flutter/material.dart';
import 'package:flip_layout/flip_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns the translation of the nearest [Transform] ancestor of [label].
Offset _translateOf(WidgetTester tester, String label) {
  final transform = tester.widget<Transform>(
    find
        .ancestor(
          of: find.text(label),
          matching: find.byType(Transform),
        )
        .first,
  );
  final t = transform.transform.getTranslation();
  return Offset(t.x, t.y);
}

void main() {
  testWidgets('LayoutMotion renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LayoutMotion(child: Text('hello'))),
      ),
    );
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('reorder slides the moved child (FLIP inverse then settle)',
      (tester) async {
    var order = [1, 2, 3];

    Widget build() => MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  for (final i in order)
                    LayoutMotion(
                      key: ValueKey(i),
                      duration: const Duration(milliseconds: 200),
                      child: SizedBox(height: 60, child: Text('item $i')),
                    ),
                  ElevatedButton(
                    onPressed: () =>
                        setState(() => order = order.reversed.toList()),
                    child: const Text('reverse'),
                  ),
                ],
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pump(); // establish initial bounds

    // At rest, no translation.
    expect(_translateOf(tester, 'item 1').distance, lessThan(0.01));

    await tester.tap(find.text('reverse'));
    await tester.pump(); // rebuild new order + post-frame measurement → forward
    await tester.pump(const Duration(milliseconds: 40)); // mid-animation

    // item 1 moved from top to bottom → mid-flight it is offset (inverted).
    expect(_translateOf(tester, 'item 1').distance, greaterThan(1.0),
        reason: 'moved child should be mid-slide, not snapped');

    await tester.pumpAndSettle();
    expect(_translateOf(tester, 'item 1').distance, lessThan(0.01),
        reason: 'settles exactly back to identity');
  });

  testWidgets('interruptible: a reorder mid-slide stays continuous and settles',
      (tester) async {
    var order = [1, 2, 3];
    late void Function(void Function()) setter;

    Widget build() => MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setter = setState;
                return Column(
                  children: [
                    for (final i in order)
                      LayoutMotion(
                        key: ValueKey(i),
                        duration: const Duration(milliseconds: 200),
                        child: SizedBox(height: 60, child: Text('r$i')),
                      ),
                  ],
                );
              },
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pump();

    setter(() => order = [3, 2, 1]); // first reorder
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60)); // mid-slide
    final mid = _translateOf(tester, 'r1').distance;
    expect(mid, greaterThan(1.0), reason: 'first slide in flight');

    setter(() => order = [1, 2, 3]); // interrupt with a second reorder
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // Right after interruption it must not snap to a wildly larger offset —
    // it re-targets from the current on-screen position.
    final afterInterrupt = _translateOf(tester, 'r1').distance;
    expect(afterInterrupt, lessThan(mid + 200),
        reason: 'no discontinuous jump on interruption');

    await tester.pumpAndSettle();
    expect(_translateOf(tester, 'r1').distance, lessThan(0.01),
        reason: 'settles cleanly to identity after interruption');
  });

  testWidgets('scrolling does NOT trigger a spurious slide', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                for (var i = 0; i < 20; i++)
                  LayoutMotion(
                    key: ValueKey('row-$i'),
                    duration: const Duration(milliseconds: 200),
                    child: SizedBox(height: 60, child: Text('row $i')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.jumpTo(120);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    // A visible row must not be animating just because the page scrolled.
    expect(_translateOf(tester, 'row 3').distance, lessThan(0.01),
        reason: 'scrolling is measured in content space → no FLIP');

    controller.dispose();
  });

  testWidgets('AnimatedLayout wraps children with LayoutMotion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedLayout(
            builder: (context, wrap) => Column(
              children: [
                wrap(const Text('a', key: ValueKey('a'))),
                wrap(const Text('b', key: ValueKey('b'))),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.byType(LayoutMotion), findsNWidgets(2));
  });

  testWidgets('AnimatedLayout asserts children carry a key', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedLayout(
            builder: (context, wrap) => Column(
              children: [wrap(const Text('no-key'))],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('onEnd fires once when a slide completes', (tester) async {
    var ended = 0;
    var order = [1, 2];

    Widget build() => MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  for (final i in order)
                    LayoutMotion(
                      key: ValueKey(i),
                      duration: const Duration(milliseconds: 100),
                      onEnd: () => ended++,
                      child: SizedBox(height: 60, child: Text('n$i')),
                    ),
                  ElevatedButton(
                    onPressed: () =>
                        setState(() => order = order.reversed.toList()),
                    child: const Text('swap'),
                  ),
                ],
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pump();
    await tester.tap(find.text('swap'));
    await tester.pumpAndSettle();

    expect(ended, greaterThan(0));
  });

  group('MotionGroup', () {
    Widget host(List<int> items, {bool animateInitial = false}) => MaterialApp(
          home: Scaffold(
            body: MotionGroup(
              duration: const Duration(milliseconds: 200),
              animateInitial: animateInitial,
              children: [
                for (final i in items)
                  SizedBox(key: ValueKey(i), height: 40, child: Text('m$i')),
              ],
              builder: (context, children) => Wrap(children: children),
            ),
          ),
        );

    testWidgets('renders its children through the builder', (tester) async {
      await tester.pumpWidget(host([1, 2, 3]));
      await tester.pump();
      expect(find.text('m1'), findsOneWidget);
      expect(find.text('m3'), findsOneWidget);
    });

    testWidgets('a removed child stays mounted while it animates out, then goes',
        (tester) async {
      await tester.pumpWidget(host([1, 2, 3]));
      await tester.pump();
      expect(find.text('m2'), findsOneWidget);

      // Remove item 2.
      await tester.pumpWidget(host([1, 3]));
      await tester.pump(const Duration(milliseconds: 50));
      // Still present, mid-exit (AnimatePresence behaviour).
      expect(find.text('m2'), findsOneWidget,
          reason: 'exiting child is kept mounted during its animation');
      final opacity = tester.widget<FadeTransition>(
        find.ancestor(of: find.text('m2'), matching: find.byType(FadeTransition)).first,
      );
      expect(opacity.opacity.value, lessThan(1.0),
          reason: 'exiting child is fading out');

      await tester.pumpAndSettle();
      expect(find.text('m2'), findsNothing, reason: 'removed after exit');
    });

    testWidgets('an added child animates in (opacity starts below 1)',
        (tester) async {
      await tester.pumpWidget(host([1, 2]));
      await tester.pump();

      await tester.pumpWidget(host([1, 2, 3]));
      await tester.pump(const Duration(milliseconds: 40));
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: find.text('m3'), matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, lessThan(1.0), reason: 'entering child fades in');

      await tester.pumpAndSettle();
      final settled = tester.widget<FadeTransition>(
        find.ancestor(of: find.text('m3'), matching: find.byType(FadeTransition)).first,
      );
      expect(settled.opacity.value, 1.0);
    });

    testWidgets('animateInitial:false shows initial children instantly',
        (tester) async {
      await tester.pumpWidget(host([1, 2], animateInitial: false));
      await tester.pump();
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: find.text('m1'), matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, 1.0);
    });

    testWidgets('asserts children carry a key', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MotionGroup(
              children: const [Text('no-key')],
              builder: (context, children) => Column(children: children),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('exitTransitionBuilder is used only for leaving children',
        (tester) async {
      Widget host(List<int> items) => MaterialApp(
            home: Scaffold(
              body: MotionGroup(
                duration: const Duration(milliseconds: 200),
                animateInitial: false,
                exitTransitionBuilder: (context, animation, child) =>
                    RotationTransition(turns: animation, child: child),
                children: [
                  for (final i in items)
                    SizedBox(key: ValueKey(i), height: 40, child: Text('e$i')),
                ],
                builder: (context, children) => Column(children: children),
              ),
            ),
          );

      await tester.pumpWidget(host([1, 2, 3]));
      await tester.pump();

      await tester.pumpWidget(host([1, 3])); // remove 2
      await tester.pump(const Duration(milliseconds: 50));

      // The leaving child (2) is wrapped by the exit builder...
      expect(
        find.ancestor(
            of: find.text('e2'), matching: find.byType(RotationTransition)),
        findsOneWidget,
        reason: 'the leaving child uses the exit builder',
      );
      // ...but a surviving child (1) is not.
      expect(
        find.ancestor(
            of: find.text('e1'), matching: find.byType(RotationTransition)),
        findsNothing,
        reason: 'present children use the enter builder, not the exit one',
      );

      await tester.pumpAndSettle();
      expect(find.text('e2'), findsNothing, reason: 'removed after exit');
    });
  });

  group('SpringCurve', () {
    test('starts at 0, ends at 1, and an underdamped spring overshoots', () {
      final spring = SpringCurve(stiffness: 240, damping: 6); // bouncy
      expect(spring.transform(0.0), 0.0);
      expect(spring.transform(1.0), 1.0);

      var maxValue = 0.0;
      for (var i = 1; i < 40; i++) {
        final v = spring.transform(i / 40);
        if (v > maxValue) maxValue = v;
      }
      expect(maxValue, greaterThan(1.0),
          reason: 'underdamped spring overshoots the target');
    });

    test('an overdamped spring settles without overshooting', () {
      final spring = SpringCurve(stiffness: 120, damping: 30); // stiff/damped
      for (var i = 0; i <= 40; i++) {
        expect(spring.transform(i / 40), lessThanOrEqualTo(1.0 + 1e-6));
      }
    });
  });

  group('MotionConfig', () {
    testWidgets('reduceMotion skips the LayoutMotion slide (instant)',
        (tester) async {
      var order = [1, 2, 3];
      late StateSetter setter;
      Widget build() => MaterialApp(
            home: Scaffold(
              body: MotionConfig(
                reduceMotion: true,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setter = setState;
                    return Column(
                      children: [
                        for (final i in order)
                          LayoutMotion(
                            key: ValueKey(i),
                            child: SizedBox(height: 60, child: Text('z$i')),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );

      await tester.pumpWidget(build());
      await tester.pump();
      setter(() => order = [3, 2, 1]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 8));
      expect(_translateOf(tester, 'z1').distance, lessThan(0.01),
          reason: 'reduced motion → jump to new position, no slide');
    });
  });
}
