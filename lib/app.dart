import 'core/theme/site_palette.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'features/assistant/chat_session_store.dart';
import 'package:flutter/material.dart';

import 'core/auth/auth_service.dart';
import 'core/analytics/usage_analytics_service.dart';
import 'core/analytics/site_measurement.dart';
import 'core/platform/browser_location.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/ui.dart';
import 'core/widgets/book_navigation.dart';
import 'data/models/story.dart';
import 'data/repositories/story_repository.dart';
import 'data/repositories/catalog_repository.dart';
import 'data/catalogs/story_catalog.dart';
import 'features/assistant/assistant_page.dart';
import 'features/contribute/contribute_page.dart';
import 'features/explore/explore_page.dart';
import 'features/home/home_page.dart';
import 'features/home/home_page_refined.dart';
import 'features/legal/legal_page.dart';
import 'features/legal/meta_compliance_page.dart';
import 'features/story/story_like_service.dart';

class DarditoApp extends StatefulWidget {
  const DarditoApp({
    super.key,
    this.authService,
    this.storyRepository,
    this.browserLocation,
  });

  final AuthService? authService;
  final StoryRepository? storyRepository;
  final BrowserLocationController? browserLocation;

  @override
  State<DarditoApp> createState() => _DarditoAppState();
}

class _DarditoAppState extends State<DarditoApp> {
  static const _legalPath = '/terminos_y_politicas';
  static const _serviceTermsPath = '/condiciones_del_servicio';
  static const _dataDeletionPath = '/eliminacion_de_datos';

  late final StoryRepository _repository;
  late final bool _ownsRepository;
  late final AuthService _auth;
  late final RemoteCatalogRepository _catalogRepository;
  late final FirebaseStoryLikeService _storyLikes;
  late final BrowserLocationController _browserLocation;
  late final bool _ownsAuth;
  final _siteTheme = SiteThemeController();
  final _navigatorKey = GlobalKey<NavigatorState>();
  int _section = 0;
  CityStory? _focusedStory;
  CityStory? _assistantStory;
  LegalDocument _legalDocument = LegalDocument.terms;
  List<CityStory> _stories = [];
  PublicCatalogs? _catalogs;
  bool _storiesLoading = true;
  String? _storiesError;
  String? _exploreCategory;
  late final String? _requestedStoryId;

  @override
  void initState() {
    super.initState();
    _ownsAuth = widget.authService == null;
    _auth = widget.authService ?? FirebaseAuthService();
    _ownsRepository = widget.storyRepository == null;
    _repository = widget.storyRepository ?? RemoteStoryRepository();
    _catalogRepository = RemoteCatalogRepository();
    _storyLikes = FirebaseStoryLikeService();
    _browserLocation =
        widget.browserLocation ?? createBrowserLocationController();
    _browserLocation.listen(_handleBrowserLocationChanged);
    UsageAnalyticsService.instance.start();
    final initialUri = _browserLocation.uri;
    _section = _sectionFromUri(initialUri);
    measureSiteSection(_section);
    final requestedStoryId = initialUri.queryParameters['story']?.trim();
    _requestedStoryId =
        requestedStoryId != null &&
            RegExp(r'^[a-zA-Z0-9_-]{1,120}$').hasMatch(requestedStoryId)
        ? requestedStoryId
        : null;
    _loadStories();
  }

  int _sectionFromUri(Uri uri) {
    if (_isLegalPath(uri.path)) return 4;
    if (_isPath(uri.path, _serviceTermsPath)) return 5;
    if (_isPath(uri.path, _dataDeletionPath)) return 6;
    return switch (uri.queryParameters['section']) {
      'explore' => 1,
      'assistant' => 2,
      _ => 0,
    };
  }

  bool _isLegalPath(String path) {
    return _isPath(path, _legalPath);
  }

  bool _isPath(String path, String expectedPath) {
    final normalizedPath = path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    return normalizedPath == expectedPath;
  }

  bool _isStandaloneLegalPath(String path) {
    return _isLegalPath(path) ||
        _isPath(path, _serviceTermsPath) ||
        _isPath(path, _dataDeletionPath);
  }

  void _handleBrowserLocationChanged(Uri uri) {
    if (!mounted) return;
    final targetSection = _sectionFromUri(uri);
    if (targetSection == _section) return;
    setState(() {
      _section = targetSection;
      measureSiteSection(_section);
      if (targetSection == 2) _assistantStory = null;
    });
  }

  Future<void> _loadStories({bool forceRefresh = false}) async {
    setState(() {
      _storiesLoading = true;
      _storiesError = null;
    });
    try {
      final catalogRequest = _catalogRepository.fetch();
      final stories = await _repository.fetchAll(forceRefresh: forceRefresh);
      PublicCatalogs? catalogs;
      try {
        catalogs = await catalogRequest;
        StoryCatalog.applyRemote(
          categoryEntries: catalogs.categories,
          evidenceEntries: catalogs.evidenceLevels,
        );
      } catch (_) {
        // Los valores integrados quedan como respaldo si el catálogo público
        // atraviesa una indisponibilidad temporal.
      }
      if (!mounted) return;
      CityStory? requestedStory;
      if (_requestedStoryId != null) {
        for (final story in stories) {
          if (story.id == _requestedStoryId) {
            requestedStory = story;
            break;
          }
        }
      }
      setState(() {
        _stories = stories;
        _catalogs = catalogs;
        _focusedStory = requestedStory ?? _focusedStory;
        if (requestedStory != null) {
          _section = 1;
          measureSiteSection(_section);
        }
        _storiesLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _storiesLoading = false;
        _storiesError = error.toString();
      });
    }
  }

  void _openLegal(LegalDocument document) {
    if (!_isLegalPath(_browserLocation.uri.path)) {
      _browserLocation.pushPath(_legalPath);
    }
    setState(() {
      _legalDocument = document;
      _section = 4;
      measureSiteSection(_section);
    });
  }

  Future<void> _goTo(int index) async {
    if (index == 2 || index == 3) {
      final authenticated = await _ensureAuthenticated(
        index == 2 ? _AuthDestination.assistant : _AuthDestination.contribute,
      );
      if (!authenticated || !mounted) return;
    }
    if (_isStandaloneLegalPath(_browserLocation.uri.path)) {
      _browserLocation.replacePath('/');
    }
    setState(() {
      _section = index;
      if (index == 1) _exploreCategory = null;
      measureSiteSection(_section);
      if (index == 2) _assistantStory = null;
    });
  }

  Future<void> _askDarditoAbout(CityStory story) async {
    final authenticated = await _ensureAuthenticated(
      _AuthDestination.assistant,
    );
    if (!authenticated || !mounted) return;
    setState(() {
      _assistantStory = story;
      _section = 2;
      measureSiteSection(_section);
    });
  }

  Future<bool> _ensureAuthenticated(_AuthDestination destination) async {
    if (_auth.currentUser != null) {
      final access = await _auth.checkAccess();
      if (!mounted) return false;
      if (access.allowed) return true;
      if (access.reason == 'banned' || access.reason == 'ip_blocked') {
        ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text(
              'Esta cuenta o conexión no puede acceder en este momento.',
            ),
          ),
        );
        return false;
      }
      if (_auth.currentUser != null) {
        ChatSessionStore().clear(_auth.currentUser!.id);
      }
      await _auth.signOut();
    }
    final authenticated = await showDialog<bool>(
      context: _navigatorKey.currentContext!,
      builder: (dialogContext) => _OAuthDialog(
        signIn: _auth.signIn,
        destination: destination,
        onOpenLegal: (document) {
          Navigator.pop(dialogContext);
          _openLegal(document);
        },
      ),
    );
    return authenticated == true;
  }

  int _storyLikeCount(String storyId) {
    for (final story in _stories) {
      if (story.id == storyId) return story.likeCount;
    }
    return 0;
  }

  void _applyLikeState(StoryLikeState state) {
    if (!mounted) return;
    setState(() {
      _stories = _stories
          .map(
            (story) => story.id == state.storyId
                ? story.withLikeCount(state.likeCount)
                : story,
          )
          .toList(growable: false);
      if (_focusedStory?.id == state.storyId) {
        _focusedStory = _focusedStory!.withLikeCount(state.likeCount);
      }
    });
  }

  Future<StoryLikeState> _storyLikeStatus(String storyId) async {
    if (_auth.currentUser == null) {
      return StoryLikeState(
        storyId: storyId,
        liked: false,
        likeCount: _storyLikeCount(storyId),
      );
    }
    try {
      final state = await _storyLikes.status(storyId);
      _applyLikeState(state);
      return state;
    } catch (_) {
      return StoryLikeState(
        storyId: storyId,
        liked: false,
        likeCount: _storyLikeCount(storyId),
      );
    }
  }

  Future<StoryLikeState> _toggleStoryLike(String storyId) async {
    final authenticated = await _ensureAuthenticated(_AuthDestination.like);
    if (!authenticated) {
      throw StoryLikeException('Se requiere una sesión habilitada.');
    }
    try {
      final state = await _storyLikes.toggle(storyId);
      _applyLikeState(state);
      return state;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          _navigatorKey.currentContext!,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      rethrow;
    }
  }

  void _explore([CityStory? story]) {
    if (story != null) UsageAnalyticsService.instance.storyViewed(story);
    setState(() {
      _focusedStory = story;
      _exploreCategory = null;
      _section = 1;
      measureSiteSection(_section);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SiteThemeScope(
      controller: _siteTheme,
      child: ListenableBuilder(
        listenable: _siteTheme,
        builder: (context, _) => MaterialApp(
          darkTheme: AppTheme.dark,
          themeMode: _siteTheme.dark ? ThemeMode.dark : ThemeMode.light,
          navigatorKey: _navigatorKey,
          title: 'El Mapa de las Historias de La Plata',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          builder: (context, child) => StoryLikesScope(
            status: _storyLikeStatus,
            toggle: _toggleStoryLike,
            child: child ?? SizedBox.shrink(),
          ),
          home: DarditoShell(
            currentIndex: _section,
            onNavigate: _goTo,
            child: KeyedSubtree(
              key: ValueKey(
                '$_section-$_storiesLoading-${_storiesError != null}',
              ),
              child: _storiesLoading
                  ? _StoryLoadingView()
                  : _storiesError != null
                  ? _StoryLoadingError(
                      message: _storiesError!,
                      onRetry: () => _loadStories(forceRefresh: true),
                    )
                  : switch (_section) {
                      0 =>
                        (bool.fromEnvironment('DARDITO_REFINED_HOME')
                            ? RefinedHomePage.new
                            : HomePage.new)(
                          stories: _stories,
                          onExplore: _explore,
                          onExploreCategory: (category) => setState(() {
                            _focusedStory = null;
                            _exploreCategory = category;
                            _section = 1;
                            measureSiteSection(_section);
                          }),
                          onNavigate: _goTo,
                          onOpenLegal: _openLegal,
                        ),
                      1 => ExplorePage(
                        stories: _stories,
                        catalogNeighborhoods: _catalogs?.neighborhoods
                            .map((entry) => entry.label)
                            .toSet(),
                        initiallySelected: _focusedStory,
                        initialCategory: _exploreCategory,
                        onAskDardito: _askDarditoAbout,
                      ),
                      2 => AssistantPage(
                        key: ValueKey(
                          'assistant-${_auth.currentUser?.id ?? 'anonymous'}-${_assistantStory?.id ?? 'general'}',
                        ),
                        stories: _stories,
                        contextStory: _assistantStory,
                        userId: _auth.currentUser?.id,
                        onExplore: _explore,
                        onNavigate: _goTo,
                      ),
                      3 => ContributePage(
                        user: _auth.currentUser!,
                        neighborhoods:
                            (_catalogs?.neighborhoods
                                .map((entry) => entry.label)
                                .toList() ??
                            (_stories
                                .map((story) => story.neighborhood)
                                .toSet()
                                .toList()
                              ..sort())),
                        categories: StoryCatalog.categories,
                        evidenceLevels: StoryCatalog.evidenceLevels,
                        onSignOut: () async {
                          if (_auth.currentUser != null) {
                            ChatSessionStore().clear(_auth.currentUser!.id);
                          }
                          await _auth.signOut();
                          if (mounted) {
                            setState(() {
                              _section = 0;
                              measureSiteSection(_section);
                            });
                          }
                        },
                        onExplore: () => _goTo(1),
                        onOpenLegal: _openLegal,
                      ),
                      4 => LegalPage(
                        initialDocument: _legalDocument,
                        onBack: () => _goTo(0),
                      ),
                      5 => MetaCompliancePage(
                        document: MetaComplianceDocument.serviceTerms,
                      ),
                      _ => MetaCompliancePage(
                        document:
                            MetaComplianceDocument.dataDeletionInstructions,
                      ),
                    },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _siteTheme.dispose();
    UsageAnalyticsService.instance.dispose();
    if (_ownsRepository) _repository.dispose();
    _catalogRepository.dispose();
    _storyLikes.dispose();
    _browserLocation.dispose();
    if (_ownsAuth && _auth is FirebaseAuthService) {
      _auth.dispose();
    }
    super.dispose();
  }
}

class _StoryLoadingView extends StatelessWidget {
  const _StoryLoadingView();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: SitePalette.of(context).cream,
    child: Center(
      child: Semantics(
        label: 'Cargando historias publicadas',
        child: CircularProgressIndicator(color: SitePalette.of(context).green),
      ),
    ),
  );
}

class _StoryLoadingError extends StatelessWidget {
  const _StoryLoadingError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: SitePalette.of(context).cream,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: SitePalette.of(context).green,
              ),
              SizedBox(height: 18),
              Text(
                'No pudimos cargar las historias publicadas',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: SitePalette.of(context).muted),
              ),
              SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh_rounded),
                label: Text('Volver a intentar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DarditoShell extends StatefulWidget {
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
  State<DarditoShell> createState() => _DarditoShellState();
}

class _DarditoShellState extends State<DarditoShell> {
  bool _navVisible = true;
  double _homeOffset = 0;
  int get currentIndex => widget.currentIndex;
  ValueChanged<int> get onNavigate => widget.onNavigate;
  Widget get child => widget.child;

  @override
  void didUpdateWidget(covariant DarditoShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _navVisible = true;
      _homeOffset = 0;
    }
  }

  bool _trackScroll(ScrollUpdateNotification event) {
    if (event.depth != 0 || event.metrics.axis != Axis.vertical) return false;
    final delta = event.scrollDelta ?? 0;
    final visible = event.metrics.pixels <= 20
        ? true
        : delta < -.5
        ? true
        : delta > .5
        ? false
        : _navVisible;
    final homeOffset = event.metrics.pixels.clamp(0.0, 110.0);
    if (visible != _navVisible ||
        (currentIndex == 0 && homeOffset != _homeOffset)) {
      setState(() {
        _navVisible = visible;
        _homeOffset = homeOffset;
      });
    }
    return false;
  }

  Widget _movingNav(Widget nav, {bool bottom = false}) => IgnorePointer(
    ignoring: !_navVisible,
    child: ExcludeSemantics(
      excluding: !_navVisible,
      child: AnimatedSlide(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: _navVisible ? Offset.zero : Offset(0, bottom ? 1.5 : -1.5),
        child: nav,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < AppBreakpoints.desktop;
    return Scaffold(
      extendBody: true,
      body: NotificationListener<ScrollUpdateNotification>(
        onNotification: _trackScroll,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 480),
                reverseDuration: Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: Offset(.025, .015),
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
                  child: _movingNav(
                    _MobileDock(
                      currentIndex: currentIndex,
                      onNavigate: onNavigate,
                    ),
                    bottom: true,
                  ),
                ),
              )
            else if (!mobile && currentIndex == 0) ...[
              if (_homeOffset < 90)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 14 - _homeOffset,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.sizeOf(context).width * .035,
                      ),
                      child: BookNavigation(
                        key: ValueKey('map-desktop-nav'),
                        onNavigate: onNavigate,
                      ),
                    ),
                  ),
                ),
              if (_homeOffset >= 90)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 14,
                  child: SafeArea(
                    bottom: false,
                    child: _movingNav(
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.sizeOf(context).width * .035,
                        ),
                        child: BookNavigation(
                          key: ValueKey('spine-desktop-nav'),
                          spine: true,
                          onNavigate: onNavigate,
                        ),
                      ),
                    ),
                  ),
                ),
            ] else if (!mobile && currentIndex != 2)
              Positioned(
                left: 0,
                right: 0,
                top: 14,
                child: SafeArea(
                  bottom: false,
                  child: _movingNav(
                    MaxWidth(
                      child: _DesktopNav(
                        currentIndex: currentIndex,
                        onNavigate: onNavigate,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopNav extends StatelessWidget {
  const _DesktopNav({required this.currentIndex, required this.onNavigate});
  final int currentIndex;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) => BookNavigation(
    spine: true,
    currentIndex: currentIndex,
    onNavigate: onNavigate,
  );
}

class _MobileDock extends StatelessWidget {
  const _MobileDock({required this.currentIndex, required this.onNavigate});
  final int currentIndex;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) => Container(
    height: 70,
    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 7),
    decoration: BoxDecoration(
      color: SitePalette.of(context).paper.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: SitePalette.of(context).line),
      boxShadow: [
        BoxShadow(
          color: SitePalette.of(context).ink.withValues(alpha: .18),
          blurRadius: 28,
          offset: Offset(0, 12),
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
                duration: Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: currentIndex == i
                      ? (i == 3
                            ? SitePalette.of(context).ink
                            : AppColors.yellow)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      DarditoShell.icons[i],
                      size: 21,
                      color: currentIndex == i
                          ? (i == 3
                                ? SitePalette.of(context).paper
                                : AppColors.ink)
                          : SitePalette.of(context).ink,
                    ),
                    if (currentIndex == i) ...[
                      SizedBox(height: 2),
                      Text(
                        i == 2
                            ? 'Dardito'
                            : DarditoShell.labels[i].split(' ').first,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: i == 3
                              ? SitePalette.of(context).paper
                              : AppColors.ink,
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

enum _AuthDestination { assistant, contribute, like }

typedef _SignInCallback =
    Future<AuthUser> Function(
      AuthProvider provider, {
      required AuthConsent consent,
    });

class _OAuthDialog extends StatefulWidget {
  const _OAuthDialog({
    required this.signIn,
    required this.destination,
    required this.onOpenLegal,
  });

  final _SignInCallback signIn;
  final _AuthDestination destination;
  final ValueChanged<LegalDocument> onOpenLegal;

  @override
  State<_OAuthDialog> createState() => _OAuthDialogState();
}

class _OAuthDialogState extends State<_OAuthDialog> {
  AuthProvider? _loading;
  String? _error;
  bool _accepted = false;

  Future<void> _choose(AuthProvider provider) async {
    if (_loading != null || !_accepted) return;
    setState(() {
      _loading = provider;
      _error = null;
    });

    try {
      // La apertura del popup debe ocurrir dentro del mismo gesto del usuario.
      // Una espera previa hace que Safari y las PWA bloqueen Google OAuth.
      final signIn = widget.signIn(
        provider,
        consent: AuthConsent(accepted: true),
      );
      await signIn;
      if (mounted) Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Google sign-in failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = null;
        _error = _authErrorMessage(error);
      });
    }
  }

  String _authErrorMessage(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'popup-blocked' =>
          'El navegador bloqueó la ventana de Google. Permití las ventanas emergentes e intentá nuevamente.',
        'popup-closed-by-user' || 'cancelled-popup-request' =>
          'La conexión con Google se canceló. Intentá nuevamente y completá la selección de cuenta.',
        'unauthorized-domain' =>
          'Este dominio todavía no está autorizado para conectarse con Google.',
        'network-request-failed' =>
          'No pudimos comunicarnos con Google. Revisá tu conexión e intentá nuevamente.',
        'account-exists-with-different-credential' =>
          'Ese correo ya está asociado a otro método de acceso.',
        _ => 'No pudimos conectar tu cuenta de Google (${error.code}).',
      };
    }
    return 'No pudimos conectar tu cuenta de Google. Intentá nuevamente.';
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: SitePalette.of(context).paper,
    insetPadding: EdgeInsets.all(20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 480),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded),
              ),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.edit_note_rounded, size: 34),
            ),
            SizedBox(height: 22),
            Text(
              switch (widget.destination) {
                _AuthDestination.assistant =>
                  'Antes de conversar,\nqueremos conocerte.',
                _AuthDestination.contribute =>
                  'Antes de compartir,\nqueremos conocerte.',
                _AuthDestination.like =>
                  'Antes de puntuar,\nqueremos conocerte.',
              },
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            SizedBox(height: 12),
            Text(
              switch (widget.destination) {
                _AuthDestination.assistant =>
                  'Tu identidad nos ayuda a cuidar la comunidad y mantener una experiencia segura.',
                _AuthDestination.contribute =>
                  'Tu identidad nos ayuda a cuidar la comunidad y a contactarte durante la revisión editorial.',
                _AuthDestination.like =>
                  'Tu cuenta permite registrar un único Me gusta por historia y recordarlo cuando vuelvas.',
              },
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SitePalette.of(context).muted,
                height: 1.5,
              ),
            ),
            SizedBox(height: 26),
            CheckboxListTile(
              value: _accepted,
              onChanged: _loading == null
                  ? (value) => setState(() => _accepted = value == true)
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: _TermsConsentLabel(
                onTap: () => widget.onOpenLegal(LegalDocument.terms),
              ),
            ),
            SizedBox(height: 12),
            _OAuthButton(
              label: 'Continuar con Gmail',
              icon: Icons.g_mobiledata_rounded,
              loading: _loading == AuthProvider.google,
              enabled: _loading == null && _accepted,
              onTap: () => _choose(AuthProvider.google),
            ),
            if (_error != null) ...[
              SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFFFECE8),
                  border: Border.all(color: Color(0xFFB53D2E)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8E2F23),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            SizedBox(height: 18),
            Text(
              'Se abrirá Google para que elijas o ingreses tu cuenta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: SitePalette.of(context).muted,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TermsConsentLabel extends StatelessWidget {
  const _TermsConsentLabel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12, height: 1.4);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Declaro que he leído y acepto los ', style: style),
        InkWell(
          onTap: onTap,
          child: Text(
            'Términos y Condiciones.',
            style: TextStyle(
              color: SitePalette.of(context).rust,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
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
        foregroundColor: SitePalette.of(context).ink,
        side: BorderSide(color: SitePalette.of(context).line),
        padding: EdgeInsets.symmetric(vertical: 17),
      ),
      icon: loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 25),
      label: Text(label),
    ),
  );
}
