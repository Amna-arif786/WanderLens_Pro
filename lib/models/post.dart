import 'package:cloud_firestore/cloud_firestore.dart';

enum PostPrivacy { public, private, friends }

/// Moderation status assigned by the AI verification pipeline.
///
///   approved  – passed AI check; visible in the public feed.
///   pending   – AI was uncertain; waiting for admin review.
///   rejected  – failed moderation; image deleted from Cloudinary.
enum PostStatus { approved, pending, rejected }

class Post {
  final String id;
  final String userId;
  final String? username;
  final String? userDisplayName;
  final String? userProfileImage;
  final String imageUrl;

  /// Cloudinary public_id — needed for server-side deletion.
  final String? cloudinaryPublicId;

  final String caption;
  final String location;
  final String cityName;
  final double? latitude;
  final double? longitude;
  final PostPrivacy privacy;
  final bool isVerified;
  final PostStatus status;

  /// AI verification metadata — stored so admin panel can see WHY a post is
  /// pending and what the AI detected.
  final double aiConfidenceScore;
  final List<String> aiDetectedLabels;
  final String aiVerificationSource;

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
    this.cloudinaryPublicId,
    required this.caption,
    required this.location,
    required this.cityName,
    this.latitude,
    this.longitude,
    this.privacy = PostPrivacy.public,
    this.isVerified = false,
    this.status = PostStatus.pending,
    this.aiConfidenceScore = 0.0,
    this.aiDetectedLabels = const [],
    this.aiVerificationSource = 'none',
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
      'cloudinaryPublicId': cloudinaryPublicId,
      'caption': caption,
      'description': caption,
      'location': location,
      'cityName': cityName,
      'latitude': latitude,
      'longitude': longitude,
      'privacy': privacy.name,
      'isVerified': isVerified,
      'status': status.name,
      'aiConfidenceScore': aiConfidenceScore,
      'aiDetectedLabels': aiDetectedLabels,
      'aiVerificationSource': aiVerificationSource,
      // Aliases for external admin panel compatibility
      'publicId': cloudinaryPublicId,
      'public_id': cloudinaryPublicId,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'saveCount': saveCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.parse(date);
      return DateTime.now();
    }

    return Post(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'],
      userDisplayName: json['userDisplayName'],
      userProfileImage: json['userProfileImage'],
      imageUrl: json['imageUrl'] ?? '',
      cloudinaryPublicId: json['cloudinaryPublicId'],
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
      // Posts created before the moderation system have no 'status' field.
      // Treat them as approved so they appear in the feed.
      status: PostStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PostStatus.approved,
      ),
      aiConfidenceScore: (json['aiConfidenceScore'] as num?)?.toDouble() ?? 0.0,
      aiDetectedLabels: (json['aiDetectedLabels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      aiVerificationSource: json['aiVerificationSource'] as String? ?? 'none',
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
    String? cloudinaryPublicId,
    String? caption,
    String? location,
    String? cityName,
    double? latitude,
    double? longitude,
    PostPrivacy? privacy,
    bool? isVerified,
    PostStatus? status,
    double? aiConfidenceScore,
    List<String>? aiDetectedLabels,
    String? aiVerificationSource,
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
      cloudinaryPublicId: cloudinaryPublicId ?? this.cloudinaryPublicId,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      cityName: cityName ?? this.cityName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      privacy: privacy ?? this.privacy,
      isVerified: isVerified ?? this.isVerified,
      status: status ?? this.status,
      aiConfidenceScore: aiConfidenceScore ?? this.aiConfidenceScore,
      aiDetectedLabels: aiDetectedLabels ?? this.aiDetectedLabels,
      aiVerificationSource: aiVerificationSource ?? this.aiVerificationSource,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      saveCount: saveCount ?? this.saveCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
