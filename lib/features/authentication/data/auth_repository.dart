import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/errors/failure.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/user_profile.dart';
import '../domain/user_role.dart';

abstract class AuthRepository {
  Stream<UserProfile?> get authStateChanges;
  UserProfile? get currentUser;
  Future<UserProfile> signIn(String email, String password);
  Future<void> signOut();
  Future<List<UserProfile>> getAllProfiles();
  Future<void> toggleUserActiveStatus(String userId, bool active);
  Future<void> updateUserRole(String userId, UserRole role);
}

class SupabaseAuthRepository implements AuthRepository {
  final sb.SupabaseClient _client;
  final _controller = StreamController<UserProfile?>.broadcast();
  UserProfile? _cachedUser;

  SupabaseAuthRepository(this._client) {
    _client.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user == null) {
        _cachedUser = null;
        _controller.add(null);
      } else {
        try {
          final profile = await _fetchProfile(user.id);
          _cachedUser = profile;
          _controller.add(profile);
        } catch (_) {
          _cachedUser = null;
          _controller.add(null);
        }
      }
    });
  }

  Future<UserProfile> _fetchProfile(String id) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .single();
    return UserProfile.fromJson(response);
  }

  @override
  Stream<UserProfile?> get authStateChanges => _controller.stream;

  @override
  UserProfile? get currentUser => _cachedUser;

  @override
  Future<UserProfile> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw AuthFailure('Authentication failed.');
      }
      final profile = await _fetchProfile(response.user!.id);
      if (!profile.isActive) {
        await signOut();
        throw AuthFailure('Your account has been deactivated. Please contact support.');
      }
      _cachedUser = profile;
      _controller.add(profile);
      return profile;
    } on sb.AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _cachedUser = null;
    _controller.add(null);
  }

  @override
  Future<List<UserProfile>> getAllProfiles() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);
      return (response as List).map((p) => UserProfile.fromJson(p)).toList();
    } catch (e) {
      throw Failure('Failed to fetch user profiles.');
    }
  }

  @override
  Future<void> toggleUserActiveStatus(String userId, bool active) async {
    try {
      await _client
          .from('profiles')
          .update({'is_active': active})
          .eq('id', userId);
    } catch (e) {
      throw Failure('Failed to update user status.');
    }
  }

  @override
  Future<void> updateUserRole(String userId, UserRole role) async {
    try {
      await _client
          .from('profiles')
          .update({'role': role.nameStr})
          .eq('id', userId);
    } catch (e) {
      throw Failure('Failed to update user role.');
    }
  }
}

class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<UserProfile?>.broadcast();
  UserProfile? _cachedUser;
  
  final List<UserProfile> _mockProfiles = [
    UserProfile(
      id: 'mock-admin-id',
      fullName: 'Dr. Sarah Al-Otaibi (Admin)',
      email: 'admin@evidencehub.com',
      role: UserRole.admin,
      department: 'Public Health Department',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 100)),
      updatedAt: DateTime.now(),
    ),
    UserProfile(
      id: 'mock-editor-id',
      fullName: 'Fahad Al-Harbi (Editor)',
      email: 'editor@evidencehub.com',
      role: UserRole.editor,
      department: 'Epidemiological Surveillance',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 50)),
      updatedAt: DateTime.now(),
    ),
    UserProfile(
      id: 'mock-viewer-id',
      fullName: 'Aisha Al-Ghamdi (Viewer)',
      email: 'viewer@evidencehub.com',
      role: UserRole.viewer,
      department: 'Preventive Medicine Division',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now(),
    ),
    UserProfile(
      id: 'mock-inactive-id',
      fullName: 'Khaled Al-Subaie (Inactive)',
      email: 'inactive@evidencehub.com',
      role: UserRole.viewer,
      department: 'Information Technology',
      isActive: false,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now(),
    )
  ];

  MockAuthRepository() {
    // Start as logged out
    Timer(const Duration(milliseconds: 100), () => _controller.add(null));
  }

  @override
  Stream<UserProfile?> get authStateChanges => _controller.stream;

  @override
  UserProfile? get currentUser => _cachedUser;

  @override
  Future<UserProfile> signIn(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulating network latency
    
    final normalizedEmail = email.trim().toLowerCase();
    
    // Find matching profile
    UserProfile? profile;
    if (normalizedEmail == 'admin@evidencehub.com' && password == 'admin123') {
      profile = _mockProfiles.firstWhere((p) => p.role == UserRole.admin);
    } else if (normalizedEmail == 'editor@evidencehub.com' && password == 'editor123') {
      profile = _mockProfiles.firstWhere((p) => p.role == UserRole.editor);
    } else if (normalizedEmail == 'viewer@evidencehub.com' && password == 'viewer123') {
      profile = _mockProfiles.firstWhere((p) => p.role == UserRole.viewer);
    } else if (normalizedEmail == 'inactive@evidencehub.com' && password == 'inactive123') {
      profile = _mockProfiles.firstWhere((p) => !p.isActive);
    }
    
    if (profile == null) {
      throw AuthFailure('Invalid email or password. Use: admin@evidencehub.com/admin123, editor@evidencehub.com/editor123, viewer@evidencehub.com/viewer123');
    }
    
    if (!profile.isActive) {
      throw AuthFailure('Your account has been deactivated. Please contact support.');
    }
    
    _cachedUser = profile;
    _controller.add(profile);
    return profile;
  }

  @override
  Future<void> signOut() async {
    _cachedUser = null;
    _controller.add(null);
  }

  @override
  Future<List<UserProfile>> getAllProfiles() async {
    return _mockProfiles;
  }

  @override
  Future<void> toggleUserActiveStatus(String userId, bool active) async {
    final index = _mockProfiles.indexWhere((p) => p.id == userId);
    if (index != -1) {
      _mockProfiles[index] = _mockProfiles[index].copyWith(isActive: active);
    }
  }

  @override
  Future<void> updateUserRole(String userId, UserRole role) async {
    final index = _mockProfiles.indexWhere((p) => p.id == userId);
    if (index != -1) {
      _mockProfiles[index] = _mockProfiles[index].copyWith(role: role);
    }
  }
}

// Riverpod Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return SupabaseAuthRepository(supabase.client);
});

// Current User Provider
final authStateProvider = StreamProvider<UserProfile?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});
