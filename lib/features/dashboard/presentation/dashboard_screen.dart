import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/user_role.dart';
import '../../categories/data/category_repository.dart';
import '../../favorites/data/favorite_repository.dart';
import '../../references/data/reference_repository.dart';
import '../../references/domain/reference_model.dart';
import '../../snippets/data/snippet_repository.dart';

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final refRepo = ref.watch(referenceRepositoryProvider);
  final snipRepo = ref.watch(snippetRepositoryProvider);
  final catRepo = ref.watch(categoryRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);

  final references = await refRepo.getReferences();
  final categories = await catRepo.getCategories();

  int snippetCount = 0;
  for (var r in references) {
    final snips = await snipRepo.getSnippetsByReference(r.id);
    snippetCount += snips.length;
  }

  int activeUsers = 0;
  if (authRepo.currentUser?.role == UserRole.admin) {
    final profiles = await authRepo.getAllProfiles();
    activeUsers = profiles.where((p) => p.isActive).length;
  }

  final recent = await refRepo.getRecentReferences(limit: 4);

  // Favorites
  List<ReferenceModel> favoriteRefs = [];
  final user = authRepo.currentUser;
  if (user != null) {
    final favIds = await ref.watch(favoriteRepositoryProvider).getFavoriteReferenceIds(user.id);
    for (var id in favIds) {
      final refModel = await refRepo.getReferenceById(id);
      if (refModel != null) {
        favoriteRefs.add(refModel);
      }
    }
  }

  return {
    'referencesCount': references.length,
    'snippetsCount': snippetCount,
    'categoriesCount': categories.length,
    'activeUsersCount': activeUsers,
    'recentReferences': recent,
    'favorites': favoriteRefs,
  };
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final user = ref.watch(authRepositoryProvider).currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardStatsProvider.future),
        child: statsAsync.when(
          loading: () => const LoadingState(),
          error: (err, stack) => ErrorState(
            message: err.toString(),
            onRetry: () => ref.invalidate(dashboardStatsProvider),
          ),
          data: (data) {
            final referencesCount = data['referencesCount'] as int;
            final snippetsCount = data['snippetsCount'] as int;
            final categoriesCount = data['categoriesCount'] as int;
            final activeUsersCount = data['activeUsersCount'] as int;
            final recentReferences = data['recentReferences'] as List<ReferenceModel>;
            final favorites = data['favorites'] as List<ReferenceModel>;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Greeting
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${context.tr('appName')} 👋',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                          ),
                          Text(
                            context.tr('appSubtitle'),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).hintColor,
                                ),
                          ),
                        ],
                      ),
                      if (user != null && user.role != UserRole.viewer)
                        ElevatedButton.icon(
                          onPressed: () => context.go('/references/add'),
                          icon: const Icon(Icons.add),
                          label: Text(context.tr('addReference')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Search Box
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark ? Theme.of(context).dividerColor : Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: TextField(
                        readOnly: true,
                        onTap: () => context.go('/search'),
                        decoration: InputDecoration(
                          hintText: context.tr('searchPlaceholder'),
                          prefixIcon: const Icon(Icons.search),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Stats Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = ResponsiveLayout.isDesktop(context)
                          ? 4
                          : ResponsiveLayout.isTablet(context)
                              ? 2
                              : 1;

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.2,
                        children: [
                          _StatsCard(
                            title: context.tr('totalReferences'),
                            value: referencesCount.toString(),
                            icon: Icons.menu_book,
                            color: colorScheme.primary,
                          ),
                          _StatsCard(
                            title: context.tr('totalSnippets'),
                            value: snippetsCount.toString(),
                            icon: Icons.description_outlined,
                            color: Colors.indigo,
                          ),
                          _StatsCard(
                            title: context.tr('totalCategories'),
                            value: categoriesCount.toString(),
                            icon: Icons.category_outlined,
                            color: Colors.teal,
                          ),
                          if (user?.role == UserRole.admin)
                            _StatsCard(
                              title: context.tr('activeUsers'),
                              value: activeUsersCount.toString(),
                              icon: Icons.people_outline,
                              color: Colors.orange,
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Content Layout (Recent Additions and Favorites Side-by-Side on Desktop)
                  ResponsiveLayout(
                    mobile: Column(
                      children: [
                        _RecentReferencesSection(recentReferences: recentReferences),
                        const SizedBox(height: 24),
                        _FavoritesSection(favorites: favorites),
                      ],
                    ),
                    desktop: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _RecentReferencesSection(recentReferences: recentReferences),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 2,
                          child: _FavoritesSection(favorites: favorites),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentReferencesSection extends StatelessWidget {
  final List<ReferenceModel> recentReferences;

  const _RecentReferencesSection({required this.recentReferences});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(context.tr('recentReferences'), style: titleStyle),
        ),
        if (recentReferences.isEmpty)
          Card(
            child: ListTile(
              title: Text(context.tr('emptyState')),
              subtitle: const Text('Add reference to see it here'),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentReferences.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final ref = recentReferences[index];
              final title = context.isRTL && ref.titleAr != null && ref.titleAr!.isNotEmpty
                  ? ref.titleAr!
                  : ref.title;

              return Card(
                child: ListTile(
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(ref.organization),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => context.go('/references/${ref.id}'),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _FavoritesSection extends StatelessWidget {
  final List<ReferenceModel> favorites;

  const _FavoritesSection({required this.favorites});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(context.tr('myFavorites'), style: titleStyle),
        ),
        if (favorites.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.star_border, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('emptyState'),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: favorites.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final ref = favorites[index];
              final title = context.isRTL && ref.titleAr != null && ref.titleAr!.isNotEmpty
                  ? ref.titleAr!
                  : ref.title;

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    ref.organization,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => context.go('/references/${ref.id}'),
                ),
              );
            },
          ),
      ],
    );
  }
}
