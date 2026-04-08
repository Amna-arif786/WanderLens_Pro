import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:wanderlens/services/user_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
    'openid',
  ];

  /// Signs in with Google.
  ///
  /// Calls [disconnect] first so the account picker always appears —
  /// important when the device has multiple Google accounts.
  ///
  /// Returns:
  ///   'isNewUser'    → bool
  ///   'tempUserData' → Map?  (only for new users)
  ///
  /// Returns null if the user cancels.
  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    // Clear cached account so the picker is always shown.
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}

    // Show the native Google account picker.
    final GoogleSignInAccount googleUser;
    try {
      googleUser =
          await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw Exception('Google sign-in failed: ${e.description ?? e.code.name}');
    }

    // idToken for Firebase credential (sync getter in v7).
    final String? idToken = googleUser.authentication.idToken;
    if (idToken == null) throw Exception('Google did not return an ID token.');

    // accessToken is optional for Firebase; attempt to fetch but don't fail.
    String? accessToken;
    try {
      final auth = await googleUser.authorizationClient
          .authorizationForScopes(_scopes);
      accessToken = auth?.accessToken;
    } catch (_) {
      // accessToken is not required by Firebase — proceed with idToken only.
    }

    final AuthCredential credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );

    final UserCredential userCredential;
    try {
      userCredential = await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception('Firebase auth failed: ${e.message}');
    }

    final User? firebaseUser = userCredential.user;
    if (firebaseUser == null) throw Exception('Firebase user is null.');

    final existingUser = await UserService.getUserById(firebaseUser.uid);

    return {
      'userCredential': userCredential,
      'isNewUser': existingUser == null,
      'tempUserData': existingUser == null
          ? {
              'id': firebaseUser.uid,
              'email': firebaseUser.email,
              'displayName': firebaseUser.displayName,
              'photoURL': firebaseUser.photoURL,
            }
          : null,
    };
  }

  static Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
