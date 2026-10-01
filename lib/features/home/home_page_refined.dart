// Propuesta conservadora de la portada existente. Activar con DARDITO_REFINED_HOME.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/whatsapp_config.dart';
import '../../core/platform/whatsapp_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/catalogs/story_catalog.dart';
import '../../data/models/story.dart';
import 'home_map_preview.dart';
import 'home_hero_backdrop.dart';
import 'home_entrance.dart';
import 'home_explore_invitation.dart';
import '../legal/legal_page.dart';
import '../story/story_widgets.dart';

class RefinedHomePage extends StatelessWidget {
  const RefinedHomePage({
    super.key,
    required this.stories,
    required this.onExplore,
    required this.onExploreCategory,
    required this.onNavigate,
    required this.onOpenLegal,
  });
  final List<CityStory> stories;
  final ValueChanged<CityStory?> onExplore;
  final ValueChanged<String> onExploreCategory;
  final ValueChanged<int> onNavigate;
  final ValueChanged<LegalDocument> onOpenLegal;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        RefinedHomeHero(
          onExplore: () => onExplore(null),
          onAsk: () => onNavigate(2),
        ),
        const SizedBox(height: 72),
        MaxWidth(
          child: _MapCallout(
            stories: stories,
            onExplore: () => onExplore(null),
          ),
        ),
        const SizedBox(height: 80),
        HomeEntrance(
          child: MaxWidth(child: _Categories(onExplore: onExploreCategory)),
        ),
        const SizedBox(height: 80),
        MaxWidth(
          child: _Featured(
            stories: stories.where((s) => s.featured).toList(),
            onExplore: onExplore,
          ),
        ),
        const SizedBox(height: 80),
        HomeEntrance(
          child: MaxWidth(
            child: _TrustSection(onContribute: () => onNavigate(3)),
          ),
        ),
        const SizedBox(height: 80),
        _WhatsAppCallout(onAsk: () => _openWhatsAppConversation(context)),
        _Footer(onOpenLegal: onOpenLegal),
      ],
    ),
  );
}

Future<void> _openWhatsAppConversation(BuildContext context) async {
  final opened = await openDarditoWhatsApp(
    message: 'Hola Dardito, quiero conocer una historia de La Plata.',
  );
  if (opened || !context.mounted) return;
  await Clipboard.setData(
    const ClipboardData(text: WhatsAppConfig.displayPhoneNumber),
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text(
          'No pudimos abrir WhatsApp. Copiamos el número +54 9 221 319-7058.',
        ),
      ),
    );
}

class RefinedHomeHero extends StatelessWidget {
  const RefinedHomeHero({
    super.key,
    required this.onExplore,
    required this.onAsk,
  });
  final VoidCallback onExplore;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) => HomeHeroBackdrop(
    child: MaxWidth(
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 950;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                [
                      Text(
                        'El Mapa de las\nHistorias de La Plata.',
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              color: AppColors.cream,
                              fontSize: narrow
                                  ? (c.maxWidth * .115).clamp(34.0, 48.0)
                                  : (c.maxWidth * .052).clamp(48.0, 64.0),
                            ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Dardito te ayuda a descubrirlas.',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: AppColors.yellow,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Text(
                          'Explorá las historias, personas, lugares y misterios que hicieron, hacen y siguen haciendo única a La Plata.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppColors.cream.withValues(alpha: .78),
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'La ciudad nunca deja de contarse.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.cream.withValues(alpha: .72),
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                      if (narrow) ...[
                        const SizedBox(height: 26),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: HomeExploreInvitation(
                            compact: true,
                            onTap: onExplore,
                          ),
                        ),
                      ],
                    ].indexed
                    .map(
                      (entry) => entry.$2 is SizedBox
                          ? entry.$2
                          : HomeEntrance(
                              delay: Duration(milliseconds: entry.$1 * 45),
                              child: entry.$2,
                            ),
                    )
                    .toList(),
          );
          // Keep the illustration and its dialogue in one coordinate system.
          // Scaling the whole composition preserves the tail's attachment.
          final visual = LayoutBuilder(
            builder: (context, bounds) {
              final width = bounds.maxWidth.clamp(0.0, 460.0);
              return Center(
                child: SizedBox(
                  width: width,
                  height: width * 560 / 460,
                  child: FittedBox(
                    child: SizedBox(
                      width: 460,
                      height: 560,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 100,
                            top: 106,
                            width: 480,
                            height: 584,
                            child: Semantics(
                              label:
                                  'Dardito, el personaje guardián de las historias de La Plata',
                              image: true,
                              child: Image.asset(
                                'assets/brand/dardito_hero_regenerated_v4.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 18,
                            left: 12,
                            child: Transform.rotate(
                              angle: -.055,
                              child: Transform.scale(
                                scale: .7,
                                alignment: Alignment.bottomRight,
                                child: _DarditoSpeechBubble(onPressed: onAsk),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
          if (narrow) {
            return Padding(
              padding: const EdgeInsets.only(top: 36, bottom: 36),
              child: Column(
                children: [
                  copy,
                  const SizedBox(height: 12),
                  HomeEntrance(
                    delay: const Duration(milliseconds: 160),
                    child: Transform.translate(
                      offset: const Offset(24, 0),
                      child: visual,
                    ),
                  ),
                ],
              ),
            );
          }
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 106, bottom: 130),
                child: Row(
                  children: [
                    Expanded(
                      flex: 11,
                      child: Transform.translate(
                        offset: const Offset(72, -110),
                        child: copy,
                      ),
                    ),
                    const SizedBox(width: 32),
                    const Expanded(flex: 8, child: SizedBox(height: 560)),
                  ],
                ),
              ),
              Positioned(
                right: -(MediaQuery.sizeOf(context).width - c.maxWidth) / 2,
                bottom: 0,
                width: (c.maxWidth * .46).clamp(450.0, 550.0),
                height: 700,
                child: HomeEntrance(
                  delay: const Duration(milliseconds: 160),
                  child: LayoutBuilder(
                    builder: (context, frame) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          right: -frame.maxWidth * .19,
                          top: 100,
                          width: frame.maxWidth * 1.16,
                          height: frame.maxWidth * 1.42,
                          child: Image.asset(
                            'assets/brand/dardito_hero_regenerated_v4.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            semanticLabel:
                                'Dardito, el personaje guardián de las historias de La Plata',
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 0,
                          child: Transform.rotate(
                            angle: -.055,
                            child: Transform.scale(
                              scale: .7,
                              alignment: Alignment.bottomRight,
                              child: _DarditoSpeechBubble(onPressed: onAsk),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -(MediaQuery.sizeOf(context).width - c.maxWidth) / 2,
                right: -(MediaQuery.sizeOf(context).width - c.maxWidth) / 2,
                bottom: 0,
                child: HomeExploreInvitation(compact: false, onTap: onExplore),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// A restrained comic panel: ink outline, yellow print offset and a spoken tail.
class _DarditoSpeechBubble extends StatelessWidget {
  const _DarditoSpeechBubble({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Preguntale a Dardito',
    child: SizedBox(
      width: 280,
      height: 170,
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 7,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: AppColors.yellow,
                shape: const _SpeechBubbleShape(),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            right: 6,
            bottom: 7,
            child: Material(
              color: AppColors.cream,
              shape: const _SpeechBubbleShape(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                mouseCursor: SystemMouseCursors.click,
                hoverColor: AppColors.yellow.withValues(alpha: .25),
                focusColor: AppColors.yellow.withValues(alpha: .35),
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 22, 23, 44),
                    child: Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Preguntale a',
                                  style: TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                                DarditoAnimatedName(
                                  style: TextStyle(
                                    fontFamily: 'Lora',
                                    color: AppColors.ink,
                                    fontSize: 37,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: AppColors.yellow,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.north_east_rounded,
                            size: 21,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SpeechBubbleShape extends ShapeBorder {
  const _SpeechBubbleShape();
  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(2);
  @override
  ShapeBorder scale(double t) => this;
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = rect.deflate(2);
    final w = r.width;
    final h = r.height;
    return Path()
      ..moveTo(r.left + 24, r.top + 3)
      ..quadraticBezierTo(r.left + w * .55, r.top - 2, r.right - 23, r.top + 5)
      ..quadraticBezierTo(r.right, r.top + 7, r.right, r.top + 29)
      ..lineTo(r.right - 2, r.top + h * .62)
      ..quadraticBezierTo(
        r.right - 3,
        r.top + h * .76,
        r.right - 27,
        r.top + h * .77,
      )
      ..lineTo(r.left + w * .79, r.top + h * .77)
      ..lineTo(r.right - 9, r.bottom)
      ..quadraticBezierTo(
        r.left + w * .69,
        r.top + h * .91,
        r.left + w * .61,
        r.top + h * .78,
      )
      ..lineTo(r.left + 26, r.top + h * .80)
      ..quadraticBezierTo(r.left, r.top + h * .80, r.left, r.top + h * .64)
      ..lineTo(r.left + 1, r.top + 27)
      ..quadraticBezierTo(r.left + 2, r.top + 5, r.left + 24, r.top + 3)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(2), textDirection: textDirection);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    canvas.drawPath(
      getOuterPath(rect),
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({required this.onExplore});
  final ValueChanged<String> onExplore;

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
              : 2;
          final width = (c.maxWidth - (16 * (columns - 1))) / columns;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (var index = 0; index < _explorationDoors.length; index++)
                _CategoryCard(
                  category: _explorationDoor(_explorationDoors[index]),
                  index: index,
                  width: width,
                  onTap: () => onExplore(_explorationDoors[index].id),
                ),
            ],
          );
        },
      ),
    ],
  );
}

const _explorationDoors = <StoryCategory>[
  StoryCategory(
    'architecture',
    'Arquitectura',
    Icons.architecture_rounded,
    AppColors.rust,
    description:
        'Historias vinculadas a edificios, casas, plazas, monumentos, calles, obras, espacios urbanos y al diseño de la ciudad.',
  ),
  StoryCategory(
    'mystery',
    'Misterios',
    Icons.help_outline_rounded,
    Color(0xFF5E537B),
    description:
        'Historias, enigmas, leyendas, versiones o preguntas que todavía no tienen una explicación del todo clara.',
  ),
  StoryCategory(
    'culture',
    'Cultura',
    Icons.theater_comedy_rounded,
    Color(0xFF9A6B24),
    description:
        'Costumbres, expresiones, personajes, espacios, actividades o formas de vivir que forman parte de la identidad y la vida cotidiana de La Plata.',
  ),
  StoryCategory(
    'memory',
    'Tradición oral',
    Icons.record_voice_over_outlined,
    Color(0xFF416A76),
    description:
        'Historias que se transmitieron de persona a persona, en familias, barrios, clubes, escuelas o instituciones, aunque no siempre estén escritas o documentadas.',
  ),
];

StoryCategory _explorationDoor(StoryCategory fallback) {
  final description = StoryCatalog.resolve(
    fallback.id,
    fallback.label,
  ).description?.trim();
  return StoryCategory(
    fallback.id,
    fallback.label,
    fallback.icon,
    fallback.color,
    description: description == null || description.isEmpty
        ? fallback.description
        : description,
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
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: category.color.withValues(alpha: .05),
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 24, 16, 24),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 45,
                child: Text(
                  '0${index + 1}',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 17,
                    color: category.color,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category.label,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(fontSize: 26),
                          ),
                        ),
                        Icon(category.icon, size: 25, color: category.color),
                        const SizedBox(width: 18),
                        const Icon(
                          Icons.arrow_forward,
                          size: 20,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Text(
                      category.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                        height: 1.65,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
              : 3;
          final width = (c.maxWidth - (cols - 1) * 16) / cols;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (var index = 0; index < stories.length; index++)
                SizedBox(
                  width: width,
                  height: 310,
                  child: _RefinedStoryCard(
                    story: stories[index],
                    onTap: () => showStoryDetails(context, stories[index]),
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

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/map/la_plata_map_style.json').then((style) {
      if (mounted) setState(() => _mapStyle = style);
    });
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: EdgeInsets.zero,
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
                  'Recorré La Plata por barrio, época o curiosidad. Encontrá historias documentadas y aportes de vecinos, familias e instituciones.',
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
            borderRadius: BorderRadius.zero,
            child: SizedBox(
              height: narrow ? 340 : 470,
              child: HomeMapPreview(
                stories: widget.stories,
                style: _mapStyle,
                onExplore: widget.onExplore,
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
            'Tu historia también puede\nformar parte del mapa.',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 18),
          Text(
            'Puede ser una persona, un comercio, una institución, una costumbre, una fotografía, un lugar especial o algo que esté ocurriendo hoy. Cada aporte se revisa antes de publicarse.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          Text(
            'La Plata también se cuenta desde quienes la viven.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.muted,
              fontStyle: FontStyle.italic,
            ),
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
                'Identificamos cada historia como Documentada o Aporte de vecinos, según su respaldo.',
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
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth >= 1050
        ? _DesktopWhatsAppCallout(onAsk: onAsk)
        : _CompactWhatsAppCallout(onAsk: onAsk),
  );
}

class _DesktopWhatsAppCallout extends StatelessWidget {
  const _DesktopWhatsAppCallout({required this.onAsk});
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 390,
    child: ColoredBox(
      color: AppColors.cream,
      child: Stack(
        children: [
          const Positioned(
            top: 105,
            right: 0,
            bottom: 0,
            left: 0,
            child: ColoredBox(color: AppColors.yellow),
          ),
          Positioned.fill(
            child: MaxWidth(
              child: Stack(
                children: [
                  Positioned(
                    top: 155,
                    right: 0,
                    left: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(child: _WhatsAppCopy()),
                        const SizedBox(width: 280),
                        _WhatsAppButton(onAsk: onAsk),
                      ],
                    ),
                  ),
                  const Positioned(
                    top: 0,
                    right: 205,
                    child: _BoundaryDardito(width: 270, height: 360),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CompactWhatsAppCallout extends StatelessWidget {
  const _CompactWhatsAppCallout({required this.onAsk});
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final phone = constraints.maxWidth < 600;
      final artHeight = phone ? 250.0 : 290.0;
      final artWidth = phone ? 188.0 : 218.0;
      return ColoredBox(
        color: AppColors.cream,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 80),
              padding: EdgeInsets.fromLTRB(24, phone ? 205 : 230, 24, 52),
              color: AppColors.yellow,
              child: MaxWidth(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WhatsAppCopy(compact: phone),
                    const SizedBox(height: 28),
                    _WhatsAppButton(onAsk: onAsk),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: _BoundaryDardito(width: artWidth, height: artHeight),
            ),
          ],
        ),
      );
    },
  );
}

class _WhatsAppCopy extends StatelessWidget {
  const _WhatsAppCopy({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionEyebrow('También en WhatsApp'),
      const SizedBox(height: 16),
      Text(
        'Una conversación puede ser el comienzo de otro recorrido.',
        style: Theme.of(
          context,
        ).textTheme.displayMedium?.copyWith(fontSize: compact ? 36 : 42),
      ),
      const SizedBox(height: 12),
      const Text(
        'Preguntá por tu barrio, una persona, un lugar, una época o pedile a Dardito una historia al azar.',
      ),
    ],
  );
}

class _WhatsAppButton extends StatelessWidget {
  const _WhatsAppButton({required this.onAsk});
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onAsk,
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.paper,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    ),
    icon: const Icon(Icons.forum_outlined),
    label: const Text('Abrir WhatsApp'),
  );
}

class _BoundaryDardito extends StatelessWidget {
  const _BoundaryDardito({required this.width, required this.height});
  final double width;
  final double height;

  static const _asset = 'assets/brand/dardito_seated_phone_v1.png';

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Dardito sentado conversando por teléfono',
    child: SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: Transform.translate(
                offset: const Offset(8, 12),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: .28),
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(
                      _asset,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Image.asset(
              _asset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
            ),
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
                'Historias, lugares y personas de ayer y de hoy que hacen única a La Plata.',
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
                if (mobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '© 2026 El Mapa de las Historias de La Plata',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      const _SimbiosisDigitalLink(),
                    ],
                  )
                else
                  const Row(
                    children: [
                      Text(
                        '© 2026 El Mapa de las Historias de La Plata',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      Spacer(),
                      _SimbiosisDigitalLink(),
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
  Widget build(BuildContext context) => const ProjectMark(light: true);
}

class _SimbiosisDigitalLink extends StatelessWidget {
  const _SimbiosisDigitalLink();

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      await launchUrl(
        Uri.parse('https://simbiosisdigital.com.ar'),
        mode: LaunchMode.externalApplication,
      );
    },
    child: const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'Desarrollado por SimbiosisDigital',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
    ),
  );
}

class _RefinedStoryCard extends StatelessWidget {
  const _RefinedStoryCard({required this.story, required this.onTap});
  final CityStory story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: AppColors.line),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 18, color: story.category.color),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    story.category.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: story.category.color,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_outward_rounded,
                  size: 20,
                  color: AppColors.muted,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 7),
            Text(
              story.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              story.shortStory,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            if (story.publicAuthor != null) ...[
              const SizedBox(height: 6),
              Text(
                'Aporte de: ${story.publicAuthor}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const Spacer(),
            const Divider(color: AppColors.line, height: 28),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 15),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    story.neighborhood,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${story.readMinutes} min',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: AppColors.rust,
                ),
                const SizedBox(width: 4),
                Text(
                  '${story.likeCount}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
