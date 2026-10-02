import '../theme/site_palette.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

Future<void> showWhatsAppComingSoonDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: (dialogContext) => PointerInterceptor(
        child: AlertDialog(
          backgroundColor: SitePalette.of(context).paper,
          constraints: BoxConstraints(maxWidth: 440),
          insetPadding: EdgeInsets.all(20),
          scrollable: true,
          title: Row(
            children: [
              Expanded(child: Text('¡Hola!')),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: Text(
            'Pronto podremos hablar por WhatsApp. Regresá en unos días.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
