import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../core/utils/vancouver_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../activity_logs/data/activity_repository.dart';
import '../../authentication/data/auth_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/domain/category_model.dart';
import '../../references/data/reference_repository.dart';
import '../../references/domain/reference_model.dart';

// State model for search filters
class SearchState {
  final String query;
  final String? categoryId;
  final String? type;
  final int? year;
  final String? language;
  final bool onlyFavorites;
  final String sortBy;

  SearchState({
    this.query = '',
    this.categoryId,
    this.type,
    this.year,
    this.language,
    this.onlyFavorites = false,
    this.sortBy = 'relevance',
  });

  SearchState copyWith({
    String? query,
    String? categoryId,
    String? type,
    int? year,
    String? language,
    bool? onlyFavorites,
    String? sortBy,
  }) {
    return SearchState(
      query: query ?? this.query,
      categoryId: categoryId == 'all' ? null : (categoryId ?? this.categoryId),
      type: type == 'all' ? null : (type ?? this.type),
      year: year == 0 ? null : (year ?? this.year),
      language: language == 'all' ? null : (language ?? this.language),
      onlyFavorites: onlyFavorites ?? this.onlyFavorites,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

// Search State Provider
class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier() : super(SearchState());

  Timer? _debounce;

  void updateQuery(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      state = state.copyWith(query: query);
    });
  }

  void updateCategory(String? catId) => state = state.copyWith(categoryId: catId);
  void updateType(String? type) => state = state.copyWith(type: type);
  void updateYear(int? year) => state = state.copyWith(year: year);
  void updateLanguage(String? lang) => state = state.copyWith(language: lang);
  void toggleFavorites(bool fav) => state = state.copyWith(onlyFavorites: fav);
  void updateSort(String sort) => state = state.copyWith(sortBy: sort);
  
  void clearFilters() {
    state = SearchState(query: state.query);
  }
}

final searchStateProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier();
});

// Search results provider
final searchResultsProvider = FutureProvider<List<ReferenceModel>>((ref) {
  final search = ref.watch(searchStateProvider);
  final repo = ref.watch(referenceRepositoryProvider);
  final user = ref.watch(authRepositoryProvider).currentUser;

  // Log search in live/database if query is significant
  if (search.query.trim().isNotEmpty) {
    ref.read(activityRepositoryProvider).logActivity(
          action: 'search',
          description: 'Searched query: "${search.query}".',
          metadata: {'query': search.query},
        );
  }

  return repo.getReferences(
    query: search.query,
    categoryId: search.categoryId,
    type: search.type,
    year: search.year,
    language: search.language,
    onlyFavorites: search.onlyFavorites,
    sortBy: search.sortBy,
    currentUserId: user?.id,
  );
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final List<String> _typesList = [
    'all',
    'Guideline',
    'Policy',
    'Circular',
    'Scientific Article',
    'Statistical Report',
    'Manual',
    'Protocol',
    'WHO Document',
    'Ministry Document',
    'Epidemiological Definition',
    'Standard Operating Procedure',
    'Other'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left filters column for large screens
          if (ResponsiveLayout.isDesktop(context))
            Container(
              width: 300,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: isDark ? Theme.of(context).dividerColor : Colors.grey[200]!),
                ),
              ),
              child: _buildFiltersPanel(context, categoriesAsync, searchState),
            ),
          
          // Main search search content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search text input bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => ref.read(searchStateProvider.notifier).updateQuery(val),
                          decoration: InputDecoration(
                            hintText: context.tr('searchPlaceholder'),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref.read(searchStateProvider.notifier).updateQuery('');
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      if (!ResponsiveLayout.isDesktop(context)) ...[
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.tune),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => _buildFiltersPanel(
                                context,
                                categoriesAsync,
                                searchState,
                              ),
                            );
                          },
                          tooltip: context.tr('filterBy'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sorting & Favorites toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: searchState.onlyFavorites,
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(searchStateProvider.notifier).toggleFavorites(val);
                              }
                            },
                          ),
                          Text(context.tr('myFavorites'), style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      Row(
                        children: [
                          Text('${context.tr('sortBy')}: ', style: const TextStyle(fontSize: 12)),
                          DropdownButton<String>(
                            value: searchState.sortBy,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                            underline: const SizedBox(),
                            items: [
                              DropdownMenuItem(value: 'relevance', child: Text(context.tr('relevance'))),
                              DropdownMenuItem(value: 'newest', child: Text(context.tr('newest'))),
                              DropdownMenuItem(value: 'oldest', child: Text(context.tr('oldest'))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(searchStateProvider.notifier).updateSort(val);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Results List
                  Expanded(
                    child: resultsAsync.when(
                      loading: () => const LoadingState(),
                      error: (err, stack) => ErrorState(message: err.toString()),
                      data: (results) {
                        if (results.isEmpty) {
                          return EmptyState(
                            title: context.tr('searchNoResults'),
                            message: 'Try clearing filters or checking spelling.',
                            icon: Icons.search_off_outlined,
                          );
                        }

                        return ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final refModel = results[index];
                            return _SearchResultTile(reference: refModel);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(
      BuildContext context,
      AsyncValue<List<CategoryModel>> categoriesAsync,
      SearchState searchState) {

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text(err.toString())),
      data: (categories) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('filterBy'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  TextButton(
                    onPressed: () => ref.read(searchStateProvider.notifier).clearFilters(),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Categories Filter
              const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: searchState.categoryId ?? 'all',
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Categories')),
                  ...categories.map((c) {
                    final name = context.isRTL ? c.nameAr : c.nameEn;
                    return DropdownMenuItem(value: c.id, child: Text(name));
                  }),
                ],
                onChanged: (val) => ref.read(searchStateProvider.notifier).updateCategory(val),
              ),
              const SizedBox(height: 20),

              // Types Filter
              const Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: searchState.type ?? 'all',
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                items: _typesList.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t));
                }).toList(),
                onChanged: (val) => ref.read(searchStateProvider.notifier).updateType(val),
              ),
              const SizedBox(height: 20),

              // Language Filter
              const Text('Language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: searchState.language ?? 'all',
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Languages')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                ],
                onChanged: (val) => ref.read(searchStateProvider.notifier).updateLanguage(val),
              ),
              const SizedBox(height: 20),

              // Year Filter
              const Text('Year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: searchState.year ?? 0,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('All Years')),
                  DropdownMenuItem(value: 2026, child: Text('2026')),
                  DropdownMenuItem(value: 2025, child: Text('2025')),
                  DropdownMenuItem(value: 2024, child: Text('2024')),
                  DropdownMenuItem(value: 2023, child: Text('2023')),
                  DropdownMenuItem(value: 2022, child: Text('2022')),
                ],
                onChanged: (val) => ref.read(searchStateProvider.notifier).updateYear(val),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchResultTile extends ConsumerWidget {
  final ReferenceModel reference;

  const _SearchResultTile({required this.reference});

  void _copyVancouver(BuildContext context, WidgetRef ref) async {
    final vancouverText = reference.vancouverReference ??
        VancouverFormatter.format(
          title: reference.title,
          organization: reference.organization,
          publicationYear: reference.publicationYear,
        );

    await Clipboard.setData(ClipboardData(text: vancouverText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('vancouverCopied'))),
    );

    await ref.read(activityRepositoryProvider).logActivity(
          action: 'copy_vancouver',
          entityType: 'reference',
          entityId: reference.id,
          description: 'Copied Vancouver citation for "${reference.title}" from search results.',
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final title = context.isRTL && reference.titleAr != null && reference.titleAr!.isNotEmpty
        ? reference.titleAr!
        : reference.title;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Type Badge & Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    reference.referenceType,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () => _copyVancouver(context, ref),
                      tooltip: context.tr('copyVancouver'),
                    ),
                    if (reference.sourceUrl != null && reference.sourceUrl!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        onPressed: () async {
                          final uri = Uri.parse(reference.sourceUrl!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        tooltip: context.tr('openLink'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),

            // Excerpt summary
            Text(
              reference.summary ?? 'No summary.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),

            // Footer metadata
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${reference.organization} • ${reference.publicationYear}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.go('/references/${reference.id}'),
                  child: const Row(
                    children: [
                      Text('View details', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
