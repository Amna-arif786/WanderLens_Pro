class Like {
  final String id;
  final String postId;
  final String userId;
  final DateTime createdAt;

  Like({
    required this.id,
    required this.postId,
    required this.userId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Like.fromJson(Map<String, dynamic> json) {
    return Like(
      id: json['id'] ?? '',
      postId: json['postId'] ?? '',
      userId: json['userId'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Like copyWith({
    String? id,
    String? postId,
    String? userId,
    DateTime? createdAt,
  }) {
    return Like(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}