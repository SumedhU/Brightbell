import 'dart:async';

import 'package:brightbell/screens/splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _child = Directionality(
  textDirection: TextDirection.ltr,
  child: Text('home'),
);

bool _splashVisible() => find
    .byWidgetPredicate((w) => w is CustomPaint && w.painter is SplashPainter)
    .evaluate()
    .isNotEmpty;

void main() {
  testWidgets('stays up until initialization finishes', (tester) async {
    final ready = Completer<void>();
    await tester.pumpWidget(SplashGate(ready: ready.future, child: _child));

    await tester.pump(const Duration(seconds: 10));
    expect(_splashVisible(), isTrue);
    expect(find.text('home'), findsNothing);

    ready.complete();
    await tester.pumpAndSettle();
    expect(_splashVisible(), isFalse);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('plays the full animation when initialization is instant', (
    tester,
  ) async {
    await tester.pumpWidget(SplashGate(ready: Future.value(), child: _child));

    await tester.pump(const Duration(seconds: 1));
    expect(_splashVisible(), isTrue);

    await tester.pumpAndSettle();
    expect(_splashVisible(), isFalse);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('skips the animation when animations are disabled', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(SplashGate(ready: Future.value(), child: _child));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_splashVisible(), isFalse);
    expect(find.text('home'), findsOneWidget);
  });
}
