import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brightbell/components/add_sets.dart';
import 'package:brightbell/models/exercise.dart' as models;

void main() {
  testWidgets('slides up, edits sets and returns the exercise', (tester) async {
    // Small phone, to catch layout overflow.
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    models.Exercise? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await AddSets.show(
                context,
                exerciseName: 'Bench Press',
                initialSets: [
                  models.Set(
                    id: 1,
                    numberOfReps: 8,
                    weight: 135,
                    isWarmUp: false,
                    isDropSet: false,
                  ),
                ],
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 100));
    // Still sliding in partway through the animation.
    expect(find.text('Bench Press'), findsOneWidget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Set'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Failure').last);
    await tester.pumpAndSettle();
    expect(find.text('F'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Bench Press');
    expect(result!.sets.length, 2);
    expect(result!.sets.last.isFailure, isTrue);
    expect(find.text('Add Set'), findsNothing);
  });

  testWidgets('saving without reps shows a message instead of closing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => AddSets.show(context, exerciseName: 'Squat'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Add reps to at least one set'), findsOneWidget);
    expect(find.text('Add Set'), findsOneWidget);
  });
}
