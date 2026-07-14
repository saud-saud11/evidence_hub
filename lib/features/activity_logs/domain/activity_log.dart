class ActivityLog {
  final String id;
  final String? userId;
  final String action;
  final String? entityType;
  final String? entityId;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  ActivityLog({
    required this.id,
    this.userId,
    required this.action,
    this.entityType,
    this.entityId,
    required this.description,
    this.metadata,
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      action: json['action'] as String,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      description: json['description'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'description': description,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
