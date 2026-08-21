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

    testWidgets('warns once when child count exceeds the debug threshold',
        (tester) async {
      final logs = <String>[];
      final original = debugPrint;
      // debugPrint is a foundation debug var — it MUST be restored before the
      // test body ends (the framework asserts this), so restore in a finally.
      debugPrint = (String? m, {int? wrapWidth}) {
        if (m != null) logs.add(m);
      };
      MotionGroup.debugChildCountWarningThreshold = 5;
      addTearDown(() => MotionGroup.debugChildCountWarningThreshold = 150);
      try {
        await tester.pumpWidget(host([1, 2, 3, 4, 5, 6])); // 6 > 5
        await tester.pump();
        // Rebuild again — the warning must not repeat.
        await tester.pumpWidget(host([1, 2, 3, 4, 5, 6, 7]));
        await tester.pump();
      } finally {
        debugPrint = original;
      }

      expect(logs.where((l) => l.contains('exceeds')).length, 1,
          reason: 'the large-collection warning fires exactly once');
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

    testWidgets('onEnter/onExitComplete fire with the child key', (tester) async {
      final entered = <Object>[];
      final exited = <Object>[];
      Widget lifecycleHost(List<int> items) => MaterialApp(
            home: Scaffold(
              body: MotionGroup(
                duration: const Duration(milliseconds: 120),
                animateInitial: false, // don't fire onEnter for the first batch
                onEnter: (key) => entered.add((key as ValueKey).value),
                onExitComplete: (key) => exited.add((key as ValueKey).value),
                children: [
                  for (final i in items)
                    SizedBox(key: ValueKey(i), height: 40, child: Text('L$i')),
                ],
                builder: (context, children) => Column(children: children),
              ),
            ),
          );

      await tester.pumpWidget(lifecycleHost([1, 2]));
      await tester.pump();
      expect(entered, isEmpty, reason: 'animateInitial:false → no enter events');

      await tester.pumpWidget(lifecycleHost([1, 2, 3])); // add 3
      await tester.pumpAndSettle();
      expect(entered, contains(3), reason: 'onEnter fired for the new child');

      await tester.pumpWidget(lifecycleHost([1, 3])); // remove 2
      await tester.pumpAndSettle();
      expect(exited, contains(2),
          reason: 'onExitComplete fired once the exit finished');
      expect(find.text('L2'), findsNothing);
    });

    testWidgets('exitStagger delays later leavers (each stays visible in turn)',
        (tester) async {
      double fadeOf(String label) => tester
          .widget<FadeTransition>(find
              .ancestor(of: find.text(label), matching: find.byType(FadeTransition))
              .first)
          .opacity
          .value;

      Widget staggerHost(List<int> items) => MaterialApp(
            home: Scaffold(
              body: MotionGroup(
                duration: const Duration(milliseconds: 120),
                animateInitial: false,
                exitStagger: const Duration(milliseconds: 200),
                children: [
                  for (final i in items)
                    SizedBox(key: ValueKey(i), height: 40, child: Text('x$i')),
                ],
                builder: (context, children) => Column(children: children),
              ),
            ),
          );

      await tester.pumpWidget(staggerHost([1, 2, 3]));
      await tester.pump();

      // Remove 1 and 2 together; with a 200ms exit stagger the first leaver
      // (1) starts fading immediately while the second (2) waits its turn.
      await tester.pumpWidget(staggerHost([3]));
      await tester.pump(const Duration(milliseconds: 60));
      expect(fadeOf('x1'), lessThan(1.0), reason: 'first leaver is exiting');
      expect(fadeOf('x2'), 1.0,
          reason: 'second leaver still fully visible until its staggered turn');

      await tester.pumpAndSettle();
      expect(find.text('x1'), findsNothing);
      expect(find.text('x2'), findsNothing);
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

  group('MotionSpring (velocity-preserving)', () {
    test('presets and equality/description', () {
      expect(MotionSpring.gentle, isNot(MotionSpring.bouncy));
      const a = MotionSpring(stiffness: 200, damping: 18);
      const b = MotionSpring(stiffness: 200, damping: 18);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      final d = a.description;
      expect(d.stiffness, 200);
      expect(d.damping, 18);
      expect(d.mass, 1.0);
    });

    // Reads the *current* order via a getter so the StatefulBuilder rebuild
    // sees mutations (capturing the list by value would freeze the first order).
    Widget springColumn(
            List<int> Function() order, void Function(StateSetter) capture,
            {MotionSpring spring = const MotionSpring(stiffness: 200, damping: 18)}) =>
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                capture(setState);
                return Column(
                  children: [
                    for (final i in order())
                      LayoutMotion(
                        key: ValueKey(i),
                        spring: spring,
                        child: SizedBox(height: 60, child: Text('s$i')),
                      ),
                  ],
                );
              },
            ),
          ),
        );

    testWidgets('a spring reorder slides then settles exactly to identity',
        (tester) async {
      var order = [1, 2, 3];
      late StateSetter setter;
      await tester.pumpWidget(springColumn(() => order, (s) => setter = s));
      await tester.pump();
      expect(_translateOf(tester, 's1').distance, lessThan(0.01));

      setter(() => order = [3, 2, 1]);
      await tester.pump(); // rebuild + post-frame → spring starts
      await tester.pump(const Duration(milliseconds: 40)); // mid-slide
      expect(_translateOf(tester, 's1').distance, greaterThan(1.0),
          reason: 'moved child is mid spring-slide, not snapped');

      await tester.pumpAndSettle();
      expect(_translateOf(tester, 's1').distance, lessThan(0.01),
          reason: 'spring settles exactly to identity');
    });

    testWidgets('a re-target mid-spring stays continuous (momentum) and settles',
        (tester) async {
      var order = [1, 2, 3];
      late StateSetter setter;
      await tester.pumpWidget(springColumn(() => order, (s) => setter = s));
      await tester.pump();

      setter(() => order = [3, 2, 1]); // first spring
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final mid = _translateOf(tester, 's1').distance;
      expect(mid, greaterThan(1.0), reason: 'first spring in flight');

      setter(() => order = [1, 2, 3]); // interrupt: re-target
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final afterInterrupt = _translateOf(tester, 's1').distance;
      // Momentum is carried from the in-flight velocity: the offset must evolve
      // continuously from where it was, not snap to a wildly different value.
      expect(afterInterrupt, lessThan(mid + 200),
          reason: 'velocity carried across the re-target — no discontinuity');

      await tester.pumpAndSettle();
      expect(_translateOf(tester, 's1').distance, lessThan(0.01),
          reason: 'settles cleanly after the interruption');
    });

    testWidgets('reduceMotion skips the spring slide (instant)', (tester) async {
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
                            spring: const MotionSpring(),
                            child: SizedBox(height: 60, child: Text('q$i')),
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
      expect(_translateOf(tester, 'q1').distance, lessThan(0.01),
          reason: 'reduced motion → jump, no spring');
    });
  });

  group('MotionSharedId', () {
    testWidgets('flies a copy when the id is handed to a different widget',
        (tester) async {
      var alt = false;
      late StateSetter setter;
      Widget build() => MaterialApp(
            home: Scaffold(
              body: MotionSharedScope(
                duration: const Duration(milliseconds: 200),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setter = setState;
                    return Stack(
                      children: [
                        if (!alt)
                          Positioned(
                            left: 0,
                            top: 0,
                            child: MotionSharedId(
                              id: 'x',
                              key: const ValueKey('a'),
                              child: Container(
                                  width: 40,
                                  height: 40,
                                  color: const Color(0xFFFF0000),
                                  child: const Text('X',
                                      textDirection: TextDirection.ltr)),
                            ),
                          )
                        else
                          Positioned(
                            left: 180,
                            top: 180,
                            child: MotionSharedId(
                              id: 'x',
                              key: const ValueKey('b'),
                              child: Container(
                                  width: 120,
                                  height: 120,
                                  color: const Color(0xFFFF0000),
                                  child: const Text('X',
                                      textDirection: TextDirection.ltr)),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      setter(() => alt = true); // hand the id to a different widget → fly

      var sawFlight = false;
      for (var i = 0; i < 12 && !sawFlight; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (tester.widgetList(find.text('X')).length >= 2) sawFlight = true;
      }
      expect(sawFlight, isTrue,
          reason: 'a flying copy appears during the shared-element transition');

      await tester.pumpAndSettle();
      expect(find.text('X'), findsOneWidget, reason: 'flight cleaned up');
      expect(tester.takeException(), isNull);
    });

    testWidgets('does NOT fly when the same element merely moves (scroll)',
        (tester) async {
      var top = 0.0;
      late StateSetter setter;
      Widget build() => MaterialApp(
            home: Scaffold(
              body: MotionSharedScope(
                duration: const Duration(milliseconds: 200),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setter = setState;
                    return Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: top,
                          child: MotionSharedId(
                            id: 'y',
                            child: Container(
                                width: 40,
                                height: 40,
                                color: const Color(0xFF00FF00),
                                child: const Text('Y',
                                    textDirection: TextDirection.ltr)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      setter(() => top = 320); // same element moves (like a scroll)

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.widgetList(find.text('Y')).length, 1,
            reason: 'same-element movement must not spawn a flying copy');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('source stays hidden while a newer holder owns the id',
        (tester) async {
      var overlay = false;
      late StateSetter setter;
      double opacityOf(Key k) => tester
          .widget<Opacity>(find
              .descendant(of: find.byKey(k), matching: find.byType(Opacity))
              .first)
          .opacity;

      Widget box() => Container(
          color: const Color(0xFF123456),
          child: const Text('S', textDirection: TextDirection.ltr));

      Widget build() => MaterialApp(
            home: Scaffold(
              body: MotionSharedScope(
                duration: const Duration(milliseconds: 150),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setter = setState;
                    return Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          child: MotionSharedId(
                            id: 's',
                            key: const ValueKey('src'),
                            child: SizedBox(width: 40, height: 40, child: box()),
                          ),
                        ),
                        if (overlay)
                          Center(
                            child: MotionSharedId(
                              id: 's',
                              key: const ValueKey('dst'),
                              child:
                                  SizedBox(width: 120, height: 120, child: box()),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(opacityOf(const ValueKey('src')), 1.0);

      setter(() => overlay = true);
      await tester.pumpAndSettle(); // fly-in completes
      expect(opacityOf(const ValueKey('src')), 0.0,
          reason: 'source hidden while the detail owns the id');
      expect(opacityOf(const ValueKey('dst')), 1.0);

      setter(() => overlay = false);
      await tester.pumpAndSettle(); // fly-back completes
      expect(opacityOf(const ValueKey('src')), 1.0,
          reason: 'source reappears once the detail is gone');
    });

    testWidgets('does NOT fly when an id reappears after being absent (recycle)',
        (tester) async {
      var phase = 0; // 0: at (10,10) · 1: absent · 2: back at (200,200)
      late StateSetter setter;
      Widget build() => MaterialApp(
            home: Scaffold(
              body: MotionSharedScope(
                duration: const Duration(milliseconds: 200),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setter = setState;
                    return Stack(
                      children: [
                        if (phase != 1)
                          Positioned(
                            left: phase == 2 ? 200 : 10,
                            top: phase == 2 ? 200 : 10,
                            child: MotionSharedId(
                              id: 'r',
                              child: Container(
                                  width: 40,
                                  height: 40,
                                  color: const Color(0xFF0000FF),
                                  child: const Text('R',
                                      textDirection: TextDirection.ltr)),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      setter(() => phase = 1); // scrolled off (disposed)
      await tester.pumpAndSettle();
      setter(() => phase = 2); // recycled back at a new position

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.widgetList(find.text('R')).length, 1,
            reason: 'reappearing after absence is not a swap → no flight');
      }
      expect(tester.takeException(), isNull);
    });

    // A source→destination swap under a scope, parameterised by the scope's
    // flight options, so the shuttle tests share one harness.
    Widget swapHost({
      required bool alt,
      required void Function(StateSetter) capture,
      MotionFlightShuttleBuilder? flightShuttleBuilder,
      bool crossFade = false,
    }) {
      Widget box(String t) => SizedBox(
          width: 40,
          height: 40,
          child: Text(t, textDirection: TextDirection.ltr));
      return MaterialApp(
        home: Scaffold(
          body: MotionSharedScope(
            duration: const Duration(milliseconds: 200),
            flightShuttleBuilder: flightShuttleBuilder,
            crossFade: crossFade,
            child: StatefulBuilder(
              builder: (context, setState) {
                capture(setState);
                return Stack(
                  children: [
                    if (!alt)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: MotionSharedId(
                          id: 'x',
                          key: const ValueKey('a'),
                          child: box('SRC'),
                        ),
                      )
                    else
                      Positioned(
                        left: 180,
                        top: 180,
                        child: MotionSharedId(
                          id: 'x',
                          key: const ValueKey('b'),
                          child: box('DST'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('flightShuttleBuilder renders a custom in-flight widget with '
        'both source and destination children', (tester) async {
      var alt = false;
      late StateSetter setter;
      Widget host() => swapHost(
            alt: alt,
            capture: (s) => setter = s,
            flightShuttleBuilder: (context, animation, fromChild, toChild) =>
                Stack(fit: StackFit.expand, children: [
              fromChild,
              toChild,
              const Center(
                  child: Text('SHUTTLE', textDirection: TextDirection.ltr)),
            ]),
          );

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      setter(() => alt = true);
      await tester.pumpWidget(host());

      var sawShuttle = false;
      for (var i = 0; i < 12 && !sawShuttle; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (find.text('SHUTTLE').evaluate().isNotEmpty) sawShuttle = true;
      }
      expect(sawShuttle, isTrue,
          reason: 'the custom shuttle is shown during the flight');
      // The source child only exists in the overlay shuttle now (the real
      // source widget was removed from the tree), proving fromChild is passed.
      expect(find.text('SRC'), findsWidgets,
          reason: 'flightShuttleBuilder received the source child');

      await tester.pumpAndSettle();
      expect(find.text('SHUTTLE'), findsNothing,
          reason: 'shuttle removed when the flight completes');
      expect(find.text('SRC'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('crossFade shuttle carries both children during the flight',
        (tester) async {
      var alt = false;
      late StateSetter setter;
      Widget host() =>
          swapHost(alt: alt, capture: (s) => setter = s, crossFade: true);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      setter(() => alt = true);
      await tester.pumpWidget(host());

      var sawBoth = false;
      for (var i = 0; i < 12 && !sawBoth; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        // The source child ('SRC') exists only in the overlay cross-fade now.
        if (find.text('SRC').evaluate().isNotEmpty &&
            find.text('DST').evaluate().isNotEmpty) {
          sawBoth = true;
        }
      }
      expect(sawBoth, isTrue,
          reason: 'cross-fade shows source and destination together');

      await tester.pumpAndSettle();
      expect(find.text('SRC'), findsNothing,
          reason: 'cross-fade overlay cleaned up');
      expect(find.text('DST'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('newest of three holders of one id is the visible one '
        '(birth-order heuristic)', (tester) async {
      double opacityOf(Key k) => tester
          .widget<Opacity>(find
              .descendant(of: find.byKey(k), matching: find.byType(Opacity))
              .first)
          .opacity;

      Widget holder(String key) => Positioned(
            left: 0,
            top: 0,
            child: MotionSharedId(
              id: 'multi',
              key: ValueKey(key),
              child: SizedBox(
                  width: 30,
                  height: 30,
                  child: Text(key, textDirection: TextDirection.ltr)),
            ),
          );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MotionSharedScope(
            child: Stack(children: [holder('h1'), holder('h2'), holder('h3')]),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // h3 was built last → newest by birth order → the visible holder.
      expect(opacityOf(const ValueKey('h3')), 1.0);
      expect(opacityOf(const ValueKey('h1')), 0.0);
      expect(opacityOf(const ValueKey('h2')), 0.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapid open/close swaps settle cleanly to one holder',
        (tester) async {
      var alt = false;
      late StateSetter setter;
      Widget host() => swapHost(alt: alt, capture: (s) => setter = s);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // Toggle several times with only a couple of frames between each — each
      // flip hands the id to the other widget mid-flight.
      for (var i = 0; i < 4; i++) {
        setter(() => alt = !alt);
        await tester.pumpWidget(host());
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      // Whichever end we finished on, exactly one real widget survives and no
      // overlay copies leak.
      final surviving = alt ? 'DST' : 'SRC';
      final gone = alt ? 'SRC' : 'DST';
      expect(find.text(surviving), findsOneWidget);
      expect(find.text(gone), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a flight interrupted by a new flight settles cleanly',
        (tester) async {
      var alt = false;
      late StateSetter setter;
      Widget host() => swapHost(alt: alt, capture: (s) => setter = s);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      setter(() => alt = true); // start SRC→DST flight
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 40)); // mid-flight

      setter(() => alt = false); // interrupt with DST→SRC flight
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 40));

      await tester.pumpAndSettle();
      expect(find.text('SRC'), findsOneWidget,
          reason: 'ends on the source, overlays cleaned up');
      expect(find.text('DST'), findsNothing);
      expect(tester.takeException(), isNull);
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
