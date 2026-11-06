import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brightbell/models/exercise.dart';
import 'package:brightbell/models/workout.dart';
import 'package:brightbell/utils/auth_utils.dart';

/// The most recent time an exercise was logged.
class ExerciseHistory {
  final String date;
  final List<Set> sets;

  ExerciseHistory({required this.date, required this.sets});

  String get text => sets.map((s) => s.toText()).join('\n');
}

class WorkoutUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _workouts =>
      _firestore.collection('Workouts');

  static Future<Workout?> loadWorkoutForDate(String dateStr) async {
    final user = AuthUtils.currentUser;
    if (user == null) return null;

    final snapshot = await _workouts
        .where('userId', isEqualTo: user.uid)
        .where('date', isEqualTo: dateStr)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final first = snapshot.docs.first;
    if (snapshot.docs.length == 1) {
      return Workout.fromMap(first.data(), docId: first.id);
    }

    // Older versions could create several docs for one day (e.g. offline).
    // Merge them into the first so no data is lost.
    final List<Exercise> allExercises = [];
    String allText = '';
    for (var doc in snapshot.docs) {
      final workout = Workout.fromMap(doc.data(), docId: doc.id);
      allExercises.addAll(workout.exercises);
      if (allText.isNotEmpty && workout.rawText.isNotEmpty) {
        allText += '\n';
      }
      allText += workout.rawText;
    }

    final batch = _firestore.batch();
    for (var doc in snapshot.docs.skip(1)) {
      batch.delete(doc.reference);
    }
    batch.update(first.reference, {
      'exercises': allExercises.map((e) => e.toMap()).toList(),
      'rawText': allText,
    });
    batch.commit().ignore();

    return Workout(
      docId: first.id,
      date: dateStr,
      userId: user.uid,
      rawText: allText,
      title: Workout.fromMap(first.data()).title,
      exercises: allExercises,
    );
  }

  /// Saves the workout's exercises and returns its document id.
  ///
  /// The title is only written when creating the document (no [Workout.docId]),
  /// so edits to the exercises don't overwrite a title the user renamed.
  static Future<String?> saveWorkout(Workout workout) async {
    final user = AuthUtils.currentUser;
    if (user == null) return workout.docId;

    final data = {
      'date': workout.date,
      'userId': user.uid,
      'rawText': workout.rawText,
      'exercises': workout.exercises.map((x) => x.toMap()).toList(),
    };

    if (workout.docId != null) {
      await _workouts.doc(workout.docId).update(data);
      return workout.docId;
    }

    // Deterministic id per user and date, so a day can't end up with duplicates.
    final docRef = _workouts.doc('${user.uid}_${workout.date}');
    data['title'] = workout.title;
    await docRef.set(data, SetOptions(merge: true));
    return docRef.id;
  }

  static Future<void> updateTitle(String docId, String title) async {
    await _workouts.doc(docId).update({'title': title});
  }

  static Future<List<Workout>> getAllWorkouts() async {
    final user = AuthUtils.currentUser;
    if (user == null) return [];

    final snapshot = await _workouts
        .where('userId', isEqualTo: user.uid)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Workout.fromMap(doc.data(), docId: doc.id))
        .toList();
  }

  static Future<List<Workout>> getWorkoutsPaginated({
    String? lastDate,
    int limit = 10,
  }) async {
    final user = AuthUtils.currentUser;
    if (user == null) return [];

    var query = _workouts
        .where('userId', isEqualTo: user.uid)
        .orderBy('date', descending: true)
        .limit(limit);

    if (lastDate != null) {
      query = query.startAfter([lastDate]);
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => Workout.fromMap(doc.data(), docId: doc.id))
        .toList();
  }

  static Future<void> deleteWorkout(String dateStr) async {
    final user = AuthUtils.currentUser;
    if (user == null) return;

    final snapshot = await _workouts
        .where('userId', isEqualTo: user.uid)
        .where('date', isEqualTo: dateStr)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  static Future<List<DateTime>> getAllWorkoutDates() async {
    final workouts = await getAllWorkouts();
    return workouts
        .map((w) => DateTime.tryParse(w.date))
        .whereType<DateTime>()
        .toList();
  }

  /// The latest logged sets for each exercise (keyed by lowercase name),
  /// looking only at workouts before [beforeDateStr] when given.
  static Future<Map<String, ExerciseHistory>> getLatestExercisesHistory({
    String? beforeDateStr,
  }) async {
    final user = AuthUtils.currentUser;
    if (user == null) return {};

    var query = _workouts.where('userId', isEqualTo: user.uid);
    if (beforeDateStr != null) {
      query = query.where('date', isLessThan: beforeDateStr);
    }

    final snapshot = await query.orderBy('date', descending: true).get();

    final Map<String, ExerciseHistory> history = {};
    for (var doc in snapshot.docs) {
      final workout = Workout.fromMap(doc.data(), docId: doc.id);
      for (var ex in workout.exercises) {
        final name = ex.name.trim().toLowerCase();
        if (!history.containsKey(name) && ex.sets.isNotEmpty) {
          history[name] = ExerciseHistory(date: workout.date, sets: ex.sets);
        }
      }
    }
    return history;
  }
}
