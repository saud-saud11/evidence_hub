import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../data/activity_repository.dart';
import '../domain/activity_log.dart';

final activityLogsProvider = FutureProvider<List<ActivityLog>>((ref) {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.getActivityLogs();
});

class ActivityLogsScreen extends ConsumerWidget {
  const ActivityLogsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(activityLogsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('activityLogs'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(activityLogsProvider.future),
        child: logsAsync.when(
          loading: () => const LoadingState(),
          error: (err, stack) => ErrorState(
            message: err.toString(),
            onRetry: () => ref.invalidate(activityLogsProvider),
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return EmptyState(
                title: context.tr('emptyState'),
                message: 'No activities logged yet.',
                icon: Icons.history,
              );
            }

            final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

            return ListView.separated(
              padding: const EdgeInsets.all(24.0),
              itemCount: logs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final log = logs[index];
                final dateStr = dateFormat.format(log.createdAt.toLocal());
                final icon = _getActionIcon(log.action);
                final iconColor = _getActionColor(log.action);

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withOpacity(0.1),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    title: Text(
                      log.description,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(
                      'Action: ${log.action.toUpperCase()} • $dateStr',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    trailing: log.userId != null
                        ? Text(
                            'User: ${log.userId!.substring(0, 5)}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'create_reference':
        return Icons.add_circle_outline;
      case 'update_reference':
        return Icons.edit;
      case 'archive_reference':
        return Icons.archive;
      case 'create_snippet':
        return Icons.description_outlined;
      case 'add_favorite':
        return Icons.star;
      case 'remove_favorite':
        return Icons.star_border;
      case 'copy_vancouver':
      case 'copy_snippet_text':
        return Icons.copy;
      default:
        return Icons.info_outline;
    }
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'login':
        return Colors.green;
      case 'logout':
        return Colors.blueGrey;
      case 'create_reference':
      case 'create_snippet':
        return Colors.teal;
      case 'update_reference':
        return Colors.blue;
      case 'archive_reference':
        return Colors.red;
      case 'add_favorite':
        return Colors.amber;
      case 'remove_favorite':
        return Colors.grey;
      case 'copy_vancouver':
      case 'copy_snippet_text':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}
