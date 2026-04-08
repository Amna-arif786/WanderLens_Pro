import 'dart:typed_data';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryProfileService {
  static final String _cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static final String _uploadPreset = dotenv.env['CLOUDINARY_PROFILE_UPLOAD_PRESET'] ?? ''; 

  static final CloudinaryPublic _cloudinary = CloudinaryPublic(
    _cloudName,
    _uploadPreset,
    cache: false,
  );

  /// Uploads a profile picture using BYTES (Works on Web and Mobile)
  static Future<String> uploadProfilePictureFromBytes(Uint8List imageBytes) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          imageBytes,
          folder: 'user_profiles',
          resourceType: CloudinaryResourceType.Image,
          // Identifier is usually the filename or a unique string
          identifier: 'profile_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      return response.secureUrl;
    } on CloudinaryException catch (e) {
      throw Exception('Cloudinary Error: ${e.message}');
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  static Future<void> deleteOldImage(String? oldUrl) async {
    if (oldUrl == null || oldUrl.isEmpty) return;
    final publicId = getPublicIdFromUrl(oldUrl);
    if (publicId == null) return;

    final String functionUrl = 'https://us-central1-wanderlense-pc.cloudfunctions.net/deleteCloudinaryImage';

    try {
      await http.post(
        Uri.parse(functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'publicId': publicId}),
      );
    } catch (e) {
      // Log error internally in dev
    }
  }
  
  static String? getPublicIdFromUrl(String url) {
    try {
      if (!url.contains('user_profiles')) return null;
      final uri = Uri.parse(url);
      final parts = uri.pathSegments;
      final fileSegment = parts.last;
      final publicIdWithoutExtension = fileSegment.substring(0, fileSegment.lastIndexOf('.'));
      return 'user_profiles/$publicIdWithoutExtension';
    } catch (e) {
      return null;
    }
  }
}
