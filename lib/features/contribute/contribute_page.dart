import '../../core/theme/site_palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/auth_service.dart';
import '../../core/platform/image_file_picker.dart';
import '../../core/platform/upload_exit_guard.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/story.dart';
import '../legal/legal_page.dart';
import 'story_submission_service.dart';

class ContributePage extends StatefulWidget {
  const ContributePage({
    super.key,
    required this.user,
    required this.neighborhoods,
    required this.categories,
    required this.evidenceLevels,
    required this.onSignOut,
    required this.onExplore,
    required this.onOpenLegal,
  });

  final AuthUser user;
  final List<String> neighborhoods;
  final List<StoryCategory> categories;
  final List<MapEntry<String, String>> evidenceLevels;
  final VoidCallback onSignOut;
  final VoidCallback onExplore;
  final ValueChanged<LegalDocument> onOpenLegal;

  @override
  State<ContributePage> createState() => _ContributePageState();
}

class _ContributePageState extends State<ContributePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _story = TextEditingController();
  final _period = TextEditingController();
  final _exitGuard = UploadExitGuard();
  final List<SelectedStoryPhoto?> _photos = List.filled(storyPhotoLimit, null);
  String? _category;
  String? _neighborhood;
  String? _evidence;
  bool _materialConsent = false;
  bool _legalConsent = false;
  bool _isSubmitting = false;
  bool _isPickingPhotos = false;
  bool _filePickerNoticeAccepted = false;
  bool _sent = false;
  double _progress = 0;

  static final _sensitiveExpressions = <RegExp>[
    RegExp(
      r'\b(violaci[oó]n|violar|pedofilia|ped[oó]fil[oa]|abuso sexual|pornograf[ií]a infantil)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(descuartizar|degollar|mutilar|torturar|matar|asesinar|arma|pistola|rev[oó]lver)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(pito|pene|culo|teta|concha|vagina|genital|pelotud[oa]|bolud[oa]|forr[oa]|put[oa]|mierda|carajo|imb[eé]cil|idiota)\b',
      caseSensitive: false,
    ),
  ];

  @override
  void dispose() {
    _exitGuard.disable();
    _title.dispose();
    _story.dispose();
    _period.dispose();
    super.dispose();
  }

  List<String> _sensitiveMatches() {
    final text = '${_title.text}\n${_story.text}';
    return _sensitiveExpressions
        .expand((expression) => expression.allMatches(text))
        .map((match) => match.group(0)!.toLowerCase())
        .toSet()
        .toList();
  }

  Future<void> _pickPhotos({int? replaceIndex}) async {
    if (_isSubmitting || _isPickingPhotos) return;
    final remaining = replaceIndex == null
        ? _photos.where((photo) => photo == null).length
        : 1;
    if (remaining == 0) return;

    if (!_filePickerNoticeAccepted) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Elegir fotos desde archivos'),
          content: Text(
            'Dardito abrirá el explorador de archivos de tu dispositivo. '
            'Sólo podrá leer las imágenes que elijas y no usará la cámara.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: Icon(Icons.folder_open_rounded),
              label: Text('Abrir archivos'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      _filePickerNoticeAccepted = true;
    }

    setState(() => _isPickingPhotos = true);
    try {
      final result = await pickImageFiles(
        allowMultiple: replaceIndex == null && remaining > 1,
      );
      if (result == null || !mounted) return;

      final selected = <SelectedStoryPhoto>[];
      for (final file in result.take(remaining)) {
        final bytes = file.bytes;
        final extension = file.name.split('.').last.toLowerCase();
        final contentType = switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          'jpg' || 'jpeg' => 'image/jpeg',
          _ => null,
        };
        if (contentType == null) {
          _notice('Sólo se admiten imágenes JPG, PNG o WebP.');
          return;
        }
        if (bytes.lengthInBytes > storyPhotoBytesLimit) {
          _notice('Cada foto puede pesar como máximo 8 MB.');
          return;
        }
        selected.add(
          SelectedStoryPhoto(
            name: file.name,
            bytes: bytes,
            contentType: contentType,
          ),
        );
      }
      if (selected.isEmpty) return;

      final currentBytes = _photos.whereType<SelectedStoryPhoto>().fold<int>(
        0,
        (sum, photo) => sum + photo.bytes.lengthInBytes,
      );
      final replacedBytes = replaceIndex == null
          ? 0
          : _photos[replaceIndex]?.bytes.lengthInBytes ?? 0;
      final incomingBytes = selected.fold<int>(
        0,
        (sum, photo) => sum + photo.bytes.lengthInBytes,
      );
      if (currentBytes - replacedBytes + incomingBytes >
          storyPhotosTotalBytesLimit) {
        _notice('Las tres fotos pueden pesar como máximo 20 MB en total.');
        return;
      }

      setState(() {
        if (replaceIndex != null) {
          _photos[replaceIndex] = selected.first;
        } else {
          for (final photo in selected) {
            final empty = _photos.indexWhere((item) => item == null);
            if (empty >= 0) _photos[empty] = photo;
          }
        }
      });
    } on ImageFilePickerException catch (error) {
      if (mounted) {
        _notice(error.message);
      }
    } catch (_) {
      if (mounted) {
        _notice('No pudimos leer las fotos seleccionadas. Intentá nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _isPickingPhotos = false);
    }
  }

  Future<void> _editPhoto(int index) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.swap_horiz_rounded),
              title: Text('Cambiar esta foto'),
              onTap: () => Navigator.pop(context, 'replace'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded),
              title: Text('Quitar esta foto'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'replace') await _pickPhotos(replaceIndex: index);
    if (action == 'remove') setState(() => _photos[index] = null);
  }

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showContentWarning(List<String> matches) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revisá el contenido'),
        content: Text(
          'Detectamos expresiones que podrían describir contenido violento, sexual '
          'o contrario a las reglas (${matches.take(4).join(', ')}). '
          'Editá el relato antes de enviarlo.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onOpenLegal(LegalDocument.terms);
            },
            child: Text('Ver términos'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Volver a editar'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_materialConsent || !_legalConsent) {
      _notice('Para enviar, confirmá obligatoriamente las dos declaraciones.');
      return;
    }
    final matches = _sensitiveMatches();
    if (matches.isNotEmpty) {
      await _showContentWarning(matches);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _progress = 0;
    });
    _exitGuard.enable();
    try {
      await StorySubmissionService().submit(
        title: _title.text.trim(),
        story: _story.text.trim(),
        category: _category!,
        neighborhood: _neighborhood!,
        period: _period.text.trim(),
        evidence: _evidence!,
        materialConsent: _materialConsent,
        legalConsent: _legalConsent,
        photos: _photos.whereType<SelectedStoryPhoto>().toList(),
        clientMetadata: {
          'platform': defaultTargetPlatform.name,
          'isWeb': kIsWeb,
          'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
          'timeZone': DateTime.now().timeZoneName,
          'timeZoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
          'viewportWidth': MediaQuery.sizeOf(context).width.round(),
          'viewportHeight': MediaQuery.sizeOf(context).height.round(),
        },
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (mounted) setState(() => _sent = true);
    } on StorySubmissionException catch (error) {
      if (!mounted) return;
      if (error.code == 'CONTENT_REVIEW_REQUIRED') {
        await _showContentWarning(error.details);
      } else {
        _notice(error.message);
      }
    } finally {
      _exitGuard.disable();
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_isSubmitting,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _isSubmitting) {
        _notice('Esperá, no salgas: tu historia todavía se está cargando.');
      }
    },
    child: Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              _Hero(user: widget.user, onSignOut: widget.onSignOut),
              SizedBox(height: 56),
              MaxWidth(
                child: _sent
                    ? _Success(onExplore: widget.onExplore)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final form = _ContributionForm(
                            formKey: _formKey,
                            title: _title,
                            story: _story,
                            period: _period,
                            category: _category,
                            neighborhood: _neighborhood,
                            evidence: _evidence,
                            materialConsent: _materialConsent,
                            legalConsent: _legalConsent,
                            isSubmitting: _isSubmitting,
                            photos: _photos,
                            neighborhoods: widget.neighborhoods,
                            categories: widget.categories,
                            evidenceLevels: widget.evidenceLevels,
                            onCategory: (value) =>
                                setState(() => _category = value),
                            onNeighborhood: (value) =>
                                setState(() => _neighborhood = value),
                            onEvidence: (value) =>
                                setState(() => _evidence = value),
                            onMaterialConsent: (value) => setState(
                              () => _materialConsent = value ?? false,
                            ),
                            onLegalConsent: (value) =>
                                setState(() => _legalConsent = value ?? false),
                            onPickPhotos: () => _pickPhotos(),
                            onEditPhoto: _editPhoto,
                            onOpenLegal: widget.onOpenLegal,
                            onSubmit: _submit,
                          );
                          if (constraints.maxWidth <= 820) {
                            return Column(
                              children: [
                                _ReviewGuide(),
                                SizedBox(height: 38),
                                form,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 330, child: _ReviewGuide()),
                              SizedBox(width: 54),
                              Expanded(child: form),
                            ],
                          );
                        },
                      ),
              ),
              SizedBox(height: 110),
            ],
          ),
        ),
        if (_isSubmitting)
          Positioned.fill(child: _UploadOverlay(progress: _progress)),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.user, required this.onSignOut});
  final AuthUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Container(
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
              'assets/brand/DarditoListening.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.high,
            ),
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionEyebrow('Historias de la gente'),
              SizedBox(height: 18),
              Text(
                'Vos también sos parte\ndel mapa.',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: MediaQuery.sizeOf(context).width < 600 ? 48 : 64,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Compartí un recuerdo, una fotografía o un relato de tu barrio. '
                'Dardito lo guarda para que nuestro equipo pueda revisarlo con cuidado.',
                style: TextStyle(fontSize: 18, height: 1.45),
              ),
              SizedBox(height: 24),
              _SignedInChip(user: user, onSignOut: onSignOut),
            ],
          );
          return wide
              ? Row(
                  children: [
                    SizedBox(width: 280, height: 390, child: character),
                    SizedBox(width: 44),
                    Expanded(child: copy),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(height: 220, child: character),
                    SizedBox(height: 22),
                    copy,
                  ],
                );
        },
      ),
    ),
  );
}

class _SignedInChip extends StatelessWidget {
  const _SignedInChip({required this.user, required this.onSignOut});
  final AuthUser user;
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(8, 8, 12, 8),
    decoration: BoxDecoration(
      color: SitePalette.of(context).inset,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.yellow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.g_mobiledata_rounded, color: AppColors.ink),
        ),
        SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IDENTIDAD CONECTADA',
                style: TextStyle(
                  color: SitePalette.of(context).rust,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                user.email,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: SitePalette.of(context).ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: onSignOut,
          icon: Icon(
            Icons.logout_rounded,
            color: SitePalette.of(context).ink,
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
      SizedBox(height: 24),
      _Step('01', 'Recibimos tu historia', 'Queda guardada de forma privada.'),
      _Step(
        '02',
        'La revisamos',
        'Validamos fuentes, permisos y datos sensibles.',
      ),
      _Step(
        '03',
        'Te contactamos',
        'Usamos el email con el que te autentificaste.',
      ),
      Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: SitePalette.of(context).paper,
          border: Border.all(color: SitePalette.of(context).line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'Enviar una historia no implica su publicación automática.',
          style: TextStyle(color: SitePalette.of(context).muted),
        ),
      ),
    ],
  );
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.title, this.text);
  final String number;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: TextStyle(
            color: SitePalette.of(context).rust,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
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

class _ContributionForm extends StatelessWidget {
  const _ContributionForm({
    required this.formKey,
    required this.title,
    required this.story,
    required this.period,
    required this.category,
    required this.neighborhood,
    required this.evidence,
    required this.materialConsent,
    required this.legalConsent,
    required this.isSubmitting,
    required this.photos,
    required this.neighborhoods,
    required this.categories,
    required this.evidenceLevels,
    required this.onCategory,
    required this.onNeighborhood,
    required this.onEvidence,
    required this.onMaterialConsent,
    required this.onLegalConsent,
    required this.onPickPhotos,
    required this.onEditPhoto,
    required this.onOpenLegal,
    required this.onSubmit,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController title;
  final TextEditingController story;
  final TextEditingController period;
  final String? category;
  final String? neighborhood;
  final String? evidence;
  final bool materialConsent;
  final bool legalConsent;
  final bool isSubmitting;
  final List<SelectedStoryPhoto?> photos;
  final List<String> neighborhoods;
  final List<StoryCategory> categories;
  final List<MapEntry<String, String>> evidenceLevels;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String?> onNeighborhood;
  final ValueChanged<String?> onEvidence;
  final ValueChanged<bool?> onMaterialConsent;
  final ValueChanged<bool?> onLegalConsent;
  final VoidCallback onPickPhotos;
  final ValueChanged<int> onEditPhoto;
  final ValueChanged<LegalDocument> onOpenLegal;
  final VoidCallback onSubmit;

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
            SizedBox(height: 8),
            Text(
              'No hace falta escribir perfecto. Lo importante es que no se pierda.',
              style: TextStyle(color: SitePalette.of(context).muted),
            ),
            SizedBox(height: 30),
            _FieldLabel('Título o idea principal'),
            SizedBox(height: 8),
            TextFormField(
              controller: title,
              maxLength: storyTitleLimit,
              inputFormatters: [
                LengthLimitingTextInputFormatter(storyTitleLimit),
                _SafeTextFormatter(),
              ],
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Escribí un título de al menos 3 caracteres'
                  : null,
              decoration: InputDecoration(
                hintText: 'Ej: El almacén de mi abuelo',
                counterText: '',
              ),
            ),
            SizedBox(height: 20),
            _FieldLabel('¿Qué pasó?'),
            SizedBox(height: 8),
            TextFormField(
              controller: story,
              minLines: 5,
              maxLines: 9,
              maxLength: storyBodyLimit,
              inputFormatters: [
                LengthLimitingTextInputFormatter(storyBodyLimit),
                _SafeTextFormatter(),
              ],
              validator: (value) => (value?.trim().length ?? 0) < 30
                  ? 'Contanos un poco más (al menos 30 caracteres)'
                  : null,
              decoration: InputDecoration(
                hintText:
                    'Escribí el relato con todos los detalles que recuerdes…',
              ),
            ),
            SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final children = [
                  _DropdownField(
                    label: 'Lugar o barrio',
                    value: neighborhood,
                    hint: 'Seleccionar barrio',
                    items: neighborhoods
                        .map((value) => MapEntry(value, value))
                        .toList(),
                    onChanged: onNeighborhood,
                  ),
                  _DropdownField(
                    label: 'Categoría',
                    value: category,
                    hint: 'Seleccionar categoría',
                    items: categories
                        .map((value) => MapEntry(value.id, value.label))
                        .toList(),
                    onChanged: onCategory,
                  ),
                ];
                return constraints.maxWidth < 560
                    ? Column(
                        children: [
                          children.first,
                          SizedBox(height: 20),
                          children.last,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: children.first),
                          SizedBox(width: 16),
                          Expanded(child: children.last),
                        ],
                      );
              },
            ),
            SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final periodField = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Fecha o período de tiempo'),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: period,
                      maxLength: storyPeriodLimit,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(storyPeriodLimit),
                        _SafeTextFormatter(),
                      ],
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Indicá una fecha o período aproximado'
                          : null,
                      decoration: InputDecoration(
                        hintText: 'Ej: 1940–1960 o década de 1980',
                        counterText: '',
                      ),
                    ),
                  ],
                );
                final evidenceField = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DropdownField(
                      label: 'Nivel de evidencia',
                      value: evidence,
                      hint: 'Seleccionar nivel',
                      items: evidenceLevels,
                      onChanged: onEvidence,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Documentada: historia respaldada y validada a partir de fuentes, archivos, publicaciones, documentos, registros u otros materiales verificables.\n\nAporte de vecinos: historia, dato, testimonio o material compartido por vecinos, familias, comercios, clubes, escuelas o instituciones, que luego puede ser revisado, ampliado y contrastado por el equipo.',
                    ),
                  ],
                );
                return constraints.maxWidth < 560
                    ? Column(
                        children: [
                          periodField,
                          SizedBox(height: 20),
                          evidenceField,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: periodField),
                          SizedBox(width: 16),
                          Expanded(child: evidenceField),
                        ],
                      );
              },
            ),
            SizedBox(height: 24),
            _FieldLabel('Sumar fotos (opcional)'),
            SizedBox(height: 6),
            Text(
              'Hasta 3 fotos JPG, PNG o WebP · 8 MB por foto · 20 MB en total.',
              style: TextStyle(
                color: SitePalette.of(context).muted,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: List.generate(
                storyPhotoLimit,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < storyPhotoLimit - 1 ? 10 : 0,
                    ),
                    child: _PhotoSlot(
                      photo: photos[index],
                      onTap: photos[index] == null
                          ? onPickPhotos
                          : () => onEditPhoto(index),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 18),
            CheckboxListTile(
              value: materialConsent,
              onChanged: onMaterialConsent,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'Confirmo que puedo compartir este material y autorizo su revisión.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            CheckboxListTile(
              value: legalConsent,
              onChanged: onLegalConsent,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Declaro que he leído y acepto los ',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  _LegalLink(
                    'Términos y Condiciones.',
                    () => onOpenLegal(LegalDocument.terms),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSubmitting ? null : onSubmit,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 18),
                ),
                icon: Icon(Icons.send_outlined),
                label: Text('Enviar para revisión'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SafeTextFormatter extends TextInputFormatter {
  _SafeTextFormatter();

  static final _unsafe = RegExp(
    r'[<>\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]',
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.replaceAll(_unsafe, ''));
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final String hint;
  final List<MapEntry<String, String>> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _FieldLabel(label),
      SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(18),
        dropdownColor: SitePalette.of(context).paper,
        validator: (value) => value == null ? 'Elegí una opción' : null,
        decoration: _dropdownDecoration(context, hint),
        items: items
            .map(
              (item) =>
                  DropdownMenuItem(value: item.key, child: Text(item.value)),
            )
            .toList(),
        onChanged: onChanged,
      ),
    ],
  );
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({required this.photo, required this.onTap});
  final SelectedStoryPhoto? photo;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: Semantics(
      button: true,
      label: photo == null
          ? 'Elegir foto desde el explorador de archivos'
          : 'Cambiar o quitar ${photo!.name}',
      child: Tooltip(
        message: photo == null
            ? 'Elegir desde archivos'
            : 'Cambiar o quitar foto',
        child: Material(
          color: SitePalette.of(context).paper,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: SitePalette.of(context).line),
                borderRadius: BorderRadius.circular(18),
              ),
              child: photo == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 30),
                        SizedBox(height: 6),
                        Text(
                          'Elegir',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(photo!.bytes, fit: BoxFit.cover),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: SitePalette.of(context).paper,
                            child: Icon(Icons.more_horiz_rounded, size: 18),
                          ),
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

class _LegalLink extends StatelessWidget {
  const _LegalLink(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Text(
      label,
      style: TextStyle(
        color: SitePalette.of(context).rust,
        fontSize: 13,
        height: 1.4,
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontWeight: FontWeight.w800));
}

InputDecoration _dropdownDecoration(BuildContext context, String hintText) =>
    InputDecoration(
      hintText: hintText,
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: SitePalette.of(context).line),
      ),
    );

class _UploadOverlay extends StatelessWidget {
  const _UploadOverlay({required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: SitePalette.of(context).ink.withValues(alpha: .82),
    child: Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0, 1)),
        duration: Duration(milliseconds: 350),
        builder: (context, value, _) => Container(
          width: 420,
          margin: EdgeInsets.all(24),
          padding: EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: SitePalette.of(context).paper,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 28)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/brand/dardito_frente_green_transparent.png',
                width: 82,
                height: 82,
              ),
              SizedBox(height: 20),
              Text(
                value < .84
                    ? 'Dardito está guardando tu historia…'
                    : 'Cerrando el archivo…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: 12),
              Text(
                'Esperá, no salgas ni cierres esta ventana.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SitePalette.of(context).muted),
              ),
              SizedBox(height: 22),
              LinearProgressIndicator(
                value: value == 0 ? null : value,
                minHeight: 10,
                borderRadius: BorderRadius.circular(10),
                color: AppColors.yellow,
                backgroundColor: SitePalette.of(context).line,
              ),
              SizedBox(height: 10),
              Text('${(value * 100).round()}%'),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Success extends StatelessWidget {
  const _Success({required this.onExplore});
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 50),
    child: Column(
      children: [
        CircleAvatar(
          radius: 43,
          backgroundColor: AppColors.yellow,
          child: Icon(Icons.favorite_rounded, size: 38),
        ),
        SizedBox(height: 28),
        Text(
          'Tu historia ya es parte\ndel camino.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium,
        ),
        SizedBox(height: 16),
        Text(
          'La recibimos correctamente. Antes de sumarla al mapa, nuestro equipo la revisará.',
          textAlign: TextAlign.center,
          style: TextStyle(color: SitePalette.of(context).muted, fontSize: 16),
        ),
        SizedBox(height: 30),
        FilledButton.icon(
          onPressed: onExplore,
          icon: Icon(Icons.map_outlined),
          label: Text('Seguir explorando'),
        ),
      ],
    ),
  );
}
