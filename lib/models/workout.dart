import 'package:brightbell/models/exercise.dart';

class Workout {
  final String? docId;
  final String date;
  final String userId;
  final String rawText;
  final List<Exercise> exercises;

  Workout({
    this.docId,
    required this.date,
    required this.userId,
    required this.rawText,
    required this.exercises,
  });

  factory Workout.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Workout(
      docId: docId ?? map['docId'],
      date: map['date'] ?? '',
      userId: map['userId'] ?? '',
      rawText: map['rawText'] ?? '',
      exercises: List<Exercise>.from(
        (map['exercises'] ?? []).map((x) => Exercise.fromMap(x)),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'userId': userId,
      'rawText': rawText,
      'exercises': exercises.map((x) => x.toMap()).toList(),
    };
  }
}
