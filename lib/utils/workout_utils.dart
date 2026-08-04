import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brightbell/models/workout.dart';
import 'package:brightbell/utils/auth_utils.dart';
import 'package:brightbell/utils/user_utils.dart';
import 'package:brightbell/utils/streak_utils.dart';

class WorkoutUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<Workout?> loadWorkoutForDate(String dateStr) async {
    final user = AuthUtils.currentUser;
    if (user == null) return null;

    final snapshot = await _firestore
        .collection('Workouts')
        .where('userId', isEqualTo: user.uid)
        .where('date', isEqualTo: dateStr)
        .get();

    if (snapshot.docs.isNotEmpty) {
      if (snapshot.docs.length == 1) {
        final doc = snapshot.docs.first;
        return Workout.fromMap(doc.data(), docId: doc.id);
      } else {
        // Merge multiple documents to prevent data loss from offline duplicate creation
        List<dynamic> allExercises = [];
        String allText = '';
        String primaryDocId = snapshot.docs.first.id;
        
        for (var doc in snapshot.docs) {
          final workout = Workout.fromMap(doc.data(), docId: doc.id);
          allExercises.addAll(workout.exercises);
          if (allText.isNotEmpty && workout.rawText.isNotEmpty) {
            allText += '\n';
          }
          allText += workout.rawText;
        }

        // Clean up duplicates and save merged data (fire and forget)
        try {
          for (int i = 1; i < snapshot.docs.length; i++) {
            _firestore.collection('Workouts').doc(snapshot.docs[i].id).delete();
          }
          _firestore.collection('Workouts').doc(primaryDocId).update({
            'exercises': allExercises.map((e) => e.toMap()).toList(),
            'rawText': allText,
          });
        } catch (e) {
          // Ignore background cleanup errors
        }
        
        return Workout(
          docId: primaryDocId,
          date: dateStr,
          userId: user.uid,
          rawText: allText,
          exercises: allExercises.cast(),
        );
      }
    }
    return null;
  }

  static Future<String?> saveWorkout(Workout workout) async {
    final user = AuthUtils.currentUser;
    if (user == null) return workout.docId;

    int? currentStreak = workout.currentStreakCount;
    if (workout.docId == null && currentStreak == null) {
      try {
        DateTime parsedDate = DateTime.parse(workout.date);
        final previousWorkouts = await getAllWorkouts();
        final goalDays = await UserUtils.getGoalDays();
        currentStreak = StreakUtils.calculateNextStreak(previousWorkouts, parsedDate, goalDays);
      } catch (e) {
        currentStreak = 1;
      }
    }

    // Ensure the workout has the correct userId before saving
    final dataToSave = workout.toMap();
    if (currentStreak != null) {
      dataToSave['currentStreakCount'] = currentStreak;
    }
    dataToSave['userId'] = user.uid; 

    if (workout.docId != null) {
      await _firestore.collection('Workouts').doc(workout.docId).update(dataToSave);
      return workout.docId;
    } else {
      // Use deterministic document ID based on user and date
      final docId = '${user.uid}_${workout.date}';
      
      // Use set with merge: true to avoid overwriting existing data if it wasn't loaded properly
      await _firestore.collection('Workouts').doc(docId).set(dataToSave, SetOptions(merge: true));
      return docId;
    }
  }

  static Future<List<Workout>> getAllWorkouts() async {
    final user = AuthUtils.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('Workouts')
        .where('userId', isEqualTo: user.uid)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Workout.fromMap(doc.data(), docId: doc.id))
        .toList();
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
