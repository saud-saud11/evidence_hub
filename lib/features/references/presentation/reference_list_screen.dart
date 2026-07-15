import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/user_role.dart';
import '../data/reference_repository.dart';
import '../domain/reference_model.dart';
import '../application/excel_service.dart';
import 'package:file_picker/file_picker.dart';

final referencesListProvider = FutureProvider<List<ReferenceModel>>((ref) {
  final repo = ref.watch(referenceRepositoryProvider);
  return repo.getReferences();
});

class ReferenceListScreen extends ConsumerWidget {
  const ReferenceListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(referencesListProvider);
    final user = ref.watch(authRepositoryProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('references'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (user != null && user.role != UserRole.viewer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton.icon(
                onPressed: () => context.go('/references/add'),
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.tr('addReference')),
              ),
            ),
          if (user != null && user.role == UserRole.admin)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Bulk Actions',
                onSelected: (value) async {
                  if (value == 'download') {
                    try {
                      await ref.read(excelServiceProvider).downloadTemplate();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  } else if (value == 'upload') {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['xlsx', 'csv'],
                      withData: true,
                    );
                    if (result != null && result.files.single.bytes != null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Parsing Excel file...')),
                        );
                      }
                      try {
                        final refs = await ref.read(excelServiceProvider).parseExcelFile(result.files.single.bytes!, result.files.single.name, user.id);
                        if (refs.isEmpty) {
                           if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text('No valid references found in the file')),
                             );
                           }
                           return;
                        }
                        await ref.read(referenceRepositoryProvider).bulkAddReferences(refs);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Successfully added ${refs.length} references')),
                          );
                          ref.invalidate(referencesListProvider);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error parsing excel: $e')),
                          );
                        }
                      }
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 18),
                        SizedBox(width: 8),
                        Text('Download Excel Template'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'upload',
                    child: Row(
                      children: [
                        Icon(Icons.upload_file, size: 18),
                        SizedBox(width: 8),
                        Text('Bulk Upload via Excel'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(referencesListProvider.future),
        child: listAsync.when(
          loading: () => const LoadingState(),
          error: (err, stack) => ErrorState(
            message: err.toString(),
            onRetry: () => ref.invalidate(referencesListProvider),
          ),
          data: (references) {
            if (references.isEmpty) {
              return EmptyState(
                title: context.tr('emptyState'),
                message: 'No references available yet.',
                icon: Icons.menu_book,
              );
            }

            return ResponsiveLayout(
              mobile: _buildList(context, references),
              desktop: _buildGrid(context, references),
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<ReferenceModel> references) {
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: references.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ref = references[index];
        return _ReferenceCard(reference: ref);
      },
    );
  }

  Widget _buildGrid(BuildContext context, List<ReferenceModel> references) {
    return GridView.builder(
      padding: const EdgeInsets.all(24.0),
      itemCount: references.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.6,
      ),
      itemBuilder: (context, index) {
        final ref = references[index];
        return _ReferenceCard(reference: ref);
      },
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  final ReferenceModel reference;

  const _ReferenceCard({required this.reference});

  @override
  Widget build(BuildContext context) {
    final title = context.isRTL && reference.titleAr != null && reference.titleAr!.isNotEmpty
        ? reference.titleAr!
        : reference.title;
    
    final typeColor = _getTypeColor(reference.referenceType);

    return Card(
      child: InkWell(
        onTap: () => context.go('/references/${reference.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge & Year
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      reference.referenceType,
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    reference.publicationYear.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Divider
              const Divider(height: 16),

              // Organization and Language
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.business, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reference.organization,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.language, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        reference.language.toUpperCase(),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'guideline':
        return Colors.teal;
      case 'policy':
        return Colors.blue;
      case 'circular':
        return Colors.orange;
      case 'epidemiological definition':
        return Colors.indigo;
      case 'who document':
        return Colors.purple;
      case 'laboratory turnaround time policy':
      case 'standard operating procedure':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
