class User {
  final String id;
  final String username;
  final String email;
  final String displayName;
  final String? profileImageUrl;
  final String? bio;
  final String? location;
  final int friendCount;
  final int postCount;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.profileImageUrl,
    this.bio,
    this.location,
    this.friendCount = 0,
    this.postCount = 0,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'location': location,
      'friendCount': friendCount,
      'postCount': postCount,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      bio: json['bio'],
      location: json['location'],
      friendCount: json['friendCount'] ?? 0,
      postCount: json['postCount'] ?? 0,
      isVerified: json['isVerified'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? displayName,
    String? profileImageUrl,
    String? bio,
    String? location,
    int? friendCount,
    int? postCount,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      friendCount: friendCount ?? this.friendCount,
      postCount: postCount ?? this.postCount,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}