import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/category_model.dart';

abstract class CategoryRepository {
  Future<List<CategoryModel>> getCategories();
  Future<CategoryModel> addCategory(String nameEn, String nameAr, String icon, String color);
}

class SupabaseCategoryRepository implements CategoryRepository {
  final SupabaseService _sb;

  SupabaseCategoryRepository(this._sb);

  @override
  Future<List<CategoryModel>> getCategories() async {
    final response = await _sb.client
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('name_en');
    return (response as List).map((c) => CategoryModel.fromJson(c)).toList();
  }

  @override
  Future<CategoryModel> addCategory(String nameEn, String nameAr, String icon, String color) async {
    final response = await _sb.client.from('categories').insert({
      'name_en': nameEn,
      'name_ar': nameAr,
      'icon': icon,
      'color': color,
    }).select().single();
    return CategoryModel.fromJson(response);
  }
}

class MockCategoryRepository implements CategoryRepository {
  final List<CategoryModel> _mockCategories = [
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000001',
      nameEn: 'Hepatitis B',
      nameAr: 'التهاب الكبد ب',
      icon: 'coronavirus',
      color: '#00796B',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000002',
      nameEn: 'Hepatitis C',
      nameAr: 'التهاب الكبد ج',
      icon: 'coronavirus',
      color: '#009688',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000003',
      nameEn: 'HIV',
      nameAr: 'فيروس نقص المناعة البشرية',
      icon: 'medical_services',
      color: '#D32F2F',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000004',
      nameEn: 'Syphilis',
      nameAr: 'الزهري',
      icon: 'healing',
      color: '#E91E63',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000005',
      nameEn: 'Epidemiological Definitions',
      nameAr: 'التعريفات الوبائية',
      icon: 'menu_book',
      color: '#3F51B5',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000006',
      nameEn: 'Surveillance',
      nameAr: 'الترصد الوبائي',
      icon: 'query_stats',
      color: '#673AB7',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000007',
      nameEn: 'Laboratory',
      nameAr: 'المختبر',
      icon: 'science',
      color: '#00BCD4',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000008',
      nameEn: 'Screening',
      nameAr: 'الفحص والتقصي',
      icon: 'person_search',
      color: '#4CAF50',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000009',
      nameEn: 'Treatment',
      nameAr: 'العلاج والمتابعة',
      icon: 'medication',
      color: '#8BC34A',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000010',
      nameEn: 'Contact Tracing',
      nameAr: 'تقصي المخالطين',
      icon: 'people',
      color: '#FF9800',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000011',
      nameEn: 'High-Risk Populations',
      nameAr: 'الفئات الأكثر عرضة',
      icon: 'groups',
      color: '#795548',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000012',
      nameEn: 'WHO Indicators',
      nameAr: 'مؤشرات منظمة الصحة العالمية',
      icon: 'analytics',
      color: '#2196F3',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000013',
      nameEn: 'Ministry Circulars',
      nameAr: 'التعاميم الوزارية',
      icon: 'description',
      color: '#607D8B',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000014',
      nameEn: 'Policies and Procedures',
      nameAr: 'السياسات والإجراءات',
      icon: 'rule',
      color: '#455A64',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'c1000000-0000-0000-0000-000000000015',
      nameEn: 'Statistical Reports',
      nameAr: 'التقارير الإحصائية',
      icon: 'poll',
      color: '#E65100',
      isActive: true,
      createdAt: DateTime.now(),
    )
  ];

  @override
  Future<List<CategoryModel>> getCategories() async {
    return _mockCategories;
  }

  @override
  Future<CategoryModel> addCategory(String nameEn, String nameAr, String icon, String color) async {
    final cat = CategoryModel(
      id: 'cat-${DateTime.now().millisecondsSinceEpoch}',
      nameEn: nameEn,
      nameAr: nameAr,
      icon: icon,
      color: color,
      isActive: true,
      createdAt: DateTime.now(),
    );
    _mockCategories.add(cat);
    return cat;
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final isMock = ref.watch(isMockModeProvider);
  if (isMock) {
    return MockCategoryRepository();
  } else {
    final sb = ref.watch(supabaseServiceProvider);
    return SupabaseCategoryRepository(sb);
  }
});

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getCategories();
});
