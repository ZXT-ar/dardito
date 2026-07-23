import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/story.dart';
import '../../data/repositories/story_repository.dart';
import '../story/story_widgets.dart';
import 'map/dardito_map_surface.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    required this.stories,
    required this.onAskDardito,
    this.initiallySelected,
  });
  final List<CityStory> stories;
  final CityStory? initiallySelected;
  final VoidCallback onAskDardito;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  String? _category;
  String? _neighborhood;
  CityStory? _selected;
  bool _mapMode = true;
  bool _filtersExpanded = false;
  bool _desktopFiltersExpanded = false;
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    _selected = widget.initiallySelected;
    rootBundle.loadString('assets/map/la_plata_map_style.json').then((style) {
      if (mounted) setState(() => _mapStyle = style);
    });
  }

  List<CityStory> get _filtered => widget.stories.where((story) {
    return (_category == null || story.category.id == _category) &&
        (_neighborhood == null || story.neighborhood == _neighborhood);
  }).toList();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 600;
    final desktop = width >= 760;
    final wideDesktop = width >= 1100;
    final filtersExpanded = wideDesktop
        ? _desktopFiltersExpanded
        : _filtersExpanded;
    final activeFilters = [
      _category != null,
      _neighborhood != null,
    ].where((active) => active).length;
    final controlsTop = desktop ? 104.0 : 14.0;
    final contentInset =
        controlsTop +
        (wideDesktop
            ? (filtersExpanded ? 248.0 : 76.0)
            : filtersExpanded
            ? (narrow ? 216.0 : 110.0)
            : (narrow ? 126.0 : 92.0));

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
                      stories: _filtered,
                      selected: _selected,
                      topInset: contentInset,
                      style: _mapStyle,
                      onSelect: (s) => setState(() => _selected = s),
                      onClose: () => setState(() => _selected = null),
                      onDetails: (s) => showStoryDetails(context, s),
                      onAsk: widget.onAskDardito,
                    )
                  : _GridView(
                      key: const ValueKey('grid'),
                      stories: _filtered,
                      topInset: contentInset,
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
                    resultCount: _filtered.length,
                    category: _category,
                    neighborhood: _neighborhood,
                    neighborhoods: widget.stories
                        .map((story) => story.neighborhood)
                        .toSet(),
                    onToggleFilters: () => setState(() {
                      if (wideDesktop) {
                        _desktopFiltersExpanded = !_desktopFiltersExpanded;
                      } else {
                        _filtersExpanded = !_filtersExpanded;
                      }
                    }),
                    onModeChanged: (value) => setState(() => _mapMode = value),
                    onCategoryChanged: (value) =>
                        setState(() => _category = value),
                    onNeighborhoodChanged: (value) =>
                        setState(() => _neighborhood = value),
                    onClear: () => setState(() {
                      _category = null;
                      _neighborhood = null;
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    required this.neighborhoods,
    required this.onToggleFilters,
    required this.onModeChanged,
    required this.onCategoryChanged,
    required this.onNeighborhoodChanged,
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
  final Set<String> neighborhoods;
  final VoidCallback onToggleFilters;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onNeighborhoodChanged;
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
        neighborhoods: neighborhoods,
        onToggleFilters: onToggleFilters,
        onModeChanged: onModeChanged,
        onCategoryChanged: onCategoryChanged,
        onNeighborhoodChanged: onNeighborhoodChanged,
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
                                  : LocalStoryRepository.categories
                                        .firstWhere(
                                          (item) => item.id == category,
                                        )
                                        .label,
                              icon: Icons.category_outlined,
                              options: {
                                'Todas': null,
                                for (final item
                                    in LocalStoryRepository.categories)
                                  item.label: item.id,
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
    required this.neighborhoods,
    required this.onToggleFilters,
    required this.onModeChanged,
    required this.onCategoryChanged,
    required this.onNeighborhoodChanged,
    required this.onClear,
  });

  final bool expanded;
  final bool mapMode;
  final int activeFilters;
  final int resultCount;
  final String? category;
  final String? neighborhood;
  final Set<String> neighborhoods;
  final VoidCallback onToggleFilters;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onNeighborhoodChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topRight,
    child: Container(
      width: expanded ? 440 : null,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: .91),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FiltersControl(
                expanded: expanded,
                activeFilters: activeFilters,
                onTap: onToggleFilters,
              ),
              const SizedBox(width: 8),
              _ModeToggle(value: mapMode, onChanged: onModeChanged),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            _FilterMenu(
              label: category == null
                  ? 'Todas las categorías'
                  : LocalStoryRepository.categories
                        .firstWhere((item) => item.id == category)
                        .label,
              icon: Icons.category_outlined,
              options: {
                'Todas': null,
                for (final item in LocalStoryRepository.categories)
                  item.label: item.id,
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
            Row(
              children: [
                _ResultCount(resultCount: resultCount),
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
  });

  final bool expanded;
  final int activeFilters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _RoundControl(
    tooltip: expanded ? 'Ocultar filtros' : 'Mostrar filtros',
    onTap: onTap,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.tune_rounded, size: 19),
        const SizedBox(width: 7),
        const Text('Filtros'),
        if (activeFilters > 0) ...[
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$activeFilters'),
          ),
        ],
        const SizedBox(width: 3),
        AnimatedRotation(
          turns: expanded ? .5 : 0,
          duration: const Duration(milliseconds: 300),
          child: const Icon(Icons.keyboard_arrow_down_rounded),
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
  });
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
  const _ModeToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModeButton(
          icon: Icons.map_outlined,
          selected: value,
          tooltip: 'Vista mapa',
          onTap: () => onChanged(true),
        ),
        _ModeButton(
          icon: Icons.grid_view_rounded,
          selected: !value,
          tooltip: 'Vista grilla',
          onTap: () => onChanged(false),
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
  });
  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: selected ? AppColors.yellow : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 19),
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
  });
  final String label;
  final IconData icon;
  final Map<String, String?> options;
  final String? value;
  final ValueChanged<String?> onSelected;

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
    required this.onSelect,
    required this.onClose,
    required this.onDetails,
    required this.onAsk,
  });
  final List<CityStory> stories;
  final CityStory? selected;
  final double topInset;
  final String? style;
  final ValueChanged<CityStory> onSelect;
  final VoidCallback onClose;
  final ValueChanged<CityStory> onDetails;
  final VoidCallback onAsk;

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  DarditoMapController? _controller;

  void _selectStory(CityStory story) {
    widget.onSelect(story);
    if (MediaQuery.sizeOf(context).width < 760) {
      _showMobilePreview(context, story);
    }
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
              onSelect: _selectStory,
              onReady: (controller) => _controller = controller,
              bottomPadding: showPanel ? 12 : 112,
              rightPadding: showPanel && widget.selected != null ? 410 : 0,
              interactive: !lockMapForStory,
            ),
          ),
          Positioned(
            left: 20,
            top: widget.topInset + 12,
            child: TrustBadge(
              icon: Icons.circle,
              label: '${widget.stories.length} historias visibles',
              color: AppColors.green,
            ),
          ),
          Positioned(
            left: 20,
            bottom: showPanel ? 20 : 116,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: widget.selected == null && showPanel
                  ? const _MapHint(key: ValueKey('map-hint'))
                  : const SizedBox.shrink(key: ValueKey('map-hint-hidden')),
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

class _MapHint extends StatelessWidget {
  const _MapHint({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: AppColors.paper.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.touch_app_outlined, size: 19),
        SizedBox(width: 8),
        Text('Elegí un punto para abrir su historia'),
      ],
    ),
  );
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
  final VoidCallback onAsk;

  String get evidenceLabel => switch (story.evidence) {
    EvidenceLevel.documented => 'Historia documentada',
    EvidenceLevel.oralTradition => 'Tradición oral',
    EvidenceLevel.community => 'Memoria de la comunidad',
  };

  IconData get evidenceIcon => switch (story.evidence) {
    EvidenceLevel.documented => Icons.verified_outlined,
    EvidenceLevel.oralTradition => Icons.record_voice_over_outlined,
    EvidenceLevel.community => Icons.groups_2_outlined,
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
                    onPressed: onAsk,
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

class _GridView extends StatelessWidget {
  const _GridView({super.key, required this.stories, required this.topInset});
  final List<CityStory> stories;
  final double topInset;
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.cream,
    child: stories.isEmpty
        ? const Center(
            child: Text('No encontramos historias con esos filtros.'),
          )
        : LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth < 650
                  ? 1
                  : c.maxWidth < 1000
                  ? 2
                  : 3;
              final ratio = cols == 1 ? 1.8 : 1.05;
              return GridView.builder(
                padding: EdgeInsets.fromLTRB(24, topInset + 14, 24, 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: ratio,
                ),
                itemCount: stories.length,
                itemBuilder: (context, i) => StoryCard(
                  story: stories[i],
                  onTap: () => showStoryDetails(context, stories[i]),
                ),
              );
            },
          ),
  );
}
