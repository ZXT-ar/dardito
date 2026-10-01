import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

enum AuthProvider { google }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.provider,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String email;
  final AuthProvider provider;
  final String? photoUrl;
}

class AuthConsent {
  const AuthConsent({
    required this.accepted,
    this.termsVersion = '2026-08-15',
    this.privacyVersion = '2026-08-15',
  });

  final bool accepted;
  final String termsVersion;
  final String privacyVersion;
}

class AuthAccessStatus {
  const AuthAccessStatus({required this.allowed, this.reason});
  final bool allowed;
  final String? reason;
}

abstract interface class AuthService {
  AuthUser? get currentUser;
  Future<AuthUser> signIn(
    AuthProvider provider, {
    required AuthConsent consent,
  });
  Future<AuthAccessStatus> checkAccess();
  Future<void> signOut();
}

class FirebaseAuthService extends ChangeNotifier implements AuthService {
  FirebaseAuthService({firebase_auth.FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance {
    _subscription = _firebaseAuth.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  final firebase_auth.FirebaseAuth _firebaseAuth;
  late final Stream<firebase_auth.User?> _authStateStream = _firebaseAuth
      .authStateChanges();
  late final StreamSubscription<firebase_auth.User?> _subscription;

  Stream<firebase_auth.User?> get authStateChanges => _authStateStream;

  @override
  AuthUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) return null;
    return AuthUser(
      id: user.uid,
      name: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'Explorador/a de La Plata',
      email: user.email!,
      provider: AuthProvider.google,
      photoUrl: user.photoURL,
    );
  }

  @override
  Future<AuthUser> signIn(
    AuthProvider provider, {
    required AuthConsent consent,
  }) async {
    if (!consent.accepted) {
      throw StateError('Debés aceptar los términos y condiciones.');
    }
    final googleProvider = firebase_auth.GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    final credential = kIsWeb
        ? await _firebaseAuth.signInWithPopup(googleProvider)
        : await _firebaseAuth.signInWithProvider(googleProvider);
    final firebaseUser = credential.user;
    if (firebaseUser == null || firebaseUser.email == null) {
      throw StateError('Google no devolvió una identidad válida.');
    }
    await _registerProfile(firebaseUser, consent);
    notifyListeners();
    return currentUser!;
  }

  Future<void> _registerProfile(
    firebase_auth.User user,
    AuthConsent consent,
  ) async {
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw StateError('No fue posible validar la sesión de Google.');
    }
    final response = await http
        .post(
          BackendConfig.profileEndpoint,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'consent': {
              'accepted': consent.accepted,
              'termsVersion': consent.termsVersion,
              'privacyVersion': consent.privacyVersion,
            },
            'client': {
              'platform': defaultTargetPlatform.name,
              'isWeb': kIsWeb,
              'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
              'timeZone': DateTime.now().timeZoneName,
              'timeZoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
            },
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await _firebaseAuth.signOut();
      throw StateError(
        'No pudimos crear tu perfil seguro. Intentá nuevamente.',
      );
    }
  }

  @override
  Future<AuthAccessStatus> checkAccess() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return const AuthAccessStatus(allowed: false);
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      return const AuthAccessStatus(allowed: false, reason: 'invalid_session');
    }
    try {
      final response = await http
          .post(
            BackendConfig.accessEndpoint,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'client': {
                'platform': defaultTargetPlatform.name,
                'isWeb': kIsWeb,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      final reason = decoded is Map<String, dynamic>
          ? decoded['reason'] as String?
          : null;
      return AuthAccessStatus(
        allowed: response.statusCode == 200,
        reason: reason,
      );
    } catch (_) {
      return const AuthAccessStatus(allowed: false, reason: 'unavailable');
    }
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
