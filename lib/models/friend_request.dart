enum FriendRequestStatus { pending, accepted, rejected }

class FriendRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.status = FriendRequestStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      receiverId: json['receiverId'] ?? '',
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  FriendRequest copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    FriendRequestStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}