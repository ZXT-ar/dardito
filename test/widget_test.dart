import 'package:dardito/app.dart';
import 'package:dardito/core/auth/auth_service.dart';
import 'package:dardito/core/platform/browser_location.dart';
import 'package:dardito/core/theme/app_theme.dart';
import 'package:dardito/data/catalogs/story_catalog.dart';
import 'package:dardito/data/models/story.dart';
import 'package:dardito/data/repositories/story_repository.dart';
import 'package:dardito/features/explore/explore_page.dart';
import 'package:dardito/features/explore/map/dardito_map_surface.dart';
import 'package:dardito/features/assistant/assistant_page.dart';
import 'package:dardito/features/assistant/dardito_assistant_service.dart';
import 'package:dardito/features/legal/legal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('grupo permite elegir una historia y abrir su ficha a $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final stories = await _TestStoryRepository(
        allCategories: true,
      ).fetchAll();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ExplorePage(stories: stories, onAskDardito: (_) {}),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      tester
          .widget<DarditoMapSurface>(find.byType(DarditoMapSurface))
          .onCluster!(stories);
      await tester.pumpAndSettle();
      expect(find.text('4 historias en esta zona'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(4));
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      expect(find.text('4 historias en esta zona'), findsNothing);
      expect(find.text('Resumen de una historia pública.'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [390.0, 1440.0]) {
    testWidgets('tarjetas filtran el mapa y permiten restablecer a $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        DarditoApp(
          authService: _TestAuthService(),
          storyRepository: _TestStoryRepository(allCategories: true),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      for (final entry in {
        'Arquitectura': 'architecture',
        'Misterios': 'mystery',
        'Cultura': 'culture',
        'Tradición oral': 'memory',
      }.entries) {
        final card = find.text(entry.key);
        await Scrollable.ensureVisible(tester.element(card), alignment: .5);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(card);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ExplorePage), findsOneWidget);
        expect(find.text(entry.key), findsOneWidget);
        final map = tester.widget<DarditoMapSurface>(
          find.byType(DarditoMapSurface),
        );
        expect(
          map.stories.every((story) => story.category.id == entry.value),
          isTrue,
        );
        expect(map.stories.length, 1);
        await tester.tap(find.text('Restablecer'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          tester
              .widget<DarditoMapSurface>(find.byType(DarditoMapSurface))
              .stories,
          hasLength(4),
        );
        expect(find.text('Todas las categorías'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Return through the app's navigation, then choose a different door.
        if (width < 600) {
          await tester.tap(find.byIcon(Icons.home_rounded));
        } else {
          await tester.tap(find.text('Inicio'));
        }
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }
    });
  }
  test('aplica Lora como primaria e Inter como secundaria', () {
    final textTheme = AppTheme.light.textTheme;

    expect(textTheme.displayLarge?.fontFamily, 'Lora');
    expect(textTheme.headlineMedium?.fontFamily, 'Lora');
    expect(textTheme.titleLarge?.fontFamily, 'Lora');
    expect(textTheme.bodyLarge?.fontFamily, 'Inter');
    expect(textTheme.titleMedium?.fontFamily, 'Inter');
    expect(textTheme.labelLarge?.fontFamily, 'Inter');
  });

  testWidgets('muestra la portada y permite navegar al mapa', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      DarditoApp(
        authService: _TestAuthService(),
        storyRepository: _TestStoryRepository(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('El Mapa de las\nHistorias de La Plata.'), findsOneWidget);
    expect(find.text('EL MAPA DE LAS HISTORIAS DE LA PLATA'), findsNothing);
    expect(find.text('Dardito te ayuda a descubrirlas.'), findsOneWidget);
    expect(find.text('Explorar el mapa'), findsOneWidget);
    expect(find.text('EL MAPA VIVO'), findsOneWidget);
    expect(find.text('Una ciudad imaginada'), findsNothing);
    for (final label in [
      'Arquitectura',
      'Misterios',
      'Cultura',
      'Tradición oral',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/brand/dardito_hero_regenerated_v4.png',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/brand/dardito_seated_phone_v1.png',
      ),
      findsNWidgets(2),
    );
    expect(find.text('Desarrollado por SimbiosisDigital'), findsOneWidget);
    expect(find.text('Privacidad'), findsNothing);
    expect(find.text('Condiciones del servicio'), findsNothing);
    expect(
      find.text('Instrucciones para la eliminación de datos'),
      findsNothing,
    );
    expect(
      tester.getCenter(find.text('Desarrollado por SimbiosisDigital')).dx,
      greaterThan(
        tester
            .getCenter(find.text('© 2026 El Mapa de las Historias de La Plata'))
            .dx,
      ),
    );

    await tester.tap(find.text('Explorar'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Explorá La Plata'), findsNothing);
    expect(find.text('Filtros'), findsOneWidget);
    expect(find.text('Todas las categorías'), findsNothing);
    expect(find.byTooltip('Usar mapa claro'), findsOneWidget);

    await tester.tap(find.byTooltip('Usar mapa claro'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byTooltip('Usar mapa oscuro'), findsOneWidget);

    await tester.tap(find.text('Filtros'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Todas las categorías'), findsOneWidget);
    expect(find.textContaining('historias visibles'), findsNothing);
    expect(find.textContaining('Elegí un punto'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1300));
  });

  testWidgets('el formulario comunitario renderiza en móvil', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      DarditoApp(
        authService: _TestAuthService(),
        storyRepository: _TestStoryRepository(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.byIcon(Icons.add_circle_rounded));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Continuar con Gmail'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Continuar con Gmail'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Continuar con Gmail'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Continuar con Gmail'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Vos también sos parte\ndel mapa.'), findsOneWidget);
    expect(find.text('demo@gmail.com'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/brand/DarditoListening.png',
      ),
      findsOneWidget,
    );
    expect(find.text('Elegir'), findsNWidgets(3));
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(
      find.text('Acepto que me contacten al email con el que me autentifiqué.'),
      findsNothing,
    );

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

  testWidgets('Dardito exige la misma autenticación y consentimiento', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      DarditoApp(
        authService: _TestAuthService(),
        storyRepository: _TestStoryRepository(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.text('Preguntale a Dardito').first);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Antes de conversar,\nqueremos conocerte.'),
      findsOneWidget,
    );
    expect(find.text('Continuar con Gmail'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Declaro que he leído y acepto los '), findsOneWidget);
    expect(find.text('Términos y Condiciones.'), findsOneWidget);
    expect(find.textContaining('Política de privacidad'), findsNothing);
  });

  testWidgets('abre Dardito con la historia seleccionada como contexto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final story = CityStory(
      id: 'bosque-antes-ciudad',
      title: 'El bosque antes de la ciudad',
      subtitle: 'Un paisaje que cambió de sentido',
      category: StoryCatalog.categories.first,
      neighborhood: 'El Bosque',
      period: 'Siglo XIX',
      shortStory: 'Resumen de prueba.',
      fullStory: 'Historia completa de prueba.',
      source: 'Archivo de prueba',
      evidence: 'documented',
      evidenceLabel: 'Documentada',
      mapX: .5,
      mapY: .5,
      latitude: -34.92,
      longitude: -57.95,
    );
    final assistant = _TestAssistantService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantPage(
            stories: [story],
            contextStory: story,
            assistantService: assistant,
            onExplore: (_) {},
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    const contextualMessage =
        'Quiero saber más sobre la historia “El bosque antes de la ciudad”. Contame más.';
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText && widget.data == contextualMessage,
      ),
      findsOneWidget,
    );
    expect(assistant.lastMessage, contextualMessage);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('el centro legal muestra únicamente los términos definitivos', (
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
    expect(find.text('Privacidad'), findsNothing);
    expect(find.textContaining('Documento preliminar'), findsNothing);
    expect(find.textContaining('Texto operativo preliminar'), findsNothing);
    expect(find.text('Envío de aportes'), findsOneWidget);
    expect(
      find.text('Aceptación de los Términos y Condiciones'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/brand/dardito_legal_document_v1.png',
      ),
      findsOneWidget,
    );
    expect(find.text('Desarrollado por SimbiosisDigital'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la sección legal usa la ruta pública solicitada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final browserLocation = _TestBrowserLocation(
      Uri.parse('https://darditohistoriasplatenses.com/'),
    );

    await tester.pumpWidget(
      DarditoApp(
        authService: _TestAuthService(),
        storyRepository: _TestStoryRepository(),
        browserLocation: browserLocation,
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.ensureVisible(find.text('Términos y condiciones'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Términos y condiciones'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(browserLocation.uri.path, '/terminos_y_politicas');
    expect(
      find.text('Reglas claras para cuidar\nlas historias de todos.'),
      findsOneWidget,
    );

    browserLocation.goTo('/');
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('El Mapa de las\nHistorias de La Plata.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('las condiciones del servicio abren únicamente por su ruta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final browserLocation = _TestBrowserLocation(
      Uri.parse(
        'https://darditohistoriasplatenses.com/condiciones_del_servicio',
      ),
    );

    await tester.pumpWidget(
      DarditoApp(
        authService: _TestAuthService(),
        storyRepository: _TestStoryRepository(),
        browserLocation: browserLocation,
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Condiciones del servicio'), findsWidgets);
    expect(find.text('Uso permitido'), findsOneWidget);
    expect(find.text('INFORMACIÓN LEGAL'), findsNothing);
    expect(find.text('Documento vigente'), findsNothing);
    expect(find.text('Documento público'), findsNothing);
    expect(browserLocation.uri.path, '/condiciones_del_servicio');
    expect(tester.takeException(), isNull);
  });

  testWidgets('las instrucciones de eliminación abren por su ruta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final browserLocation = _TestBrowserLocation(
      Uri.parse('https://darditohistoriasplatenses.com/eliminacion_de_datos'),
    );

    await tester.pumpWidget(
      DarditoApp(
        authService: _TestAuthService(),
        storyRepository: _TestStoryRepository(),
        browserLocation: browserLocation,
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    expect(
      find.text('Instrucciones para la eliminación de datos'),
      findsWidgets,
    );
    expect(find.text('Cómo iniciar la solicitud'), findsOneWidget);
    expect(find.text('PRIVACIDAD Y CONTROL'), findsNothing);
    expect(find.text('Procedimiento público'), findsNothing);
    expect(find.text('Documento público'), findsNothing);
    expect(browserLocation.uri.path, '/eliminacion_de_datos');
    expect(tester.takeException(), isNull);
  });

  testWidgets('la grilla limita resultados a 15 y pagina el corpus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final stories = List.generate(
      32,
      (index) => CityStory(
        id: 'story-$index',
        title: 'Historia número ${index + 1}',
        subtitle: 'Una historia de prueba',
        category:
            StoryCatalog.categories[index % StoryCatalog.categories.length],
        neighborhood: index.isEven ? 'Centro' : 'Tolosa',
        period: '${1882 + index}',
        shortStory: 'Resumen público de la historia ${index + 1}.',
        fullStory: 'Relato completo de prueba.',
        source: 'Archivo de prueba',
        evidence: 'documented',
        evidenceLabel: 'Documentada',
        mapX: .5,
        mapY: .5,
        latitude: -34.92,
        longitude: -57.95,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExplorePage(stories: stories, onAskDardito: (_) {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Filtros'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Todas las categorías'), findsOneWidget);
    expect(find.text('Todos los barrios'), findsOneWidget);
    expect(find.text('Todos los períodos'), findsOneWidget);
    expect(find.text('32 historias'), findsOneWidget);

    final periodMenuInkWell = find.ancestor(
      of: find.text('Todos los períodos'),
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(periodMenuInkWell).onTap!();
    await tester.pump(const Duration(milliseconds: 250));
    final firstPeriodOption = find.ancestor(
      of: find.text('1882'),
      matching: find.byType(MenuItemButton),
    );
    tester.widget<MenuItemButton>(firstPeriodOption).onPressed!();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('1 historia'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Todas las categorías'), findsOneWidget);
    expect(find.text('Todos los barrios'), findsOneWidget);
    expect(find.text('1882'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Todos los tipos'), findsNothing);
    expect(find.text('Mostrando 1–1 de 1 historias'), findsOneWidget);

    await tester.tap(find.text('Restablecer'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Mostrando 1–15 de 32 historias'), findsOneWidget);
    expect(find.text('Historia número 1'), findsOneWidget);
    expect(find.text('Historia número 16'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Historia número 16');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mostrando 1–1 de 1 historias'), findsOneWidget);
    expect(find.text('Historia número 16'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}

class _TestAuthService implements AuthService {
  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<AuthUser> signIn(
    AuthProvider provider, {
    required AuthConsent consent,
  }) async {
    if (!consent.accepted) throw StateError('Consentimiento requerido');
    return _user = const AuthUser(
      id: 'test-user',
      name: 'Usuario de prueba',
      email: 'demo@gmail.com',
      provider: AuthProvider.google,
    );
  }

  @override
  Future<AuthAccessStatus> checkAccess() async =>
      AuthAccessStatus(allowed: _user != null);

  @override
  Future<void> signOut() async {
    _user = null;
  }
}

class _TestStoryRepository implements StoryRepository {
  _TestStoryRepository({this.allCategories = false});
  final bool allCategories;
  @override
  Future<List<CityStory>> fetchAll({bool forceRefresh = false}) async => [
    for (final category
        in allCategories
            ? StoryCatalog.categories.where(
                (item) => [
                  'architecture',
                  'mystery',
                  'culture',
                  'memory',
                ].contains(item.id),
              )
            : [StoryCatalog.categories.first])
      CityStory(
        id: allCategories ? 'test-${category.id}' : 'test-story',
        title: 'Historia de prueba',
        subtitle: 'Una historia remota de prueba',
        category: category,
        neighborhood: 'Centro',
        period: '1882',
        shortStory: 'Resumen de una historia pública.',
        fullStory: 'Relato completo de una historia pública de prueba.',
        source: 'Archivo de prueba',
        evidence: 'documented',
        evidenceLabel: 'Documentada',
        mapX: .5,
        mapY: .5,
        latitude: -34.92,
        longitude: -57.95,
        featured: true,
        readMinutes: 3,
      ),
  ];

  @override
  void dispose() {}
}

class _TestAssistantService implements DarditoAssistantService {
  String? lastMessage;

  @override
  Future<DarditoAssistantReply> send({
    required String message,
    required String conversationId,
    required String sessionId,
  }) async {
    lastMessage = message;
    return DarditoAssistantReply(
      answer: 'Respuesta contextual de prueba.',
      conversationId: conversationId,
      sourceIds: const ['bosque-antes-ciudad'],
      moderationAction: 'none',
      yellowCount: 0,
    );
  }
}

class _TestBrowserLocation implements BrowserLocationController {
  _TestBrowserLocation(this._uri);

  Uri _uri;
  BrowserLocationListener? _listener;

  @override
  Uri get uri => _uri;

  @override
  void pushPath(String path) {
    _uri = _uri.resolve(path);
  }

  @override
  void replacePath(String path) {
    _uri = _uri.resolve(path);
  }

  @override
  void listen(BrowserLocationListener listener) {
    _listener = listener;
  }

  void goTo(String path) {
    _uri = _uri.resolve(path);
    _listener?.call(_uri);
  }

  @override
  void dispose() {
    _listener = null;
  }
}
