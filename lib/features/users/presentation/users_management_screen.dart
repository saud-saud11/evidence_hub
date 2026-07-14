import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/user_profile.dart';
import '../../authentication/domain/user_role.dart';

final usersListProvider = FutureProvider<List<UserProfile>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getAllProfiles();
});

class UsersManagementScreen extends ConsumerWidget {
  const UsersManagementScreen({Key? key}) : super(key: key);

  void _toggleUserStatus(BuildContext context, WidgetRef ref, UserProfile user, bool active) async {
    try {
      await ref.read(authRepositoryProvider).toggleUserActiveStatus(user.id, active);
      ref.invalidate(usersListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User status updated successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  void _changeUserRole(BuildContext context, WidgetRef ref, UserProfile user, UserRole role) async {
    try {
      await ref.read(authRepositoryProvider).updateUserRole(user.id, role);
      ref.invalidate(usersListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User role updated successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('usersMgmt'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(usersListProvider.future),
        child: usersAsync.when(
          loading: () => const LoadingState(),
          error: (err, stack) => ErrorState(
            message: err.toString(),
            onRetry: () => ref.invalidate(usersListProvider),
          ),
          data: (users) {
            return ListView.separated(
              padding: const EdgeInsets.all(24.0),
              itemCount: users.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final userProfile = users[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          foregroundColor: Theme.of(context).primaryColor,
                          child: Text(userProfile.fullName.substring(0, 1).toUpperCase()),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userProfile.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                userProfile.email,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              if (userProfile.department != null)
                                Text(
                                  userProfile.department!,
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Role Dropdown
                        DropdownButton<UserRole>(
                          value: userProfile.role,
                          underline: const SizedBox(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          items: UserRole.values.map((r) {
                            return DropdownMenuItem(
                              value: r,
                              child: Text(context.tr(r.nameStr)),
                            );
                          }).toList(),
                          onChanged: (role) {
                            if (role != null && role != userProfile.role) {
                              _changeUserRole(context, ref, userProfile, role);
                            }
                          },
                        ),
                        const SizedBox(width: 20),

                        // Active switch
                        Switch(
                          value: userProfile.isActive,
                          onChanged: (active) => _toggleUserStatus(context, ref, userProfile, active),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
