class UserFriend {
  final String id;
  final String userId;
  final String friendId;
  final DateTime createdAt;

  UserFriend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'friendId': friendId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserFriend.fromJson(Map<String, dynamic> json) {
    return UserFriend(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      friendId: json['friendId'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  UserFriend copyWith({
    String? id,
    String? userId,
    String? friendId,
    DateTime? createdAt,
  }) {
    return UserFriend(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      friendId: friendId ?? this.friendId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}