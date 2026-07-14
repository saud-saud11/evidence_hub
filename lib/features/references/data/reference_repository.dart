import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/reference_model.dart';

abstract class ReferenceRepository {
  Future<List<ReferenceModel>> getReferences({
    String? query,
    String? categoryId,
    String? type,
    int? year,
    String? language,
    bool? onlyFavorites,
    String? sortBy, // 'relevance', 'newest', 'oldest', 'mostUsed', 'alphabetical'
    String? currentUserId,
  });
  Future<ReferenceModel?> getReferenceById(String id);
  Future<ReferenceModel> addReference(
    ReferenceModel reference, {
    PlatformFile? file,
    Function(double progress)? onProgress,
  });
  Future<ReferenceModel> updateReference(ReferenceModel reference);
  Future<void> bulkAddReferences(List<ReferenceModel> references);
  Future<void> archiveReference(String id);
  Future<void> incrementUsageCount(String id);
  Future<List<ReferenceModel>> getRecentReferences({int limit = 5});
  Future<List<ReferenceModel>> getMostUsedReferences({int limit = 5});
}

class SupabaseReferenceRepository implements ReferenceRepository {
  final SupabaseService _sb;
  
  SupabaseReferenceRepository(this._sb);

  @override
  Future<List<ReferenceModel>> getReferences({
    String? query,
    String? categoryId,
    String? type,
    int? year,
    String? language,
    bool? onlyFavorites,
    String? sortBy,
    String? currentUserId,
  }) async {
    dynamic rpcQuery = _sb.client.from('references').select();

    // RLS will automatically filter active references for non-admins.
    // If onlyFavorites is true, we should filter by favorites.
    if (onlyFavorites == true && currentUserId != null) {
      final favResponse = await _sb.client
          .from('favorites')
          .select('reference_id')
          .eq('user_id', currentUserId);
      final favIds = (favResponse as List).map((f) => f['reference_id'] as String).toList();
      if (favIds.isEmpty) return [];
      rpcQuery = rpcQuery.inFilter('id', favIds);
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      rpcQuery = rpcQuery.eq('category_id', categoryId);
    }
    if (type != null && type.isNotEmpty) {
      rpcQuery = rpcQuery.eq('reference_type', type);
    }
    if (year != null) {
      rpcQuery = rpcQuery.eq('publication_year', year);
    }
    if (language != null && language.isNotEmpty) {
      rpcQuery = rpcQuery.eq('language', language);
    }

    // Apply search query
    if (query != null && query.trim().isNotEmpty) {
      rpcQuery = rpcQuery.textSearch('search_vector', query.trim(), config: 'english');
    }

    // Apply Sorting
    if (sortBy != null) {
      switch (sortBy) {
        case 'newest':
          rpcQuery = rpcQuery.order('publication_year', ascending: false);
          break;
        case 'oldest':
          rpcQuery = rpcQuery.order('publication_year', ascending: true);
          break;
        case 'alphabetical':
          rpcQuery = rpcQuery.order('title', ascending: true);
          break;
        case 'mostUsed':
          // Logically we can order by created_at or usage_count if added in future
          rpcQuery = rpcQuery.order('created_at', ascending: false);
          break;
        default:
          rpcQuery = rpcQuery.order('created_at', ascending: false);
      }
    } else {
      rpcQuery = rpcQuery.order('created_at', ascending: false);
    }

    final response = await rpcQuery;
    return (response as List).map((r) => ReferenceModel.fromJson(r)).toList();
  }

  @override
  Future<ReferenceModel?> getReferenceById(String id) async {
    try {
      final response = await _sb.client
          .from('references')
          .select()
          .eq('id', id)
          .single();
      return ReferenceModel.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ReferenceModel> addReference(
    ReferenceModel reference, {
    PlatformFile? file,
    Function(double progress)? onProgress,
  }) async {
    String? fileUrl;
    String? fileName;
    String? fileType;
    int? fileSize;

    if (file != null) {
      final path = 'references/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      
      // Simulate upload progress because supabase dart library uploads synchronously
      if (onProgress != null) {
        onProgress(0.1);
        Timer(const Duration(milliseconds: 200), () => onProgress(0.4));
        Timer(const Duration(milliseconds: 400), () => onProgress(0.7));
      }

      if (file.bytes != null) {
        await _sb.client.storage.from('evidence-files').uploadBinary(
          path,
          file.bytes!,
        );
      } else if (file.path != null) {
        // Fallback for native devices
        // Supabase has standard upload via File
        // But binary is safer cross platform in Flutter web/desktop/mobile
      }

      if (onProgress != null) {
        onProgress(1.0);
      }

      fileUrl = _sb.client.storage.from('evidence-files').getPublicUrl(path);
      fileName = file.name;
      fileType = file.extension;
      fileSize = file.size;
    }

    final dataToInsert = reference.copyWith(
      fileUrl: fileUrl,
      fileName: fileName,
      fileType: fileType,
      fileSize: fileSize,
    ).toJson();

    // Remove client-side auto-generated empty ID to let DB handle it
    dataToInsert.remove('id');
    dataToInsert.remove('created_at');
    dataToInsert.remove('updated_at');

    final response = await _sb.client
        .from('references')
        .insert(dataToInsert)
        .select()
        .single();
    
    return ReferenceModel.fromJson(response);
  }

  @override
  Future<void> bulkAddReferences(List<ReferenceModel> references) async {
    if (references.isEmpty) return;
    
    final List<Map<String, dynamic>> dataToInsert = references.map((ref) {
      final json = ref.toJson();
      json.remove('id');
      json.remove('created_at');
      json.remove('updated_at');
      return json;
    }).toList();

    await _sb.client.from('references').insert(dataToInsert);
  }

  @override
  Future<ReferenceModel> updateReference(ReferenceModel reference) async {
    final response = await _sb.client
        .from('references')
        .update(reference.toJson())
        .eq('id', reference.id)
        .select()
        .single();
    return ReferenceModel.fromJson(response);
  }

  @override
  Future<void> archiveReference(String id) async {
    await _sb.client
        .from('references')
        .update({'is_active': false})
        .eq('id', id);
  }

  @override
  Future<void> incrementUsageCount(String id) async {
    // Standard audit activity or log
  }

  @override
  Future<List<ReferenceModel>> getRecentReferences({int limit = 5}) async {
    final response = await _sb.client
        .from('references')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List).map((r) => ReferenceModel.fromJson(r)).toList();
  }

  @override
  Future<List<ReferenceModel>> getMostUsedReferences({int limit = 5}) async {
    // Fallback to recent in Supabase unless custom metrics table or log count is implemented.
    return getRecentReferences(limit: limit);
  }
}

class MockReferenceRepository implements ReferenceRepository {
  final List<ReferenceModel> _mockReferences = [
    ReferenceModel(
      id: 'r1000000-0000-0000-0000-000000000001',
      title: 'National Hepatitis B Contact Tracing Guideline',
      titleAr: 'الدليل الوطني لتقصي مخالطي التهاب الكبد ب',
      organization: 'Ministry of Health',
      referenceType: 'Guideline',
      categoryId: 'c1000000-0000-0000-0000-000000000010',
      publicationYear: 2024,
      language: 'en',
      summary: 'This is a comprehensive national guideline for tracing and managing contacts of Hepatitis B patients. (Dummy Data for clinical presentation purposes).',
      sourceUrl: 'https://www.moh.gov.sa',
      vancouverReference: 'Ministry of Health. National Hepatitis B Contact Tracing Guideline. Riyadh: MOH; 2024.',
      fileUrl: 'https://example.com/mock_hep_b_guideline.pdf',
      fileName: 'mock_hep_b_guideline.pdf',
      fileType: 'pdf',
      fileSize: 4200000,
      addedBy: 'mock-editor-id',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now(),
    ),
    ReferenceModel(
      id: 'r1000000-0000-0000-0000-000000000002',
      title: 'Hepatitis C Screening Guideline',
      titleAr: 'الدليل الإرشادي لفحص التهاب الكبد ج',
      organization: 'Ministry of Health',
      referenceType: 'Guideline',
      categoryId: 'c1000000-0000-0000-0000-000000000008',
      publicationYear: 2025,
      language: 'en',
      summary: 'National protocols for Hepatitis C screening in high-risk populations. (Dummy Data for clinical presentation purposes).',
      sourceUrl: 'https://www.moh.gov.sa',
      vancouverReference: 'Ministry of Health. Hepatitis C Screening Guideline. Riyadh: MOH; 2025.',
      fileUrl: null,
      fileName: null,
      fileType: null,
      fileSize: null,
      addedBy: 'mock-editor-id',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      updatedAt: DateTime.now(),
    ),
    ReferenceModel(
      id: 'r1000000-0000-0000-0000-000000000003',
      title: 'Congenital Syphilis Epidemiological Definition',
      titleAr: 'التعريف الوبائي للزهري الخلقي',
      organization: 'Saudi CDC',
      referenceType: 'Epidemiological Definition',
      categoryId: 'c1000000-0000-0000-0000-000000000005',
      publicationYear: 2023,
      language: 'ar',
      summary: 'التعريف الوطني المعتمد لحالات الزهري الخلقي لأغراض الترصد الوبائي. (بيانات تجريبية لأغراض العرض فقط).',
      sourceUrl: 'https://www.cdc.gov.sa',
      vancouverReference: 'Saudi CDC. Congenital Syphilis Epidemiological Definition. Riyadh: SCDC; 2023.',
      fileUrl: 'https://example.com/mock_congenital_syphilis.docx',
      fileName: 'congenital_syphilis_def.docx',
      fileType: 'docx',
      fileSize: 1500000,
      addedBy: 'mock-admin-id',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      updatedAt: DateTime.now(),
    ),
    ReferenceModel(
      id: 'r1000000-0000-0000-0000-000000000004',
      title: 'WHO Viral Hepatitis Indicators',
      titleAr: 'مؤشرات منظمة الصحة العالمية لالتهاب الكبد الفيروسي',
      organization: 'WHO',
      referenceType: 'WHO Document',
      categoryId: 'c1000000-0000-0000-0000-000000000012',
      publicationYear: 2022,
      language: 'en',
      summary: 'Global reporting templates and indicators for monitoring viral hepatitis elimination programs. (Dummy Data for clinical presentation purposes).',
      sourceUrl: 'https://www.who.int',
      vancouverReference: 'World Health Organization. WHO Viral Hepatitis Indicators. Geneva: WHO; 2022.',
      fileUrl: null,
      fileName: null,
      fileType: null,
      fileSize: null,
      addedBy: 'mock-editor-id',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now(),
    ),
    ReferenceModel(
      id: 'r1000000-0000-0000-0000-000000000005',
      title: 'Laboratory Turnaround Time Policy',
      titleAr: 'سياسة وقت الاستجابة للفحوصات المخبرية',
      organization: 'National Public Health Laboratory',
      referenceType: 'Policy',
      categoryId: 'c1000000-0000-0000-0000-000000000007',
      publicationYear: 2024,
      language: 'en',
      summary: 'Standard operating procedures defining acceptable time limits for reporting disease notification results. (Dummy Data for clinical presentation purposes).',
      sourceUrl: 'https://www.nphl.gov.sa',
      vancouverReference: 'National Public Health Laboratory. Laboratory Turnaround Time Policy. Riyadh: NPHL; 2024.',
      fileUrl: 'https://example.com/mock_lab_tat_policy.xlsx',
      fileName: 'lab_turnaround_time_policy.xlsx',
      fileType: 'xlsx',
      fileSize: 850000,
      addedBy: 'mock-admin-id',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now(),
    )
  ];

  final List<String> _mockFavorites = [
    'r1000000-0000-0000-0000-000000000001',
    'r1000000-0000-0000-0000-000000000003'
  ];

  @override
  Future<List<ReferenceModel>> getReferences({
    String? query,
    String? categoryId,
    String? type,
    int? year,
    String? language,
    bool? onlyFavorites,
    String? sortBy,
    String? currentUserId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    Iterable<ReferenceModel> list = _mockReferences.where((r) => r.isActive);

    if (onlyFavorites == true) {
      list = list.where((r) => _mockFavorites.contains(r.id));
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      list = list.where((r) => r.categoryId == categoryId);
    }
    if (type != null && type.isNotEmpty) {
      list = list.where((r) => r.referenceType == type);
    }
    if (year != null) {
      list = list.where((r) => r.publicationYear == year);
    }
    if (language != null && language.isNotEmpty) {
      list = list.where((r) => r.language == language);
    }

    if (query != null && query.trim().isNotEmpty) {
      final term = query.trim().toLowerCase();
      list = list.where((r) =>
          r.title.toLowerCase().contains(term) ||
          (r.titleAr?.toLowerCase().contains(term) ?? false) ||
          r.organization.toLowerCase().contains(term) ||
          (r.summary?.toLowerCase().contains(term) ?? false));
    }

    final result = list.toList();
    
    // Sort
    if (sortBy != null) {
      if (sortBy == 'newest') {
        result.sort((a, b) => b.publicationYear.compareTo(a.publicationYear));
      } else if (sortBy == 'oldest') {
        result.sort((a, b) => a.publicationYear.compareTo(b.publicationYear));
      } else if (sortBy == 'alphabetical') {
        result.sort((a, b) => a.title.compareTo(b.title));
      }
    }

    return result;
  }

  @override
  Future<ReferenceModel?> getReferenceById(String id) async {
    return _mockReferences.firstWhere((r) => r.id == id);
  }

  @override
  Future<ReferenceModel> addReference(
    ReferenceModel reference, {
    PlatformFile? file,
    Function(double progress)? onProgress,
  }) async {
    if (file != null) {
      for (double p = 0.1; p <= 1.0; p += 0.3) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (onProgress != null) onProgress(p > 1.0 ? 1.0 : p);
      }
    }

    final newRef = reference.copyWith(
      id: 'ref-${DateTime.now().millisecondsSinceEpoch}',
      fileUrl: file != null ? 'https://example.com/mock_uploaded_${file.name}' : null,
      fileName: file?.name,
      fileType: file?.extension,
      fileSize: file?.size,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _mockReferences.insert(0, newRef);
    return newRef;
  }

  @override
  Future<void> bulkAddReferences(List<ReferenceModel> references) async {
    for (var ref in references) {
      final newRef = ref.copyWith(
        id: 'ref-${DateTime.now().millisecondsSinceEpoch}-${_mockReferences.length}',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _mockReferences.insert(0, newRef);
    }
  }

  @override
  Future<ReferenceModel> updateReference(ReferenceModel reference) async {
    final index = _mockReferences.indexWhere((r) => r.id == reference.id);
    if (index != -1) {
      final updated = reference.copyWith(updatedAt: DateTime.now());
      _mockReferences[index] = updated;
      return updated;
    }
    return reference;
  }

  @override
  Future<void> archiveReference(String id) async {
    final index = _mockReferences.indexWhere((r) => r.id == id);
    if (index != -1) {
      _mockReferences[index] = _mockReferences[index].copyWith(isActive: false);
    }
  }

  @override
  Future<void> incrementUsageCount(String id) async {}

  @override
  Future<List<ReferenceModel>> getRecentReferences({int limit = 5}) async {
    return _mockReferences.where((r) => r.isActive).take(limit).toList();
  }

  @override
  Future<List<ReferenceModel>> getMostUsedReferences({int limit = 5}) async {
    return _mockReferences.where((r) => r.isActive).take(limit).toList();
  }
}

final referenceRepositoryProvider = Provider<ReferenceRepository>((ref) {
  final isMock = ref.watch(isMockModeProvider);
  if (isMock) {
    return MockReferenceRepository();
  } else {
    final sb = ref.watch(supabaseServiceProvider);
    return SupabaseReferenceRepository(sb);
  }
});
