import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/site_palette.dart';
import 'ui.dart';

class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key, required this.onOpenLegal});
  final VoidCallback onOpenLegal;

  @override
  Widget build(BuildContext context) => Container(
    color: SitePalette.of(context).heroPaper,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;
        final brand = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FooterBrandMark(),
            SizedBox(height: 20),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 430),
              child: Text(
                'Historias, lugares y personas de ayer y de hoy que hacen única a La Plata.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: SitePalette.of(context).muted,
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
                  onPressed: onOpenLegal,
                  style: TextButton.styleFrom(
                    foregroundColor: SitePalette.of(context).ink,
                  ),
                  child: Text('Términos y condiciones'),
                ),
              ],
            ),
            SizedBox(height: 22),
            Text(
              'La ciudad nunca termina de contarse.',
              textAlign: mobile ? TextAlign.left : TextAlign.right,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: SitePalette.of(context).ink,
              ),
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
                    children: [brand, SizedBox(height: 38), links],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 5, child: brand),
                      SizedBox(width: 64),
                      Expanded(flex: 6, child: links),
                    ],
                  ),
                SizedBox(height: 44),
                Divider(color: SitePalette.of(context).line),
                SizedBox(height: 22),
                if (mobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '© 2026 El Mapa de las Historias de La Plata',
                        style: TextStyle(
                          color: SitePalette.of(context).muted,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 8),
                      _SimbiosisDigitalLink(),
                    ],
                  )
                else
                  Row(
                    children: [
                      Text(
                        '© 2026 El Mapa de las Historias de La Plata',
                        style: TextStyle(
                          color: SitePalette.of(context).muted,
                          fontSize: 12,
                        ),
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
  Widget build(BuildContext context) => ProjectMark();
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
