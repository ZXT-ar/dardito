import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
    color: AppColors.heroPaper,
    child: SingleChildScrollView(
      child: Column(
        children: [
          HomeCartography(
            stories: stories,
            onExplore: onExplore,
            hero: const bool.fromEnvironment('DARDITO_REFINED_HERO')
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
          const SizedBox(height: 96),
          Entrance(
            child: MaxWidth(
              child: PaperCategories(onExplore: onExploreCategory),
            ),
          ),
          const SizedBox(height: 96),
          Entrance(
            delay: const Duration(milliseconds: 80),
            child: MaxWidth(
              child: PaperFeatured(
                stories: stories.where((s) => s.featured).toList(),
                onOpen: (story) => showStoryDetails(context, story),
                onViewAll: () => onExplore(null),
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
          _WhatsAppCallout(onAsk: () => _openWhatsAppConversation(context)),
          _Footer(onOpenLegal: onOpenLegal),
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
              Text(
                'El Mapa de las\nHistorias de La Plata.',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppColors.cream,
                  fontSize: narrow ? 46 : 68,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Dardito te ayuda a descubrirlas.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.yellow,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  'Explorá las historias, personas, lugares y misterios que hicieron, hacen y siguen haciendo única a La Plata.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.cream.withValues(alpha: .78),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'La ciudad nunca deja de contarse.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.cream.withValues(alpha: .72),
                  fontStyle: FontStyle.italic,
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
      color: AppColors.heroPaper,
      child: Stack(
        children: [
          const Positioned(
            top: 105,
            right: 0,
            bottom: 0,
            left: 0,
            child: ColoredBox(color: AppColors.heroPaper),
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
        color: AppColors.heroPaper,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 80),
              padding: EdgeInsets.fromLTRB(24, phone ? 205 : 230, 24, 52),
              color: AppColors.heroPaper,
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
    color: AppColors.heroPaper,
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
                  color: AppColors.muted,
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
                  style: TextButton.styleFrom(foregroundColor: AppColors.ink),
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
              ).textTheme.headlineSmall?.copyWith(color: AppColors.ink),
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
                Divider(color: AppColors.line),
                const SizedBox(height: 22),
                if (mobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '© 2026 El Mapa de las Historias de La Plata',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
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
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
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
  Widget build(BuildContext context) => const ProjectMark();
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
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ),
  );
}
