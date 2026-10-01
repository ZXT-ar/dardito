import 'package:flutter/material.dart';

import '../../data/models/story.dart';
import '../explore/map/dardito_map_surface.dart';

/// La portada muestra el mismo catálogo y los mismos marcadores que Explorar.
/// El mapa no captura el scroll: pulsarlo abre la experiencia completa.
class HomeMapPreview extends StatelessWidget {
  const HomeMapPreview({
    super.key,
    required this.stories,
    required this.style,
    required this.onExplore,
  });

  final List<CityStory> stories;
  final String? style;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeSemantics(
        child: IgnorePointer(
          child: DarditoMapSurface(
            stories: stories,
            selected: null,
            style: style,
            interactive: false,
            onSelect: (_) => onExplore(),
            onReady: (_) {},
            bottomPadding: 0,
            rightPadding: 0,
          ),
        ),
      ),
      Semantics(
        label: 'Abrir el mapa de historias en Explorar',
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('home-map-open-explore'),
            onTap: onExplore,
            mouseCursor: SystemMouseCursors.click,
            hoverColor: Colors.white.withValues(alpha: .04),
            focusColor: Colors.white.withValues(alpha: .12),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ],
  );
}
