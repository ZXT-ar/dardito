import 'dart:convert';
import 'package:dardito/features/assistant/chat_session_store.dart';
import 'dart:io';
import 'dart:async';
import 'package:dardito/app.dart';
import 'dart:ui' as ui;

import 'package:dardito/core/theme/app_theme.dart';
import 'package:dardito/features/assistant/assistant_page.dart';
import 'package:dardito/features/assistant/assistant_response.dart';
import 'package:dardito/features/assistant/reading_palette.dart';
import 'package:dardito/features/assistant/response_entities.dart';
import 'package:dardito/features/assistant/dardito_assistant_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const answer =
    '## El día que nació La Plata\n\n'
    'La Plata fue fundada el **19 de noviembre de 1882** para ser la capital de la provincia de Buenos Aires.\n\n'
    '**Una ciudad pensada en detalle**\n'
    'Diagonales, plazas y espacios verdes dieron forma a su identidad.\n\n'
    '- Las plazas forman parte del trazado.\n'
    '- Las diagonales conectan distintos puntos de la ciudad.\n\n'
    'No tengo información suficiente para confirmar otros detalles.';

const narrativeAnswer =
    '¡Hola! Qué lindo que quieras sumergirte en los secretos que esconden nuestras diagonales céntricas. El corazón de La Plata tiene guardadas varias historias fascinantes que oscilan entre la realidad histórica y los mitos urbanos que corren de boca en boca.\n\n'
    'Por un lado, tenemos un hecho con fuerte respaldo histórico. Se trata de **los primeros habitantes de la Plaza San Martín**. A pocos días de fundarse la ciudad, se descubrieron restos óseos indígenas en la zona de la plaza, justo frente a donde hoy se erigen los palacios de gobierno. El mismísimo perito Francisco Pascasio Moreno observó que pertenecían a comunidades pampas o querandís. Esta historia está plenamente **documentada** y nos revela la preexistencia comunitaria en el mismísimo suelo donde se diseñó el centro político platense.\n\n'
    'Por otro lado, si nos movemos hacia el ámbito de las leyendas urbanas, encontramos un clásico **aporte de vecinos: el mito de la cárcel universitaria**. Desde hace décadas, entre los estudiantes de la Universidad Nacional de La Plata corre el rumor de que el edificio de "Tres Facultades", construido a fines de los años 60, fue hecho siguiendo los planos de una prisión panóptica francesa.';

const albertiAnswer =
    '¿Alguna vez escuchaste hablar del refugio subterráneo del Parque Alberti, ahí en la zona de calles 25 y 38? En el barrio de La Loma siempre corrió el mito de que existían túneles secretos en esa plaza. Esta es una **historia documentada** por el investigador Nicolás Colombo en su libro *Misterios de la ciudad de La Plata*, y tiene una base muy real.\n\n'
    'Resulta que en el año 2004, un grupo de vecinos logró recuperar un espacio subterráneo que estaba abandonado. Al bajar una escalera de veintidós escalones, se encontraron con un gran salón de unos 140 metros cuadrados. Lejos de ser un pasadizo de película, el lugar había funcionado hasta la década de 1950 como una usina eléctrica para el tranvía (o trolebús).\n\n'
    'Aunque en su momento los vecinos tuvieron la hermosa idea de transformarlo en una biblioteca o un centro cultural, el proyecto no prosperó de inmediato. De todas formas, ese gran salón bajo la plaza quedó en el recuerdo y en la curiosidad de los platenses.';

class _Service implements DarditoAssistantService {
  _Service(this.response);
  final String response;
  @override
  Future<DarditoAssistantReply> send({
    required String message,
    required String conversationId,
    required String sessionId,
  }) async => DarditoAssistantReply(
    answer: response,
    conversationId: conversationId,
    sourceIds: const [],
    moderationAction: 'none',
    yellowCount: 0,
  );
}

class _PendingService implements DarditoAssistantService {
  final reply = Completer<DarditoAssistantReply>();
  @override
  Future<DarditoAssistantReply> send({
    required String message,
    required String conversationId,
    required String sessionId,
  }) => reply.future;
}

class _MemorySessionStore extends ChatSessionStore {
  final values = <String, String>{};
  @override
  String? read(String userId) => values[userId];
  @override
  void write(String userId, String value) {
    values[userId] = value;
  }

  @override
  void clear(String userId) {
    values.remove(userId);
  }
}

void main() {
  testWidgets('menú compacto hereda el modo oscuro y reduce sus esquinas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AssistantPage(
            stories: const [],
            onExplore: (_) {},
            onNavigate: (_) {},
            assistantService: _Service(answer),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Activar modo oscuro'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();
    expect(find.text('MENÚ'), findsOneWidget);
    expect(find.text('MENÚ DARDITO'), findsNothing);
    expect(
      Theme.of(tester.element(find.text('MENÚ'))).brightness,
      Brightness.dark,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).borderRadius ==
                BorderRadius.circular(14),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Cerrar menú'));
    await tester.pumpAndSettle();
    expect(find.text('MENÚ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'restaura conversación y borrador por cuenta; sesión nueva no los hereda',
    (tester) async {
      final cache = _MemorySessionStore();
      Widget page(String user) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AssistantPage(
            key: ValueKey(user),
            userId: user,
            sessionStore: cache,
            stories: const [],
            onExplore: (_) {},
            onNavigate: (_) {},
            assistantService: _Service('Respuesta conservada'),
          ),
        ),
      );
      await tester.pumpWidget(page('uno'));
      await tester.enterText(find.byType(TextField), 'Mi pregunta');
      await tester.tap(find.byTooltip('Enviar pregunta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Mi borrador');
      final conversation = jsonDecode(cache.read('uno')!)['conversationId'];
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(page('uno'));
      await tester.pumpAndSettle();
      expect(find.text('Respuesta conservada'), findsOneWidget);
      expect(find.text('Mi borrador'), findsOneWidget);
      expect(find.text('Vos'), findsOneWidget);
      final question = tester.widget<SelectableText>(
        find.widgetWithText(SelectableText, 'Mi pregunta'),
      );
      expect(question.textAlign, TextAlign.right);
      await tester.enterText(find.byType(TextField), 'Otra pregunta');
      await tester.tap(find.byTooltip('Enviar pregunta'));
      await tester.pumpAndSettle();
      expect(jsonDecode(cache.read('uno')!)['conversationId'], conversation);
      await tester.pumpWidget(page('dos'));
      await tester.pumpAndSettle();
      expect(find.text('Respuesta conservada'), findsNothing);
      cache.clear('uno');
      await tester.pumpWidget(page('uno'));
      await tester.pumpAndSettle();
      expect(find.text('Respuesta conservada'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('En se presenta arriba del año y el mes después del día', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: AssistantResponse(
            text:
                'En 1885 comenzó. El 19 de noviembre de 1882 se fundó La Plata. La historia de la ciudad se puede recorrer entre sus plazas y sus diagonales, recordando los lugares y las personas que forman parte de la memoria colectiva.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('En')).dy,
      lessThan(tester.getTopLeft(find.text('1885')).dy),
    );
    expect(
      tester.getTopLeft(find.text('de noviembre de 1882')).dy,
      greaterThan(tester.getTopLeft(find.text('19')).dy),
    );
  });

  testWidgets(
    'mobile permite desplazar el texto dentro del input',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AssistantPage(
              stories: const [],
              onExplore: (_) {},
              onNavigate: (_) {},
              assistantService: _Service('Respuesta'),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'Primero\nSegundo\nTercero\nCuarto\nÚltimo',
      );
      await tester.pumpAndSettle();
      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      final offset = editable.renderEditable.offset;
      final before = offset.pixels;
      expect(before, greaterThan(0));
      await tester.drag(find.byType(EditableText), const Offset(0, 90));
      await tester.pumpAndSettle();
      expect(offset.pixels, lessThan(before));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        endsWith('Último'),
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'input limita a 350, se contrae con scroll y Enter envía en desktop',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AssistantPage(
              stories: const [],
              onExplore: (_) {},
              onNavigate: (_) {},
              assistantService: _Service('Respuesta breve'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byType(TextField);
      await tester.enterText(input, 'Primero\nSegundo');
      await tester.pumpAndSettle();
      final twoLines = tester.getSize(input).height;
      await tester.enterText(input, 'Primero\nSegundo\nTercero');
      await tester.pumpAndSettle();
      expect(tester.getSize(input).height, lessThan(twoLines));
      expect(
        tester.widget<TextField>(input).maxLines,
        isNull,
      ); // vertical wrapped scrolling
      await tester.enterText(input, 'a' * 351);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(input).controller!.text.characters.length,
        350,
      );
      await tester.enterText(input, 'Pregunta con Enter');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(find.text('Respuesta breve'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Respuesta breve'), findsOneWidget);
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'night library history navigates to actual turns and shell keeps one masthead',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? destination;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DarditoShell(
            currentIndex: 2,
            onNavigate: (value) => destination = value,
            child: AssistantPage(
              stories: const [],
              onExplore: (_) {},
              onNavigate: (value) => destination = value,
              assistantService: _Service(albertiAnswer),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.byTooltip('Activar modo oscuro'), findsOneWidget);
      await tester.tap(find.byTooltip('Activar modo oscuro'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Activar modo claro'), findsOneWidget);
      final inputContext = tester.element(find.byType(TextField));
      expect(Theme.of(inputContext).brightness, Brightness.dark);
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration?.fillColor,
        const ReadingPalette(true).paper,
      );
      final responseContext = tester.element(
        find.byType(AssistantResponse).first,
      );
      expect(
        Theme.of(responseContext).textTheme.bodyLarge?.color,
        const ReadingPalette(true).ink,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color ==
                  const ReadingPalette(true).paper,
        ),
        findsWidgets,
      );

      for (final question in ['Primera pregunta', 'Segunda pregunta']) {
        await tester.enterText(find.byType(TextField), question);
        await tester.tap(find.byTooltip('Enviar pregunta'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      }
      // Changing the reading palette must retain the conversation and input.
      await tester.enterText(find.byType(TextField), 'Borrador sin enviar');
      await tester.tap(find.byTooltip('Activar modo claro'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Activar modo oscuro'), findsOneWidget);
      expect(find.text('Borrador sin enviar'), findsOneWidget);
      expect(find.byTooltip('Copiar respuesta'), findsNWidgets(3));
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('chat-scroll')),
          )
          .controller!;
      final before = scroll.offset;
      await tester.tap(find.widgetWithText(TextButton, 'Primera pregunta'));
      await tester.pumpAndSettle();
      expect(scroll.offset, lessThan(before));
      await tester.tap(find.widgetWithText(TextButton, 'Explorar'));
      expect(destination, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading and failed requests remain usable on the dark canvas', (
    tester,
  ) async {
    final service = _PendingService();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AssistantPage(
            stories: const [],
            onExplore: (_) {},
            onNavigate: (_) {},
            assistantService: service,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Una pregunta');
    await tester.tap(find.byTooltip('Enviar pregunta'));
    await tester.pump();
    expect(find.text('Dardito está buscando…'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    service.reply.completeError(Exception('test unavailable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Dardito está buscando…'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(find.byType(AssistantResponse), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  test('extracts literal dates, quantities and names without guessing', () {
    final entities = ResponseEntities.parse(albertiAnswer);
    for (final value in [
      'el año 2004',
      'hasta la década de 1950',
      'veintidós escalones',
      'unos 140 metros cuadrados',
      'Nicolás Colombo',
      'Parque Alberti',
    ]) {
      expect(entities.any((e) => e.text == value), isTrue, reason: value);
    }
    expect(
      entities.singleWhere((e) => e.text == 'veintidós escalones').value,
      'veintidós',
    );
    expect(
      entities
          .singleWhere((e) => e.text == 'unos 140 metros cuadrados')
          .caption,
      'unos metros cuadrados',
    );
    final tricky = ResponseEntities.parse(
      'No se confirmó: entre 1881 y 1883. Calle 2004. https://example.com/1950/140',
    );
    expect(tricky.where((e) => e.value != null), isEmpty);
    expect(
      tricky.where((e) => e.kind == ResponseEntityKind.date).single.text,
      'entre 1881 y 1883',
    );
  });
  testWidgets('conserva matices, enlaces y fechas en su contexto', (
    tester,
  ) async {
    const text =
        'No se confirmó el 19 de noviembre de 1882.\n\n'
        'Versiones: 1881–1883; https://example.com/fuente\n'
        'Texto **sin cerrar y <script>literal</script>.';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AssistantResponse(text: text)),
      ),
    );
    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
        .join('\n');
    expect(rendered, contains('No se confirmó el 19 de noviembre de 1882.'));
    expect(
      rendered,
      contains('Versiones: 1881–1883; https://example.com/fuente'),
    );
    expect(
      rendered,
      contains('Texto **sin cerrar y <script>literal</script>.'),
    );
    expect(tester.takeException(), isNull);
  });

  for (final response in [answer, narrativeAnswer, albertiAnswer]) {
    for (final width in [320.0, 390.0, 768.0, 1440.0]) {
      for (final scale in [1.0, 1.8]) {
        testWidgets(
          'chat ${response == answer
              ? 'estructurado'
              : response == albertiAnswer
              ? 'alberti'
              : 'narrativo'} a $width px y escala $scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 1100);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            for (final family in ['Inter', 'Lora']) {
              final loader = FontLoader(family)
                ..addFont(rootBundle.load('assets/fonts/$family-Variable.ttf'));
              await loader.load();
            }
            final icons = FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
            await icons.load();
            final capture = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: capture,
                  child: Scaffold(
                    body: AssistantPage(
                      stories: const [],
                      onExplore: (_) {},
                      onNavigate: (_) {},
                      assistantService: _Service(response),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            if (Platform.environment['DARDITO_DARK_CAPTURE'] == '1') {
              await tester.tap(find.byTooltip('Activar modo oscuro'));
              await tester.pumpAndSettle();
            }
            await tester.enterText(
              find.byType(TextField),
              response == answer
                  ? '¿Cómo nació La Plata?'
                  : 'Contame misterios del centro',
            );
            await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
            await tester.pump(const Duration(milliseconds: 100));
            await tester.pumpAndSettle();
            await tester.drag(
              find.byKey(const ValueKey('chat-scroll')),
              const Offset(0, -1800),
            );
            await tester.pumpAndSettle();
            expect(find.byType(AssistantResponse), findsWidgets);
            expect(
              find.text('Preguntá.\nExplorá.\nVolvé a mirar.'),
              findsNothing,
            );
            if (response == albertiAnswer) {
              for (final value in [
                '2004',
                '1950',
                '140',
                'veintidós',
                'Parque Alberti',
              ]) {
                expect(find.text(value), findsOneWidget);
              }
            }
            expect(tester.takeException(), isNull);
            final content = tester
                .widgetList<Text>(find.byType(Text))
                .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
                .join('\n');
            expect(
              content,
              contains(
                response == answer
                    ? 'No tengo información suficiente para confirmar otros detalles.'
                    : response == albertiAnswer
                    ? 'curiosidad de los platenses.'
                    : 'prisión panóptica francesa.',
              ),
            );
            expect(content, isNot(contains('Para mirar con otros ojos')));
            if (response == narrativeAnswer) {
              expect(
                find.text('los primeros habitantes de la Plaza San Martín'),
                findsOneWidget,
              );
              expect(
                find.text(
                  'aporte de vecinos: el mito de la cárcel universitaria',
                ),
                findsOneWidget,
              );
              expect(content, contains('corre el rumor'));
            }
            expect(find.text('Ver en el mapa'), findsNothing);
            if (response == answer) {
              expect(find.text('19'), findsOneWidget);
              expect(find.text('de noviembre de 1882'), findsOneWidget);
            }
            if (Platform.environment['DARDITO_CAPTURE'] == '1' && scale == 1) {
              final boundary =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              await tester.runAsync(() async {
                final image = await boundary.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  'outputs/chat-${Platform.environment['DARDITO_DARK_CAPTURE'] == '1' ? 'oscuro' : 'claro'}-20261002/${response == answer
                      ? 'estructurado'
                      : response == albertiAnswer
                      ? 'alberti'
                      : 'narrativo'}-${width.toInt()}.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          },
        );
      }
    }
  }
}
