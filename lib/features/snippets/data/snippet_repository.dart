import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/snippet_model.dart';

abstract class SnippetRepository {
  Future<List<EvidenceSnippet>> getSnippetsByReference(String referenceId);
  Future<EvidenceSnippet> addSnippet(EvidenceSnippet snippet);
  Future<EvidenceSnippet> updateSnippet(EvidenceSnippet snippet);
  Future<void> deleteSnippet(String id);
  Future<List<EvidenceSnippet>> searchSnippets(String query);
}

class SupabaseSnippetRepository implements SnippetRepository {
  final SupabaseService _sb;

  SupabaseSnippetRepository(this._sb);

  @override
  Future<List<EvidenceSnippet>> getSnippetsByReference(String referenceId) async {
    final response = await _sb.client
        .from('snippets')
        .select()
        .eq('reference_id', referenceId)
        .order('created_at');
    return (response as List).map((s) => EvidenceSnippet.fromJson(s)).toList();
  }

  @override
  Future<EvidenceSnippet> addSnippet(EvidenceSnippet snippet) async {
    final data = snippet.toJson();
    data.remove('id');
    data.remove('created_at');
    data.remove('updated_at');

    final response = await _sb.client
        .from('snippets')
        .insert(data)
        .select()
        .single();
    return EvidenceSnippet.fromJson(response);
  }

  @override
  Future<EvidenceSnippet> updateSnippet(EvidenceSnippet snippet) async {
    final response = await _sb.client
        .from('snippets')
        .update(snippet.toJson())
        .eq('id', snippet.id)
        .select()
        .single();
    return EvidenceSnippet.fromJson(response);
  }

  @override
  Future<void> deleteSnippet(String id) async {
    await _sb.client
        .from('snippets')
        .delete()
        .eq('id', id);
  }

  @override
  Future<List<EvidenceSnippet>> searchSnippets(String query) async {
    if (query.trim().isEmpty) return [];
    final response = await _sb.client
        .from('snippets')
        .select()
        .textSearch('search_vector', query.trim(), config: 'english');
    return (response as List).map((s) => EvidenceSnippet.fromJson(s)).toList();
  }
}

class MockSnippetRepository implements SnippetRepository {
  final List<EvidenceSnippet> _mockSnippets = [
    // Reference 1 Snippets
    EvidenceSnippet(
      id: 's1000000-0000-0000-0000-000000000001',
      referenceId: 'r1000000-0000-0000-0000-000000000001',
      title: 'Household Contact Screening',
      titleAr: 'فحص المخالطين المنزليين',
      evidenceText: 'All household contacts of a newly diagnosed Hepatitis B case must be screened for HBsAg, anti-HBs, and anti-HBc. Non-immune contacts should receive the HBV vaccine series. (Dummy Data).',
      pageNumber: 12,
      sectionName: 'Chapter 3: Tracing Protocols',
      categoryId: 'c1000000-0000-0000-0000-000000000010',
      keywords: ['hepatitis b', 'screening', 'contacts', 'vaccine'],
      notes: 'Highly recommended to verify vaccine availability before referral.',
      addedBy: 'mock-editor-id',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    EvidenceSnippet(
      id: 's1000000-0000-0000-0000-000000000002',
      referenceId: 'r1000000-0000-0000-0000-000000000001',
      title: 'Infant Post-Exposure Prophylaxis',
      titleAr: 'الوقاية بعد التعرض للرضع',
      evidenceText: 'Infants born to HBsAg-positive mothers must receive HBV vaccine and 0.5 mL of HBIG within 12 hours of birth. Dose 2 and 3 should follow standard schedules. (Dummy Data).',
      pageNumber: 25,
      sectionName: 'Chapter 5: Perinatal Transmission',
      categoryId: 'c1000000-0000-0000-0000-000000000010',
      keywords: ['infant', 'hbig', 'perinatal', 'vaccination'],
      notes: 'Coordinate with delivery rooms directly.',
      addedBy: 'mock-editor-id',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    // Reference 2 Snippets
    EvidenceSnippet(
      id: 's1000000-0000-0000-0000-000000000003',
      referenceId: 'r1000000-0000-0000-0000-000000000002',
      title: 'High-Risk Group Screening Frequency',
      titleAr: 'تكرار الفحص للفئات الأكثر عرضة للخطورة',
      evidenceText: 'Routine screening for Hepatitis C is recommended annually for individuals with history of intravenous drug use, hemodialysis, or occupational exposure. (Dummy Data).',
      pageNumber: 5,
      sectionName: 'Section 2: High-Risk Groups',
      categoryId: 'c1000000-0000-0000-0000-000000000008',
      keywords: ['hepatitis c', 'screening', 'high-risk', 'hemodialysis'],
      notes: 'Confirm screening kits are WHO approved.',
      addedBy: 'mock-editor-id',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    EvidenceSnippet(
      id: 's1000000-0000-0000-0000-000000000004',
      referenceId: 'r1000000-0000-0000-0000-000000000002',
      title: 'Confirmatory PCR Testing',
      titleAr: 'فحص تأكيد الحالات بالـ PCR',
      evidenceText: 'Any specimen reactive to anti-HCV must be followed up with an HCV RNA PCR test to confirm active infection before initiating therapy. (Dummy Data).',
      pageNumber: 9,
      sectionName: 'Section 4: Diagnostic Algorithm',
      categoryId: 'c1000000-0000-0000-0000-000000000008',
      keywords: ['pcr', 'hcv rna', 'confirmatory', 'diagnostics'],
      notes: 'Send samples to the regional laboratory.',
      addedBy: 'mock-editor-id',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    // Reference 3 Snippets
    EvidenceSnippet(
      id: 's1000000-0000-0000-0000-000000000005',
      referenceId: 'r1000000-0000-0000-0000-000000000003',
      title: 'Confirmed Case Definition',
      titleAr: 'تعريف الحالة المؤكدة',
      evidenceText: 'A case is confirmed congenital syphilis when Treponema pallidum is identified by darkfield microscopy, PCR, or special stains in specimens from the placenta, umbilical cord, or autopsy material. (Dummy Data).',
      pageNumber: 2,
      sectionName: 'القسم الأول: تصنيف الحالات',
      categoryId: 'c1000000-0000-0000-0000-000000000005',
      keywords: ['syphilis', 'congenital', 'pcr', 'case definition'],
      notes: 'أهمية الإبلاغ الفوري خلال 24 ساعة من التشخيص.',
      addedBy: 'mock-admin-id',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    EvidenceSnippet(
      id: 's1000000-0000-0000-0000-000000000006',
      referenceId: 'r1000000-0000-0000-0000-000000000003',
      title: 'Probable Case Definition',
      titleAr: 'تعريف الحالة المحتملة',
      evidenceText: 'A case is probable if the infant is born to a mother with untreated or inadequately treated syphilis at delivery, regardless of infant laboratory findings. (Dummy Data).',
      pageNumber: 3,
      sectionName: 'القسم الأول: تصنيف الحالات',
      categoryId: 'c1000000-0000-0000-0000-000000000005',
      keywords: ['syphilis', 'probable case', 'clinical criteria'],
      notes: 'يتطلب المتابعة السريرية لمدة عام كامل.',
      addedBy: 'mock-admin-id',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    // Reference 4 Snippets
    EvidenceSnippet(
      id: 's1000000-0000-0000-0000-000000000007',
      referenceId: 'r1000000-0000-0000-0000-000000000004',
      title: 'Hepatitis B Third Dose Coverage Rate',
      titleAr: 'نسبة تغطية الجرعة الثالثة للقاح الكبد ب',
      evidenceText: 'Indicator definition: Percentage of infants surviving to 1 year who received 3 doses of HepB vaccine. Target goal is >= 90% coverage globally. (Dummy Data).',
      pageNumber: 44,
      sectionName: 'Annex A: Global Core Indicators',
      categoryId: 'c1000000-0000-0000-0000-000000000012',
      keywords: ['who', 'indicators', 'coverage', 'hepatitis b'],
      notes: 'Computed annually from national coverage statistics.',
      addedBy: 'mock-editor-id',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    // Reference 5 Snippets
    EvidenceSnippet(
      id: 's1000000-0000-0000-0000-000000000008',
      referenceId: 'r1000000-0000-0000-0000-000000000005',
      title: 'Standard Turnaround Times',
      titleAr: 'أوقات الاستجابة القياسية للعينات',
      evidenceText: 'Epidemiological priority samples (e.g., suspected Measles, MERS, or Meningitis) must be processed and results reported within 24 hours of sample receipt. (Dummy Data).',
      pageNumber: 7,
      sectionName: 'Policy Statement 1: Timeframes',
      categoryId: 'c1000000-0000-0000-0000-000000000007',
      keywords: ['tat', 'turnaround time', 'laboratory', 'priority'],
      notes: 'Logs must record exact receipt and dispatch times.',
      addedBy: 'mock-admin-id',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    )
  ];

  @override
  Future<List<EvidenceSnippet>> getSnippetsByReference(String referenceId) async {
    return _mockSnippets.where((s) => s.referenceId == referenceId).toList();
  }

  @override
  Future<EvidenceSnippet> addSnippet(EvidenceSnippet snippet) async {
    final newSnippet = EvidenceSnippet(
      id: 'snippet-${DateTime.now().millisecondsSinceEpoch}',
      referenceId: snippet.referenceId,
      title: snippet.title,
      titleAr: snippet.titleAr,
      evidenceText: snippet.evidenceText,
      pageNumber: snippet.pageNumber,
      sectionName: snippet.sectionName,
      categoryId: snippet.categoryId,
      keywords: snippet.keywords,
      notes: snippet.notes,
      addedBy: snippet.addedBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _mockSnippets.add(newSnippet);
    return newSnippet;
  }

  @override
  Future<EvidenceSnippet> updateSnippet(EvidenceSnippet snippet) async {
    final index = _mockSnippets.indexWhere((s) => s.id == snippet.id);
    if (index != -1) {
      final updated = EvidenceSnippet(
        id: snippet.id,
        referenceId: snippet.referenceId,
        title: snippet.title,
        titleAr: snippet.titleAr,
        evidenceText: snippet.evidenceText,
        pageNumber: snippet.pageNumber,
        sectionName: snippet.sectionName,
        categoryId: snippet.categoryId,
        keywords: snippet.keywords,
        notes: snippet.notes,
        addedBy: snippet.addedBy,
        createdAt: _mockSnippets[index].createdAt,
        updatedAt: DateTime.now(),
      );
      _mockSnippets[index] = updated;
      return updated;
    }
    return snippet;
  }

  @override
  Future<void> deleteSnippet(String id) async {
    _mockSnippets.removeWhere((s) => s.id == id);
  }

  @override
  Future<List<EvidenceSnippet>> searchSnippets(String query) async {
    if (query.trim().isEmpty) return [];
    final term = query.trim().toLowerCase();
    return _mockSnippets.where((s) =>
        s.title.toLowerCase().contains(term) ||
        (s.titleAr?.toLowerCase().contains(term) ?? false) ||
        s.evidenceText.toLowerCase().contains(term) ||
        s.keywords.any((k) => k.toLowerCase().contains(term))).toList();
  }
}

final snippetRepositoryProvider = Provider<SnippetRepository>((ref) {
  final sb = ref.watch(supabaseServiceProvider);
  return SupabaseSnippetRepository(sb);
});
