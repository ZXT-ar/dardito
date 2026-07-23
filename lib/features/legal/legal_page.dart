import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';

enum LegalDocument { terms, privacy }

class LegalPage extends StatefulWidget {
  const LegalPage({
    super.key,
    required this.initialDocument,
    required this.onBack,
  });

  final LegalDocument initialDocument;
  final VoidCallback onBack;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  late LegalDocument _document;

  @override
  void initState() {
    super.initState();
    _document = widget.initialDocument;
  }

  @override
  Widget build(BuildContext context) {
    final isTerms = _document == LegalDocument.terms;
    return Material(
      color: AppColors.cream,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(0, 130, 0, 58),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.navy, Color(0xFF122B32)],
                ),
              ),
              child: MaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: widget.onBack,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.cream,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Volver a Dardito'),
                    ),
                    const SizedBox(height: 26),
                    const SectionEyebrow('Centro legal', light: true),
                    const SizedBox(height: 18),
                    Text(
                      'Reglas claras para cuidar\nlas historias de todos.',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.cream,
                        fontSize: MediaQuery.sizeOf(context).width < 600
                            ? 44
                            : 62,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Text(
                        'Transparencia, respeto y responsabilidad editorial para construir un mapa confiable de la memoria de La Plata.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.cream.withValues(alpha: .72),
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    _DocumentSwitch(
                      value: _document,
                      onChanged: (value) => setState(() => _document = value),
                    ),
                  ],
                ),
              ),
            ),
            MaxWidth(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 58),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final metadata = _LegalMetadata(isTerms: isTerms);
                    final body = AnimatedSwitcher(
                      duration: const Duration(milliseconds: 380),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(.025, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _LegalDocumentBody(
                        key: ValueKey(_document),
                        document: _document,
                      ),
                    );
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 285, child: metadata),
                              const SizedBox(width: 54),
                              Expanded(child: body),
                            ],
                          )
                        : Column(
                            children: [
                              metadata,
                              const SizedBox(height: 34),
                              body,
                            ],
                          );
                  },
                ),
              ),
            ),
            const _LegalFooter(),
          ],
        ),
      ),
    );
  }
}

class _DocumentSwitch extends StatelessWidget {
  const _DocumentSwitch({required this.value, required this.onChanged});
  final LegalDocument value;
  final ValueChanged<LegalDocument> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SwitchOption(
          label: 'Términos y condiciones',
          icon: Icons.gavel_rounded,
          selected: value == LegalDocument.terms,
          onTap: () => onChanged(LegalDocument.terms),
        ),
        _SwitchOption(
          label: 'Privacidad',
          icon: Icons.shield_outlined,
          selected: value == LegalDocument.privacy,
          onTap: () => onChanged(LegalDocument.privacy),
        ),
      ],
    ),
  );
}

class _SwitchOption extends StatelessWidget {
  const _SwitchOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 500 ? 12 : 20,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.yellow : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.yellow.withValues(alpha: .25),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? AppColors.ink : AppColors.cream,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.ink : AppColors.cream,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

class _LegalMetadata extends StatelessWidget {
  const _LegalMetadata({required this.isTerms});
  final bool isTerms;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                isTerms
                    ? Icons.description_outlined
                    : Icons.lock_outline_rounded,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isTerms ? 'Documento de uso' : 'Documento de privacidad',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const _MetadataRow(label: 'Versión', value: 'Borrador 1.0'),
            const _MetadataRow(label: 'Actualización', value: '21/07/2026'),
            const _MetadataRow(label: 'Responsable', value: 'Dardito'),
            const _MetadataRow(
              label: 'Jurisdicción',
              value: 'La Plata, Argentina',
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.yellow.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 19),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Texto operativo preliminar. Requiere validación jurídica antes del lanzamiento público.',
                style: TextStyle(fontSize: 12, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _LegalDocumentBody extends StatelessWidget {
  const _LegalDocumentBody({super.key, required this.document});
  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final terms = document == LegalDocument.terms;
    final sections = terms ? _termsSections : _privacySections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionEyebrow(
          terms ? 'Condiciones del servicio' : 'Tratamiento de datos',
        ),
        const SizedBox(height: 14),
        Text(
          terms ? 'Términos y condiciones' : 'Política de privacidad',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 14),
        Text(
          terms
              ? 'Estos términos regulan el acceso y uso de Dardito, el Mapa de las Historias de La Plata y sus canales asociados.'
              : 'Esta política explica qué información se solicita, para qué se utiliza y qué decisiones conservan las personas sobre sus datos.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 36),
        for (var i = 0; i < sections.length; i++)
          _LegalSection(
            number: (i + 1).toString().padLeft(2, '0'),
            title: sections[i].$1,
            body: sections[i].$2,
            bullets: sections[i].$3,
          ),
      ],
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({
    required this.number,
    required this.title,
    required this.body,
    required this.bullets,
  });
  final String number;
  final String title;
  final String body;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.yellow,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(body, style: const TextStyle(height: 1.6, color: AppColors.muted)),
        if (bullets.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final bullet in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: const BoxDecoration(
                      color: AppColors.yellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(bullet, style: const TextStyle(height: 1.45)),
                  ),
                ],
              ),
            ),
        ],
      ],
    ),
  );
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: AppColors.ink,
    padding: const EdgeInsets.symmetric(vertical: 38),
    child: const MaxWidth(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DarditoMark(light: true),
          Text(
            'Consultas legales y de privacidad\nlegal@dardito.ar · Documento preliminar',
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white60),
          ),
        ],
      ),
    ),
  );
}

const _termsSections = <(String, String, List<String>)>[
  (
    'Aceptación y alcance',
    'El acceso a Dardito implica la aceptación de estas condiciones. El servicio ofrece una experiencia cultural, turística y comunitaria destinada a descubrir historias vinculadas con la ciudad de La Plata.',
    [
      'Las personas deben utilizar la plataforma de manera lícita y respetuosa.',
      'La disponibilidad de funciones puede cambiar durante las etapas de prueba.',
    ],
  ),
  (
    'Naturaleza de los contenidos',
    'Dardito diferencia entre hechos documentados, interpretaciones, tradición oral y aportes de la comunidad. La clasificación busca aportar contexto y no constituye una certificación absoluta de veracidad.',
    [
      'Las leyendas y versiones no verificadas serán identificadas como tales.',
      'Los contenidos turísticos no reemplazan asesoramiento profesional ni información oficial.',
    ],
  ),
  (
    'Historias enviadas por la comunidad',
    'Quien comparte una historia declara que cuenta con autorización suficiente para enviar el texto, las imágenes y la documentación asociada. Todo aporte queda sujeto a revisión antes de una eventual publicación.',
    [
      'El envío no garantiza la publicación.',
      'Dardito podrá solicitar información adicional, editar el contenido o rechazarlo.',
      'No deben enviarse datos sensibles de terceros sin autorización.',
    ],
  ),
  (
    'Propiedad intelectual',
    'Cada persona conserva los derechos que le correspondan sobre el material original enviado. Al autorizar su publicación, concede a Dardito un permiso no exclusivo para reproducirlo, adaptarlo editorialmente y comunicarlo dentro del proyecto.',
    [
      'Las fuentes y autorías disponibles serán reconocidas.',
      'Los usos comerciales o cesiones adicionales requerirán acuerdos específicos cuando corresponda.',
    ],
  ),
  (
    'Conductas no permitidas',
    'No está permitido utilizar la plataforma para vulnerar derechos, acosar personas, difundir información manifiestamente falsa como hecho documentado o interferir con la seguridad y el funcionamiento del sistema.',
    [
      'Se podrán suspender aportes o accesos ante incumplimientos.',
      'Los contenidos sensibles podrán requerir revisión reforzada.',
    ],
  ),
  (
    'Cambios, contacto y vigencia',
    'Las condiciones podrán actualizarse para reflejar nuevas funciones, obligaciones o criterios editoriales. La versión vigente indicará su fecha de actualización y estará disponible desde el footer de la aplicación.',
    [],
  ),
];

const _privacySections = <(String, String, List<String>)>[
  (
    'Responsable y principios',
    'Dardito administrará la información bajo criterios de finalidad, minimización, seguridad y transparencia. Solo se solicitarán datos razonablemente necesarios para prestar el servicio y revisar aportes.',
    [],
  ),
  (
    'Información que podemos solicitar',
    'Al iniciar sesión o enviar una historia podremos recibir datos de identificación, contacto, contenido aportado y datos técnicos básicos de la interacción.',
    [
      'Nombre, correo electrónico e identificador del proveedor OAuth.',
      'Textos, ubicaciones, imágenes o documentos enviados voluntariamente.',
      'Registros técnicos necesarios para seguridad, diagnóstico y prevención de abuso.',
    ],
  ),
  (
    'Finalidades del tratamiento',
    'La información será utilizada para autenticar a la persona, gestionar el aporte, comunicarnos durante la revisión, moderar contenidos y mejorar la seguridad y calidad del servicio.',
    [
      'No se publicará el correo electrónico de quien aporta una historia.',
      'No se utilizarán datos para finalidades incompatibles sin información y consentimiento cuando corresponda.',
    ],
  ),
  (
    'Proveedores y transferencias',
    'La operación podrá requerir proveedores de autenticación, alojamiento, almacenamiento, analítica o mensajería. Cada integración deberá limitarse a la información necesaria y contar con condiciones adecuadas de protección.',
    [
      'Google y Apple actuarán según sus propias políticas durante OAuth.',
      'La lista definitiva de encargados se publicará antes del lanzamiento.',
    ],
  ),
  (
    'Conservación y seguridad',
    'Los datos serán conservados durante el tiempo necesario para revisar historias, cumplir obligaciones y proteger la plataforma. Se aplicarán controles técnicos y organizativos proporcionales al tipo de información.',
    [
      'Los aportes rechazados tendrán una política de eliminación definida.',
      'Los documentos e imágenes se almacenarán de forma privada durante la revisión.',
    ],
  ),
  (
    'Decisiones de las personas',
    'Las personas podrán solicitar acceso, actualización, corrección o eliminación de sus datos y retirar consentimientos cuando resulte aplicable. El canal formal será informado antes de la puesta en producción.',
    [
      'Las solicitudes requerirán validación razonable de identidad.',
      'También será posible consultar por el estado de una historia enviada.',
    ],
  ),
];
