import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/activity_log.dart';

abstract class ActivityRepository {
  Future<List<ActivityLog>> getActivityLogs();
  Future<void> logActivity({
    required String action,
    required String description,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
  });
}

class SupabaseActivityRepository implements ActivityRepository {
  final SupabaseService _sb;
  final Ref _ref;

  SupabaseActivityRepository(this._sb, this._ref);

  @override
  Future<List<ActivityLog>> getActivityLogs() async {
    final response = await _sb.client
        .from('activity_logs')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((l) => ActivityLog.fromJson(l)).toList();
  }

  @override
  Future<void> logActivity({
    required String action,
    required String description,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    await _sb.client.from('activity_logs').insert({
      'user_id': user.id,
      'action': action,
      'description': description,
      'entity_type': entityType,
      'entity_id': entityId,
      'metadata': metadata,
    });
  }
}

class MockActivityRepository implements ActivityRepository {
  final Ref _ref;
  final List<ActivityLog> _mockLogs = [];

  MockActivityRepository(this._ref) {
    // Seed some mock logs
    _mockLogs.addAll([
      ActivityLog(
        id: 'log-1',
        userId: 'mock-admin-id',
        action: 'login',
        description: 'User Dr. Sarah Al-Otaibi logged in.',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      ActivityLog(
        id: 'log-2',
        userId: 'mock-editor-id',
        action: 'create_reference',
        entityType: 'reference',
        entityId: 'r1000000-0000-0000-0000-000000000001',
        description: 'Created reference "National Hepatitis B Contact Tracing Guideline".',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      ActivityLog(
        id: 'log-3',
        userId: 'mock-viewer-id',
        action: 'copy_vancouver',
        entityType: 'reference',
        entityId: 'r1000000-0000-0000-0000-000000000001',
        description: 'Copied Vancouver reference for "National Hepatitis B Contact Tracing Guideline".',
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      )
    ]);
  }

  @override
  Future<List<ActivityLog>> getActivityLogs() async {
    return _mockLogs.reversed.toList();
  }

  @override
  Future<void> logActivity({
    required String action,
    required String description,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _ref.read(authRepositoryProvider).currentUser;
    final log = ActivityLog(
      id: 'log-${DateTime.now().millisecondsSinceEpoch}',
      userId: user?.id ?? 'anonymous',
      action: action,
      entityType: entityType,
      entityId: entityId,
      description: description,
      metadata: metadata,
      createdAt: DateTime.now(),
    );
    _mockLogs.add(log);
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final sb = ref.watch(supabaseServiceProvider);
  return SupabaseActivityRepository(sb, ref);
});
