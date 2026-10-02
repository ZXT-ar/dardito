import '../../core/theme/site_palette.dart';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/site_footer.dart';

import '../../core/config/whatsapp_config.dart';
import '../../core/platform/whatsapp_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/story.dart';
import '../legal/legal_page.dart';
import '../story/story_widgets.dart';
import 'home_page_refined.dart' show RefinedHomeHero;
import 'home_cartography.dart';
import 'paper_discovery.dart';

class HomePage extends StatelessWidget {
  const HomePage({
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
  Widget build(BuildContext context) => ColoredBox(
    color: SitePalette.of(context).heroPaper,
    child: SingleChildScrollView(
      child: Column(
        children: [
          HomeCartography(
            stories: stories,
            onExplore: onExplore,
            hero: bool.fromEnvironment('DARDITO_REFINED_HERO')
                ? RefinedHomeHero(
                    withBackdrop: false,
                    onExplore: () => onExplore(null),
                    onAsk: () => onNavigate(2),
                  )
                : _Hero(
                    onExplore: () => onExplore(null),
                    onAsk: () => onNavigate(2),
                  ),
          ),
          SizedBox(
            height: MediaQuery.sizeOf(context).width >= 700 ? 105.6 : 96,
          ),
          Entrance(
            child: MaxWidth(
              child: PaperCategories(onExplore: onExploreCategory),
            ),
          ),
          SizedBox(
            height: MediaQuery.sizeOf(context).width >= 700 ? 105.6 : 96,
          ),
          Entrance(
            delay: Duration(milliseconds: 80),
            child: MaxWidth(
              child: PaperFeatured(
                stories: stories.where((s) => s.featured).toList(),
                onOpen: (story) => showStoryDetails(context, story),
                onViewAll: () => onExplore(null),
              ),
            ),
          ),
          SizedBox(
            height: MediaQuery.sizeOf(context).width >= 700 ? 105.6 : 96,
          ),
          Entrance(
            delay: Duration(milliseconds: 180),
            child: MaxWidth(
              child: _TrustSection(onContribute: () => onNavigate(3)),
            ),
          ),
          SizedBox(
            height: MediaQuery.sizeOf(context).width >= 700 ? 105.6 : 96,
          ),
          _WhatsAppCallout(onAsk: () => _openWhatsAppConversation(context)),
          SiteFooter(onOpenLegal: () => onOpenLegal(LegalDocument.terms)),
        ],
      ),
    ),
  );
}

Future<void> _openWhatsAppConversation(BuildContext context) async {
  final opened = await openDarditoWhatsApp(
    message: 'Hola Dardito, quiero conocer una historia de La Plata.',
  );
  if (opened || !context.mounted) return;
  await Clipboard.setData(
    ClipboardData(text: WhatsAppConfig.displayPhoneNumber),
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          'No pudimos abrir WhatsApp. Copiamos el número +54 9 221 319-7058.',
        ),
      ),
    );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onExplore, required this.onAsk});
  final VoidCallback onExplore;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: 650),
    decoration: BoxDecoration(
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
              Text(
                'El Mapa de las\nHistorias de La Plata.',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: SitePalette.of(context).cream,
                  fontSize: narrow ? 46 : 68,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Dardito te ayuda a descubrirlas.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.yellow,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 20),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 520),
                child: Text(
                  'Explorá las historias, personas, lugares y misterios que hicieron, hacen y siguen haciendo única a La Plata.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: SitePalette.of(context).cream.withValues(alpha: .78),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'La ciudad nunca deja de contarse.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: SitePalette.of(context).cream.withValues(alpha: .72),
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 34),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onExplore,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.yellow,
                      foregroundColor: SitePalette.of(context).ink,
                      padding: EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                    ),
                    icon: Icon(Icons.explore_outlined),
                    label: Text('Explorar el mapa'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onAsk,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SitePalette.of(context).cream,
                      side: BorderSide(
                        color: SitePalette.of(
                          context,
                        ).cream.withValues(alpha: .35),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                    ),
                    icon: Icon(Icons.chat_bubble_outline_rounded),
                    label: Text('Preguntale a Dardito'),
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
                  'assets/brand/dardito_hero_regenerated_v4.png',
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
                ? Column(children: [copy, SizedBox(height: 42), visual])
                : Row(
                    children: [
                      Expanded(flex: 10, child: copy),
                      SizedBox(width: 50),
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
      duration: Duration(milliseconds: 4200),
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
          SectionEyebrow('Un mapa entre todos'),
          SizedBox(height: 18),
          Text(
            'Tu historia también puede\nformar parte del mapa.',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          SizedBox(height: 18),
          Text(
            'Puede ser una persona, un comercio, una institución, una costumbre, una fotografía, un lugar especial o algo que esté ocurriendo hoy. Cada aporte se revisa antes de publicarse.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: SitePalette.of(context).muted,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'La Plata también se cuenta desde quienes la viven.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: SitePalette.of(context).muted,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onContribute,
            icon: Icon(Icons.add_a_photo_outlined),
            label: Text('Compartir una historia'),
          ),
        ],
      );
      final principles = Column(
        children: [
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
              children: [copy, SizedBox(height: 40), principles],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: copy),
                SizedBox(width: 80),
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
    padding: EdgeInsets.symmetric(vertical: 14),
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
        SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(color: SitePalette.of(context).muted),
              ),
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
      color: SitePalette.of(context).heroPaper,
      child: Stack(
        children: [
          Positioned(
            top: 105,
            right: 0,
            bottom: 0,
            left: 0,
            child: ColoredBox(color: SitePalette.of(context).heroPaper),
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
                        Expanded(child: _WhatsAppCopy()),
                        SizedBox(width: 280),
                        _WhatsAppButton(onAsk: onAsk),
                      ],
                    ),
                  ),
                  Positioned(
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
        color: SitePalette.of(context).heroPaper,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(top: 80),
              padding: EdgeInsets.fromLTRB(24, phone ? 205 : 230, 24, 52),
              color: SitePalette.of(context).heroPaper,
              child: MaxWidth(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WhatsAppCopy(compact: phone),
                    SizedBox(height: 28),
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
      SectionEyebrow('También en WhatsApp'),
      SizedBox(height: 16),
      Text(
        'Una conversación puede ser el comienzo de otro recorrido.',
        style: Theme.of(
          context,
        ).textTheme.displayMedium?.copyWith(fontSize: compact ? 36 : 42),
      ),
      SizedBox(height: 12),
      Text(
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
      backgroundColor: SitePalette.of(context).ink,
      foregroundColor: SitePalette.of(context).paper,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    ),
    icon: Icon(Icons.forum_outlined),
    label: Text('Abrir WhatsApp'),
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
                offset: Offset(8, 12),
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
