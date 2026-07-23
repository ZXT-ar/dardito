import 'package:flutter/foundation.dart';

enum AuthProvider { google, apple }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.provider,
  });

  final String id;
  final String name;
  final String email;
  final AuthProvider provider;
}

abstract interface class AuthService {
  AuthUser? get currentUser;
  Future<AuthUser> signIn(AuthProvider provider);
  Future<void> signOut();
}

/// Implementación temporal para probar el recorrido completo sin credenciales.
/// Se reemplaza por OAuthAuthService al conectar Google/Apple y el backend.
class DemoAuthService extends ChangeNotifier implements AuthService {
  AuthUser? _currentUser;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<AuthUser> signIn(AuthProvider provider) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    _currentUser = AuthUser(
      id: 'demo-user',
      name: 'Explorador/a de La Plata',
      email: provider == AuthProvider.google
          ? 'demo@gmail.com'
          : 'demo@icloud.com',
      provider: provider,
    );
    notifyListeners();
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
  }
}
