import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' show GoogleSignIn, GoogleSignInAccount, GoogleSignInAuthentication;
import 'package:wanderlens/services/user_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static Future<Map<String, dynamic>?> signInWithgoogle() async {
    try {
      // Sign out first to ensure account picker
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final existingUser = await UserService.getUserById(firebaseUser.uid);
        
        return {
          'userCredential': userCredential,
          'isNewUser': existingUser == null,
          'tempUserData': existingUser == null ? {
            'id': firebaseUser.uid,
            'email': firebaseUser.email,
            'displayName': firebaseUser.displayName,
            'photoURL': firebaseUser.photoURL,
          } : null,
        };
      }
      return null;
    } catch (e) {
      print('Google Sign-In Error: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Sign-Out Error: $e');
    }
  }
}

extension on GoogleSignInAuthentication {
   String? get accessToken =>this.accessToken;
}
