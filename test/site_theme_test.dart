import 'package:dardito/app.dart';
import 'package:dardito/core/theme/app_theme.dart';
import 'package:dardito/core/theme/theme_controller.dart';
import 'package:dardito/core/theme/theme_store.dart';
import 'package:dardito/features/home/home_page.dart';
import 'package:dardito/features/explore/explore_page.dart';
import 'package:dardito/features/explore/map/dardito_map_surface.dart';
import 'package:dardito/features/assistant/assistant_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryThemeStore extends ThemeStore {
  bool value = false;
  void Function(bool)? changed;
  @override
  bool read() => value;
  @override
  void write(bool dark) => value = dark;
  @override
  void listen(void Function(bool) callback) => changed = callback;
  void external(bool dark) {
    value = dark;
    changed?.call(dark);
  }
}

void main() {
  test('persiste preferencia y escucha cambios externos', () {
    final store = MemoryThemeStore();
    final first = SiteThemeController(store: store);
    expect(first.dark, false);
    first.toggle();
    expect(store.value, true);
    first.dispose();
    final second = SiteThemeController(store: store);
    expect(second.dark, true);
    var changes = 0;
    second.addListener(() => changes++);
    store.external(false);
    expect(second.dark, false);
    expect(changes, 1);
    second.dispose();
  });
  testWidgets('Inicio, Explorar y chat comparten ambos modos al navegar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = SiteThemeController(store: MemoryThemeStore());
    addTearDown(controller.dispose);
    var page = 0;
    late StateSetter update;
    await tester.pumpWidget(
      SiteThemeScope(
        controller: controller,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: controller.dark ? ThemeMode.dark : ThemeMode.light,
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                void navigate(int index) => setState(() => page = index);
                return DarditoShell(
                  currentIndex: page,
                  onNavigate: navigate,
                  child: KeyedSubtree(
                    key: ValueKey(page),
                    child: switch (page) {
                      0 => HomePage(
                        stories: const [],
                        onExplore: (_) => navigate(1),
                        onExploreCategory: (_) => navigate(1),
                        onNavigate: navigate,
                        onOpenLegal: (_) {},
                      ),
                      1 => ExplorePage(
                        stories: const [],
                        onAskDardito: (_) => navigate(2),
                      ),
                      _ => AssistantPage(
                        stories: const [],
                        onExplore: (_) => navigate(1),
                        onNavigate: navigate,
                      ),
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Activar modo oscuro'));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.dark, true);
    await tester.tap(find.text('Explorar'));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester
          .widget<DarditoMapSurface>(find.byType(DarditoMapSurface))
          .lightTheme,
      false,
    );
    update(() => page = 2);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.dark, false);
    update(() => page = 1);
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester
          .widget<DarditoMapSurface>(find.byType(DarditoMapSurface))
          .lightTheme,
      true,
    );
    await tester.tap(find.byTooltip('Usar mapa oscuro'));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.dark, true);
    await tester.tap(find.text('Inicio'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Activar modo claro'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(HomePage))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
