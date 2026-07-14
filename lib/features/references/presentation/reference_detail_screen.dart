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
import '../../authentication/domain/user_role.dart';
import '../../favorites/data/favorite_repository.dart';
import '../data/reference_repository.dart';
import '../domain/reference_model.dart';
import '../../snippets/data/snippet_repository.dart';
import '../../snippets/domain/snippet_model.dart';

// Providers for details
final referenceDetailsProvider = FutureProvider.family<ReferenceModel?, String>((ref, id) {
  return ref.read(referenceRepositoryProvider).getReferenceById(id);
});

final snippetsListProvider = FutureProvider.family<List<EvidenceSnippet>, String>((ref, refId) {
  return ref.read(snippetRepositoryProvider).getSnippetsByReference(refId);
});

class ReferenceDetailScreen extends ConsumerStatefulWidget {
  final String referenceId;
  
  const ReferenceDetailScreen({Key? key, required this.referenceId}) : super(key: key);

  @override
  ConsumerState<ReferenceDetailScreen> createState() => _ReferenceDetailScreenState();
}

class _ReferenceDetailScreenState extends ConsumerState<ReferenceDetailScreen> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  void _checkFavorite() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      final favs = await ref.read(favoriteRepositoryProvider).getFavoriteReferenceIds(user.id);
      if (mounted) {
        setState(() {
          _isFavorite = favs.contains(widget.referenceId);
        });
      }
    }
  }

  void _toggleFavorite(ReferenceModel refModel) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    final favRepo = ref.read(favoriteRepositoryProvider);
    final activityRepo = ref.read(activityRepositoryProvider);

    try {
      if (_isFavorite) {
        await favRepo.removeFavorite(user.id, widget.referenceId);
        setState(() {
          _isFavorite = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('favoriteRemoved'))),
          );
        }
        await activityRepo.logActivity(
          action: 'remove_favorite',
          entityType: 'reference',
          entityId: refModel.id,
          description: 'Removed reference "${refModel.title}" from favorites.',
        );
      } else {
        await favRepo.addFavorite(user.id, widget.referenceId);
        setState(() {
          _isFavorite = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('favoriteAdded'))),
          );
        }
        await activityRepo.logActivity(
          action: 'add_favorite',
          entityType: 'reference',
          entityId: refModel.id,
          description: 'Added reference "${refModel.title}" to favorites.',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  void _launchURL(String url, String actionName, ReferenceModel refModel) async {
    final uri = Uri.parse(url);
    final activityRepo = ref.read(activityRepositoryProvider);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        await activityRepo.logActivity(
          action: actionName,
          entityType: 'reference',
          entityId: refModel.id,
          description: 'Opened external resource for "${refModel.title}".',
          metadata: {'url': url},
        );
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copyToClipboard(String text, String snackBarKey, String actionName, ReferenceModel refModel) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr(snackBarKey))),
    );

    await ref.read(activityRepositoryProvider).logActivity(
          action: actionName,
          entityType: 'reference',
          entityId: refModel.id,
          description: 'Copied $actionName for reference "${refModel.title}".',
        );
  }

  void _archiveReference(ReferenceModel refModel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('archive')),
        content: const Text('Are you sure you want to archive this reference?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('archive')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(referenceRepositoryProvider).archiveReference(refModel.id);
        await ref.read(activityRepositoryProvider).logActivity(
              action: 'archive_reference',
              entityType: 'reference',
              entityId: refModel.id,
              description: 'Archived reference "${refModel.title}".',
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('deleteReferenceSuccess'))),
          );
          context.go('/references');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final refAsync = ref.watch(referenceDetailsProvider(widget.referenceId));
    final snippetsAsync = ref.watch(snippetsListProvider(widget.referenceId));
    final user = ref.watch(authRepositoryProvider).currentUser;

    return refAsync.when(
      loading: () => const Scaffold(body: LoadingState()),
      error: (err, stack) => Scaffold(
        body: ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(referenceDetailsProvider(widget.referenceId)),
        ),
      ),
      data: (refModel) {
        if (refModel == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(message: 'Reference not found'),
          );
        }

        final vancouverText = refModel.vancouverReference ??
            VancouverFormatter.format(
              title: refModel.title,
              organization: refModel.organization,
              publicationYear: refModel.publicationYear,
            );

        final showEditActions = user != null &&
            (user.role == UserRole.admin ||
                (user.role == UserRole.editor && refModel.addedBy == user.id));

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('metadata')),
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.star : Icons.star_border,
                  color: _isFavorite ? Colors.amber : null,
                ),
                onPressed: () => _toggleFavorite(refModel),
                tooltip: context.tr('favorites'),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _copyToClipboard(
                  '${Uri.base.origin}/#/references/${refModel.id}',
                  'copiedSuccess',
                  'share_link',
                  refModel,
                ),
                tooltip: context.tr('share'),
              ),
              if (showEditActions) ...[
                IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  color: Colors.redAccent,
                  onPressed: () => _archiveReference(refModel),
                  tooltip: context.tr('archive'),
                ),
              ],
            ],
          ),
          body: ResponsiveLayout(
            mobile: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailsCard(context, refModel, vancouverText),
                  const SizedBox(height: 24),
                  _buildSnippetsSection(context, snippetsAsync, refModel, showEditActions),
                ],
              ),
            ),
            desktop: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: _buildDetailsCard(context, refModel, vancouverText),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: _buildSnippetsSection(context, snippetsAsync, refModel, showEditActions),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailsCard(BuildContext context, ReferenceModel refModel, String vancouverText) {
    final title = context.isRTL && refModel.titleAr != null && refModel.titleAr!.isNotEmpty
        ? refModel.titleAr!
        : refModel.title;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Metadata Row Info
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _MetadataItem(label: context.tr('organization'), value: refModel.organization, icon: Icons.business),
                _MetadataItem(label: context.tr('referenceType'), value: refModel.referenceType, icon: Icons.tag),
                _MetadataItem(label: context.tr('publicationYear'), value: refModel.publicationYear.toString(), icon: Icons.calendar_today),
                _MetadataItem(label: context.tr('language'), value: refModel.language.toUpperCase(), icon: Icons.language),
              ],
            ),
            const Divider(height: 32),

            // Summary
            Text(
              context.tr('summary'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              refModel.summary ?? 'No summary available.',
              style: TextStyle(height: 1.4, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
            ),
            const Divider(height: 32),

            // Vancouver Reference
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('vancouverReference'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _copyToClipboard(vancouverText, 'vancouverCopied', 'copy_vancouver', refModel),
                  icon: const Icon(Icons.copy, size: 14),
                  label: Text(context.tr('copyText')),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Theme.of(context).dividerColor : Colors.grey[200]!),
              ),
              child: Text(
                vancouverText,
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, height: 1.3),
              ),
            ),
            const SizedBox(height: 24),

            // External Links & Attachment Buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (refModel.sourceUrl != null && refModel.sourceUrl!.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _launchURL(refModel.sourceUrl!, 'open_source_url', refModel),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(context.tr('openLink')),
                  ),
                if (refModel.fileUrl != null && refModel.fileUrl!.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _launchURL(refModel.fileUrl!, 'open_file', refModel),
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: Text(context.tr('openFile')),
                  ),
              ],
            ),

            if (refModel.fileName != null) ...[
              const SizedBox(height: 12),
              Text(
                '${context.tr('fileUploaded')}: ${refModel.fileName} (${(refModel.fileSize ?? 0) / 1024 ~/ 1024}MB)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSnippetsSection(
      BuildContext context,
      AsyncValue<List<EvidenceSnippet>> snippetsAsync,
      ReferenceModel refModel,
      bool showAddAction) {
    return snippetsAsync.when(
      loading: () => const LoadingState(),
      error: (err, stack) => ErrorState(message: err.toString()),
      data: (snippets) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('snippets'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (showAddAction)
                  TextButton.icon(
                    onPressed: () => context.go('/references/${refModel.id}/add_snippet'),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(context.tr('addSnippet')),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (snippets.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      context.tr('noSnippets'),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snippets.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final snippet = snippets[index];
                  return _SnippetCard(snippet: snippet, refModel: refModel);
                },
              ),
          ],
        );
      },
    );
  }
}

class _MetadataItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetadataItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

class _SnippetCard extends ConsumerWidget {
  final EvidenceSnippet snippet;
  final ReferenceModel refModel;

  const _SnippetCard({
    required this.snippet,
    required this.refModel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = context.isRTL && snippet.titleAr != null && snippet.titleAr!.isNotEmpty
        ? snippet.titleAr!
        : snippet.title;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: snippet.evidenceText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('textCopied'))),
                    );
                    await ref.read(activityRepositoryProvider).logActivity(
                          action: 'copy_snippet_text',
                          entityType: 'snippet',
                          entityId: snippet.id,
                          description: 'Copied snippet text from "${snippet.title}".',
                        );
                  },
                  tooltip: context.tr('copyText'),
                ),
              ],
            ),
            if (snippet.sectionName != null || snippet.pageNumber != null) ...[
              const SizedBox(height: 4),
              Text(
                '${snippet.sectionName ?? ""} ${snippet.pageNumber != null ? "(Page ${snippet.pageNumber})" : ""}',
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              snippet.evidenceText,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            if (snippet.keywords.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: snippet.keywords.map((tag) {
                  return Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 9)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
