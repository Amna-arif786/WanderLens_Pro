import 'package:cloud_firestore/cloud_firestore.dart';

enum PostPrivacy { public, friends }

class Post {
  final String id;
  final String userId;
  final String? username;
  final String? userDisplayName; // Added for denormalization
  final String? userProfileImage;
  final String imageUrl;
  final String caption;
  final String location;
  final String cityName;
  final double? latitude;
  final double? longitude;
  final PostPrivacy privacy;
  final bool isVerified;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Post({
    required this.id,
    required this.userId,
    this.username,
    this.userDisplayName,
    this.userProfileImage,
    required this.imageUrl,
    required this.caption,
    required this.location,
    required this.cityName,
    this.latitude,
    this.longitude,
    this.privacy = PostPrivacy.public,
    this.isVerified = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.saveCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'userDisplayName': userDisplayName,
      'userProfileImage': userProfileImage,
      'imageUrl': imageUrl,
      'caption': caption,
      'description': caption,
      'location': location,
      'cityName': cityName,
      'latitude': latitude,
      'longitude': longitude,
      'privacy': privacy.name,
      'isVerified': isVerified,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'saveCount': saveCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) {
        return date.toDate();
      } else if (date is String) {
        return DateTime.parse(date);
      } else {
        return DateTime.now();
      }
    }

    return Post(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'],
      userDisplayName: json['userDisplayName'],
      userProfileImage: json['userProfileImage'],
      imageUrl: json['imageUrl'] ?? '',
      caption: json['caption'] ?? json['description'] ?? '',
      location: json['location'] ?? '',
      cityName: json['cityName'] ?? '',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      privacy: PostPrivacy.values.firstWhere(
        (e) => e.name == json['privacy'],
        orElse: () => PostPrivacy.public,
      ),
      isVerified: json['isVerified'] ?? false,
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      saveCount: json['saveCount'] ?? 0,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Post copyWith({
    String? id,
    String? userId,
    String? username,
    String? userDisplayName,
    String? userProfileImage,
    String? imageUrl,
    String? caption,
    String? location,
    String? cityName,
    double? latitude,
    double? longitude,
    PostPrivacy? privacy,
    bool? isVerified,
    int? likeCount,
    int? commentCount,
    int? saveCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      cityName: cityName ?? this.cityName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      privacy: privacy ?? this.privacy,
      isVerified: isVerified ?? this.isVerified,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      saveCount: saveCount ?? this.saveCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
