class ReferenceModel {
  final String id;
  final String title;
  final String? titleAr;
  final String organization;
  final String referenceType;
  final String? categoryId;
  final int publicationYear;
  final String language;
  final String? summary;
  final String? sourceUrl;
  final String? vancouverReference;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final int? fileSize;
  final String? addedBy;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReferenceModel({
    required this.id,
    required this.title,
    this.titleAr,
    required this.organization,
    required this.referenceType,
    this.categoryId,
    required this.publicationYear,
    required this.language,
    this.summary,
    this.sourceUrl,
    this.vancouverReference,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.fileSize,
    this.addedBy,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReferenceModel.fromJson(Map<String, dynamic> json) {
    return ReferenceModel(
      id: json['id'] as String,
      title: json['title'] as String,
      titleAr: json['title_ar'] as String?,
      organization: json['organization'] as String,
      referenceType: json['reference_type'] as String,
      categoryId: json['category_id'] as String?,
      publicationYear: json['publication_year'] as int,
      language: json['language'] as String? ?? 'en',
      summary: json['summary'] as String?,
      sourceUrl: json['source_url'] as String?,
      vancouverReference: json['vancouver_reference'] as String?,
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      fileType: json['file_type'] as String?,
      fileSize: json['file_size'] as int?,
      addedBy: json['added_by'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'title_ar': titleAr,
      'organization': organization,
      'reference_type': referenceType,
      'category_id': categoryId,
      'publication_year': publicationYear,
      'language': language,
      'summary': summary,
      'source_url': sourceUrl,
      'vancouver_reference': vancouverReference,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
      'added_by': addedBy,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ReferenceModel copyWith({
    String? id,
    String? title,
    String? titleAr,
    String? organization,
    String? referenceType,
    String? categoryId,
    int? publicationYear,
    String? language,
    String? summary,
    String? sourceUrl,
    String? vancouverReference,
    String? fileUrl,
    String? fileName,
    String? fileType,
    int? fileSize,
    String? addedBy,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReferenceModel(
      id: id ?? this.id,
      title: title ?? this.title,
      titleAr: titleAr ?? this.titleAr,
      organization: organization ?? this.organization,
      referenceType: referenceType ?? this.referenceType,
      categoryId: categoryId ?? this.categoryId,
      publicationYear: publicationYear ?? this.publicationYear,
      language: language ?? this.language,
      summary: summary ?? this.summary,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      vancouverReference: vancouverReference ?? this.vancouverReference,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      addedBy: addedBy ?? this.addedBy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
