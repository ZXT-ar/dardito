import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../theme/app_theme.dart';

Future<void> showWhatsAppComingSoonDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: (dialogContext) => PointerInterceptor(
        child: AlertDialog(
          backgroundColor: AppColors.paper,
          constraints: const BoxConstraints(maxWidth: 440),
          insetPadding: const EdgeInsets.all(20),
          scrollable: true,
          title: Row(
            children: [
              const Expanded(child: Text('¡Hola!')),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: const Text(
            'Pronto podremos hablar por WhatsApp. Regresá en unos días.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
