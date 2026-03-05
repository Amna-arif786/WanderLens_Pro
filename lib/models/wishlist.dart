class Wishlist {
  final String id;
  final String userId;
  final String postId;
  final DateTime createdAt;

  Wishlist({
    required this.id,
    required this.userId,
    required this.postId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'postId': postId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Wishlist.fromJson(Map<String, dynamic> json) {
    return Wishlist(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      postId: json['postId'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Wishlist copyWith({
    String? id,
    String? userId,
    String? postId,
    DateTime? createdAt,
  }) {
    return Wishlist(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      postId: postId ?? this.postId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}