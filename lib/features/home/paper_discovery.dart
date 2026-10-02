import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/catalogs/story_catalog.dart';
import '../../data/models/story.dart';

const _ink = Color(0xFF26271F);
const _olive = Color(0xFF606C40);
const _rule = Color(0xFFBAAE8C);
const _doors = [
  (
    'architecture',
    'Arquitectura',
    'Edificios, plazas y formas de mirar la ciudad.',
  ),
  ('mystery', 'Misterios', 'Enigmas y versiones que siguen vivos.'),
  ('culture', 'Cultura', 'Costumbres, expresiones y vida platense.'),
  (
    'memory',
    'Tradición oral',
    'Historias que se transmitieron de persona a persona.',
  ),
];

class PaperCategories extends StatelessWidget {
  const PaperCategories({super.key, required this.onExplore});
  final ValueChanged<String> onExplore;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '¿Qué querés descubrir hoy?',
        style: Theme.of(context).textTheme.displayMedium?.copyWith(color: _ink),
      ),
      const SizedBox(height: 36),
      LayoutBuilder(
        builder: (context, bounds) {
          // Keep every label visible; at narrow widths the index folds into two rows.
          final columns =
              bounds.maxWidth < 600 ||
                  MediaQuery.textScalerOf(context).scale(18) > 25
              ? 2
              : 4;
          final rows = <Widget>[];
          for (var start = 0; start < _doors.length; start += columns) {
            rows.add(
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _rule)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = start; i < start + columns; i++) ...[
                      if (i > start) const SizedBox(width: 6),
                      Expanded(
                        child: _PaperTab(
                          index: i,
                          onTap: () => onExplore(_doors[i].$1),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
            if (start + columns < _doors.length) {
              rows.add(const SizedBox(height: 16));
            }
          }
          return Column(children: rows);
        },
      ),
    ],
  );
}

class _PaperTab extends StatefulWidget {
  const _PaperTab({required this.index, required this.onTap});
  final int index;
  final VoidCallback onTap;
  @override
  State<_PaperTab> createState() => _PaperTabState();
}

class _PaperTabState extends State<_PaperTab> {
  bool _hover = false, _focus = false;
  @override
  Widget build(BuildContext context) {
    final door = _doors[widget.index];
    final remote = StoryCatalog.resolve(door.$1, door.$2).description?.trim();
    final active = _hover || _focus;
    final dark = active || widget.index == 1;
    const fills = [
      Color(0xFFE3D5AF),
      _olive,
      Color(0xFFE6C68D),
      Color(0xFFECE2C7),
    ];
    return Tooltip(
      message: remote == null || remote.isEmpty ? door.$3 : remote,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 160,
          ),
          decoration: BoxDecoration(
            color: active ? _olive : fills[widget.index],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onFocusChange: (value) => setState(() => _focus = value),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  10,
                  16 +
                      (widget.index == 1
                          ? 5
                          : widget.index == 2
                          ? 2
                          : 0) +
                      (active ? 4 : 0),
                  10,
                  15,
                ),
                child: Text(
                  door.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 18,
                    height: 1.25,
                    color: dark ? AppColors.heroPaper : _ink,
                    decoration: _focus ? TextDecoration.underline : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PaperFeatured extends StatelessWidget {
  const PaperFeatured({
    super.key,
    required this.stories,
    required this.onOpen,
    required this.onViewAll,
  });
  final List<CityStory> stories;
  final ValueChanged<CityStory> onOpen;
  final VoidCallback onViewAll;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final narrow =
          bounds.maxWidth < 680 ||
          MediaQuery.textScalerOf(context).scale(20) > 28;
      final title = Text(
        'Historias para empezar',
        style: Theme.of(context).textTheme.displayMedium?.copyWith(color: _ink),
      );
      final all = TextButton(
        onPressed: onViewAll,
        style: TextButton.styleFrom(foregroundColor: _olive),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ver todas',
              style: TextStyle(fontFamily: 'Lora', fontSize: 16),
            ),
            SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20),
          ],
        ),
      );
      final preview = stories.take(3).toList();
      Widget entry(CityStory story) =>
          _PaperStory(story: story, onTap: () => onOpen(story));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (narrow) ...[
            title,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: all),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: title),
                const SizedBox(width: 20),
                all,
              ],
            ),
          const SizedBox(height: 28),
          if (narrow) ...[
            for (var i = 0; i < preview.length; i++) ...[
              if (i > 0) const Divider(color: _rule, height: 32, thickness: .6),
              entry(preview[i]),
            ],
          ] else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < preview.length; i++) ...[
                    if (i > 0)
                      const VerticalDivider(
                        color: _rule,
                        width: 44,
                        thickness: .6,
                      ),
                    Expanded(child: entry(preview[i])),
                  ],
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _PaperStory extends StatefulWidget {
  const _PaperStory({required this.story, required this.onTap});
  final CityStory story;
  final VoidCallback onTap;
  @override
  State<_PaperStory> createState() => _PaperStoryState();
}

class _PaperStoryState extends State<_PaperStory> {
  bool _hover = false, _focus = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (value) => setState(() => _focus = value),
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.story.title,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 25,
                    height: 1.35,
                    color: _hover || _focus ? _olive : _ink,
                    decoration: _focus ? TextDecoration.underline : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSlide(
                duration: Duration(
                  milliseconds: MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : 160,
                ),
                offset: Offset(_hover || _focus ? .15 : 0, 0),
                child: const Icon(Icons.chevron_right, size: 21, color: _olive),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
