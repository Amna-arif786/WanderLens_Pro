import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:wanderlens/services/user_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
    'openid',
  ];

  /// Signs in with Google — platform-aware:
  ///
  ///  • **Web**    → Firebase `signInWithPopup` (Google's popup OAuth flow).
  ///  • **Mobile** → `GoogleSignIn.instance.authenticate()` with a forced
  ///                 account picker (disconnect first so multi-account devices
  ///                 always see the picker).
  ///
  /// Returns:
  ///   'isNewUser'    → bool
  ///   'tempUserData' → Map?  (only for new users — passed to profile-setup)
  ///
  /// Returns null if the user cancels.
  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    final UserCredential userCredential;

    try {
      if (kIsWeb) {
        userCredential = await _signInWithGoogleWeb();
      } else {
        userCredential = await _signInWithGoogleMobile();
      }
    } on _CancelledByUser {
      return null; // user dismissed the picker — treat as no-op
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

  // ── Web ──────────────────────────────────────────────────────────────────

  static Future<UserCredential> _signInWithGoogleWeb() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});
    // 'select_account' forces the account chooser even if one is already
    // signed in — mirrors the mobile behaviour for multi-account devices.
    try {
      return await _auth.signInWithPopup(provider);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        throw _CancelledByUser();
      }
      throw Exception('Google sign-in failed: ${e.message}');
    }
  }

  // ── Mobile / Desktop ─────────────────────────────────────────────────────

  static Future<UserCredential> _signInWithGoogleMobile() async {
    // Disconnect clears cached account → account picker always shown.
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}

    final GoogleSignInAccount googleUser;
    try {
      googleUser =
          await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw _CancelledByUser();
      throw Exception(
          'Google sign-in failed: ${e.description ?? e.code.name}');
    }

    // idToken (sync getter in v7).
    final String? idToken = googleUser.authentication.idToken;
    if (idToken == null) throw Exception('Google did not return an ID token.');

    // accessToken — optional for Firebase, but fetch it when available.
    String? accessToken;
    try {
      final auth =
          await googleUser.authorizationClient.authorizationForScopes(_scopes);
      accessToken = auth?.accessToken;
    } catch (_) {}

    final AuthCredential credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );

    try {
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception('Firebase auth failed: ${e.message}');
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  static Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }
}

/// Internal sentinel thrown when the user cancels the sign-in flow.
/// Caught in the UI layer and treated as a no-op (no snackbar shown).
class _CancelledByUser implements Exception {}
