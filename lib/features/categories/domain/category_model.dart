class CategoryModel {
  final String id;
  final String nameEn;
  final String nameAr;
  final String? icon;
  final String? color;
  final bool isActive;
  final DateTime createdAt;

  CategoryModel({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    this.icon,
    this.color,
    required this.isActive,
    required this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_en': nameEn,
      'name_ar': nameAr,
      'icon': icon,
      'color': color,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
