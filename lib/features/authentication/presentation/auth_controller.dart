import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../activity_logs/data/activity_repository.dart';
import '../data/auth_repository.dart';
import '../domain/user_profile.dart';

class AuthController extends StateNotifier<AsyncValue<UserProfile?>> {
  final AuthRepository _repo;
  final Ref _ref;

  AuthController(this._repo, this._ref) : super(const AsyncValue.data(null)) {
    _repo.authStateChanges.listen((user) {
      state = AsyncValue.data(user);
    }, onError: (err, stack) {
      state = AsyncValue.error(err, stack);
    });
  }

  Future<bool> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signIn(email, password);
      state = AsyncValue.data(user);
      
      // Log activity
      await _ref.read(activityRepositoryProvider).logActivity(
        action: 'login',
        description: 'User ${user.fullName} logged in successfully.',
      );
      
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<void> logout() async {
    final user = _repo.currentUser;
    state = const AsyncValue.loading();
    try {
      if (user != null) {
        await _ref.read(activityRepositoryProvider).logActivity(
          action: 'logout',
          description: 'User ${user.fullName} logged out.',
        );
      }
      await _repo.signOut();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<UserProfile?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo, ref);
});
