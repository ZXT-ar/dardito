import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/story.dart';

abstract interface class DarditoMapController {
  void zoomIn();
  void zoomOut();
}

class DarditoMapSurface extends StatelessWidget {
  const DarditoMapSurface({
    super.key,
    required this.stories,
    required this.selected,
    required this.style,
    required this.onSelect,
    required this.onReady,
    required this.bottomPadding,
    required this.rightPadding,
    this.interactive = true,
    this.lightTheme = false,
    this.onCluster,
  });

  final List<CityStory> stories;
  final CityStory? selected;
  final String? style;
  final ValueChanged<CityStory> onSelect;
  final ValueChanged<DarditoMapController> onReady;
  final double bottomPadding;
  final double rightPadding;
  final bool interactive;
  final bool lightTheme;
  final ValueChanged<List<CityStory>>? onCluster;

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.navy,
    child: Center(
      child: Text(
        'El mapa interactivo está disponible en la aplicación web.',
        style: TextStyle(color: AppColors.cream),
      ),
    ),
  );
}
