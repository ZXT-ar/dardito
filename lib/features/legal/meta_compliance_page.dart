import '../../core/theme/site_palette.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';

enum MetaComplianceDocument { serviceTerms, dataDeletionInstructions }

class MetaCompliancePage extends StatelessWidget {
  const MetaCompliancePage({super.key, required this.document});

  final MetaComplianceDocument document;

  @override
  Widget build(BuildContext context) {
    final content = switch (document) {
      MetaComplianceDocument.serviceTerms => _serviceTerms,
      MetaComplianceDocument.dataDeletionInstructions => _dataDeletion,
    };
    return Material(
      color: SitePalette.of(context).cream,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(0, 130, 0, 64),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [SitePalette.of(context).navy, Color(0xFF122B32)],
                ),
              ),
              child: MaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 900),
                      child: Text(
                        content.title,
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              color: SitePalette.of(context).cream,
                              fontSize: MediaQuery.sizeOf(context).width < 600
                                  ? 42
                                  : 62,
                            ),
                      ),
                    ),
                    SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 760),
                      child: Text(
                        content.summary,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: SitePalette.of(
                            context,
                          ).cream.withValues(alpha: .76),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            MaxWidth(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 58),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 900),
                    child: _ComplianceBody(sections: content.sections),
                  ),
                ),
              ),
            ),
            _ComplianceFooter(),
          ],
        ),
      ),
    );
  }
}

class _ComplianceBody extends StatelessWidget {
  const _ComplianceBody({required this.sections});

  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var index = 0; index < sections.length; index++)
        _ComplianceSection(
          number: (index + 1).toString().padLeft(2, '0'),
          title: sections[index].$1,
          body: sections[index].$2,
        ),
    ],
  );
}

class _ComplianceSection extends StatelessWidget {
  const _ComplianceSection({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 34),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.yellow.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            number,
            style: TextStyle(
              color: SitePalette.of(context).green,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: 9),
              SelectableText(
                body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: SitePalette.of(context).muted,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ComplianceFooter extends StatelessWidget {
  const _ComplianceFooter();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: SitePalette.of(context).ink,
    padding: EdgeInsets.symmetric(vertical: 42),
    child: MaxWidth(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 28,
        runSpacing: 22,
        children: [
          ProjectMark(compact: true),
          Text(
            'Consultas legales y solicitudes sobre datos\nlegal@dardito.ar',
            style: TextStyle(color: SitePalette.of(context).muted, height: 1.6),
          ),
        ],
      ),
    ),
  );
}

typedef _ComplianceContent = ({
  String title,
  String summary,
  List<(String, String)> sections,
});

const _ComplianceContent _serviceTerms = (
  title: 'Condiciones del servicio',
  summary:
      'Estas condiciones regulan el acceso y el uso de El Mapa de las Historias de La Plata, Dardito y sus servicios digitales asociados.',
  sections: [
    (
      'Identificación y alcance',
      'El servicio es provisto por El Mapa de las Historias de La Plata, proyecto cultural y tecnológico con sede operativa en La Plata, Provincia de Buenos Aires, Argentina. Estas condiciones se aplican al sitio web, al mapa, al asistente Dardito, a los formularios de aportes y a los canales digitales vinculados al proyecto.',
    ),
    (
      'Aceptación',
      'El acceso o uso del servicio implica la aceptación de estas Condiciones del servicio. Quien no esté de acuerdo deberá abstenerse de utilizarlo. Cuando una funcionalidad requiera marcar una casilla de consentimiento, esa aceptación será registrada junto con la versión vigente del documento.',
    ),
    (
      'Finalidad del servicio',
      'La plataforma permite descubrir, consultar y compartir historias, lugares, personas y memorias vinculadas con La Plata. Su finalidad es informativa, cultural, histórica, patrimonial y educativa. El contenido no constituye asesoramiento profesional, legal, académico ni una certificación absoluta de los hechos relatados.',
    ),
    (
      'Cuentas y acceso',
      'Algunas funciones pueden requerir autenticación mediante un proveedor externo. La persona usuaria debe aportar información auténtica, proteger el acceso a su cuenta y avisar ante cualquier uso no autorizado. El proyecto podrá limitar o suspender accesos cuando resulte necesario para proteger la seguridad, prevenir abusos o cumplir obligaciones legales.',
    ),
    (
      'Uso permitido',
      'La persona usuaria se compromete a utilizar el servicio de forma lícita y respetuosa. No podrá interferir con su funcionamiento, introducir código malicioso, intentar acceder sin autorización a sistemas o datos, eludir controles de seguridad, suplantar identidades, automatizar consultas abusivas ni utilizar el servicio para hostigar, discriminar, amenazar o vulnerar derechos de terceros.',
    ),
    (
      'Aportes de la comunidad',
      'Las historias, fotografías, documentos y demás materiales enviados por la comunidad se rigen además por los Términos y condiciones de aportes disponibles en /terminos_y_politicas. El envío no garantiza publicación. La persona aportante declara contar con legitimidad suficiente para compartir el material y acepta su revisión editorial.',
    ),
    (
      'Dardito y contenido automatizado',
      'Dardito puede generar respuestas mediante sistemas automatizados a partir del corpus editorial del proyecto. Aunque se aplican medidas de revisión y recuperación de fuentes, las respuestas pueden contener errores, omisiones o interpretaciones. La información relevante debe contrastarse con las fuentes indicadas y con documentación independiente.',
    ),
    (
      'Propiedad intelectual',
      'La identidad de Dardito, las marcas, diseños, interfaces, textos editoriales, bases organizadas, software y demás elementos propios del servicio se encuentran protegidos por la normativa aplicable. Los materiales de terceros conservan la titularidad y las condiciones que correspondan a sus autores o titulares. El acceso al servicio no transfiere derechos de propiedad intelectual.',
    ),
    (
      'Servicios de terceros',
      'El funcionamiento puede apoyarse en proveedores de autenticación, alojamiento, mapas, mensajería, analítica o infraestructura, incluidos servicios de Google, Firebase y Meta cuando corresponda. Cada proveedor puede aplicar sus propias condiciones. El proyecto procura utilizar únicamente los datos y permisos necesarios para prestar y proteger el servicio.',
    ),
    (
      'Disponibilidad y cambios',
      'El servicio puede actualizarse, modificarse, suspenderse o interrumpirse temporalmente por mantenimiento, seguridad, decisiones editoriales, cambios técnicos o causas ajenas al proyecto. No se garantiza disponibilidad permanente ni ausencia total de errores, aunque se adoptarán medidas razonables para sostener la continuidad y corregir incidentes.',
    ),
    (
      'Responsabilidad',
      'Dentro de los límites permitidos por la legislación aplicable, el proyecto no será responsable por decisiones adoptadas exclusivamente sobre la base de contenidos informativos del servicio, por usos contrarios a estas condiciones ni por interrupciones o acciones de terceros fuera de su control razonable. Nada en este documento limita derechos irrenunciables de consumidores o titulares de datos.',
    ),
    (
      'Protección y eliminación de datos',
      'Los datos personales se tratan para operar, proteger y mejorar el servicio, gestionar cuentas, conversaciones y aportes, y responder solicitudes. Las instrucciones para pedir su eliminación están disponibles en /eliminacion_de_datos. La supresión podrá estar limitada cuando exista una obligación legal de conservación o sea necesario proteger derechos legítimos de terceros.',
    ),
    (
      'Modificaciones de estas condiciones',
      'Estas condiciones podrán actualizarse para reflejar cambios funcionales, regulatorios o de seguridad. La versión y fecha de vigencia se publicarán en esta página. Cuando un cambio sea material y exista un medio de contacto disponible, podrán adoptarse medidas razonables para informarlo o solicitar una nueva aceptación.',
    ),
    (
      'Ley aplicable, jurisdicción y contacto',
      'Estas condiciones se interpretan conforme a las leyes de la República Argentina. Para cuestiones que no puedan resolverse de manera directa resultarán competentes los tribunales que correspondan en la ciudad de La Plata, sin perjuicio de las normas obligatorias aplicables. Las consultas pueden enviarse a legal@dardito.ar.',
    ),
  ],
);

const _ComplianceContent _dataDeletion = (
  title: 'Instrucciones para la eliminación de datos',
  summary:
      'Cualquier persona puede solicitar gratuitamente la eliminación de los datos personales vinculados con su uso de Dardito y El Mapa de las Historias de La Plata.',
  sections: [
    (
      'Cómo iniciar la solicitud',
      'Enviá un correo electrónico a legal@dardito.ar desde la misma dirección utilizada para acceder al servicio. Usá como asunto “Solicitud de eliminación de datos”. Si ya no tenés acceso a ese correo, indicalo en el mensaje para que podamos ofrecerte un método alternativo de verificación.',
    ),
    (
      'Información necesaria',
      'Incluí tu nombre completo, el correo asociado a la cuenta y una descripción de los datos que querés eliminar. Podés indicar, si corresponde, identificadores de cuenta o de Meta, conversaciones con Dardito, Me gusta, aportes enviados, fotografías u otros materiales. No envíes contraseñas, códigos de acceso ni información financiera.',
    ),
    (
      'Verificación de identidad',
      'Antes de eliminar datos podremos pedir información adicional estrictamente necesaria para comprobar que la solicitud proviene de la persona titular o de su representante autorizado. La verificación busca evitar que terceros eliminen información ajena. Los datos aportados para verificar identidad se utilizarán únicamente para tramitar el pedido.',
    ),
    (
      'Datos alcanzados',
      'Según el uso realizado, la solicitud puede comprender el perfil y los identificadores de autenticación, correo y nombre asociados, conversaciones y mensajes vinculados con la cuenta, reacciones o Me gusta, aportes pendientes o archivados, fotografías cargadas, datos de contacto, consentimientos y metadatos técnicos asociados directamente con la persona solicitante.',
    ),
    (
      'Conexiones con Meta',
      'Si vinculaste el servicio con Facebook, Instagram u otro producto de Meta, podés retirar primero el acceso desde la configuración de Aplicaciones y sitios web de tu cuenta de Meta. Esa acción revoca permisos en Meta, pero puede no eliminar automáticamente los datos ya enviados a nuestro servicio. Para completar la eliminación, remití también la solicitud por correo siguiendo estas instrucciones.',
    ),
    (
      'Plazo y confirmación',
      'Confirmaremos la recepción y tramitaremos las solicitudes procedentes dentro de los plazos legales aplicables. Cuando resulte aplicable la Ley argentina 25.326, la rectificación, actualización o supresión se realizará en un plazo máximo de cinco días hábiles desde la recepción del reclamo y la verificación razonable de identidad. Al finalizar enviaremos una confirmación al correo de contacto.',
    ),
    (
      'Contenido publicado y datos anonimizados',
      'Si un aporte ya fue publicado, se evaluará su retiro, anonimización o desvinculación de la identidad de la persona aportante. Los conteos y estadísticas agregadas que no permitan identificar a una persona pueden conservarse. La eliminación de una cuenta no obliga a suprimir hechos históricos, fuentes públicas o contenidos legítimos que no constituyan datos personales de quien realiza la solicitud.',
    ),
    (
      'Conservación excepcional',
      'Podrá conservarse información mínima cuando exista una obligación legal, sea necesaria para ejercer o defender derechos, investigar fraude o abuso, proteger la seguridad, respetar derechos de terceros o mantener registros de cumplimiento. Cuando sea posible, esos datos quedarán bloqueados, con acceso restringido y sin uso para finalidades ordinarias. Las copias de respaldo se eliminarán o sobrescribirán conforme a sus ciclos técnicos.',
    ),
    (
      'Gratuidad y reclamos',
      'La solicitud de supresión es gratuita. Si considerás que la respuesta es insuficiente o no se cumplió el plazo aplicable, podés formular un reclamo ante la Agencia de Acceso a la Información Pública de la República Argentina o ejercer las acciones previstas por la normativa vigente. Para seguimiento, escribí a legal@dardito.ar conservando el asunto y la copia del pedido original.',
    ),
  ],
);
