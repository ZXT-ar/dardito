import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/story.dart';
import 'dardito_assistant_service.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({
    super.key,
    required this.stories,
    required this.onExplore,
    required this.onNavigate,
  });
  final List<CityStory> stories;
  final ValueChanged<CityStory?> onExplore;
  final ValueChanged<int> onNavigate;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _Message {
  const _Message(this.text, {this.fromDardito = false, this.story});
  final String text;
  final bool fromDardito;
  final CityStory? story;
}

class _AssistantPageState extends State<AssistantPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final DarditoAssistantService _assistant = FirebaseDarditoAssistantService();
  late final String _conversationId =
      'web-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';
  bool _typing = false;
  final List<_Message> _messages = const [
    _Message(
      '¡Hola! Soy Dardito. Estoy para ayudarte a mirar La Plata con otros ojos. ¿Qué te gustaría descubrir?',
      fromDardito: true,
    ),
  ].toList();

  static const suggestions = [
    'Una historia al azar',
    'Misterios del centro',
    'Historias de barrios',
    '¿Qué pasó en 1882?',
  ];

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _typing) return;
    _controller.clear();
    setState(() {
      _messages.add(_Message(text));
      _typing = true;
    });
    _toBottom();
    try {
      final reply = await _assistant.send(
        message: text,
        conversationId: _conversationId,
      );
      if (!mounted) return;
      CityStory? story;
      for (final candidate in widget.stories) {
        if (reply.sourceIds.contains(candidate.id)) {
          story = candidate;
          break;
        }
      }
      setState(() {
        _typing = false;
        _messages.add(_Message(reply.answer, fromDardito: true, story: story));
      });
      _toBottom();
    } catch (error) {
      if (!mounted) return;
      debugPrint('No se pudo consultar el backend de Dardito: $error');
      setState(() {
        _typing = false;
        _messages.add(
          const _Message(
            'Ahora mismo no pude conectarme con mis historias. No quiero inventarte '
            'una respuesta: probá enviarme el mensaje nuevamente en unos segundos.',
            fromDardito: true,
          ),
        );
      });
      _toBottom();
    }
  }

  void _toBottom() => Future.delayed(const Duration(milliseconds: 80), () {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;
    return Container(
      color: AppColors.cream,
      child: Padding(
        padding: EdgeInsets.only(top: desktop ? 98 : 0),
        child: MaxWidth(
          padding: EdgeInsets.zero,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (desktop)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: SizedBox(width: 340, child: _AssistantIntro()),
                ),
              Expanded(
                child: Container(
                  margin: desktop
                      ? const EdgeInsets.fromLTRB(0, 18, 18, 18)
                      : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(desktop ? 28 : 0),
                    border: desktop ? Border.all(color: AppColors.line) : null,
                  ),
                  child: Column(
                    children: [
                      _ChatHeader(
                        onNavigate: widget.onNavigate,
                        onWhatsApp: () async {
                          final uri = Uri.parse(
                            'https://wa.me/?text=${Uri.encodeComponent('Hola Dardito, contame una historia de La Plata')}',
                          );
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 24,
                          ),
                          itemCount: _messages.length + (_typing ? 1 : 0),
                          itemBuilder: (context, i) => i == _messages.length
                              ? const _TypingBubble()
                              : _MessageBubble(
                                  message: _messages[i],
                                  onMap: () =>
                                      widget.onExplore(_messages[i].story),
                                ),
                        ),
                      ),
                      if (_messages.length == 1)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                          child: Row(
                            children: [
                              for (final s in suggestions)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ActionChip(
                                    onPressed: () => _send(s),
                                    avatar: const Icon(
                                      Icons.auto_awesome,
                                      size: 16,
                                    ),
                                    label: Text(s),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      _Composer(
                        controller: _controller,
                        enabled: !_typing,
                        onSend: _send,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantIntro extends StatelessWidget {
  const _AssistantIntro();
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.navy,
      borderRadius: BorderRadius.circular(28),
    ),
    padding: const EdgeInsets.all(34),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        const DarditoMark(light: true),
        const SizedBox(height: 34),
        Text(
          'Preguntá.\nExplorá.\nVolvé a mirar.',
          style: Theme.of(
            context,
          ).textTheme.displayMedium?.copyWith(color: AppColors.cream),
        ),
        const SizedBox(height: 18),
        Text(
          'Dardito conecta historias y lugares. Si una versión no está verificada, te lo cuenta con claridad.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.cream.withValues(alpha: .68),
          ),
        ),
        const Spacer(),
        const TrustBadge(
          icon: Icons.shield_outlined,
          label: 'Respuestas sobre contenido curado',
          color: AppColors.yellow,
        ),
      ],
    ),
  );
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.onWhatsApp, required this.onNavigate});
  final VoidCallback onWhatsApp;
  final ValueChanged<int> onNavigate;

  void _openMenu(BuildContext context) => showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar menú de navegación',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _ChatNavigationOverlay(onNavigate: onNavigate),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < AppBreakpoints.desktop;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          const _DarditoFace(size: 46),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dardito',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                Row(
                  children: [
                    Icon(Icons.circle, color: Color(0xFF4D8B57), size: 9),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Listo para descubrir',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onWhatsApp,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 12),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('WhatsApp'),
          ),
          if (mobile) ...[
            const SizedBox(width: 2),
            Semantics(
              button: true,
              label: 'Abrir menú de navegación',
              child: IconButton(
                tooltip: 'Menú',
                onPressed: () => _openMenu(context),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.ink,
                  minimumSize: const Size(42, 42),
                ),
                icon: const Icon(Icons.menu_rounded, size: 22),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatNavigationOverlay extends StatelessWidget {
  const _ChatNavigationOverlay({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  static const _labels = [
    'Inicio',
    'Explorar',
    'Preguntale a Dardito',
    'Compartí tu historia',
  ];

  static const _shortLabels = ['Inicio', 'Explorar', 'Dardito', 'Compartir'];

  static const _icons = [
    Icons.home_rounded,
    Icons.map_rounded,
    Icons.chat_bubble_rounded,
    Icons.add_circle_rounded,
  ];

  void _select(BuildContext context, int index) {
    Navigator.of(context).pop();
    if (index != 2) {
      Future<void>.delayed(
        const Duration(milliseconds: 180),
        () => onNavigate(index),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
      child: ColoredBox(
        color: const Color(0xFF8B6800).withValues(alpha: .34),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 88, 16, 18),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.paper.withValues(alpha: .96),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: .25),
                        blurRadius: 40,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 2, 10),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.yellow,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MENÚ DARDITO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.1,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '¿A dónde querés ir?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cerrar menú',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 1.6,
                            ),
                        itemCount: _labels.length,
                        itemBuilder: (context, index) => Semantics(
                          button: true,
                          selected: index == 2,
                          label: _labels[index],
                          child: InkWell(
                            onTap: () => _select(context, index),
                            borderRadius: BorderRadius.circular(19),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: index == 2
                                    ? AppColors.yellow
                                    : AppColors.cream,
                                borderRadius: BorderRadius.circular(19),
                                border: Border.all(
                                  color: index == 2
                                      ? AppColors.yellow
                                      : AppColors.line,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(_icons[index], size: 24),
                                    const SizedBox(height: 6),
                                    Text(
                                      _shortLabels[index],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onMap});
  final _Message message;
  final VoidCallback onMap;
  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: message.fromDardito ? AppColors.cream : AppColors.ink,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(message.fromDardito ? 4 : 18),
          bottomRight: Radius.circular(message.fromDardito ? 18 : 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: message.fromDardito ? AppColors.ink : AppColors.paper,
              height: 1.45,
            ),
          ),
          if (message.story != null) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onMap,
              icon: const Icon(Icons.location_on_outlined, size: 18),
              label: const Text('Ver en el mapa'),
            ),
          ],
        ],
      ),
    );
    return Align(
      alignment: message.fromDardito
          ? Alignment.centerLeft
          : Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: message.fromDardito
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 668),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _DarditoFace(size: 34, circular: true),
                    const SizedBox(width: 9),
                    Flexible(child: bubble),
                  ],
                ),
              )
            : bubble,
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DarditoFace(size: 34, circular: true),
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Dardito está buscando…',
              style: TextStyle(
                color: AppColors.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DarditoFace extends StatelessWidget {
  const _DarditoFace({required this.size, this.circular = false});
  final double size;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final portrait = SizedBox.square(
      dimension: size,
      child: ClipRect(
        child: Transform.scale(
          scale: 2.15,
          child: Image.asset(
            'assets/brand/dardito_waving.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -.22),
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
    if (!circular) return portrait;
    return ClipOval(
      child: ColoredBox(color: AppColors.cream, child: portrait),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Preguntá por un lugar, barrio o época…',
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: enabled ? onSend : null,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(52, 52),
            ),
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    ),
  );
}
