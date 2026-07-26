import 'package:flutter/material.dart';

import 'core/auth/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/ui.dart';
import 'data/models/story.dart';
import 'data/repositories/story_repository.dart';
import 'features/assistant/assistant_page.dart';
import 'features/contribute/contribute_page.dart';
import 'features/explore/explore_page.dart';
import 'features/home/home_page.dart';
import 'features/legal/legal_page.dart';

class DarditoApp extends StatefulWidget {
  const DarditoApp({super.key, this.authService});

  final AuthService? authService;

  @override
  State<DarditoApp> createState() => _DarditoAppState();
}

class _DarditoAppState extends State<DarditoApp> {
  final _repository = LocalStoryRepository();
  late final AuthService _auth;
  late final bool _ownsAuth;
  final _navigatorKey = GlobalKey<NavigatorState>();
  int _section = 0;
  CityStory? _focusedStory;
  LegalDocument _legalDocument = LegalDocument.terms;

  @override
  void initState() {
    super.initState();
    _ownsAuth = widget.authService == null;
    _auth = widget.authService ?? FirebaseAuthService();
    _section = switch (Uri.base.queryParameters['section']) {
      'explore' => 1,
      'assistant' => 2,
      _ => 0,
    };
  }

  void _openLegal(LegalDocument document) => setState(() {
    _legalDocument = document;
    _section = 4;
  });

  Future<void> _goTo(int index) async {
    if (index == 3 && _auth.currentUser == null) {
      final provider = await showDialog<AuthProvider>(
        context: _navigatorKey.currentContext!,
        builder: (context) => const _OAuthDialog(),
      );
      if (provider == null || !mounted) return;
      try {
        await _auth.signIn(provider);
        if (!mounted) return;
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : 'No pudimos conectar tu cuenta de Google.',
            ),
          ),
        );
        return;
      }
    }
    setState(() => _section = index);
  }

  void _explore([CityStory? story]) => setState(() {
    _focusedStory = story;
    _section = 1;
  });

  @override
  Widget build(BuildContext context) {
    final stories = _repository.getAll();
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Dardito · Historias de La Plata',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: DarditoShell(
        currentIndex: _section,
        onNavigate: _goTo,
        child: KeyedSubtree(
          key: ValueKey(_section),
          child: switch (_section) {
            0 => HomePage(
              stories: stories,
              onExplore: _explore,
              onNavigate: _goTo,
              onOpenLegal: _openLegal,
            ),
            1 => ExplorePage(
              stories: stories,
              initiallySelected: _focusedStory,
              onAskDardito: () => _goTo(2),
            ),
            2 => AssistantPage(
              stories: stories,
              onExplore: _explore,
              onNavigate: _goTo,
            ),
            3 => ContributePage(
              user: _auth.currentUser!,
              onSignOut: () async {
                await _auth.signOut();
                if (mounted) setState(() => _section = 0);
              },
              onExplore: () => _goTo(1),
              onOpenLegal: _openLegal,
            ),
            _ => LegalPage(
              initialDocument: _legalDocument,
              onBack: () => _goTo(0),
            ),
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_ownsAuth && _auth is FirebaseAuthService) {
      _auth.dispose();
    }
    super.dispose();
  }
}

class DarditoShell extends StatelessWidget {
  const DarditoShell({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    required this.child,
  });
  final int currentIndex;
  final ValueChanged<int> onNavigate;
  final Widget child;

  static const labels = [
    'Inicio',
    'Explorar',
    'Preguntale a Dardito',
    'Compartí tu historia',
  ];
  static const icons = [
    Icons.home_rounded,
    Icons.map_rounded,
    Icons.chat_bubble_rounded,
    Icons.add_circle_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < AppBreakpoints.desktop;
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 480),
              reverseDuration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(.025, .015),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: child,
            ),
          ),
          if (mobile && currentIndex != 2)
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: SafeArea(
                top: false,
                child: _MobileDock(
                  currentIndex: currentIndex,
                  onNavigate: onNavigate,
                ),
              ),
            )
          else if (!mobile)
            Positioned(
              left: 0,
              right: 0,
              top: 14,
              child: SafeArea(
                bottom: false,
                child: MaxWidth(
                  child: _DesktopNav(
                    currentIndex: currentIndex,
                    onNavigate: onNavigate,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DesktopNav extends StatelessWidget {
  const _DesktopNav({required this.currentIndex, required this.onNavigate});
  final int currentIndex;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => Container(
    height: 68,
    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
    decoration: BoxDecoration(
      color: AppColors.paper.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: .85)),
      boxShadow: [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: .12),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Row(
      children: [
        InkWell(
          onTap: () => onNavigate(0),
          borderRadius: BorderRadius.circular(14),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: DarditoMark(compact: true),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                _NavItem(
                  index: i,
                  selected: currentIndex == i,
                  onTap: () => onNavigate(i),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: () => onNavigate(3),
          style: FilledButton.styleFrom(
            backgroundColor: currentIndex == 3
                ? AppColors.yellow
                : AppColors.ink,
            foregroundColor: currentIndex == 3
                ? AppColors.ink
                : AppColors.paper,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          icon: Icon(
            currentIndex == 3 ? Icons.edit_note_rounded : Icons.add_rounded,
            size: 19,
          ),
          label: const Text('Compartí tu historia'),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.selected,
    required this.onTap,
  });
  final int index;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 3),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.paper : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: .08),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedRotation(
              turns: selected ? .03 : 0,
              duration: const Duration(milliseconds: 240),
              child: Icon(DarditoShell.icons[index], size: 17),
            ),
            const SizedBox(width: 7),
            Text(
              DarditoShell.labels[index],
              style: TextStyle(
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MobileDock extends StatelessWidget {
  const _MobileDock({required this.currentIndex, required this.onNavigate});
  final int currentIndex;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) => Container(
    height: 70,
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.paper.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white),
      boxShadow: [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: .18),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Row(
      children: [
        for (var i = 0; i < DarditoShell.labels.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => onNavigate(i),
              borderRadius: BorderRadius.circular(17),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: currentIndex == i
                      ? (i == 3 ? AppColors.ink : AppColors.yellow)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      DarditoShell.icons[i],
                      size: 21,
                      color: currentIndex == i && i == 3
                          ? AppColors.paper
                          : AppColors.ink,
                    ),
                    if (currentIndex == i) ...[
                      const SizedBox(height: 2),
                      Text(
                        i == 2
                            ? 'Dardito'
                            : DarditoShell.labels[i].split(' ').first,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: i == 3 ? AppColors.paper : AppColors.ink,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _OAuthDialog extends StatefulWidget {
  const _OAuthDialog();
  @override
  State<_OAuthDialog> createState() => _OAuthDialogState();
}

class _OAuthDialogState extends State<_OAuthDialog> {
  AuthProvider? _loading;
  Future<void> _choose(AuthProvider provider) async {
    setState(() => _loading = provider);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) Navigator.pop(context, provider);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.paper,
    insetPadding: const EdgeInsets.all(20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.edit_note_rounded, size: 34),
            ),
            const SizedBox(height: 22),
            Text(
              'Antes de compartir,\nqueremos conocerte.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Tu identidad nos ayuda a cuidar la comunidad y a contactarte durante la revisión editorial.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 26),
            _OAuthButton(
              label: 'Continuar con Gmail',
              icon: Icons.g_mobiledata_rounded,
              loading: _loading == AuthProvider.google,
              enabled: _loading == null,
              onTap: () => _choose(AuthProvider.google),
            ),
            const SizedBox(height: 18),
            const Text(
              'Se abrirá Google para que elijas o ingreses tu cuenta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Al continuar aceptás los Términos y la Política de privacidad.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.muted.withValues(alpha: .8),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OAuthButton extends StatelessWidget {
  const _OAuthButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(vertical: 17),
      ),
      icon: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 25),
      label: Text(label),
    ),
  );
}
