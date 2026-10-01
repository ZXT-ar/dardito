import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/backend_config.dart';
import '../../core/config/whatsapp_config.dart';
import '../../core/platform/native_share.dart';
import '../../core/platform/whatsapp_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/story.dart';

Future<void> showStoryShareOptions(
  BuildContext context,
  CityStory story,
) async {
  final storyUrl = BackendConfig.publicStoryUri(story.id);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .9,
    ),
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Compartir historia',
                  style: Theme.of(sheetContext).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  story.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 22),
                _ShareOption(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'WhatsApp',
                  detail: 'Abrir una conversación con Dardito',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final opened = await openDarditoWhatsApp(
                      message:
                          'Hola Dardito, quiero conversar sobre esta historia:\n'
                          '${story.title}\n$storyUrl',
                    );
                    if (!opened && context.mounted) {
                      await Clipboard.setData(
                        const ClipboardData(
                          text: WhatsAppConfig.displayPhoneNumber,
                        ),
                      );
                      if (context.mounted) {
                        _notify(
                          context,
                          'No pudimos abrir WhatsApp. Copiamos el número +54 9 221 319-7058.',
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 10),
                _ShareOption(
                  icon: Icons.camera_alt_outlined,
                  title: 'Instagram',
                  detail: 'Abrir el selector del equipo para elegir Instagram',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final shared = await shareWithSystem(
                      title: story.title,
                      text: story.shortStory,
                      url: storyUrl,
                    );
                    if (!shared) {
                      await Clipboard.setData(
                        ClipboardData(text: storyUrl.toString()),
                      );
                      await launchUrl(
                        Uri.parse('https://www.instagram.com/'),
                        mode: LaunchMode.externalApplication,
                      );
                      if (context.mounted) {
                        _notify(
                          context,
                          'Enlace copiado. Pegalo en tu historia o mensaje de Instagram.',
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 10),
                _ShareOption(
                  icon: Icons.link_rounded,
                  title: 'Copiar enlace',
                  detail: 'Copiar el vínculo único de esta historia',
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: storyUrl.toString()),
                    );
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                    if (context.mounted) {
                      _notify(context, 'Enlace de la historia copiado.');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_outward_rounded, size: 20),
          ],
        ),
      ),
    ),
  );
}
