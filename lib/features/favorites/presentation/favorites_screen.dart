import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../authentication/data/auth_repository.dart';
import '../../references/data/reference_repository.dart';
import '../../references/domain/reference_model.dart';
import '../data/favorite_repository.dart';

final favoritesReferencesProvider = FutureProvider<List<ReferenceModel>>((ref) async {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return [];

  final favIds = await ref.watch(favoriteRepositoryProvider).getFavoriteReferenceIds(user.id);
  final refRepo = ref.watch(referenceRepositoryProvider);

  List<ReferenceModel> refs = [];
  for (var id in favIds) {
    final r = await refRepo.getReferenceById(id);
    if (r != null && r.isActive) {
      refs.add(r);
    }
  }
  return refs;
});

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favRefsAsync = ref.watch(favoritesReferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('myFavorites'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(favoritesReferencesProvider.future),
        child: favRefsAsync.when(
          loading: () => const LoadingState(),
          error: (err, stack) => ErrorState(
            message: err.toString(),
            onRetry: () => ref.invalidate(favoritesReferencesProvider),
          ),
          data: (references) {
            final filtered = references.where((r) {
              if (_searchQuery.trim().isEmpty) return true;
              final q = _searchQuery.trim().toLowerCase();
              return r.title.toLowerCase().contains(q) ||
                  (r.titleAr?.toLowerCase().contains(q) ?? false) ||
                  r.organization.toLowerCase().contains(q);
            }).toList();

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  if (references.isNotEmpty) ...[
                    TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search in favorites...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Expanded(
                    child: filtered.isEmpty
                        ? EmptyState(
                            title: context.tr('emptyState'),
                            message: references.isEmpty
                                ? 'Star references to view them here.'
                                : 'No favorites match search query.',
                            icon: Icons.star_border,
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final refModel = filtered[index];
                              final title = context.isRTL && refModel.titleAr != null && refModel.titleAr!.isNotEmpty
                                  ? refModel.titleAr!
                                  : refModel.title;

                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.star, color: Colors.amber),
                                  title: Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(refModel.organization),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                                  onTap: () => context.go('/references/${refModel.id}'),
                                ),
                              );
                            },
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
