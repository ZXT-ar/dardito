import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/analytics/usage_analytics_service.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/story.dart';
import 'story_share.dart';
import 'story_like_service.dart';

class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.story,
    required this.onTap,
    this.compact = false,
  });
  final CityStory story;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => HoverLift(
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: story.category.color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      story.category.icon,
                      color: story.category.color,
                      size: 21,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    color: AppColors.muted.withValues(alpha: .7),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                story.category.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                  color: story.category.color,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                story.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                story.shortStory,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              if (story.publicAuthor != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Aporte de: ${story.publicAuthor}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const Spacer(),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 15),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      story.neighborhood,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${story.readMinutes} min',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.favorite_rounded,
                    size: 14,
                    color: AppColors.rust,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${story.likeCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void showStoryDetails(BuildContext context, CityStory story) {
  UsageAnalyticsService.instance.storyViewed(story);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (context) => FractionallySizedBox(
      heightFactor: .9,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: story.category.color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        story.category.icon,
                        color: story.category.color,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            story.category.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w900,
                              color: story.category.color,
                            ),
                          ),
                          Text(
                            '${story.neighborhood} · ${story.period}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  story.title,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  story.subtitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                _ContributionOriginBadge(story.contributionOrigin),
                if (story.publicAuthor != null) ...[
                  const SizedBox(height: 8),
                  Text('Aporte de: ${story.publicAuthor}'),
                ],
                const SizedBox(height: 24),
                _EvidenceBadge(story.evidence, story.evidenceLabel),
                const SizedBox(height: 18),
                _StoryLikeButton(story: story),
                const SizedBox(height: 28),
                Text(
                  story.fullStory,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.library_books_outlined, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'FUENTE Y CONTEXTO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              story.source,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showStoryShareOptions(context, story),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Compartir'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Volver al mapa'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _StoryLikeButton extends StatefulWidget {
  const _StoryLikeButton({required this.story});
  final CityStory story;

  @override
  State<_StoryLikeButton> createState() => _StoryLikeButtonState();
}

class _StoryLikeButtonState extends State<_StoryLikeButton> {
  bool _liked = false;
  bool _loading = false;
  bool _loaded = false;
  late int _likeCount = widget.story.likeCount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final scope = StoryLikesScope.maybeOf(context);
    if (scope == null) return;
    scope.status(widget.story.id).then((state) {
      if (!mounted) return;
      setState(() {
        _liked = state.liked;
        _likeCount = state.likeCount;
      });
    });
  }

  Future<void> _toggle() async {
    final scope = StoryLikesScope.maybeOf(context);
    if (scope == null || _loading) return;
    setState(() => _loading = true);
    try {
      final state = await scope.toggle(widget.story.id);
      if (!mounted) return;
      setState(() {
        _liked = state.liked;
        _likeCount = state.likeCount;
      });
    } catch (_) {
      // El coordinador global muestra el error o el diálogo de autenticación.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: _liked,
    label: _liked ? 'Quitar Me gusta' : 'Me gusta esta historia',
    child: OutlinedButton.icon(
      onPressed: _loading ? null : _toggle,
      style: OutlinedButton.styleFrom(
        foregroundColor: _liked ? AppColors.rust : AppColors.ink,
        side: BorderSide(color: _liked ? AppColors.rust : AppColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            ),
      label: Text(_liked ? 'Te gusta · $_likeCount' : 'Me gusta · $_likeCount'),
    ),
  );
}

class _EvidenceBadge extends StatelessWidget {
  const _EvidenceBadge(this.level, this.customLabel);
  final String level;
  final String customLabel;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (level) {
      'documented' => (Icons.verified_outlined, 'Documentada', AppColors.green),
      'oral_tradition' || 'community' => (
        Icons.groups_outlined,
        'Aporte de vecinos',
        const Color(0xFF416A76),
      ),
      _ => (Icons.fact_check_outlined, customLabel, AppColors.green),
    };
    return TrustBadge(icon: icon, label: label, color: color);
  }
}

class _ContributionOriginBadge extends StatelessWidget {
  const _ContributionOriginBadge(this.origin);

  final StoryContributionOrigin origin;

  @override
  Widget build(BuildContext context) => TrustBadge(
    icon: origin == StoryContributionOrigin.community
        ? Icons.groups_outlined
        : Icons.verified_user_outlined,
    label: origin.label,
    color: origin == StoryContributionOrigin.community
        ? const Color(0xFF416A76)
        : AppColors.green,
  );
}
