class EvidenceSnippet {
  final String id;
  final String referenceId;
  final String title;
  final String? titleAr;
  final String evidenceText;
  final int? pageNumber;
  final String? sectionName;
  final String? categoryId;
  final List<String> keywords;
  final String? notes;
  final String? addedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  EvidenceSnippet({
    required this.id,
    required this.referenceId,
    required this.title,
    this.titleAr,
    required this.evidenceText,
    this.pageNumber,
    this.sectionName,
    this.categoryId,
    required this.keywords,
    this.notes,
    this.addedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EvidenceSnippet.fromJson(Map<String, dynamic> json) {
    return EvidenceSnippet(
      id: json['id'] as String,
      referenceId: json['reference_id'] as String,
      title: json['title'] as String,
      titleAr: json['title_ar'] as String?,
      evidenceText: json['evidence_text'] as String,
      pageNumber: json['page_number'] as int?,
      sectionName: json['section_name'] as String?,
      categoryId: json['category_id'] as String?,
      keywords: List<String>.from(json['keywords'] ?? []),
      notes: json['notes'] as String?,
      addedBy: json['added_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference_id': referenceId,
      'title': title,
      'title_ar': titleAr,
      'evidence_text': evidenceText,
      'page_number': pageNumber,
      'section_name': sectionName,
      'category_id': categoryId,
      'keywords': keywords,
      'notes': notes,
      'added_by': addedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
