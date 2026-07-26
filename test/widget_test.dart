import 'package:dardito/app.dart';
import 'package:dardito/core/auth/auth_service.dart';
import 'package:dardito/features/legal/legal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra la portada y permite navegar al mapa', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(DarditoApp(authService: _TestAuthService()));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('La Plata tiene\nmiles de historias.'), findsOneWidget);
    expect(find.text('Explorar el mapa'), findsOneWidget);
    expect(find.text('Llevá Dardito con vos'), findsOneWidget);

    await tester.tap(find.text('Explorar'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Explorá La Plata'), findsNothing);
    expect(find.text('Filtros'), findsOneWidget);
    expect(find.text('Todas las categorías'), findsNothing);

    await tester.tap(find.text('Filtros'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Todas las categorías'), findsOneWidget);
    expect(find.textContaining('historias visibles'), findsOneWidget);
  });

  testWidgets('el formulario comunitario renderiza en móvil', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(DarditoApp(authService: _TestAuthService()));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.byIcon(Icons.add_circle_rounded));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Continuar con Gmail'), findsOneWidget);
    await tester.tap(find.text('Continuar con Gmail'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Vos también sos parte\ndel mapa.'), findsOneWidget);
    expect(find.text('demo@gmail.com'), findsOneWidget);
    expect(find.text('Elegir'), findsNWidgets(3));

    await tester.ensureVisible(find.text('Elegir').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir').first);
    await tester.pumpAndSettle();

    expect(find.text('Elegir fotos desde archivos'), findsOneWidget);
    expect(find.textContaining('no usará la cámara'), findsOneWidget);
    expect(find.text('Abrir archivos'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('el centro legal alterna entre términos y privacidad', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: LegalPage(initialDocument: LegalDocument.terms, onBack: () {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Términos y condiciones'), findsWidgets);
    await tester.tap(find.text('Privacidad').first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Política de privacidad'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestAuthService implements AuthService {
  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<AuthUser> signIn(AuthProvider provider) async {
    return _user = const AuthUser(
      id: 'test-user',
      name: 'Usuario de prueba',
      email: 'demo@gmail.com',
      provider: AuthProvider.google,
    );
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }
}
