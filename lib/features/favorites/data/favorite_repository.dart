import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

abstract class FavoriteRepository {
  Future<List<String>> getFavoriteReferenceIds(String userId);
  Future<void> addFavorite(String userId, String referenceId);
  Future<void> removeFavorite(String userId, String referenceId);
}

class SupabaseFavoriteRepository implements FavoriteRepository {
  final SupabaseService _sb;

  SupabaseFavoriteRepository(this._sb);

  @override
  Future<List<String>> getFavoriteReferenceIds(String userId) async {
    final response = await _sb.client
        .from('favorites')
        .select('reference_id')
        .eq('user_id', userId);
    return (response as List).map((f) => f['reference_id'] as String).toList();
  }

  @override
  Future<void> addFavorite(String userId, String referenceId) async {
    await _sb.client.from('favorites').insert({
      'user_id': userId,
      'reference_id': referenceId,
    });
  }

  @override
  Future<void> removeFavorite(String userId, String referenceId) async {
    await _sb.client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('reference_id', referenceId);
  }
}

class MockFavoriteRepository implements FavoriteRepository {
  final List<Map<String, String>> _mockFavorites = [
    {'user_id': 'mock-admin-id', 'reference_id': 'r1000000-0000-0000-0000-000000000001'},
    {'user_id': 'mock-admin-id', 'reference_id': 'r1000000-0000-0000-0000-000000000003'},
    {'user_id': 'mock-editor-id', 'reference_id': 'r1000000-0000-0000-0000-000000000002'}
  ];

  @override
  Future<List<String>> getFavoriteReferenceIds(String userId) async {
    return _mockFavorites
        .where((f) => f['user_id'] == userId)
        .map((f) => f['reference_id']!)
        .toList();
  }

  @override
  Future<void> addFavorite(String userId, String referenceId) async {
    final exists = _mockFavorites.any(
        (f) => f['user_id'] == userId && f['reference_id'] == referenceId);
    if (!exists) {
      _mockFavorites.add({'user_id': userId, 'reference_id': referenceId});
    }
  }

  @override
  Future<void> removeFavorite(String userId, String referenceId) async {
    _mockFavorites.removeWhere(
        (f) => f['user_id'] == userId && f['reference_id'] == referenceId);
  }
}

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  final isMock = ref.watch(isMockModeProvider);
  if (isMock) {
    return MockFavoriteRepository();
  } else {
    final sb = ref.watch(supabaseServiceProvider);
    return SupabaseFavoriteRepository(sb);
  }
});

// A family provider to check favorite status dynamically
final favoritesProvider = FutureProvider.family<List<String>, String>((ref, userId) {
  final repo = ref.watch(favoriteRepositoryProvider);
  return repo.getFavoriteReferenceIds(userId);
});
