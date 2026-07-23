import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/story.dart';
import '../../data/repositories/story_repository.dart';
import '../explore/map/dardito_map_surface.dart';
import '../install/install_banner.dart';
import '../legal/legal_page.dart';
import '../story/story_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.stories,
    required this.onExplore,
    required this.onNavigate,
    required this.onOpenLegal,
  });
  final List<CityStory> stories;
  final ValueChanged<CityStory?> onExplore;
  final ValueChanged<int> onNavigate;
  final ValueChanged<LegalDocument> onOpenLegal;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        _Hero(onExplore: () => onExplore(null), onAsk: () => onNavigate(2)),
        Transform.translate(
          offset: const Offset(0, -24),
          child: const Entrance(
            distance: 14,
            startScale: .985,
            child: MaxWidth(child: InstallBanner()),
          ),
        ),
        const SizedBox(height: 52),
        Entrance(
          child: MaxWidth(child: _Categories(onExplore: () => onExplore(null))),
        ),
        const SizedBox(height: 96),
        Entrance(
          delay: const Duration(milliseconds: 80),
          child: MaxWidth(
            child: _Featured(
              stories: stories.where((s) => s.featured).toList(),
              onExplore: onExplore,
            ),
          ),
        ),
        const SizedBox(height: 96),
        Entrance(
          delay: const Duration(milliseconds: 140),
          child: MaxWidth(
            child: _MapCallout(
              stories: stories,
              onExplore: () => onExplore(null),
            ),
          ),
        ),
        const SizedBox(height: 96),
        Entrance(
          delay: const Duration(milliseconds: 180),
          child: MaxWidth(
            child: _TrustSection(onContribute: () => onNavigate(3)),
          ),
        ),
        const SizedBox(height: 96),
        _WhatsAppCallout(
          onAsk: () async {
            final uri = Uri.parse(
              'https://wa.me/?text=${Uri.encodeComponent('Hola Dardito, quiero descubrir una historia de La Plata')}',
            );
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        ),
        _Footer(onOpenLegal: onOpenLegal),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onExplore, required this.onAsk});
  final VoidCallback onExplore;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 650),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF11120F), Color(0xFF1D2019), Color(0xFF0B151B)],
      ),
    ),
    child: MaxWidth(
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 800;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SectionEyebrow('El guardián de las historias', light: true),
              const SizedBox(height: 24),
              Text(
                'La Plata tiene\nmiles de historias.',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppColors.cream,
                  fontSize: narrow ? 46 : 68,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Dardito te ayuda a encontrarlas.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.yellow,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  'Explorá lugares, conectá recuerdos y descubrí lo que hace única a la ciudad.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.cream.withValues(alpha: .78),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onExplore,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.yellow,
                      foregroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                    ),
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('Explorar el mapa'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onAsk,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cream,
                      side: BorderSide(
                        color: AppColors.cream.withValues(alpha: .35),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Preguntale a Dardito'),
                  ),
                ],
              ),
            ],
          );
          final visual = _FloatingVisual(
            child: Semantics(
              label:
                  'Dardito, el personaje guardián de las historias de La Plata',
              image: true,
              child: SizedBox(
                height: narrow ? 370 : 570,
                child: Image.asset(
                  'assets/brand/dardito_waving.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          );
          return Padding(
            padding: EdgeInsets.symmetric(vertical: narrow ? 46 : 54),
            child: narrow
                ? Column(children: [copy, const SizedBox(height: 42), visual])
                : Row(
                    children: [
                      Expanded(flex: 10, child: copy),
                      const SizedBox(width: 50),
                      Expanded(flex: 9, child: visual),
                    ],
                  ),
          );
        },
      ),
    ),
  );
}

class _FloatingVisual extends StatefulWidget {
  const _FloatingVisual({required this.child});
  final Widget child;

  @override
  State<_FloatingVisual> createState() => _FloatingVisualState();
}

class _FloatingVisualState extends State<_FloatingVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final value = Curves.easeInOut.transform(_controller.value);
      return Transform.translate(
        offset: Offset(0, 8 - value * 16),
        child: Transform.rotate(angle: -.006 + value * .012, child: child),
      );
    },
  );
}

class _Categories extends StatelessWidget {
  const _Categories({required this.onExplore});
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionTitle(
        eyebrow: 'Elegí tu curiosidad',
        title: '¿Qué querés descubrir hoy?',
        description: 'Cada historia abre una puerta distinta a la ciudad.',
      ),
      const SizedBox(height: 32),
      LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth < 600
              ? 1
              : c.maxWidth < 960
              ? 2
              : 3;
          final width = (c.maxWidth - (16 * (columns - 1))) / columns;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (
                var index = 0;
                index < LocalStoryRepository.categories.length;
                index++
              )
                _CategoryCard(
                  category: LocalStoryRepository.categories[index],
                  index: index,
                  width: width,
                  onTap: onExplore,
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.index,
    required this.width,
    required this.onTap,
  });

  final StoryCategory category;
  final int index;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ScrollEntrance(
    delay: Duration(milliseconds: 60 * index),
    distance: .055,
    startScale: .975,
    child: SizedBox(
      width: width,
      height: 142,
      child: HoverLift(
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ScrollEntrance(
                    delay: Duration(milliseconds: 100 + 60 * index),
                    distance: .06,
                    startScale: .84,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(category.icon, color: category.color),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      category.label,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ScrollEntrance(
                    delay: Duration(milliseconds: 150 + 60 * index),
                    distance: .08,
                    child: _CategoryArrow(color: category.color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CategoryArrow extends StatelessWidget {
  const _CategoryArrow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: .16),
          AppColors.yellow.withValues(alpha: .13),
        ],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: .22)),
    ),
    child: Stack(
      children: [
        Center(
          child: Icon(Icons.arrow_outward_rounded, size: 21, color: color),
        ),
        Positioned(
          top: 7,
          right: 7,
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.yellow,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Featured extends StatelessWidget {
  const _Featured({required this.stories, required this.onExplore});
  final List<CityStory> stories;
  final ValueChanged<CityStory?> onExplore;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionTitle(
        eyebrow: 'Selección de Dardito',
        title: 'Historias para empezar',
        trailing: MediaQuery.sizeOf(context).width > 700
            ? TextButton.icon(
                onPressed: () => onExplore(null),
                label: const Text('Ver todas'),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward),
              )
            : null,
      ),
      const SizedBox(height: 32),
      LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth < 600
              ? 1
              : c.maxWidth < 960
              ? 2
              : 4;
          final width = (c.maxWidth - (cols - 1) * 16) / cols;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (var index = 0; index < stories.length; index++)
                ScrollEntrance(
                  delay: Duration(milliseconds: 65 * index),
                  distance: .055,
                  startScale: .975,
                  child: SizedBox(
                    width: width,
                    height: 330,
                    child: StoryCard(
                      story: stories[index],
                      onTap: () => showStoryDetails(context, stories[index]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _MapCallout extends StatefulWidget {
  const _MapCallout({required this.stories, required this.onExplore});
  final List<CityStory> stories;
  final VoidCallback onExplore;

  @override
  State<_MapCallout> createState() => _MapCalloutState();
}

class _MapCalloutState extends State<_MapCallout> {
  String? _mapStyle;
  late final List<CityStory> _previewStories;

  @override
  void initState() {
    super.initState();
    final shuffled = [...widget.stories]..shuffle(Random(1882));
    _previewStories = shuffled.take(min(6, shuffled.length)).toList();
    rootBundle.loadString('assets/map/la_plata_map_style.json').then((style) {
      if (mounted) setState(() => _mapStyle = style);
    });
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(30),
    child: Container(
      padding: const EdgeInsets.all(8),
      color: AppColors.navy,
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 800;
          final copy = Padding(
            padding: EdgeInsets.all(narrow ? 24 : 42),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SectionEyebrow('El mapa vivo', light: true),
                const SizedBox(height: 20),
                Text(
                  'Cada punto guarda\nalgo para contar.',
                  style: Theme.of(
                    context,
                  ).textTheme.displayMedium?.copyWith(color: AppColors.cream),
                ),
                const SizedBox(height: 18),
                Text(
                  'Recorré La Plata por barrio, época o curiosidad. Las historias documentadas y las memorias de la comunidad tienen su propia señal.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.cream.withValues(alpha: .72),
                  ),
                ),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: widget.onExplore,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: AppColors.ink,
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Abrir el mapa'),
                ),
              ],
            ),
          );
          final miniMap = ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: narrow ? 340 : 470,
              child: DarditoMapSurface(
                stories: _previewStories,
                selected: null,
                style: _mapStyle,
                interactive: false,
                onSelect: (_) {},
                onReady: (_) {},
                bottomPadding: 0,
                rightPadding: 0,
              ),
            ),
          );
          return narrow
              ? Column(children: [copy, miniMap])
              : Row(
                  children: [
                    Expanded(child: copy),
                    Expanded(child: miniMap),
                  ],
                );
        },
      ),
    ),
  );
}

class _TrustSection extends StatelessWidget {
  const _TrustSection({required this.onContribute});
  final VoidCallback onContribute;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final narrow = c.maxWidth < 800;
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionEyebrow('Un mapa entre todos'),
          const SizedBox(height: 18),
          Text(
            'Tu recuerdo también\nconstruye la ciudad.',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 18),
          Text(
            'Una foto, una anécdota familiar o la historia de un comercio pueden sumar una pieza que faltaba. Cada aporte se revisa antes de publicarse.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onContribute,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Compartir una historia'),
          ),
        ],
      );
      final principles = Column(
        children: const [
          _Principle(
            icon: Icons.verified_outlined,
            title: 'Claridad editorial',
            text:
                'Distinguimos hechos documentados, tradición oral y aportes comunitarios.',
          ),
          _Principle(
            icon: Icons.shield_outlined,
            title: 'Cuidado y privacidad',
            text:
                'Revisamos datos personales, imágenes y contenidos sensibles antes de publicar.',
          ),
          _Principle(
            icon: Icons.groups_outlined,
            title: 'Conocimiento compartido',
            text:
                'La tecnología conecta las voces; la ciudad y sus personas son protagonistas.',
          ),
        ],
      );
      return narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 40), principles],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: copy),
                const SizedBox(width: 80),
                Expanded(child: principles),
              ],
            );
    },
  );
}

class _Principle extends StatelessWidget {
  const _Principle({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.lindenGreen.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.lindenGreen.withValues(alpha: .24),
            ),
          ),
          child: Icon(icon, color: AppColors.lindenGreen),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WhatsAppCallout extends StatelessWidget {
  const _WhatsAppCallout({required this.onAsk});
  final VoidCallback onAsk;
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.yellow,
    padding: const EdgeInsets.symmetric(vertical: 72),
    child: MaxWidth(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 28,
        children: [
          SizedBox(
            width: 680,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionEyebrow('También en WhatsApp'),
                const SizedBox(height: 16),
                Text(
                  'Una conversación puede ser el comienzo de otro recorrido.',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Preguntá por tu barrio, una época o pedile a Dardito una historia al azar.',
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onAsk,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.paper,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            ),
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Abrir WhatsApp'),
          ),
        ],
      ),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onOpenLegal});
  final ValueChanged<LegalDocument> onOpenLegal;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.ink,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;
        final brand = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FooterBrandMark(),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Text(
                'Historias, memoria y cultura para mirar La Plata con otros ojos.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.cream.withValues(alpha: .72),
                  height: 1.35,
                ),
              ),
            ),
          ],
        );
        final links = Column(
          crossAxisAlignment: mobile
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 8,
              alignment: mobile ? WrapAlignment.start : WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () => onOpenLegal(LegalDocument.terms),
                  style: TextButton.styleFrom(foregroundColor: AppColors.paper),
                  child: const Text('Términos y condiciones'),
                ),
                TextButton(
                  onPressed: () => onOpenLegal(LegalDocument.privacy),
                  style: TextButton.styleFrom(foregroundColor: AppColors.paper),
                  child: const Text('Privacidad'),
                ),
                _InstagramLink(
                  onTap: () async {
                    await launchUrl(
                      Uri.parse('https://www.instagram.com/'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'La ciudad nunca termina de contarse.',
              textAlign: mobile ? TextAlign.left : TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: AppColors.cream),
            ),
          ],
        );
        return Padding(
          padding: EdgeInsets.only(
            top: mobile ? 54 : 68,
            bottom: mobile ? 154 : 68,
          ),
          child: MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [brand, const SizedBox(height: 38), links],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 5, child: brand),
                      const SizedBox(width: 64),
                      Expanded(flex: 6, child: links),
                    ],
                  ),
                const SizedBox(height: 44),
                Divider(color: AppColors.cream.withValues(alpha: .14)),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: const [
                    Text(
                      '© 2026 Dardito · La Plata, Argentina',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Text(
                      'Copy y experiencia digital por Simbiosis Digital',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _FooterBrandMark extends StatelessWidget {
  const _FooterBrandMark();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.asset(
          'assets/brand/dardito_app_icon.png',
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
      const SizedBox(width: 13),
      const Text(
        'DARDITO',
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
          color: AppColors.cream,
        ),
      ),
      Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.only(left: 4, top: 13),
        decoration: const BoxDecoration(
          color: AppColors.yellow,
          shape: BoxShape.circle,
        ),
      ),
    ],
  );
}

class _InstagramLink extends StatelessWidget {
  const _InstagramLink({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Instagram',
    child: OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.paper,
        side: BorderSide(color: AppColors.paper.withValues(alpha: .24)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      icon: const _InstagramGlyph(),
      label: const Text('Instagram'),
    ),
  );
}

class _InstagramGlyph extends StatelessWidget {
  const _InstagramGlyph();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 18,
    child: Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.paper, width: 1.8),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.paper, width: 1.6),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: 3.3,
          top: 3.3,
          child: Container(
            width: 2.6,
            height: 2.6,
            decoration: const BoxDecoration(
              color: AppColors.paper,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}
