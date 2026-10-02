import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/security/client_session_id.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/story.dart';
import 'dardito_assistant_service.dart';
import 'assistant_response.dart';
import 'story_image_service.dart';
import 'story_plate.dart';
import 'chat_session_store.dart';
import 'reading_palette.dart';

const _assistantGreetings = [
  '¡Hola! Soy Dardito.\n'
      'Te acompaño a descubrir las historias, personas, lugares, barrios y misterios que hicieron, hacen y siguen haciendo única a La Plata.\n'
      'Podés preguntarme por un lugar, una persona, un barrio, una época… o pedirme que te muestre algo al azar.\n'
      '¿Qué querés descubrir hoy?',
  '¡Buenas! Soy Dardito.\n'
      'La Plata guarda historias en cada esquina: personas, lugares, barrios, épocas y misterios que todavía resuenan.\n'
      'Decime por dónde querés empezar o pedime una historia al azar.\n'
      '¿Qué descubrimos hoy?',
  '¡Qué bueno encontrarte! Soy Dardito.\n'
      'Hay otra La Plata escondida en sus calles: historias, protagonistas, rincones y secretos esperando ser descubiertos.\n'
      'Elegí un tema, un barrio o una época; si preferís, dejo que el azar nos guíe.\n'
      '¿Vamos?',
];

String _randomAssistantGreeting() =>
    _assistantGreetings[Random().nextInt(_assistantGreetings.length)];

class AssistantPage extends StatefulWidget {
  const AssistantPage({
    super.key,
    required this.stories,
    required this.onExplore,
    required this.onNavigate,
    this.contextStory,
    this.assistantService,
    this.imageService,
    this.userId,
    this.sessionStore,
  });
  final List<CityStory> stories;
  final ValueChanged<CityStory?> onExplore;
  final ValueChanged<int> onNavigate;
  final CityStory? contextStory;
  final DarditoAssistantService? assistantService;
  final StoryImageService? imageService;
  final String? userId;
  final ChatSessionStore? sessionStore;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _Message {
  const _Message(
    this.text, {
    this.fromDardito = false,
    this.story,
    this.moderationAction = 'none',
    this.images,
    this.sourceIds = const [],
  });
  final String text;
  final bool fromDardito;
  final CityStory? story;
  final String moderationAction;
  final Future<List<AssistantStoryImage>>? images;
  final List<String> sourceIds;
}

class _AssistantPageState extends State<AssistantPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late final StoryImageService _images =
      widget.imageService ?? StoryImageService();
  late final DarditoAssistantService _assistant =
      widget.assistantService ?? FirebaseDarditoAssistantService();
  late String _conversationId =
      'web-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';
  final String _sessionId = ClientSessionId.value;
  late final _cache = widget.sessionStore ?? ChatSessionStore();
  bool _typing = false;
  bool _hasReply = false;
  bool _dark = false;
  ReadingPalette get _palette => ReadingPalette(_dark);
  final Map<_Message, GlobalKey> _messageKeys = {};

  void _showMessage(_Message message) {
    final context = _messageKeys[message]?.currentContext;
    final object = context?.findRenderObject();
    if (object != null && _scroll.hasClients) {
      _scroll.position.ensureVisible(
        object,
        duration: const Duration(milliseconds: 280),
        alignment: 0.02,
      );
    }
  }

  Widget _history() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 22),
        child: Text(
          'ESTA CONVERSACIÓN',
          style: TextStyle(
            color: _palette.muted,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
      ),
      for (final message in _messages.where((m) => !m.fromDardito))
        TextButton(
          onPressed: () => _showMessage(message),
          style: TextButton.styleFrom(
            foregroundColor: _palette.ink,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          child: Text(
            message.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Lora',
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
    ],
  );
  final List<_Message> _messages = [
    _Message(_randomAssistantGreeting(), fromDardito: true),
  ];

  static const suggestions = [
    'Una historia al azar',
    'Misterios del centro',
    'Historias de barrios',
    '¿Qué pasó en 1882?',
  ];

  @override
  void initState() {
    super.initState();
    _restoreConversation();
    _controller.addListener(_saveConversation);
    final story = widget.contextStory;
    if (story != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _send(
          'Quiero saber más sobre la historia “${story.title}”. Contame más.',
        );
      });
    }
  }

  void _saveConversation() {
    final userId = widget.userId;
    if (userId == null) return;
    _cache.write(
      userId,
      jsonEncode({
        'version': 1,
        'conversationId': _conversationId,
        'draft': _controller.text,
        'hasReply': _hasReply,
        'messages': [
          for (final m in _messages)
            {
              'text': m.text,
              'fromDardito': m.fromDardito,
              'storyId': m.story?.id,
              'moderationAction': m.moderationAction,
              'sourceIds': m.sourceIds,
            },
        ],
      }),
    );
  }

  void _restoreConversation() {
    final userId = widget.userId;
    if (userId == null) return;
    try {
      final raw = _cache.read(userId);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != 1 ||
          data['conversationId'] is! String ||
          data['messages'] is! List) {
        return;
      }
      final restored = <_Message>[];
      for (final item in data['messages'] as List) {
        final m = item as Map<String, dynamic>;
        final ids = (m['sourceIds'] as List? ?? [])
            .whereType<String>()
            .toList();
        CityStory? story;
        for (final candidate in widget.stories) {
          if (candidate.id == m['storyId']) {
            story = candidate;
            break;
          }
        }
        final moderation = m['moderationAction'] as String? ?? 'none';
        restored.add(
          _Message(
            m['text'] as String,
            fromDardito: m['fromDardito'] == true,
            story: story,
            moderationAction: moderation,
            sourceIds: ids,
            images: ids.isNotEmpty && moderation == 'none'
                ? _images.load(ids)
                : null,
          ),
        );
      }
      if (restored.isEmpty) return;
      _messages
        ..clear()
        ..addAll(restored);
      _conversationId = data['conversationId'] as String;
      _hasReply = data['hasReply'] == true;
      _controller.text = (data['draft'] as String? ?? '').characters
          .take(350)
          .toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMessage(_messages.last);
      });
    } catch (_) {
      _cache.clear(userId);
    }
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _typing || text.characters.length > 350) return;
    _controller.clear();
    setState(() {
      _messages.add(_Message(text));
      _typing = true;
    });
    _saveConversation();
    _toBottom(onlyWhileTyping: true);
    try {
      final reply = await _assistant.send(
        message: text,
        conversationId: _conversationId,
        sessionId: _sessionId,
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
        _hasReply = true;
        _messages.add(
          _Message(
            reply.answer,
            fromDardito: true,
            story: story,
            moderationAction: reply.moderationAction,
            sourceIds: reply.sourceIds,
            images:
                reply.moderationAction == 'none' && reply.sourceIds.isNotEmpty
                ? _images.load(reply.sourceIds)
                : null,
          ),
        );
      });
      _saveConversation();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMessage(_messages.last);
      });
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
      _saveConversation();
      _toBottom();
    }
  }

  void _toBottom({bool onlyWhileTyping = false}) =>
      Future.delayed(const Duration(milliseconds: 80), () {
        if (onlyWhileTyping && !_typing) return;
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
    if (widget.imageService == null) _images.dispose();
    _controller.removeListener(_saveConversation);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >= 1180 &&
        MediaQuery.textScalerOf(context).scale(1) < 1.4;
    return Theme(
      data: _palette.theme(Theme.of(context)),
      child: ColoredBox(
        color: _palette.canvas,
        child: SafeArea(
          bottom: false,
          child: MaxWidth(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ChatHeader(
                  onNavigate: widget.onNavigate,
                  palette: _palette,
                  onToggleMode: () => setState(() => _dark = !_dark),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (wide && _hasReply)
                        SizedBox(
                          width: 190,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 32, right: 16),
                            child: SingleChildScrollView(child: _history()),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                key: const ValueKey('chat-scroll'),
                                controller: _scroll,
                                padding: EdgeInsets.fromLTRB(
                                  wide ? 32 : 16,
                                  28,
                                  wide ? 32 : 16,
                                  32,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0; i < _messages.length; i++)
                                      KeyedSubtree(
                                        key: _messageKeys.putIfAbsent(
                                          _messages[i],
                                          () => GlobalKey(),
                                        ),
                                        child: _MessageBubble(
                                          message: _messages[i],
                                          palette: _palette,
                                          pageNumber: _messages
                                              .take(i + 1)
                                              .where((m) => m.fromDardito)
                                              .length,
                                          onMap: () => widget.onExplore(
                                            _messages[i].story,
                                          ),
                                        ),
                                      ),
                                    if (_typing)
                                      _TypingBubble(palette: _palette),
                                  ],
                                ),
                              ),
                            ),
                            if (_messages.length == 1)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    for (final suggestion in suggestions)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: OutlinedButton(
                                          onPressed: () => _send(suggestion),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _palette.ink,
                                            side: BorderSide(
                                              color: _palette.line,
                                            ),
                                          ),
                                          child: Text(suggestion),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            _Composer(
                              controller: _controller,
                              enabled: !_typing,
                              onSend: _send,
                              palette: _palette,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.onNavigate,
    required this.palette,
    required this.onToggleMode,
  });
  final ReadingPalette palette;
  final VoidCallback onToggleMode;
  final ValueChanged<int> onNavigate;

  void _openMenu(BuildContext context) => showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar menú de navegación',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) => Theme(
      data: palette.theme(Theme.of(context)),
      child: _ChatNavigationOverlay(onNavigate: onNavigate),
    ),
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
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: Row(
        children: [
          const _DarditoFace(size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dardito',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    color: palette.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 23,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.circle, color: Color(0xFF4D8B57), size: 9),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Listo para descubrir',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: palette.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: palette.dark
                ? 'Activar modo claro'
                : 'Activar modo oscuro',
            onPressed: onToggleMode,
            color: palette.ink,
            icon: Icon(
              palette.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 21,
            ),
          ),
          if (!mobile && MediaQuery.textScalerOf(context).scale(1) < 1.4) ...[
            for (final entry in [
              (0, 'Inicio'),
              (1, 'Explorar'),
              (3, 'Compartir'),
            ])
              TextButton(
                onPressed: () => onNavigate(entry.$1),
                style: TextButton.styleFrom(foregroundColor: palette.ink),
                child: Text(entry.$2),
              ),
          ] else ...[
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
        color: ReadingPalette.of(context).dark
            ? const Color(0xB3101C23)
            : const Color(0xFF8B6800).withValues(alpha: .34),
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
                    color: ReadingPalette.of(
                      context,
                    ).paper.withValues(alpha: .98),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ReadingPalette.of(context).line,
                      width: 1.5,
                    ),
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
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MENÚ',
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
                                      color: ReadingPalette.of(context).muted,
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
                            child: Container(
                              decoration: BoxDecoration(
                                color: index == 2
                                    ? AppColors.yellow
                                    : ReadingPalette.of(context).inset,
                                borderRadius: BorderRadius.circular(19),
                                border: Border.all(
                                  color: index == 2
                                      ? AppColors.yellow
                                      : ReadingPalette.of(context).line,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _icons[index],
                                      size: 24,
                                      color: index == 2
                                          ? AppColors.ink
                                          : ReadingPalette.of(context).ink,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _shortLabels[index],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: index == 2
                                            ? AppColors.ink
                                            : ReadingPalette.of(context).ink,
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
  const _MessageBubble({
    required this.message,
    required this.onMap,
    required this.pageNumber,
    required this.palette,
  });
  final _Message message;
  final VoidCallback onMap;
  final int pageNumber;
  final ReadingPalette palette;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    if (!message.fromDardito) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 22),
        child: Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: .85,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: palette.muted),
                    const SizedBox(width: 6),
                    Text(
                      'Vos',
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  message.text,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 20,
                    height: 1.4,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final warning = message.moderationAction == 'yellow';
    final blocked =
        message.moderationAction == 'red' ||
        message.moderationAction == 'blocked';
    final normal = !warning && !blocked;
    final color = blocked
        ? (palette.dark ? const Color(0xFFFFA397) : const Color(0xFFC62828))
        : (palette.dark ? const Color(0xFFE9CA79) : const Color(0xFF8B6800));
    return Padding(
      padding: const EdgeInsets.only(bottom: 28, right: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (normal) ...[
            Positioned(
              top: 9,
              left: 9,
              right: -6,
              bottom: -7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.edge,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            Positioned(
              top: 5,
              left: 5,
              right: -3,
              bottom: -3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.leaf,
                  border: Border.all(color: palette.line),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              compact ? 22 : 38,
              22,
              compact ? 22 : 38,
              24,
            ),
            decoration: BoxDecoration(
              color: palette.paper,
              border: Border.all(
                color: normal ? palette.line : color,
                width: normal ? 1 : 2,
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: palette.dark
                      ? const Color(0x30000000)
                      : const Color(0x14604D29),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (normal) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 32),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'DARDITO',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 2,
                              color: palette.muted,
                            ),
                          ),
                        ),
                        Text(
                          pageNumber.toString().padLeft(2, '0'),
                          style: TextStyle(fontSize: 10, color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 24),
                    child: Divider(height: 1, color: palette.line),
                  ),
                  if (message.images == null)
                    AssistantResponse(text: message.text)
                  else
                    FutureBuilder<List<AssistantStoryImage>>(
                      future: message.images,
                      builder: (context, snapshot) {
                        final images = snapshot.data ?? <AssistantStoryImage>[];
                        if (images.isEmpty) {
                          return AssistantResponse(text: message.text);
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final entry in images.indexed)
                              StoryPlate(
                                image: NetworkImage(entry.$2.url),
                                title: entry.$2.title,
                                number: entry.$1 + 1,
                                leading: entry.$1 == 0
                                    ? AssistantResponse(text: message.text)
                                    : null,
                              ),
                          ],
                        );
                      },
                    ),
                ] else ...[
                  Text(
                    blocked ? 'TARJETA ROJA' : 'TARJETA AMARILLA',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message.text,
                    style: TextStyle(fontSize: 16, height: 1.6),
                  ),
                ],
                if (normal) ...[
                  const SizedBox(height: 24),
                  Divider(height: 1, color: palette.line),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Hoja ${pageNumber.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: palette.muted,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copiar respuesta',
                        icon: Icon(
                          Icons.copy_outlined,
                          size: 17,
                          color: palette.muted,
                        ),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: message.text),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Respuesta copiada'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
                if (message.story != null) ...[
                  const SizedBox(height: 22),
                  Divider(color: palette.line),
                  TextButton.icon(
                    onPressed: onMap,
                    icon: Icon(Icons.location_on_outlined, size: 18),
                    label: const Text('Ver en el mapa'),
                  ),
                ],
              ],
            ),
          ),
          if (normal)
            Positioned(
              top: -5,
              right: compact ? 20 : 30,
              child: Container(
                width: 30,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(3),
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child: Image.asset(
                  'assets/brand/dardito_tres_cuartos_green_transparent.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.palette});
  final ReadingPalette palette;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DarditoFace(size: 34),
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: palette.inset,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Dardito está buscando…',
              style: TextStyle(color: palette.ink, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DarditoFace extends StatelessWidget {
  const _DarditoFace({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final portrait = ClipOval(
      child: ColoredBox(
        color: Colors.white,
        child: SizedBox.square(
          dimension: size,
          child: Padding(
            padding: EdgeInsets.all(size * .035),
            child: Image.asset(
              'assets/brand/dardito_tres_cuartos_green_transparent.png',
              fit: BoxFit.contain,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
    return portrait;
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.palette,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final ReadingPalette palette;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final style = Theme.of(context).textTheme.bodyLarge!;
                  final painter =
                      TextPainter(
                        text: TextSpan(
                          text: value.text.isEmpty ? ' ' : value.text,
                          style: style,
                        ),
                        textDirection: Directionality.of(context),
                        textScaler: MediaQuery.textScalerOf(context),
                      )..layout(
                        maxWidth: (constraints.maxWidth - 36).clamp(
                          1,
                          double.infinity,
                        ),
                      );
                  final overflow = painter.computeLineMetrics().length > 2;
                  painter.dispose();
                  final desktop = {
                    TargetPlatform.macOS,
                    TargetPlatform.windows,
                    TargetPlatform.linux,
                  }.contains(defaultTargetPlatform);
                  return Focus(
                    onKeyEvent: (node, event) {
                      if (desktop &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed &&
                          value.composing.isCollapsed) {
                        if (event is KeyDownEvent && enabled) onSend();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      style: style,
                      minLines: 1,
                      maxLines: null,
                      maxLength: 350,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      scrollPhysics: const ClampingScrollPhysics(),
                      decoration: InputDecoration(
                        constraints: BoxConstraints(
                          maxHeight:
                              MediaQuery.textScalerOf(
                                    context,
                                  ).scale(style.fontSize ?? 16) *
                                  (style.height ?? 1.5) *
                                  (overflow ? 1 : 2) +
                              36 +
                              (value.text.characters.length >= 300 ? 28 : 0),
                        ),
                        hintText: 'Preguntale a Dardito…',
                        fillColor: palette.paper,
                        counterText: value.text.characters.length >= 300
                            ? '${value.text.characters.length}/350'
                            : '',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: 'Enviar pregunta',
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
