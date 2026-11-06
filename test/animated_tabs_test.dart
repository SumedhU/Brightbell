import 'package:brightbell/components/animated_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _tabs(int index, {VoidCallback? onTapFirst}) => MaterialApp(
  home: Material(
    child: AnimatedTabs(
      index: index,
      keepAlive: const {1},
      children: [
        GestureDetector(onTap: onTapFirst, child: const Text('first')),
        const TextField(),
        const Text('third'),
      ],
    ),
  ),
);

void main() {
  testWidgets('only builds the current and kept alive tabs', (tester) async {
    await tester.pumpWidget(_tabs(0));

    expect(find.text('first'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('third'), findsNothing);
  });

  testWidgets('keeps the old tab until it has animated out', (tester) async {
    await tester.pumpWidget(_tabs(0));
    await tester.pumpWidget(_tabs(2));

    await tester.pump(AnimatedTabs.duration ~/ 2);
    expect(find.text('first'), findsOneWidget);
    expect(find.text('third'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('first'), findsNothing);
    expect(find.text('third'), findsOneWidget);
  });

  testWidgets('animates a tab in when it is first built', (tester) async {
    await tester.pumpWidget(_tabs(0));
    await tester.pumpWidget(_tabs(2));
    await tester.pump(AnimatedTabs.duration ~/ 2);

    final fade = tester.renderObject<RenderAnimatedOpacity>(
      find.ancestor(
        of: find.text('third'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));

    await tester.pumpAndSettle();
    expect(fade.opacity.value, 1);
  });

  testWidgets('kept alive tabs keep their state while hidden', (tester) async {
    await tester.pumpWidget(_tabs(1));
    await tester.enterText(find.byType(TextField), 'bench press');

    await tester.pumpWidget(_tabs(0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_tabs(1));
    await tester.pumpAndSettle();

    expect(find.text('bench press'), findsOneWidget);
  });

  testWidgets('a tab returned to mid-animation stays built', (tester) async {
    await tester.pumpWidget(_tabs(0));
    await tester.pumpWidget(_tabs(2));
    await tester.pump(AnimatedTabs.duration ~/ 4);
    await tester.pumpWidget(_tabs(0));
    await tester.pumpAndSettle();

    expect(find.text('first'), findsOneWidget);
    expect(find.text('third'), findsNothing);
  });

  testWidgets('hidden tabs ignore taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_tabs(0, onTapFirst: () => taps++));
    await tester.pumpWidget(_tabs(1, onTapFirst: () => taps++));

    await tester.tapAt(tester.getCenter(find.byType(AnimatedTabs)));
    expect(taps, 0);
  });

  testWidgets('skips the animation when animations are disabled', (
    tester,
  ) async {
    Widget app(int index) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: AnimatedTabs(
          index: index,
          children: const [Text('first'), Text('third')],
        ),
      ),
    );

    await tester.pumpWidget(app(0));
    await tester.pumpWidget(app(1));
    await tester.pump();

    expect(find.text('first'), findsNothing);
  });
}
