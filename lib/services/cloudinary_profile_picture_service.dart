import 'dart:convert';
import 'dart:typed_data';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:wanderlens/storage/cloudinary_service.dart';

class CloudinaryProfileService {
  static final String _cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static final String _profileUploadPreset =
      dotenv.env['CLOUDINARY_PROFILE_UPLOAD_PRESET'] ?? '';

  static CloudinaryPublic? get _legacyCloudinary {
    if (_cloudName.isEmpty || _profileUploadPreset.isEmpty) return null;
    return CloudinaryPublic(
      _cloudName,
      _profileUploadPreset,
      cache: false,
    );
  }

  /// Uploads a profile picture using BYTES (Web & Mobile).
  ///
  /// Uses the same signed [CLOUDINARY_UPLOAD_PRESET] flow as post uploads first
  /// (fixes failures when only posts were configured). Optionally falls back to
  /// [CLOUDINARY_PROFILE_UPLOAD_PRESET] via cloudinary_public.
  static Future<String> uploadProfilePictureFromBytes(Uint8List imageBytes) async {
    final primary = await CloudinaryService.uploadProfileImageFromBytes(imageBytes);
    if (primary != null &&
        primary.secureUrl.isNotEmpty) {
      return primary.secureUrl;
    }

    final legacy = _legacyCloudinary;
    if (legacy != null) {
      try {
        final response = await legacy.uploadFile(
          CloudinaryFile.fromBytesData(
            imageBytes,
            folder: 'user_profiles',
            resourceType: CloudinaryResourceType.Image,
            identifier: 'profile_${DateTime.now().millisecondsSinceEpoch}',
          ),
        );
        return response.secureUrl;
      } on CloudinaryException catch (e) {
        throw Exception('Cloudinary Error: ${e.message}');
      }
    }

    throw Exception(
      'Profile upload failed. Add CLOUDINARY_CLOUD_NAME and '
      'CLOUDINARY_UPLOAD_PRESET to .env (same as post uploads), or set '
      'CLOUDINARY_PROFILE_UPLOAD_PRESET for an unsigned profile preset.',
    );
  }

  static Future<void> deleteOldImage(String? oldUrl) async {
    if (oldUrl == null || oldUrl.isEmpty) return;

    final publicId =
        CloudinaryService.extractPublicId(oldUrl) ?? getPublicIdFromUrl(oldUrl);
    if (publicId == null || publicId.isEmpty) return;

    if (await CloudinaryService.deleteImage(publicId)) return;

    const functionUrl =
        'https://us-central1-wanderlense-pc.cloudfunctions.net/deleteCloudinaryImage';
    try {
      await http.post(
        Uri.parse(functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'publicId': publicId}),
      );
    } catch (_) {}
  }

  /// Narrow parser for older URLs stored as `user_profiles/...` only.
  static String? getPublicIdFromUrl(String url) {
    try {
      if (!url.contains('user_profiles')) return null;
      final uri = Uri.parse(url);
      final parts = uri.pathSegments;
      final fileSegment = parts.last;
      final publicIdWithoutExtension =
          fileSegment.substring(0, fileSegment.lastIndexOf('.'));
      return 'user_profiles/$publicIdWithoutExtension';
    } catch (e) {
      return null;
    }
  }
}
