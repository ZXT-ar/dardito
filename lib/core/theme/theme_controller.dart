import 'package:flutter/material.dart';
import 'theme_store.dart';

class SiteThemeController extends ChangeNotifier {
  SiteThemeController({ThemeStore? store}) : _store = store ?? ThemeStore() {
    _dark = _store.read();
    _store.listen((value) {
      if (_dark != value) {
        _dark = value;
        notifyListeners();
      }
    });
  }
  final ThemeStore _store;
  late bool _dark;
  bool get dark => _dark;
  void toggle() {
    _dark = !_dark;
    _store.write(_dark);
    notifyListeners();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }
}

class SiteThemeScope extends InheritedNotifier<SiteThemeController> {
  const SiteThemeScope({
    super.key,
    required SiteThemeController controller,
    required super.child,
  }) : super(notifier: controller);
  static SiteThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SiteThemeScope>()?.notifier;
}

class SiteThemeButton extends StatelessWidget {
  const SiteThemeButton({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = SiteThemeScope.maybeOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Activar modo claro' : 'Activar modo oscuro',
      onPressed: controller?.toggle,
      icon: Icon(
        dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        size: 23,
      ),
    );
  }
}
