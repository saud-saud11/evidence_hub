import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../activity_logs/data/activity_repository.dart';
import '../../authentication/data/auth_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/domain/category_model.dart';
import '../data/reference_repository.dart';
import '../domain/reference_model.dart';
import 'reference_list_screen.dart';

class AddReferenceScreen extends ConsumerStatefulWidget {
  const AddReferenceScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddReferenceScreen> createState() => _AddReferenceScreenState();
}

class _AddReferenceScreenState extends ConsumerState<AddReferenceScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _titleArController = TextEditingController();
  final _orgController = TextEditingController();
  final _yearController = TextEditingController();
  final _summaryController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  final _vancouverController = TextEditingController();
  final _keywordsController = TextEditingController();

  String _selectedType = 'Guideline';
  String? _selectedCategoryId;
  String _selectedLanguage = 'en';
  bool _isActive = true;

  PlatformFile? _selectedFile;
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  final List<String> _referenceTypes = [
    'Guideline',
    'Policy',
    'Circular',
    'Scientific Article',
    'Statistical Report',
    'Manual',
    'Protocol',
    'WHO Document',
    'Ministry Document',
    'Epidemiological Definition',
    'Standard Operating Procedure',
    'Other'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _titleArController.dispose();
    _orgController.dispose();
    _yearController.dispose();
    _summaryController.dispose();
    _sourceUrlController.dispose();
    _vancouverController.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  void _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.allowedFileExtensions,
        withData: true, // required for Web
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // File size check
        if (file.size > AppConstants.maxFileSize) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('fileSizeLimitExceeded')),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category'), backgroundColor: Colors.red),
        );
        return;
      }

      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) return;

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      final newRef = ReferenceModel(
        id: '', // DB generates
        title: _titleController.text.trim(),
        titleAr: _titleArController.text.trim().isEmpty ? null : _titleArController.text.trim(),
        organization: _orgController.text.trim(),
        referenceType: _selectedType,
        categoryId: _selectedCategoryId,
        publicationYear: int.parse(_yearController.text.trim()),
        language: _selectedLanguage,
        summary: _summaryController.text.trim(),
        sourceUrl: _sourceUrlController.text.trim().isEmpty ? null : _sourceUrlController.text.trim(),
        vancouverReference: _vancouverController.text.trim().isEmpty ? null : _vancouverController.text.trim(),
        addedBy: user.id,
        isActive: _isActive,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        final referenceRepo = ref.read(referenceRepositoryProvider);
        final activityRepo = ref.read(activityRepositoryProvider);

        final result = await referenceRepo.addReference(
          newRef,
          file: _selectedFile,
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
            });
          },
        );

        await activityRepo.logActivity(
          action: 'create_reference',
          entityType: 'reference',
          entityId: result.id,
          description: 'Added new reference: "${result.title}".',
        );

        // Refresh references list provider
        ref.invalidate(referencesListProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('addReferenceSuccess'))),
          );
          context.go('/references/${result.id}');
        }
      } catch (e) {
        setState(() {
          _isUploading = false;
        });
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
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('addReference')),
      ),
      body: categoriesAsync.when(
        loading: () => const LoadingState(),
        error: (err, stack) => ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return const EmptyState(message: 'No categories available. Please add categories first.');
          }

          // Default category choice
          if (_selectedCategoryId == null && categories.isNotEmpty) {
            _selectedCategoryId = categories.first.id;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title English
                          Text(context.tr('titleEn'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(hintText: 'e.g., National TB Circular 2026'),
                            validator: (value) => value == null || value.trim().isEmpty ? 'Required field' : null,
                          ),
                          const SizedBox(height: 20),

                          // Title Arabic
                          Text(context.tr('titleAr'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _titleArController,
                            decoration: const InputDecoration(hintText: 'مثال: التعميم الوطني للدرن ٢٠٢٦'),
                          ),
                          const SizedBox(height: 20),

                          // Row: Org & Year
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(context.tr('organization'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _orgController,
                                      decoration: const InputDecoration(hintText: 'e.g., Ministry of Health'),
                                      validator: (value) => value == null || value.trim().isEmpty ? 'Required field' : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(context.tr('publicationYear'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _yearController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(hintText: 'e.g., 2026'),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) return 'Required field';
                                        if (int.tryParse(value) == null) return 'Must be a valid year';
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Row: Type, Category, Lang
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(context.tr('referenceType'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: _selectedType,
                                      decoration: const InputDecoration(),
                                      items: _referenceTypes.map((t) {
                                        return DropdownMenuItem(value: t, child: Text(t));
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedType = val;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(context.tr('categories'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: _selectedCategoryId,
                                      decoration: const InputDecoration(),
                                      items: categories.map((c) {
                                        final name = context.isRTL ? c.nameAr : c.nameEn;
                                        return DropdownMenuItem(value: c.id, child: Text(name));
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedCategoryId = val;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(context.tr('language'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: _selectedLanguage,
                                      decoration: const InputDecoration(),
                                      items: const [
                                        DropdownMenuItem(value: 'en', child: Text('English (EN)')),
                                        DropdownMenuItem(value: 'ar', child: Text('العربية (AR)')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedLanguage = val;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Summary Text Area
                          Text(context.tr('summary'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _summaryController,
                            maxLines: 4,
                            decoration: const InputDecoration(hintText: 'Enter a concise summary of this reference...'),
                            validator: (value) => value == null || value.trim().isEmpty ? 'Required field' : null,
                          ),
                          const SizedBox(height: 20),

                          // Source URL
                          Text(context.tr('sourceUrl'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _sourceUrlController,
                            decoration: const InputDecoration(hintText: 'https://example.gov.sa/document'),
                          ),
                          const SizedBox(height: 20),

                          // Vancouver Reference (Optional)
                          Text(context.tr('vancouverReference'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _vancouverController,
                            decoration: const InputDecoration(
                              hintText: 'Leave blank to generate automatically in Vancouver format.',
                            ),
                          ),
                          const SizedBox(height: 24),

                          // File Upload Section
                          const Divider(),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Attachment File (PDF, Excel, Word)', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    _selectedFile != null
                                        ? '${_selectedFile!.name} (${(_selectedFile!.size / 1024).round()} KB)'
                                        : 'No file selected (Max size: 15MB)',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                onPressed: _isUploading ? null : _pickFile,
                                icon: const Icon(Icons.attach_file),
                                label: Text(context.tr('uploadFile')),
                              ),
                            ],
                          ),

                          if (_isUploading) ...[
                            const SizedBox(height: 16),
                            Text('${context.tr('uploading')} ${(_uploadProgress * 100).round()}%'),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(value: _uploadProgress),
                          ],
                          const SizedBox(height: 24),

                          // Row: Status Active Switch
                          Row(
                            children: [
                              Switch(
                                value: _isActive,
                                onChanged: (val) {
                                  setState(() {
                                    _isActive = val;
                                  });
                                },
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isActive ? context.tr('activeStatus') : context.tr('archivedStatus'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Actions Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _isUploading ? null : () => context.pop(),
                                child: Text(context.tr('cancel')),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: _isUploading ? null : _submit,
                                child: Text(context.tr('save')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
