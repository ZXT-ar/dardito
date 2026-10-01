import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/theme/app_theme.dart';
import '../../core/analytics/usage_analytics_service.dart';
import '../../data/models/story.dart';
import '../../data/catalogs/story_catalog.dart';
import '../story/story_widgets.dart';
import 'map/dardito_map_surface.dart';

String _normalizeSearch(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàäâ]'), 'a')
    .replaceAll(RegExp('[éèëê]'), 'e')
    .replaceAll(RegExp('[íìïî]'), 'i')
    .replaceAll(RegExp('[óòöô]'), 'o')
    .replaceAll(RegExp('[úùüû]'), 'u')
    .replaceAll('ñ', 'n')
    .trim();

int _periodSortKey(String period) =>
    int.tryParse(RegExp(r'\d{4}').firstMatch(period)?.group(0) ?? '') ?? 9999;

String _categoryLabel(String id) => switch (id) {
  'architecture' => 'Arquitectura',
  'mystery' => 'Misterios',
  'culture' => 'Cultura',
  'memory' => 'Tradición oral',
  _ => StoryCatalog.resolve(id, id).label,
};

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    required this.stories,
    required this.onAskDardito,
    this.catalogNeighborhoods,
    this.initiallySelected,
    this.initialCategory,
  });
  final List<CityStory> stories;
  final CityStory? initiallySelected;
  final String? initialCategory;
  final ValueChanged<CityStory> onAskDardito;
  final Set<String>? catalogNeighborhoods;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  static const _gridPageSize = 15;

  String? _category;
  String? _neighborhood;
  String? _period;
  String _searchQuery = '';
  int _gridPage = 0;
  CityStory? _selected;
  bool _mapMode = true;
  bool _filtersExpanded = false;
  bool _desktopFiltersExpanded = false;
  String? _darkMapStyle;
  String? _lightMapStyle;
  bool _lightMapEnabled = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.initiallySelected;
    _category = widget.initialCategory;
    _filtersExpanded = _category != null;
    _desktopFiltersExpanded = _category != null;
    Future.wait([
      rootBundle.loadString('assets/map/la_plata_map_style.json'),
      rootBundle.loadString('assets/map/la_plata_map_style_light.json'),
    ]).then((styles) {
      if (!mounted) return;
      setState(() {
        _darkMapStyle = styles[0];
        _lightMapStyle = styles[1];
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CityStory> get _mapFiltered => widget.stories.where((story) {
    return (_category == null || story.category.id == _category) &&
        (_neighborhood == null || story.neighborhood == _neighborhood) &&
        (_period == null || story.period == _period);
  }).toList();

  List<CityStory> get _gridFiltered {
    final normalizedQuery = _normalizeSearch(_searchQuery);
    return _mapFiltered.where((story) {
      if (normalizedQuery.isEmpty) return true;
      final searchable = _normalizeSearch(
        [
          story.title,
          story.subtitle,
          story.shortStory,
          story.neighborhood,
          story.category.label,
          story.period,
          story.evidenceLabel,
        ].join(' '),
      );
      return searchable.contains(normalizedQuery);
    }).toList();
  }

  List<String> get _availablePeriods {
    final periods = widget.stories
        .map((story) => story.period.trim())
        .where((period) => period.isNotEmpty)
        .toSet()
        .toList();
    periods.sort((a, b) {
      final byYear = _periodSortKey(a).compareTo(_periodSortKey(b));
      return byYear != 0 ? byYear : a.compareTo(b);
    });
    return periods;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 600;
    final desktop = width >= 760;
    final wideDesktop = width >= 1100;
    final filtersExpanded = wideDesktop
        ? _desktopFiltersExpanded
        : _filtersExpanded;
    final visibleStories = _mapMode ? _mapFiltered : _gridFiltered;
    final activeFilters = [
      _category != null,
      _neighborhood != null,
      _period != null,
    ].where((active) => active).length;
    final controlsTop = desktop ? 104.0 : 14.0;
    final contentInset =
        controlsTop + (wideDesktop ? 76.0 : (narrow ? 126.0 : 92.0));

    return ColoredBox(
      color: AppColors.navy,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              child: _mapMode
                  ? _MapView(
                      key: const ValueKey('map'),
                      stories: _mapFiltered,
                      selected: _selected,
                      topInset: contentInset,
                      style: _lightMapEnabled ? _lightMapStyle : _darkMapStyle,
                      lightMapEnabled: _lightMapEnabled,
                      onToggleMapTheme: () =>
                          setState(() => _lightMapEnabled = !_lightMapEnabled),
                      onSelect: (s) => setState(() => _selected = s),
                      onClose: () => setState(() => _selected = null),
                      onDetails: (s) => showStoryDetails(context, s),
                      onAsk: widget.onAskDardito,
                    )
                  : _GridView(
                      key: const ValueKey('grid'),
                      stories: _gridFiltered,
                      topInset: contentInset,
                      searchController: _searchController,
                      searchQuery: _searchQuery,
                      currentPage: _gridPage,
                      pageSize: _gridPageSize,
                      onSearchChanged: (value) => setState(() {
                        _searchQuery = value;
                        _gridPage = 0;
                      }),
                      onPageChanged: (value) =>
                          setState(() => _gridPage = value),
                      onClear: _clearAllFilters,
                    ),
            ),
          ),
          Positioned(
            left: narrow ? 14 : 24,
            right: narrow ? 14 : 24,
            top: controlsTop,
            child: PointerInterceptor(
              child: Align(
                alignment: wideDesktop ? Alignment.topRight : Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: _ExploreControls(
                    narrow: narrow,
                    desktopCompact: wideDesktop,
                    expanded: filtersExpanded,
                    mapMode: _mapMode,
                    activeFilters: activeFilters,
                    resultCount: visibleStories.length,
                    category: _category,
                    neighborhood: _neighborhood,
                    period: _period,
                    periods: _availablePeriods,
                    neighborhoods:
                        widget.catalogNeighborhoods ??
                        widget.stories
                            .map((story) => story.neighborhood)
                            .toSet(),
                    onToggleFilters: () => setState(() {
                      if (wideDesktop) {
                        _desktopFiltersExpanded = !_desktopFiltersExpanded;
                      } else {
                        _filtersExpanded = !_filtersExpanded;
                      }
                    }),
                    onModeChanged: (value) => setState(() {
                      _mapMode = value;
                      if (!value) _gridPage = 0;
                    }),
                    onCategoryChanged: (value) => setState(() {
                      _category = value;
                      _gridPage = 0;
                    }),
                    onNeighborhoodChanged: (value) => setState(() {
                      _neighborhood = value;
                      _gridPage = 0;
                    }),
                    onPeriodChanged: (value) => setState(() {
                      _period = value;
                      _gridPage = 0;
                    }),
                    onClear: _clearAllFilters,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _category = null;
      _neighborhood = null;
      _period = null;
      _searchQuery = '';
      _gridPage = 0;
      _searchController.clear();
    });
  }
}

class _ExploreControls extends StatelessWidget {
  const _ExploreControls({
    required this.narrow,
    required this.desktopCompact,
    required this.expanded,
    required this.mapMode,
    required this.activeFilters,
    required this.resultCount,
    required this.category,
    required this.neighborhood,
    required this.period,
    required this.periods,
    required this.neighborhoods,
    required this.onToggleFilters,
    required this.onModeChanged,
    required this.onCategoryChanged,
    required this.onNeighborhoodChanged,
    required this.onPeriodChanged,
    required this.onClear,
  });

  final bool narrow;
  final bool desktopCompact;
  final bool expanded;
  final bool mapMode;
  final int activeFilters;
  final int resultCount;
  final String? category;
  final String? neighborhood;
  final String? period;
  final List<String> periods;
  final Set<String> neighborhoods;
  final VoidCallback onToggleFilters;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onNeighborhoodChanged;
  final ValueChanged<String?> onPeriodChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (desktopCompact) {
      return _DesktopExploreControls(
        expanded: expanded,
        mapMode: mapMode,
        activeFilters: activeFilters,
        resultCount: resultCount,
        category: category,
        neighborhood: neighborhood,
        period: period,
        periods: periods,
        neighborhoods: neighborhoods,
        onToggleFilters: onToggleFilters,
        onModeChanged: onModeChanged,
        onCategoryChanged: onCategoryChanged,
        onNeighborhoodChanged: onNeighborhoodChanged,
        onPeriodChanged: onPeriodChanged,
        onClear: onClear,
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.all(narrow ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: .90),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.explore_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MAPA DE HISTORIAS',
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: AppColors.yellow,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Explorá La Plata',
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.cream,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (!narrow) ...[
                _FiltersControl(
                  expanded: expanded,
                  activeFilters: activeFilters,
                  onTap: onToggleFilters,
                ),
                const SizedBox(width: 8),
              ],
              _ModeToggle(value: mapMode, onChanged: onModeChanged),
            ],
          ),
          if (narrow) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _FiltersControl(
                    compact: true,
                    expanded: expanded,
                    activeFilters: activeFilters,
                    onTap: onToggleFilters,
                  ),
                ),
                const SizedBox(width: 8),
                _ResultCount(resultCount: resultCount),
              ],
            ),
          ],
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: narrow ? double.infinity : null,
                            child: _FilterMenu(
                              label: category == null
                                  ? 'Todas las categorías'
                                  : _categoryLabel(category!),
                              icon: Icons.category_outlined,
                              options: {
                                'Todas': null,
                                for (final item in StoryCatalog.categories)
                                  _categoryLabel(item.id): item.id,
                              },
                              descriptions: {
                                for (final item in StoryCatalog.categories)
                                  item.id:
                                      item.description ?? 'Sin descripción',
                              },
                              value: category,
                              onSelected: onCategoryChanged,
                            ),
                          ),
                          SizedBox(
                            width: narrow ? double.infinity : null,
                            child: _FilterMenu(
                              label: neighborhood ?? 'Todos los barrios',
                              icon: Icons.location_on_outlined,
                              options: {
                                'Todos': null,
                                for (final item in neighborhoods) item: item,
                              },
                              value: neighborhood,
                              onSelected: onNeighborhoodChanged,
                            ),
                          ),
                          SizedBox(
                            width: narrow ? double.infinity : null,
                            child: _FilterMenu(
                              label: period ?? 'Todos los períodos',
                              icon: Icons.calendar_month_outlined,
                              options: {
                                'Todos los períodos': null,
                                for (final item in periods) item: item,
                              },
                              value: period,
                              onSelected: onPeriodChanged,
                            ),
                          ),
                          if (!narrow) _ResultCount(resultCount: resultCount),
                          if (activeFilters > 0)
                            TextButton.icon(
                              onPressed: onClear,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Restablecer'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.cream,
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopExploreControls extends StatelessWidget {
  const _DesktopExploreControls({
    required this.expanded,
    required this.mapMode,
    required this.activeFilters,
    required this.resultCount,
    required this.category,
    required this.neighborhood,
    required this.period,
    required this.periods,
    required this.neighborhoods,
    required this.onToggleFilters,
    required this.onModeChanged,
    required this.onCategoryChanged,
    required this.onNeighborhoodChanged,
    required this.onPeriodChanged,
    required this.onClear,
  });

  final bool expanded;
  final bool mapMode;
  final int activeFilters;
  final int resultCount;
  final String? category;
  final String? neighborhood;
  final String? period;
  final List<String> periods;
  final Set<String> neighborhoods;
  final VoidCallback onToggleFilters;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onNeighborhoodChanged;
  final ValueChanged<String?> onPeriodChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topRight,
    child: Container(
      width: 440,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: .91),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _ResultCount(resultCount: resultCount),
              const Spacer(),
              _FiltersControl(
                expanded: expanded,
                activeFilters: activeFilters,
                onTap: onToggleFilters,
                compact: true,
              ),
              const SizedBox(width: 6),
              _ModeToggle(
                value: mapMode,
                onChanged: onModeChanged,
                compact: true,
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            _FilterMenu(
              label: category == null
                  ? 'Todas las categorías'
                  : _categoryLabel(category!),
              icon: Icons.category_outlined,
              options: {
                'Todas': null,
                for (final item in StoryCatalog.categories)
                  _categoryLabel(item.id): item.id,
              },
              descriptions: {
                for (final item in StoryCatalog.categories)
                  item.id: item.description ?? 'Sin descripción',
              },
              value: category,
              onSelected: onCategoryChanged,
            ),
            const SizedBox(height: 8),
            _FilterMenu(
              label: neighborhood ?? 'Todos los barrios',
              icon: Icons.location_on_outlined,
              options: {
                'Todos': null,
                for (final item in neighborhoods) item: item,
              },
              value: neighborhood,
              onSelected: onNeighborhoodChanged,
            ),
            const SizedBox(height: 8),
            _FilterMenu(
              label: period ?? 'Todos los períodos',
              icon: Icons.calendar_month_outlined,
              options: {
                'Todos los períodos': null,
                for (final item in periods) item: item,
              },
              value: period,
              onSelected: onPeriodChanged,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                if (activeFilters > 0)
                  TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Restablecer'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.cream,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class _FiltersControl extends StatelessWidget {
  const _FiltersControl({
    required this.expanded,
    required this.activeFilters,
    required this.onTap,
    this.compact = false,
  });

  final bool expanded;
  final int activeFilters;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => _RoundControl(
    tooltip: expanded ? 'Ocultar filtros' : 'Mostrar filtros',
    onTap: onTap,
    compact: compact,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.tune_rounded, size: compact ? 15 : 19),
        SizedBox(width: compact ? 5 : 7),
        Text('Filtros', style: compact ? const TextStyle(fontSize: 12) : null),
        if (activeFilters > 0) ...[
          SizedBox(width: compact ? 5 : 7),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 5 : 7,
              vertical: compact ? 1 : 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$activeFilters',
              style: compact ? const TextStyle(fontSize: 11) : null,
            ),
          ),
        ],
        SizedBox(width: compact ? 2 : 3),
        AnimatedRotation(
          turns: expanded ? .5 : 0,
          duration: const Duration(milliseconds: 300),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: compact ? 18 : 24,
          ),
        ),
      ],
    ),
  );
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.resultCount});

  final int resultCount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$resultCount ${resultCount == 1 ? 'historia' : 'historias'}',
      maxLines: 1,
      style: const TextStyle(
        color: AppColors.cream,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.compact = false,
  });
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(compact ? 11 : 15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 11 : 15),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 7 : 11,
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.w800),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.value,
    required this.onChanged,
    this.compact = false,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 2 : 3),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(compact ? 11 : 15),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModeButton(
          icon: Icons.map_outlined,
          selected: value,
          tooltip: 'Vista mapa',
          onTap: () => onChanged(true),
          compact: compact,
        ),
        _ModeButton(
          icon: Icons.grid_view_rounded,
          selected: !value,
          tooltip: 'Vista grilla',
          onTap: () => onChanged(false),
          compact: compact,
        ),
      ],
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
    this.compact = false,
  });
  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 8 : 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.all(compact ? 6 : 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.yellow : Colors.transparent,
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
        ),
        child: Icon(icon, size: compact ? 15 : 19),
      ),
    ),
  );
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.icon,
    required this.options,
    required this.value,
    required this.onSelected,
    this.descriptions = const {},
  });
  final String label;
  final IconData icon;
  final Map<String, String?> options;
  final String? value;
  final ValueChanged<String?> onSelected;
  final Map<String, String> descriptions;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    crossAxisUnconstrained: false,
    alignmentOffset: const Offset(0, 6),
    useRootOverlay: true,
    style: MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(AppColors.paper),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(18),
      shadowColor: WidgetStatePropertyAll(AppColors.ink.withValues(alpha: .28)),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.ink.withValues(alpha: .10)),
        ),
      ),
    ),
    menuChildren: options.entries.map((entry) {
      final selected = entry.value == value;
      return MenuItemButton(
        onPressed: () => onSelected(entry.value),
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(42)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => selected
                ? AppColors.yellow.withValues(alpha: .18)
                : states.contains(WidgetState.hovered)
                ? AppColors.ink.withValues(alpha: .055)
                : Colors.transparent,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (entry.value != null &&
                descriptions.containsKey(entry.value)) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: descriptions[entry.value]!,
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 5),
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(Icons.info_outline_rounded, size: 17),
                ),
              ),
            ],
            if (selected) ...[
              const SizedBox(width: 12),
              const Icon(Icons.check_rounded, size: 18),
            ],
          ],
        ),
      );
    }).toList(),
    builder: (context, controller, child) => Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.ink.withValues(alpha: .10)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              AnimatedRotation(
                turns: controller.isOpen ? .5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MapView extends StatefulWidget {
  const _MapView({
    super.key,
    required this.stories,
    required this.selected,
    required this.topInset,
    required this.style,
    required this.lightMapEnabled,
    required this.onToggleMapTheme,
    required this.onSelect,
    required this.onClose,
    required this.onDetails,
    required this.onAsk,
  });
  final List<CityStory> stories;
  final CityStory? selected;
  final double topInset;
  final String? style;
  final bool lightMapEnabled;
  final VoidCallback onToggleMapTheme;
  final ValueChanged<CityStory> onSelect;
  final VoidCallback onClose;
  final ValueChanged<CityStory> onDetails;
  final ValueChanged<CityStory> onAsk;

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  DarditoMapController? _controller;

  void _selectStory(CityStory story) {
    UsageAnalyticsService.instance.storyViewed(story);
    widget.onSelect(story);
    if (MediaQuery.sizeOf(context).width < 760) {
      _showMobilePreview(context, story);
    }
  }

  Future<void> _showCluster(List<CityStory> stories) async {
    final sorted = [...stories]..sort((a, b) => a.title.compareTo(b.title));
    final selected = await showModalBottomSheet<CityStory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => PointerInterceptor(
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .65,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${stories.length} historias en esta zona',
                              style: Theme.of(
                                sheetContext,
                              ).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            const Text('Elegí una para descubrir su historia.'),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar historias de la zona',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: sorted.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final story = sorted[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: story.category.color.withValues(
                            alpha: .12,
                          ),
                          child: Icon(
                            story.category.icon,
                            color: story.category.color,
                          ),
                        ),
                        title: Text(
                          story.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${_categoryLabel(story.category.id)} · ${story.neighborhood}\n${story.shortStory}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.arrow_forward_rounded),
                        onTap: () => Navigator.pop(sheetContext, story),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted && selected != null) _selectStory(selected);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final showPanel = c.maxWidth >= 760;
      final lockMapForStory = widget.selected != null && c.maxWidth < 1100;
      return Stack(
        children: [
          Positioned.fill(
            child: DarditoMapSurface(
              stories: widget.stories,
              selected: widget.selected,
              style: widget.style,
              lightTheme: widget.lightMapEnabled,
              onSelect: _selectStory,
              onCluster: _showCluster,
              onReady: (controller) => _controller = controller,
              bottomPadding: showPanel ? 12 : 112,
              rightPadding: showPanel && widget.selected != null ? 410 : 0,
              interactive: !lockMapForStory,
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            right: showPanel && widget.selected != null ? 430 : 20,
            bottom: showPanel ? 20 : 116,
            child: PointerInterceptor(
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'map-theme',
                    tooltip: widget.lightMapEnabled
                        ? 'Usar mapa oscuro'
                        : 'Usar mapa claro',
                    onPressed: widget.onToggleMapTheme,
                    backgroundColor: widget.lightMapEnabled
                        ? AppColors.ink
                        : AppColors.paper,
                    foregroundColor: widget.lightMapEnabled
                        ? AppColors.paper
                        : AppColors.ink,
                    child: Icon(
                      widget.lightMapEnabled
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      size: 22,
                      color: widget.lightMapEnabled
                          ? Colors.white
                          : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'plus',
                    tooltip: 'Acercar',
                    onPressed: () => _controller?.zoomIn(),
                    backgroundColor: AppColors.paper,
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'minus',
                    tooltip: 'Alejar',
                    onPressed: () => _controller?.zoomOut(),
                    backgroundColor: AppColors.paper,
                    child: const Icon(Icons.remove),
                  ),
                ],
              ),
            ),
          ),
          if (showPanel)
            Positioned(
              right: 20,
              top: widget.topInset + 12,
              bottom: 82,
              child: PointerInterceptor(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(.12, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: widget.selected == null
                      ? const SizedBox.shrink(key: ValueKey('no-story'))
                      : SizedBox(
                          key: ValueKey(widget.selected!.id),
                          width: 390,
                          child: _StoryPanel(
                            story: widget.selected!,
                            onClose: widget.onClose,
                            onDetails: widget.onDetails,
                            onAsk: widget.onAsk,
                          ),
                        ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _showMobilePreview(BuildContext context, CityStory story) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: .72,
          child: _StoryPanel(
            story: story,
            onClose: () => Navigator.of(sheetContext).pop(),
            onDetails: widget.onDetails,
            onAsk: widget.onAsk,
          ),
        ),
      ),
    );
    if (mounted && widget.selected?.id == story.id) {
      widget.onClose();
    }
  }
}

class _StoryPanel extends StatelessWidget {
  const _StoryPanel({
    required this.story,
    required this.onClose,
    required this.onDetails,
    required this.onAsk,
  });
  final CityStory story;
  final VoidCallback onClose;
  final ValueChanged<CityStory> onDetails;
  final ValueChanged<CityStory> onAsk;

  String get evidenceLabel => story.evidenceLabel;

  IconData get evidenceIcon => switch (story.evidence) {
    'documented' => Icons.verified_outlined,
    'oral_tradition' => Icons.record_voice_over_outlined,
    'community' => Icons.groups_2_outlined,
    _ => Icons.fact_check_outlined,
  };

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white.withValues(alpha: .8)),
      boxShadow: const [
        BoxShadow(color: Colors.black38, blurRadius: 34, offset: Offset(0, 14)),
      ],
    ),
    child: Column(
      children: [
        Container(height: 8, color: story.category.color),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: story.category.color.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(
                        story.category.icon,
                        color: story.category.color,
                      ),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      tooltip: 'Cerrar historia',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  story.category.label.toUpperCase(),
                  style: TextStyle(
                    color: story.category.color,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  story.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  story.subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(evidenceIcon, size: 16, color: AppColors.green),
                      const SizedBox(width: 6),
                      Text(
                        evidenceLabel,
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  story.shortStory,
                  style: const TextStyle(color: AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StoryFact(
                      icon: Icons.location_on_outlined,
                      label: story.neighborhood,
                    ),
                    _StoryFact(
                      icon: Icons.schedule_rounded,
                      label: story.period,
                    ),
                    _StoryFact(
                      icon: Icons.menu_book_outlined,
                      label: '${story.readMinutes} min',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => onDetails(story),
                    child: const Text('Leer historia completa'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => onAsk(story),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Preguntarle a Dardito'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _StoryFact extends StatelessWidget {
  const _StoryFact({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.ink.withValues(alpha: .055),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _GridView extends StatefulWidget {
  const _GridView({
    super.key,
    required this.stories,
    required this.topInset,
    required this.searchController,
    required this.searchQuery,
    required this.currentPage,
    required this.pageSize,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onClear,
  });

  final List<CityStory> stories;
  final double topInset;
  final TextEditingController searchController;
  final String searchQuery;
  final int currentPage;
  final int pageSize;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onClear;

  @override
  State<_GridView> createState() => _GridViewState();
}

class _GridViewState extends State<_GridView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _changePage(int page) {
    widget.onPageChanged(page);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.cream,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 600
            ? 14.0
            : constraints.maxWidth < 1000
            ? 20.0
            : 28.0;
        final pageCount = widget.stories.isEmpty
            ? 1
            : (widget.stories.length + widget.pageSize - 1) ~/ widget.pageSize;
        final safePage = widget.currentPage < pageCount
            ? widget.currentPage
            : pageCount - 1;
        final start = safePage * widget.pageSize;
        final requestedEnd = start + widget.pageSize;
        final end = requestedEnd < widget.stories.length
            ? requestedEnd
            : widget.stories.length;
        final pageStories = widget.stories.sublist(start, end);

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: widget.topInset + 14)),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              sliver: SliverToBoxAdapter(
                child: _GridSearchToolbar(
                  controller: widget.searchController,
                  query: widget.searchQuery,
                  onSearchChanged: widget.onSearchChanged,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                14,
                horizontalPadding,
                12,
              ),
              sliver: SliverToBoxAdapter(
                child: _GridResultSummary(
                  total: widget.stories.length,
                  start: widget.stories.isEmpty ? 0 : start + 1,
                  end: end,
                  page: safePage,
                  pageCount: pageCount,
                ),
              ),
            ),
            if (pageStories.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyGridResult(onClear: widget.onClear),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  22,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: constraints.maxWidth < 620
                        ? constraints.maxWidth
                        : 390,
                    mainAxisExtent: constraints.maxWidth < 620 ? 270 : 286,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => StoryCard(
                      story: pageStories[index],
                      compact: true,
                      onTap: () =>
                          showStoryDetails(context, pageStories[index]),
                    ),
                    childCount: pageStories.length,
                  ),
                ),
              ),
            if (widget.stories.isNotEmpty && pageCount > 1)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  110,
                ),
                sliver: SliverToBoxAdapter(
                  child: _GridPagination(
                    page: safePage,
                    pageCount: pageCount,
                    onChanged: _changePage,
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        );
      },
    ),
  );
}

class _GridSearchToolbar extends StatelessWidget {
  const _GridSearchToolbar({
    required this.controller,
    required this.query,
    required this.onSearchChanged,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.ink.withValues(alpha: .10)),
      boxShadow: [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: .08),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: _StorySearchField(
      controller: controller,
      query: query,
      onChanged: onSearchChanged,
    ),
  );
}

class _StorySearchField extends StatelessWidget {
  const _StorySearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 520;
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        inputFormatters: [LengthLimitingTextInputFormatter(80)],
        decoration: InputDecoration(
          hintText: compact
              ? 'Buscar historias o barrios…'
              : 'Buscar por historia, barrio o palabra clave…',
          prefixIcon: const Icon(Icons.search_rounded, size: 21),
          suffixIcon: query.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpiar búsqueda',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
          filled: true,
          fillColor: AppColors.cream.withValues(alpha: .68),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.ink.withValues(alpha: .12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.ink.withValues(alpha: .12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.yellow, width: 2),
          ),
        ),
      ),
    );
  }
}

class _GridResultSummary extends StatelessWidget {
  const _GridResultSummary({
    required this.total,
    required this.start,
    required this.end,
    required this.page,
    required this.pageCount,
  });

  final int total;
  final int start;
  final int end;
  final int page;
  final int pageCount;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          total == 0
              ? 'Sin resultados'
              : 'Mostrando $start–$end de $total historias',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (pageCount > 1)
        Text(
          'Página ${page + 1} de $pageCount',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
    ],
  );
}

class _EmptyGridResult extends StatelessWidget {
  const _EmptyGridResult({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 48, 24, 150),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.manage_search_rounded, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              'No encontramos historias',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Probá con otra palabra, período o tipo de historia.',
              style: TextStyle(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Restablecer filtros'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GridPagination extends StatelessWidget {
  const _GridPagination({
    required this.page,
    required this.pageCount,
    required this.onChanged,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;

  List<int> get visiblePages {
    var start = page - 2;
    if (start < 0) start = 0;
    var end = start + 5;
    if (end > pageCount) {
      end = pageCount;
      start = end - 5;
      if (start < 0) start = 0;
    }
    return [for (var index = start; index < end; index++) index];
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.ink.withValues(alpha: .10)),
    ),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 8,
      children: [
        IconButton.outlined(
          tooltip: 'Página anterior',
          onPressed: page == 0 ? null : () => onChanged(page - 1),
          icon: const Icon(Icons.arrow_back_rounded, size: 19),
        ),
        for (final item in visiblePages)
          SizedBox(
            width: 42,
            height: 42,
            child: item == page
                ? FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: AppColors.yellow,
                      disabledForegroundColor: AppColors.ink,
                      padding: EdgeInsets.zero,
                    ),
                    child: Text('${item + 1}'),
                  )
                : OutlinedButton(
                    onPressed: () => onChanged(item),
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    child: Text('${item + 1}'),
                  ),
          ),
        IconButton.outlined(
          tooltip: 'Página siguiente',
          onPressed: page >= pageCount - 1 ? null : () => onChanged(page + 1),
          icon: const Icon(Icons.arrow_forward_rounded, size: 19),
        ),
      ],
    ),
  );
}
