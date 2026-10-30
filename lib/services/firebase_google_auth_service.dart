import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

class FirebaseGoogleAuthService {
  FirebaseGoogleAuthService._();

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static bool _firebaseConfigured = false;
  static bool _googleSignInInitialized = false;

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _firebaseConfigured = Firebase.apps.isNotEmpty;
    } catch (_) {
      // Firebase setup is optional until firebase_options.dart is generated.
      _firebaseConfigured = false;
    }
  }

  static Future<FirebaseGoogleIdentity?> signIn() async {
    if (!_firebaseConfigured || Firebase.apps.isEmpty) {
      throw const FirebaseGoogleAuthException(
        'Configure o Firebase neste app antes de usar o login com Google. '
        'No projeto Flutter, execute flutterfire configure.',
      );
    }

    try {
      final UserCredential credential;
      if (kIsWeb) {
        credential = await FirebaseAuth.instance.signInWithPopup(
          GoogleAuthProvider(),
        );
      } else {
        if (!_googleSignInInitialized) {
          await _googleSignIn.initialize(
            serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
          );
          _googleSignInInitialized = true;
        }
        await _googleSignIn.signOut();

        final GoogleSignInAccount googleUser;
        try {
          googleUser = await _googleSignIn.authenticate();
        } on GoogleSignInException catch (error) {
          if (error.code == GoogleSignInExceptionCode.canceled) return null;
          rethrow;
        }

        final googleIdToken = googleUser.authentication.idToken;
        if (googleIdToken == null || googleIdToken.isEmpty) {
          throw const FirebaseGoogleAuthException(
            'O Google n\u{00E3}o retornou um token. Confira a configura\u{00E7}\u{00E3}o OAuth do app.',
          );
        }
        final googleCredential = GoogleAuthProvider.credential(
          idToken: googleIdToken,
        );
        credential = await FirebaseAuth.instance.signInWithCredential(
          googleCredential,
        );
      }

      final user = credential.user;
      if (user == null) {
        throw const FirebaseGoogleAuthException(
          'O Firebase n\u{00E3}o retornou os dados da conta Google.',
        );
      }
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw const FirebaseGoogleAuthException(
          'N\u{00E3}o foi poss\u{00ED}vel obter o token de autentica\u{00E7}\u{00E3}o do Firebase.',
        );
      }
      return FirebaseGoogleIdentity(idToken: idToken, name: user.displayName);
    } on FirebaseAuthException catch (error) {
      throw FirebaseGoogleAuthException(_firebaseErrorMessage(error));
    } on GoogleSignInException catch (error) {
      throw FirebaseGoogleAuthException(_googleErrorMessage(error));
    }
  }

  static Future<void> signOut() async {
    if (Firebase.apps.isEmpty) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (_googleSignInInitialized) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }

  static String _firebaseErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'operation-not-allowed':
        return 'Ative o provedor Google nas configura\u{00E7}\u{00F5}es do Firebase Authentication.';
      case 'network-request-failed':
        return 'Sem conex\u{00E3}o para autenticar com o Google. Tente novamente.';
      case 'account-exists-with-different-credential':
        return 'Este e-mail j\u{00E1} est\u{00E1} cadastrado usando outro m\u{00E9}todo de login.';
      default:
        return error.message ??
            'N\u{00E3}o foi poss\u{00ED}vel entrar com Google.';
    }
  }

  static String _googleErrorMessage(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'A configura\u{00E7}\u{00E3}o do Google Sign-In est\u{00E1} incompleta. Confira os IDs do app e o SHA-1 no Firebase.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'N\u{00E3}o foi poss\u{00ED}vel abrir a tela de contas Google neste dispositivo.';
      default:
        return error.description ??
            'N\u{00E3}o foi poss\u{00ED}vel entrar com Google.';
    }
  }
}

class FirebaseGoogleIdentity {
  const FirebaseGoogleIdentity({required this.idToken, this.name});

  final String idToken;
  final String? name;
}

class FirebaseGoogleAuthException implements Exception {
  const FirebaseGoogleAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
