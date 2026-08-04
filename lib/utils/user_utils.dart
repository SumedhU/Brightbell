import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brightbell/utils/auth_utils.dart';

class UserUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<int>> getGoalDays() async {
    final user = AuthUtils.currentUser;
    if (user == null) return [1, 2, 3, 4, 5, 6, 7];

    final doc = await _firestore.collection('Users').doc(user.uid).get();
    if (doc.exists && doc.data() != null && doc.data()!.containsKey('goalDays')) {
      final data = doc.data()!['goalDays'] as List<dynamic>;
      return data.map((e) => e as int).toList();
    }
    return [1, 2, 3, 4, 5, 6, 7];
  }

  static Future<void> saveGoalDays(List<int> goalDays) async {
    final user = AuthUtils.currentUser;
    if (user == null) return;

    await _firestore.collection('Users').doc(user.uid).set({
      'goalDays': goalDays,
    }, SetOptions(merge: true));
  }
}
