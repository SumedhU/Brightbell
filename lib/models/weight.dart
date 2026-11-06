class Weight {
  final String date;
  final double weightLbs;
  final dynamic timestamp;

  Weight({required this.date, required this.weightLbs, this.timestamp});

  factory Weight.fromMap(Map<String, dynamic> map) {
    return Weight(
      date: map['date'] ?? '',
      weightLbs: (map['weightLbs'] ?? 0.0).toDouble(),
      timestamp: map['timestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'date': date, 'weightLbs': weightLbs};
    if (timestamp != null) {
      map['timestamp'] = timestamp;
    }
    return map;
  }
}
