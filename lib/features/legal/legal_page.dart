import '../../core/theme/site_palette.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';

enum LegalDocument { terms }

class LegalPage extends StatelessWidget {
  const LegalPage({
    super.key,
    required this.initialDocument,
    required this.onBack,
  });

  final LegalDocument initialDocument;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    assert(initialDocument == LegalDocument.terms);
    return Material(
      color: SitePalette.of(context).cream,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(0, 130, 0, 58),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    SitePalette.of(context).navy,
                    SitePalette.of(context).paper,
                  ],
                ),
              ),
              child: MaxWidth(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 900;
                    final copy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          onPressed: onBack,
                          style: TextButton.styleFrom(
                            foregroundColor: SitePalette.of(context).ink,
                          ),
                          icon: Icon(Icons.arrow_back_rounded),
                          label: Text('Volver al mapa'),
                        ),
                        SizedBox(height: 26),
                        SectionEyebrow('Centro legal', light: true),
                        SizedBox(height: 18),
                        Text(
                          'Reglas claras para cuidar\nlas historias de todos.',
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                color: SitePalette.of(context).ink,
                                fontSize: MediaQuery.sizeOf(context).width < 600
                                    ? 44
                                    : 62,
                              ),
                        ),
                        SizedBox(height: 18),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 680),
                          child: Text(
                            'Transparencia, respeto y responsabilidad editorial para construir un mapa confiable de la memoria de La Plata.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: SitePalette.of(context).muted,
                                ),
                          ),
                        ),
                        SizedBox(height: 34),
                        _DocumentLabel(),
                      ],
                    );
                    final artwork = Semantics(
                      image: true,
                      label:
                          'Dardito presenta un documento con los términos y condiciones',
                      child: SizedBox(
                        height: narrow ? 330 : 460,
                        child: Image.asset(
                          'assets/brand/dardito_legal_document_v1.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    );
                    return narrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              copy,
                              SizedBox(height: 36),
                              Center(child: artwork),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(flex: 7, child: copy),
                              SizedBox(width: 28),
                              Expanded(flex: 4, child: artwork),
                            ],
                          );
                  },
                ),
              ),
            ),
            MaxWidth(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 58),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final metadata = _LegalMetadata();
                    final body = _LegalDocumentBody();
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 285, child: metadata),
                              SizedBox(width: 54),
                              Expanded(child: body),
                            ],
                          )
                        : Column(
                            children: [metadata, SizedBox(height: 34), body],
                          );
                  },
                ),
              ),
            ),
            _LegalFooter(),
          ],
        ),
      ),
    );
  }
}

class _DocumentLabel extends StatelessWidget {
  const _DocumentLabel();

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: SitePalette.of(context).ink.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: SitePalette.of(context).ink.withValues(alpha: .12),
      ),
    ),
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 500 ? 12 : 20,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.yellow.withValues(alpha: .25),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.gavel_rounded,
            size: 18,
            color: SitePalette.of(context).ink,
          ),
          SizedBox(width: 8),
          Text(
            'Términos y condiciones',
            style: TextStyle(
              color: SitePalette.of(context).ink,
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
  const _LegalMetadata();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: SitePalette.of(context).paper,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: SitePalette.of(context).line),
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
          child: Icon(Icons.description_outlined),
        ),
        SizedBox(height: 18),
        Text('Documento de uso', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 16),
        _MetadataRow(label: 'Versión', value: '1.0'),
        _MetadataRow(label: 'Actualización', value: '02/09/2026'),
        _MetadataRow(
          label: 'Responsable',
          value: 'El Mapa de las Historias de La Plata',
        ),
        _MetadataRow(label: 'Jurisdicción', value: 'La Plata, Argentina'),
      ],
    ),
  );
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
            color: SitePalette.of(context).muted,
          ),
        ),
        SizedBox(height: 3),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _LegalDocumentBody extends StatelessWidget {
  const _LegalDocumentBody();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionEyebrow('Condiciones del servicio'),
      SizedBox(height: 14),
      Text(
        'Términos y condiciones',
        style: Theme.of(context).textTheme.displayMedium,
      ),
      SizedBox(height: 14),
      Text(
        'Al enviar una historia, relato, testimonio, recuerdo, tradición oral, memoria comunitaria, documento, fotografía, archivo, enlace, material audiovisual u otro contenido a través de esta plataforma, la persona usuaria declara haber leído y aceptado los presentes Términos y Condiciones.',
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: SitePalette.of(context).muted),
      ),
      SizedBox(height: 36),
      for (var i = 0; i < _termsSections.length; i++)
        _LegalSection(
          number: (i + 1).toString().padLeft(2, '0'),
          title: _termsSections[i].$1,
          body: _termsSections[i].$2,
        ),
    ],
  );
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: 14),
    padding: EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: SitePalette.of(context).paper,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: SitePalette.of(context).line),
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
                color: SitePalette.of(context).ink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                number,
                style: TextStyle(
                  color: AppColors.yellow,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Text(
          body,
          style: TextStyle(height: 1.6, color: SitePalette.of(context).muted),
        ),
      ],
    ),
  );
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: SitePalette.of(context).canvas,
    padding: EdgeInsets.symmetric(vertical: 38),
    child: MaxWidth(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 650;
          final details = Column(
            crossAxisAlignment: mobile
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Text(
                'Consultas legales\nlegal@dardito.ar',
                textAlign: mobile ? TextAlign.left : TextAlign.right,
                style: TextStyle(
                  color: SitePalette.of(context).muted,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 8),
              _SimbiosisDigitalLink(),
            ],
          );
          return mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProjectMark(light: true),
                    SizedBox(height: 24),
                    details,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ProjectMark(light: true),
                    SizedBox(width: 32),
                    Spacer(),
                    Flexible(child: details),
                  ],
                );
        },
      ),
    ),
  );
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
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'Desarrollado por SimbiosisDigital',
        style: TextStyle(color: SitePalette.of(context).muted, fontSize: 12),
      ),
    ),
  );
}

const _termsSections = <(String, String)>[
  (
    'Envío de aportes',
    'La persona usuaria podrá remitir historias, relatos, testimonios, recuerdos, tradiciones orales, memorias comunitarias, referencias históricas, culturales o patrimoniales, fotografías, documentos, archivos, enlaces, fuentes u otros contenidos que considere de interés para su eventual incorporación al proyecto. El envío de un aporte no implica su publicación automática ni genera obligación alguna para la plataforma de incorporarlo, difundirlo o mantenerlo publicado.',
  ),
  (
    'Legitimidad del aporte',
    'La persona usuaria declara que la información, relato, recuerdo, testimonio, tradición oral, memoria comunitaria o referencia que envía corresponde a contenidos que conoce, ha recibido, recopilado o se encuentra legítimamente habilitada para compartir. No se exige que la persona aportante sea autora o titular de derechos exclusivos sobre los hechos, relatos de tradición oral, recuerdos, acontecimientos históricos, leyendas, referencias culturales o contenidos de carácter comunitario que comunique. Cuando el aporte incluya obras, fotografías, documentos, grabaciones, textos, archivos u otros materiales concretos pertenecientes o atribuibles a terceros, la persona usuaria declara que cuenta con autorización para compartirlos o que su utilización resulta legítima. La persona usuaria se compromete a no enviar materiales cuya utilización sepa que vulnera derechos de autor, derechos de imagen, privacidad u otros derechos de terceros.',
  ),
  (
    'Autorización para revisión y tratamiento editorial',
    'Mediante la aceptación de estos Términos y Condiciones, la persona usuaria autoriza expresamente al equipo responsable de la plataforma a acceder, leer, analizar, verificar, clasificar, organizar, resumir, corregir, adaptar y revisar editorialmente el contenido enviado, con el objeto de evaluar su eventual incorporación al proyecto. La revisión podrá comprender, entre otras tareas: verificación de datos; corrección de errores; adecuación de redacción o extensión; elaboración de versiones resumidas o desarrolladas; clasificación temática; incorporación de palabras clave; identificación de referencias temporales o territoriales; georreferenciación; contraste con otras fuentes; vinculación con otras historias o contenidos; incorporación de referencias o información complementaria. La revisión, modificación o adaptación editorial no implica necesariamente que el contenido vaya a ser publicado.',
  ),
  (
    'Autorización para utilización y publicación',
    'Cuando el aporte resulte seleccionado, la persona usuaria autoriza a la plataforma a utilizar, reproducir, adaptar, resumir, editar, comunicar y poner a disposición el contenido aportado dentro del sitio, aplicaciones, mapas, herramientas conversacionales y demás medios digitales vinculados al proyecto. La autorización se concede de manera no exclusiva y gratuita y se limita a las finalidades informativas, culturales, históricas, patrimoniales, educativas y de difusión propias del proyecto. La plataforma podrá decidir no publicar un contenido, retirarlo de la publicación, archivarlo o modificar su forma de presentación cuando resulte necesario por razones editoriales, técnicas, legales, de verificación o de funcionamiento del proyecto.',
  ),
  (
    'Carácter gratuito del aporte',
    'El envío de historias, relatos, testimonios, documentos, fotografías, archivos u otros contenidos a través de la plataforma se realiza de manera voluntaria y gratuita. La persona usuaria reconoce que el aporte no genera derecho a percibir honorarios, regalías, participaciones, compensaciones, premios, retribuciones económicas ni ningún otro tipo de beneficio patrimonial por su recepción, revisión, adaptación, incorporación, publicación o utilización dentro del proyecto. La eventual mención del nombre de la persona aportante tendrá carácter meramente identificatorio o de reconocimiento y no implicará relación laboral, comercial, societaria ni derecho económico alguno frente a la plataforma o sus responsables.',
  ),
  (
    'Materiales de terceros',
    'Cuando el aporte incluya fotografías, documentos, recortes, grabaciones, textos, archivos u otros materiales identificables como obras o contenidos de terceros, el equipo podrá solicitar información sobre su origen, autoría, fuente o condiciones de utilización antes de decidir su publicación. La sola comunicación de una historia, recuerdo, tradición oral, leyenda, hecho histórico o información de conocimiento comunitario no queda sujeta a esta exigencia por el solo hecho de haber sido previamente transmitida por otras personas. La plataforma podrá optar por utilizar únicamente la información contenida en el aporte sin publicar el documento, fotografía, archivo o material adjunto que la acompaña.',
  ),
  (
    'Datos personales y autorización de contacto',
    'Para efectuar un aporte podrán solicitarse determinados datos personales y de contacto, incluyendo una dirección de correo electrónico. La persona usuaria autoriza expresamente al equipo responsable del proyecto a contactarla mediante la dirección de correo electrónico informada en relación con el aporte realizado. El contacto podrá efectuarse, entre otros motivos, para: solicitar aclaraciones; ampliar información; verificar datos, hechos o fuentes; consultar sobre el origen del relato o del material; solicitar documentación complementaria; efectuar consultas vinculadas con derechos de terceros; informar cuestiones relacionadas con la evaluación o eventual publicación del aporte. La dirección de correo electrónico y los demás datos de contacto no serán publicados como parte de la historia ni puestos a disposición del público, salvo autorización expresa de la persona usuaria. Dicha autorización habilita al equipo responsable del proyecto a publicar total o parcialmente los datos de contacto informados, cuando lo considere pertinente, sin que ello genere obligación alguna de hacerlo.',
  ),
  (
    'Nombre de la persona aportante',
    'La persona usuaria autoriza a que su nombre pueda ser mencionado o publicado en relación con el aporte enviado cuando el equipo responsable del proyecto considere pertinente identificar su colaboración, testimonio, aporte o autoría. Esta autorización no implica obligación alguna para la plataforma de publicar el nombre de la persona aportante. El contenido podrá ser difundido con identificación de quien realizó el aporte, sin identificación o bajo otra modalidad de reconocimiento editorial que resulte adecuada. Los datos de contacto de la persona aportante no serán publicados por el solo hecho de que se publique su nombre.',
  ),
  (
    'Revisión, contraste y verificación de los contenidos',
    'La persona usuaria reconoce que los contenidos enviados pueden ser sometidos a procesos de revisión, contraste, investigación o verificación antes o después de su publicación. La plataforma podrá comparar la información con documentos, publicaciones, archivos, fuentes bibliográficas, testimonios, otras historias o antecedentes disponibles. La recepción o publicación de un contenido no implica que la plataforma certifique como verdadero cada uno de los hechos relatados ni que adhiera a las opiniones, interpretaciones, creencias o versiones transmitidas por la persona aportante. Cuando la naturaleza del contenido corresponda a tradición oral, memoria comunitaria, leyenda, testimonio u otra fuente de naturaleza similar, podrá ser identificado o presentado como tal.',
  ),
  (
    'Contenidos que no deberán enviarse',
    'La persona usuaria se compromete a no enviar contenidos que: a) sean manifiestamente ilícitos; b) vulneren intencionalmente derechos de terceros; c) contengan datos personales cuya divulgación resulte ilegítima; d) incluyan amenazas, incitación a la violencia o expresiones manifiestamente discriminatorias; e) atribuyan delitos o hechos gravemente lesivos a personas identificadas o identificables sin elementos que permitan un adecuado análisis editorial; f) incluyan material obtenido de manera ilícita; g) contengan información cuya difusión pueda afectar ilegítimamente la intimidad, imagen, honor u otros derechos de terceros. La plataforma podrá rechazar, no publicar, modificar, suspender o retirar contenidos que considere incompatibles con estos criterios.',
  ),
  (
    'Fuentes e información complementaria',
    'La persona usuaria podrá indicar las fuentes, referencias, documentos o antecedentes en los que basa su aporte. La plataforma podrá incorporar, contrastar o complementar el contenido mediante otras fuentes. La inclusión de una fuente o referencia aportada por la persona usuaria no implica necesariamente que dicha fuente vaya a ser publicada íntegramente ni que sea considerada suficiente para validar la totalidad del contenido.',
  ),
  (
    'Conservación del aporte',
    'Los aportes y los materiales asociados podrán conservarse durante el tiempo necesario para su recepción, evaluación, revisión, verificación, documentación, eventual publicación, archivo y trazabilidad editorial. La circunstancia de que un contenido no sea publicado, sea retirado de la visualización pública o sea archivado no implica necesariamente su eliminación inmediata de los registros internos de la plataforma.',
  ),
  (
    'Ausencia de obligación de publicación',
    'La recepción de un aporte no genera derecho a exigir su publicación, permanencia, ubicación específica dentro del mapa o la plataforma, forma de presentación, extensión, reconocimiento de autoría o mención de la persona aportante. Las decisiones de selección, edición, clasificación, presentación, publicación, archivo o retiro corresponden al equipo responsable del proyecto.',
  ),
  (
    'Aceptación de los Términos y Condiciones',
    'La marcación de la casilla correspondiente y el posterior envío del formulario implican la lectura y aceptación expresa de los presentes Términos y Condiciones. La persona usuaria declara comprender que su aporte podrá ser revisado y modificado antes de su eventual publicación y que la plataforma decidirá en cada caso si corresponde incorporarlo al proyecto.',
  ),
];
