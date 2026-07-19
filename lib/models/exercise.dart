class Exercise {
  String name;
  int numberOfSets;
  List<Set> sets;

  Exercise({
    required this.name,
    required this.numberOfSets,
    required this.sets,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'numberOfSets': numberOfSets,
      'sets': sets.map((x) => x.toMap()).toList(),
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      name: map['name'] ?? '',
      numberOfSets: map['numberOfSets']?.toInt() ?? 0,
      sets: List<Set>.from(map['sets']?.map((x) => Set.fromMap(x)) ?? []),
    );
  }
}

class Set {
  int id;
  int numberOfReps;
  double weight;
  bool isWarmUp;
  bool isDropSet;

  Set({
    required this.id,
    required this.numberOfReps,
    required this.weight,
    required this.isWarmUp,
    required this.isDropSet,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numberOfReps': numberOfReps,
      'weight': weight,
      'isWarmUp': isWarmUp,
      'isDropSet': isDropSet,
    };
  }

  factory Set.fromMap(Map<String, dynamic> map) {
    return Set(
      id: map['id']?.toInt() ?? 0,
      numberOfReps: map['numberOfReps']?.toInt() ?? 0,
      weight: map['weight']?.toDouble() ?? 0.0,
      isWarmUp: map['isWarmUp'] ?? false,
      isDropSet: map['isDropSet'] ?? false,
    );
  }

  String toText() {
    String typeStr = isWarmUp ? '(W)' : isDropSet ? '(D)' : '';
    // Format weight without trailing .0 if it's an integer
    String weightStr = weight == weight.roundToDouble()
        ? weight.toInt().toString()
        : weight.toString();
    return '[$numberOfReps, $weightStr]$typeStr';
  }
}
