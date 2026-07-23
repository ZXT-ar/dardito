import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/repositories/story_repository.dart';

class ContributePage extends StatefulWidget {
  const ContributePage({
    super.key,
    required this.user,
    required this.onSignOut,
    required this.onExplore,
  });
  final AuthUser user;
  final VoidCallback onSignOut;
  final VoidCallback onExplore;
  @override
  State<ContributePage> createState() => _ContributePageState();
}

class _ContributePageState extends State<ContributePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _story = TextEditingController();
  final _contact = TextEditingController();
  String? _category;
  String? _neighborhood;
  bool _consent = false;
  bool _sent = false;

  @override
  void dispose() {
    _title.dispose();
    _story.dispose();
    _contact.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Necesitamos tu consentimiento para revisar el aporte.',
          ),
        ),
      );
      return;
    }
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        Container(
          color: AppColors.yellow,
          padding: EdgeInsets.only(
            top: MediaQuery.sizeOf(context).width >= 760 ? 150 : 58,
            bottom: 58,
          ),
          child: MaxWidth(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 820;
                final character = Semantics(
                  image: true,
                  label: 'Dardito escucha con atención tu historia',
                  child: Image.asset(
                    'assets/brand/dardito_listening.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    filterQuality: FilterQuality.high,
                  ),
                );
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionEyebrow('Historias de la gente'),
                    const SizedBox(height: 18),
                    Text(
                      'Vos también sos parte\ndel mapa.',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: MediaQuery.sizeOf(context).width < 600
                            ? 48
                            : 64,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Text(
                        'Compartí un recuerdo, una fotografía o un relato de tu barrio. Dardito lo guarda para que nuestro equipo pueda revisarlo con cuidado.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SignedInChip(
                      user: widget.user,
                      onSignOut: widget.onSignOut,
                    ),
                  ],
                );
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(width: 280, height: 390, child: character),
                          const SizedBox(width: 44),
                          Expanded(child: copy),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: SizedBox(height: 220, child: character),
                          ),
                          const SizedBox(height: 22),
                          copy,
                        ],
                      );
              },
            ),
          ),
        ),
        const SizedBox(height: 56),
        MaxWidth(
          child: _sent
              ? _Success(onExplore: widget.onExplore)
              : LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth > 820;
                    final guide = const _ReviewGuide();
                    final form = _ContributionForm(
                      formKey: _formKey,
                      title: _title,
                      story: _story,
                      contact: _contact,
                      category: _category,
                      neighborhood: _neighborhood,
                      consent: _consent,
                      onCategory: (v) => setState(() => _category = v),
                      onNeighborhood: (v) => setState(() => _neighborhood = v),
                      onConsent: (v) => setState(() => _consent = v ?? false),
                      onSubmit: _submit,
                    );
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 330, child: guide),
                              const SizedBox(width: 54),
                              Expanded(child: form),
                            ],
                          )
                        : Column(
                            children: [guide, const SizedBox(height: 38), form],
                          );
                  },
                ),
        ),
        const SizedBox(height: 80),
      ],
    ),
  );
}

class _SignedInChip extends StatelessWidget {
  const _SignedInChip({required this.user, required this.onSignOut});
  final AuthUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
    decoration: BoxDecoration(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.yellow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            user.provider == AuthProvider.google
                ? Icons.g_mobiledata_rounded
                : Icons.apple_rounded,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'IDENTIDAD CONECTADA',
              style: TextStyle(
                color: AppColors.yellow,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            Text(
              user.email,
              style: const TextStyle(
                color: AppColors.paper,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: onSignOut,
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.logout_rounded,
            color: AppColors.paper,
            size: 18,
          ),
        ),
      ],
    ),
  );
}

class _ReviewGuide extends StatelessWidget {
  const _ReviewGuide();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '¿Qué pasa después?',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 24),
      const _Step(
        number: '01',
        title: 'Recibimos tu historia',
        text: 'Queda guardada de forma privada.',
      ),
      const _Step(
        number: '02',
        title: 'La revisamos',
        text: 'Validamos fuentes, permisos y datos sensibles.',
      ),
      const _Step(
        number: '03',
        title: 'Te contactamos',
        text: 'Podemos pedirte contexto antes de publicarla.',
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.paper,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Enviar una historia no implica su publicación automática.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.text});
  final String number;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: AppColors.rust,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 14),
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

class _ContributionForm extends StatelessWidget {
  const _ContributionForm({
    required this.formKey,
    required this.title,
    required this.story,
    required this.contact,
    required this.category,
    required this.neighborhood,
    required this.consent,
    required this.onCategory,
    required this.onNeighborhood,
    required this.onConsent,
    required this.onSubmit,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController title, story, contact;
  final String? category;
  final String? neighborhood;
  final bool consent;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String?> onNeighborhood;
  final ValueChanged<bool?> onConsent;
  final VoidCallback onSubmit;
  static final neighborhoods = LocalStoryRepository()
      .getAll()
      .map((story) => story.neighborhood)
      .toSet()
      .toList();
  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Este campo es necesario' : null;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 20 : 34),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contanos tu historia',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'No hace falta escribir perfecto. Lo importante es que no se pierda.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 30),
            const _FieldLabel('Título o idea principal'),
            const SizedBox(height: 8),
            TextFormField(
              controller: title,
              validator: _required,
              decoration: const InputDecoration(
                hintText: 'Ej: El almacén de mi abuelo en Tolosa',
              ),
            ),
            const SizedBox(height: 20),
            const _FieldLabel('¿Qué pasó?'),
            const SizedBox(height: 8),
            TextFormField(
              controller: story,
              validator: (v) => v == null || v.trim().length < 30
                  ? 'Contanos un poco más (al menos 30 caracteres)'
                  : null,
              minLines: 5,
              maxLines: 9,
              decoration: const InputDecoration(
                hintText:
                    'Escribí el relato con todos los detalles que recuerdes…',
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 560;
                final fields = [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Lugar o barrio'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: neighborhood,
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(18),
                          dropdownColor: AppColors.paper,
                          validator: (value) =>
                              value == null ? 'Elegí un barrio o zona' : null,
                          decoration: _dropdownDecoration('Seleccionar barrio'),
                          items: neighborhoods
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: onNeighborhood,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Categoría'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(18),
                          dropdownColor: AppColors.paper,
                          validator: (v) =>
                              v == null ? 'Elegí una categoría' : null,
                          decoration: _dropdownDecoration(
                            'Seleccionar categoría',
                          ),
                          items: LocalStoryRepository.categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.label),
                                ),
                              )
                              .toList(),
                          onChanged: onCategory,
                        ),
                      ],
                    ),
                  ),
                ];
                return narrow
                    ? Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: fields[0].child,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: fields[1].child,
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          fields[0],
                          const SizedBox(width: 16),
                          fields[1],
                        ],
                      );
              },
            ),
            const SizedBox(height: 20),
            const _FieldLabel('Tu email o teléfono'),
            const SizedBox(height: 8),
            TextFormField(
              controller: contact,
              validator: _required,
              decoration: const InputDecoration(
                hintText: 'Para contactarte durante la revisión',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'La carga de imágenes estará conectada al almacenamiento en la siguiente etapa.',
                  ),
                ),
              ),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Sumar fotos o documentos'),
            ),
            const SizedBox(height: 18),
            CheckboxListTile(
              value: consent,
              onChanged: onConsent,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Confirmo que puedo compartir este material y acepto que sea revisado según la política de privacidad.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Enviar para revisión'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w800));
}

InputDecoration _dropdownDecoration(String hintText) => InputDecoration(
  hintText: hintText,
  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: AppColors.line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: AppColors.line),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: AppColors.rust),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: AppColors.rust, width: 1.5),
  ),
);

class _Success extends StatelessWidget {
  const _Success({required this.onExplore});
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 50),
    child: Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: const BoxDecoration(
            color: AppColors.yellow,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.favorite_rounded, size: 38),
        ),
        const SizedBox(height: 28),
        Text(
          'Tu historia ya es parte\ndel camino.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 16),
        const SizedBox(
          width: 520,
          child: Text(
            'La recibimos correctamente. Antes de sumarla al mapa, nuestro equipo revisará el contenido y podrá contactarte para conocer más.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.5),
          ),
        ),
        const SizedBox(height: 30),
        FilledButton.icon(
          onPressed: onExplore,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Seguir explorando'),
        ),
      ],
    ),
  );
}
