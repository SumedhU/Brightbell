import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthUtils {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      return null; // User canceled sign in
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  static Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;
}
