import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/domain/user_role.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/references/presentation/reference_list_screen.dart';
import '../../features/references/presentation/reference_detail_screen.dart';
import '../../features/references/presentation/add_reference_screen.dart';
import '../../features/snippets/presentation/add_snippet_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/users/presentation/users_management_screen.dart';
import '../../features/activity_logs/presentation/activity_logs_screen.dart';
import '../../shared/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Listen to auth changes
  final authStream = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _GoRouterRefreshStream(ref.watch(authRepositoryProvider).authStateChanges),
    redirect: (context, state) {
      final user = ref.read(authRepositoryProvider).currentUser;
      final isLoggingIn = state.uri.path == '/login';

      if (user == null) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        return '/';
      }

      // Role authorization guards
      final path = state.uri.path;
      if (path == '/users' || path == '/activity-logs') {
        if (user.role != UserRole.admin) return '/';
      }
      if (path == '/references/add' || path.endsWith('/add_snippet')) {
        if (user.role == UserRole.viewer) return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/references',
            builder: (context, state) => const ReferenceListScreen(),
          ),
          GoRoute(
            path: '/references/add',
            builder: (context, state) => const AddReferenceScreen(),
          ),
          GoRoute(
            path: '/references/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return ReferenceDetailScreen(referenceId: id);
            },
          ),
          GoRoute(
            path: '/references/:id/add_snippet',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return AddSnippetScreen(referenceId: id);
            },
          ),
          GoRoute(
            path: '/favorites',
            builder: (context, state) => const FavoritesScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersManagementScreen(),
          ),
          GoRoute(
            path: '/activity-logs',
            builder: (context, state) => const ActivityLogsScreen(),
          ),
        ],
      ),
    ],
  );
});

class _GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((dynamic _) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
