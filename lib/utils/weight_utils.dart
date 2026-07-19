import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brightbell/models/weight.dart';
import 'package:brightbell/utils/auth_utils.dart';

class WeightUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> saveWeight(Weight weight) async {
    final user = AuthUtils.currentUser;
    if (user == null) return;

    final dataToSave = weight.toMap();
    dataToSave['timestamp'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('Users')
        .doc(user.uid)
        .collection('Weights')
        .doc(weight.date)
        .set(dataToSave);
  }

  static Future<List<Weight>> getWeights() async {
    final user = AuthUtils.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('Users')
        .doc(user.uid)
        .collection('Weights')
        .orderBy('date', descending: false)
        .get();

    return snapshot.docs.map((doc) => Weight.fromMap(doc.data())).toList();
  }
}
