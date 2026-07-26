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
    final height = selected ? 72.0 : 56.0;
    final width = selected ? 82.0 : 64.0;
    return gmaps.Icon(
      url: _markerAsset(category.id),
      scaledSize: gmaps.Size(width, height),
      anchor: gmaps.Point(width / 2, height * .94),
    );
  }

  String _markerAsset(String categoryId) => switch (categoryId) {
    'architecture' =>
      'assets/assets/images/map_markers_v2/optimized/architecture.png',
    'mystery' => 'assets/assets/images/map_markers_v2/optimized/mysteries.png',
    'culture' => 'assets/assets/images/map_markers_v2/optimized/culture.png',
    'neighborhood' =>
      'assets/assets/images/map_markers_v2/optimized/neighborhoods.png',
    'memory' =>
      'assets/assets/images/map_markers_v2/optimized/living_memory.png',
    _ => 'assets/assets/images/map_markers_v2/optimized/architecture.png',
  };

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}

class _WebDarditoMapController implements DarditoMapController {
  _WebDarditoMapController(this.map);
  final gmaps.Map map;

  @override
  void zoomIn() => map.zoom = (map.zoom + 1).clamp(10.8, 18);

  @override
  void zoomOut() => map.zoom = (map.zoom - 1).clamp(10.8, 18);
}
