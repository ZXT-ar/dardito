import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:google_maps/google_maps.dart' as gmaps;
import 'package:web/web.dart' as web;

import '../../../data/models/story.dart';

abstract interface class DarditoMapController {
  void zoomIn();
  void zoomOut();
}

class DarditoMapSurface extends StatefulWidget {
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
  });

  final List<CityStory> stories;
  final CityStory? selected;
  final String? style;
  final ValueChanged<CityStory> onSelect;
  final ValueChanged<DarditoMapController> onReady;
  final double bottomPadding;
  final double rightPadding;
  final bool interactive;

  @override
  State<DarditoMapSurface> createState() => _DarditoMapSurfaceState();
}

class _DarditoMapSurfaceState extends State<DarditoMapSurface> {
  static int _nextViewId = 0;
  late final String _viewType = 'dardito-google-map-${_nextViewId++}';
  gmaps.Map? _map;
  web.HTMLDivElement? _element;
  final List<gmaps.Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (
      int viewId, {
      Object? params,
    }) {
      final element = web.HTMLDivElement()
        ..id = _viewType
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = widget.interactive ? 'auto' : 'none'
        ..style.backgroundColor = '#102937';
      _element = element;
      final map = gmaps.Map(
        element,
        gmaps.MapOptions()
          ..center = gmaps.LatLng(-34.9214, -57.9544)
          ..zoom = 12.2
          ..minZoom = 10.8
          ..maxZoom = 18
          ..gestureHandling = widget.interactive ? 'greedy' : 'none'
          ..draggable = widget.interactive
          ..scrollwheel = widget.interactive
          ..disableDoubleClickZoom = !widget.interactive
          ..keyboardShortcuts = widget.interactive
          ..disableDefaultUI = true
          ..clickableIcons = false
          ..backgroundColor = '#102937'
          ..restriction = (gmaps.MapRestriction()
            ..latLngBounds = gmaps.LatLngBounds(
              gmaps.LatLng(-35.0800, -58.1500),
              gmaps.LatLng(-34.7600, -57.8000),
            )
            ..strictBounds = true)
          ..styles = _decodeStyles(widget.style),
      );
      _map = map;
      _replaceMarkers();
      widget.onReady(_WebDarditoMapController(map));
      return element;
    });
  }

  @override
  void didUpdateWidget(covariant DarditoMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_map != null &&
        (oldWidget.stories != widget.stories ||
            oldWidget.selected?.id != widget.selected?.id)) {
      _replaceMarkers();
    }
    if (_map != null && oldWidget.style != widget.style) {
      _map!.options = gmaps.MapOptions()..styles = _decodeStyles(widget.style);
    }
    if (oldWidget.interactive != widget.interactive) {
      _applyInteractivity();
    }
  }

  void _applyInteractivity() {
    _element?.style.pointerEvents = widget.interactive ? 'auto' : 'none';
    final map = _map;
    if (map == null) return;
    map.options = gmaps.MapOptions()
      ..gestureHandling = widget.interactive ? 'greedy' : 'none'
      ..draggable = widget.interactive
      ..scrollwheel = widget.interactive
      ..disableDoubleClickZoom = !widget.interactive
      ..keyboardShortcuts = widget.interactive;
  }

  List<gmaps.MapTypeStyle>? _decodeStyles(String? source) {
    if (source == null || source.isEmpty) return null;
    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded.map((rawItem) {
      final item = rawItem as Map<String, dynamic>;
      final stylers = (item['stylers'] as List<dynamic>)
          .map((styler) => (styler as Map<String, dynamic>).jsify() as JSObject)
          .toList();
      return gmaps.MapTypeStyle(
        featureType: item['featureType'] as String?,
        elementType: item['elementType'] as String?,
        stylers: stylers.toJS,
      );
    }).toList();
  }

  void _replaceMarkers() {
    final map = _map;
    if (map == null) return;
    for (final marker in _markers) {
      marker.map = null;
    }
    _markers.clear();
    for (final story in widget.stories) {
      final isSelected = story.id == widget.selected?.id;
      final marker = gmaps.Marker(
        gmaps.MarkerOptions()
          ..position = gmaps.LatLng(story.latitude, story.longitude)
          ..map = map
          ..title = story.title
          ..clickable = widget.interactive
          ..cursor = widget.interactive ? 'pointer' : 'default'
          ..optimized = false
          ..icon = _markerIcon(story.category, selected: isSelected)
          ..zIndex = isSelected ? 10 : 1,
      );
      if (widget.interactive) {
        marker.onClick.listen((_) => widget.onSelect(story));
      }
      _markers.add(marker);
    }
  }

  gmaps.Icon _markerIcon(StoryCategory category, {required bool selected}) {
    final size = selected ? 62.0 : 48.0;
    return gmaps.Icon(
      url:
          'data:image/svg+xml;charset=UTF-8,${Uri.encodeComponent(_markerSvg(category, selected: selected))}',
      scaledSize: gmaps.Size(size, size),
      anchor: gmaps.Point(size / 2, size - 3),
    );
  }

  String _markerSvg(StoryCategory category, {required bool selected}) {
    final palette = _categoryPalette(category.id);
    final icon = _categoryGlyph(category.id);
    final halo = selected
        ? '''
          <circle cx="32" cy="30" r="27" fill="${palette.accent}" opacity=".20"/>
          <circle cx="32" cy="30" r="24.5" fill="none" stroke="#FFF8EA" stroke-width="3"/>
        '''
        : '';
    final lift = selected ? 0 : 4;

    return '''
      <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
        <defs>
          <filter id="shadow" x="-35%" y="-30%" width="170%" height="190%">
            <feDropShadow dx="0" dy="4" stdDeviation="3" flood-color="#00131E" flood-opacity=".52"/>
          </filter>
          <linearGradient id="surface" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stop-color="${palette.light}"/>
            <stop offset="1" stop-color="${palette.base}"/>
          </linearGradient>
        </defs>
        <g transform="translate(0 $lift)">
          $halo
          <g filter="url(#shadow)">
            <path d="M32 4C18.2 4 8 14.2 8 27.2c0 17.1 20.6 31.2 22.9 32.7.7.5 1.5.5 2.2 0C35.4 58.4 56 44.3 56 27.2 56 14.2 45.8 4 32 4Z" fill="url(#surface)" stroke="#FFF8EA" stroke-width="2.6"/>
            <path d="M43.5 8.5c-2.7-2-6.2-3.2-9.9-3.4 4.1 1.6 7.3 4.1 9.9 7.4Z" fill="${palette.accent}"/>
            <circle cx="32" cy="27" r="15.2" fill="#FFF8EA"/>
            <circle cx="32" cy="27" r="12.8" fill="${palette.ink}" opacity=".07"/>
            <g transform="translate(20 15)" fill="none" stroke="${palette.ink}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
              $icon
            </g>
          </g>
        </g>
      </svg>
    ''';
  }

  _MarkerPalette _categoryPalette(String categoryId) => switch (categoryId) {
    'architecture' => const _MarkerPalette(
      base: '#B55A3C',
      light: '#D47B58',
      accent: '#FFC000',
      ink: '#562718',
    ),
    'mystery' => const _MarkerPalette(
      base: '#645686',
      light: '#8A79AC',
      accent: '#FFC000',
      ink: '#33274E',
    ),
    'culture' => const _MarkerPalette(
      base: '#A46E20',
      light: '#CF9741',
      accent: '#FFE08A',
      ink: '#52340D',
    ),
    'neighborhood' => const _MarkerPalette(
      base: '#607154',
      light: '#829174',
      accent: '#FFC000',
      ink: '#2F3B29',
    ),
    'memory' => const _MarkerPalette(
      base: '#3F707D',
      light: '#6594A0',
      accent: '#FFC000',
      ink: '#173C46',
    ),
    _ => const _MarkerPalette(
      base: '#C18A2B',
      light: '#DCA94F',
      accent: '#FFC000',
      ink: '#402D0D',
    ),
  };

  String _categoryGlyph(String categoryId) => switch (categoryId) {
    // A classical facade: the clearest small-scale symbol for architecture.
    'architecture' =>
      '''
      <path d="M3 9 12 4l9 5"/><path d="M5 10h14M6 19h12M4 21h16"/>
      <path d="M7 10v9M11 10v9M15 10v9M19 10v9"/>
    ''',
    // A keyhole surrounded by clues/sparks for urban mysteries.
    'mystery' =>
      '''
      <circle cx="12" cy="10" r="4.2"/><path d="M10.2 13.8 9 20h6l-1.2-6.2"/>
      <path d="M4 4v3M2.5 5.5h3M20 3v3M18.5 4.5h3"/>
    ''',
    // Two expressive masks preserve legibility at compact marker sizes.
    'culture' =>
      '''
      <path d="M3 6c2-1.5 5-1.5 7 0v7c-1.7 2.7-5.3 2.7-7 0V6Z"/>
      <path d="M14 5c2-1.5 5-1.5 7 0v8c-1.7 2.7-5.3 2.7-7 0V5Z"/>
      <path d="M5.3 9h.1M7.7 9h.1M16.3 8h.1M18.7 8h.1M5 12c1 .9 2 .9 3 0M16 12c1-.9 2-.9 3 0"/>
    ''',
    // A pair of homes suggests community instead of a generic location pin.
    'neighborhood' =>
      '''
      <path d="m2 12 6-5 6 5v8H4v-8M11 10l5-4 6 5v9h-8"/>
      <path d="M7 20v-5h4v5M17 20v-5h3v5"/>
    ''',
    // A photograph with a heart makes community memory feel human.
    'memory' =>
      '''
      <rect x="2.5" y="4" width="19" height="16" rx="2.5"/>
      <circle cx="8" cy="9" r="2"/>
      <path d="m5 17 4.5-4 3 2.5 2.5-2 4 3.5"/>
      <path d="M15.5 8.8c1-1.3 3.2-.5 3.2 1.1 0 1.5-1.6 2.5-3.2 3.7-1.6-1.2-3.2-2.2-3.2-3.7 0-1.6 2.2-2.4 3.2-1.1Z" fill="${_categoryPalette(categoryId).ink}" stroke="none"/>
    ''',
    _ => '<circle cx="12" cy="12" r="7"/>',
  };

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}

class _MarkerPalette {
  const _MarkerPalette({
    required this.base,
    required this.light,
    required this.accent,
    required this.ink,
  });

  final String base;
  final String light;
  final String accent;
  final String ink;
}

class _WebDarditoMapController implements DarditoMapController {
  _WebDarditoMapController(this.map);
  final gmaps.Map map;

  @override
  void zoomIn() => map.zoom = (map.zoom + 1).clamp(10.8, 18);

  @override
  void zoomOut() => map.zoom = (map.zoom - 1).clamp(10.8, 18);
}
