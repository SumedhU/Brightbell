import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brightbell/models/workout.dart';
import 'package:brightbell/utils/auth_utils.dart';

class WorkoutUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<Workout?> loadWorkoutForDate(String dateStr) async {
    final user = AuthUtils.currentUser;
    if (user == null) return null;

    final snapshot = await _firestore
        .collection('Workouts')
        .where('userId', isEqualTo: user.uid)
        .where('date', isEqualTo: dateStr)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      return Workout.fromMap(doc.data(), docId: doc.id);
    }
    return null;
  }

  static Future<String?> saveWorkout(Workout workout) async {
    final user = AuthUtils.currentUser;
    if (user == null) return workout.docId;

    // Ensure the workout has the correct userId before saving
    final dataToSave = workout.toMap();
    dataToSave['userId'] = user.uid; 

    if (workout.docId != null) {
      await _firestore.collection('Workouts').doc(workout.docId).update(dataToSave);
      return workout.docId;
    } else {
      final docRef = await _firestore.collection('Workouts').add(dataToSave);
      return docRef.id;
    }
  }

  static Future<List<DateTime>> getAllWorkoutDates() async {
    final user = AuthUtils.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('Workouts')
        .where('userId', isEqualTo: user.uid)
        .get();

    List<DateTime> dates = [];
    for (var doc in snapshot.docs) {
      final dateStr = doc.data()['date'] as String?;
      if (dateStr != null) {
        try {
          dates.add(DateTime.parse(dateStr));
        } catch (e) {
          // Ignore parse errors
        }
      }
    }
    return dates;
  }

  static Future<Map<String, Map<String, String>>> getLatestExercisesHistory({String? beforeDateStr}) async {
    final user = AuthUtils.currentUser;
    if (user == null) return {};

    var query = _firestore
        .collection('Workouts')
        .where('userId', isEqualTo: user.uid);

    if (beforeDateStr != null) {
      query = query.where('date', isLessThan: beforeDateStr);
    }

    final snapshot = await query
        .orderBy('date', descending: true)
        .get();

    Map<String, Map<String, String>> history = {};
    for (var doc in snapshot.docs) {
      final workout = Workout.fromMap(doc.data(), docId: doc.id);
      final date = workout.date;
      final exercises = workout.exercises;
      
      for (var ex in exercises) {
        final name = ex.name.trim().toLowerCase();
        if (!history.containsKey(name)) {
          final sets = ex.sets;
          if (sets.isNotEmpty) {
            String setsText = '';
            for (var set in sets) {
              setsText += set.toText() + '\n';
            }
            history[name] = {
              'text': setsText.trim(),
              'date': date,
            };
          }
        }
      }
    }
    return history;
  }
}
