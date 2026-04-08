enum NotificationType { like, comment, friendRequest, wishlist }

class NotificationModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String? senderProfilePic;
  final NotificationType type;
  final String? postId;
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    this.senderProfilePic,
    required this.type,
    this.postId,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      receiverId: json['receiverId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderProfilePic: json['senderProfilePic'],
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${json['type']}',
        orElse: () => NotificationType.like,
      ),
      postId: json['postId'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'senderProfilePic': senderProfilePic,
      'type': type.toString().split('.').last,
      'postId': postId,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }
}
