import 'package:brightbell/models/exercise.dart';

class Workout {
  final String? docId;
  final String date;
  final String userId;
  final String rawText;
  final String title;
  final List<Exercise> exercises;

  Workout({
    this.docId,
    required this.date,
    required this.userId,
    required this.rawText,
    this.title = 'New Workout',
    required this.exercises,
  });

  factory Workout.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Workout(
      docId: docId ?? map['docId'],
      date: map['date'] ?? '',
      userId: map['userId'] ?? '',
      rawText: map['rawText'] ?? '',
      title: map['title'] ?? 'New Workout',
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
      'title': title,
      'exercises': exercises.map((x) => x.toMap()).toList(),
    };
  }
}
