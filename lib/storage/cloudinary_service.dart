import 'dart:convert';
import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// A single AI tag returned by Cloudinary's Google Auto Tagging add-on.
class CloudinaryTag {
  const CloudinaryTag({required this.tag, required this.confidence});
  final String tag;
  final double confidence;
}

/// Holds the secure URL, public_id, and any AI analysis data returned by
/// Cloudinary's add-ons (Google Auto Tagging + Rekognition Face Detection).
class CloudinaryUploadResult {
  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    this.aiTags = const [],
    this.faceCount = 0,
  });
  final String secureUrl;
  final String publicId;

  /// Labels from Cloudinary's Google Auto Tagging add-on (free: 50/month).
  /// Empty when the add-on is not enabled or returned no data.
  final List<CloudinaryTag> aiTags;

  /// Number of faces detected by Cloudinary's Rekognition add-on (free: 50/month).
  final int faceCount;
}

class CloudinaryService {
  static final _cloudinary = CloudinaryPublic(
    dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '',
    dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '',
    cache: false,
  );

  // ── Upload helpers ────────────────────────────────────────────────────────

  /// Uploads a profile picture. Returns the secure URL (profile images are
  /// not deleted programmatically, so we only need the URL here).
  static Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path, folder: 'profiles'),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint('Cloudinary profile upload error: $e');
      return null;
    }
  }

  /// Uploads a post image using a signed request (required for signed presets).
  ///
  /// Signature covers only: folder + timestamp + upload_preset.
  /// AI add-ons (google_tagging, rekognition_face) configured inside the
  /// Cloudinary preset run automatically — no need to pass them explicitly.
  ///
  /// Falls back to unsigned upload if credentials are missing (dev/testing).
  static Future<CloudinaryUploadResult?> uploadPostImageFromBytes(
      Uint8List bytes) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return _uploadImageFromBytes(
      bytes,
      folder: 'posts',
      filename: 'post_$ts.jpg',
      categorization: 'google_tagging',
    );
  }

  /// Profile photo upload — same signing flow as posts so it works when
  /// [CLOUDINARY_UPLOAD_PRESET] is signed and [CLOUDINARY_PROFILE_UPLOAD_PRESET]
  /// was never added to `.env`.
  ///
  /// Tries folder `user_profiles` first; if that fails (preset locked to
  /// `posts`), retries under `posts` with a `profile_` filename.
  static Future<CloudinaryUploadResult?> uploadProfileImageFromBytes(
      Uint8List bytes) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final primary = await _uploadImageFromBytes(
      bytes,
      folder: 'user_profiles',
      filename: 'profile_$ts.jpg',
    );
    if (primary != null &&
        primary.secureUrl.isNotEmpty &&
        primary.publicId.isNotEmpty) {
      return primary;
    }
    debugPrint(
        'Cloudinary: profile upload to user_profiles failed, retrying folder=posts');
    return _uploadImageFromBytes(
      bytes,
      folder: 'posts',
      filename: 'profile_$ts.jpg',
    );
  }

  static Future<CloudinaryUploadResult?> _uploadImageFromBytes(
    Uint8List bytes, {
    required String folder,
    required String filename,
    String? categorization,
  }) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
    final apiKey = dotenv.env['CLOUDINARY_API_KEY'] ?? '';
    final apiSecret = dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

    if (cloudName.isEmpty || uploadPreset.isEmpty) {
      debugPrint('Cloudinary: missing CLOUDINARY_CLOUD_NAME or UPLOAD_PRESET');
      return null;
    }

    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    // ── Signed upload (required when preset is "signed") ──────────────────
    if (apiKey.isNotEmpty && apiSecret.isNotEmpty) {
      try {
        final timestamp =
            (DateTime.now().millisecondsSinceEpoch / 1000).round().toString();

        // Sign only the fields we actually send (sorted A→Z, no file/api_key/signature)
        final fieldsToSign = <String, String>{
          'folder': folder,
          'timestamp': timestamp,
          'upload_preset': uploadPreset,
          if (categorization != null && categorization.isNotEmpty)
            'categorization': categorization,
        };

        final sortedKeys = fieldsToSign.keys.toList()..sort();
        final signedPayload = sortedKeys.map((k) => '$k=${fieldsToSign[k]}').join('&');
        final toSign = '$signedPayload$apiSecret';

        final signature = sha256.convert(utf8.encode(toSign)).toString();

        final req = http.MultipartRequest('POST', uri);
        req.fields.addAll(fieldsToSign);
        req.fields['api_key'] = apiKey;
        req.fields['signature'] = signature;
        req.files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename));

        final streamed =
            await req.send().timeout(const Duration(seconds: 60));
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode == 200) {
          final result = _parseUploadResponse(response.body);
          debugPrint('Cloudinary signed upload OK — folder=$folder');
          return result;
        }

        debugPrint('Cloudinary signed upload failed '
            '(${response.statusCode}): ${response.body}');
      } catch (e) {
        debugPrint('Cloudinary signed upload error: $e');
      }
    }

    // ── Unsigned fallback (unsigned presets / dev mode) ───────────────────
    try {
      final req = http.MultipartRequest('POST', uri);
      req.fields['upload_preset'] = uploadPreset;
      req.fields['folder'] = folder;
      if (categorization != null && categorization.isNotEmpty) {
        req.fields['categorization'] = categorization;
      }
      req.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename));

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final result = _parseUploadResponse(response.body);
        debugPrint('Cloudinary unsigned upload OK — folder=$folder');
        return result;
      }

      debugPrint('Cloudinary upload failed '
          '(${response.statusCode}): ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    }
  }

  /// Parses a Cloudinary upload response, extracting AI tags from all
  /// known add-on sources: google_tagging, aws_rek_tagging, plus flat tags[].
  static CloudinaryUploadResult _parseUploadResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final secureUrl = json['secure_url'] as String? ?? '';
      final publicId = json['public_id'] as String? ?? '';

      final info = json['info'] as Map<String, dynamic>?;
      final categorization =
          info?['categorization'] as Map<String, dynamic>?;

      // Try each categorization source in priority order
      List<CloudinaryTag> aiTags = [];
      for (final source in [
        'google_tagging',
        'aws_rek_tagging',
        'cld-autotagging',
      ]) {
        final data = (categorization?[source]
                as Map<String, dynamic>?)?['data'] as List<dynamic>?;
        if (data != null && data.isNotEmpty) {
          aiTags = data.map((t) {
            final m = t as Map<String, dynamic>;
            return CloudinaryTag(
              tag: (m['tag'] as String? ?? '').toLowerCase().trim(),
              confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
            );
          }).where((t) => t.tag.isNotEmpty).toList();
          debugPrint('AI tags from "$source": ${aiTags.map((t) => '${t.tag}(${t.confidence.toStringAsFixed(2)})').join(', ')}');
          break;
        }
      }

      // Fallback: flat tags[] array (no confidence score — assign 0.80)
      if (aiTags.isEmpty) {
        final flatTags = (json['tags'] as List<dynamic>?) ?? [];
        aiTags = flatTags
            .map((t) => CloudinaryTag(
                  tag: (t as String? ?? '').toLowerCase().trim(),
                  confidence: 0.80,
                ))
            .where((t) => t.tag.isNotEmpty)
            .toList();
        if (aiTags.isNotEmpty) {
          debugPrint('AI tags from flat tags[]: ${aiTags.map((t) => t.tag).join(', ')}');
        }
      }

      // Face count from Rekognition
      final faces = ((info?['detection'] as Map<String, dynamic>?)
                  ?['rekognition_face'] as Map<String, dynamic>?)
              ?['data']?['faces'] as List<dynamic>? ??
          [];

      return CloudinaryUploadResult(
        secureUrl: secureUrl,
        publicId: publicId,
        aiTags: aiTags,
        faceCount: faces.length,
      );
    } catch (e) {
      debugPrint('Cloudinary response parse error: $e');
      // Return bare result with URLs only
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return CloudinaryUploadResult(
          secureUrl: json['secure_url'] as String? ?? '',
          publicId: json['public_id'] as String? ?? '',
        );
      } catch (_) {
        return const CloudinaryUploadResult(secureUrl: '', publicId: '');
      }
    }
  }

  /// Uploads a post image from a File (mobile only).
  static Future<CloudinaryUploadResult?> uploadPostImage(
      File imageFile) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path, folder: 'posts'),
      );
      return CloudinaryUploadResult(
        secureUrl: response.secureUrl,
        publicId: response.publicId,
      );
    } catch (e) {
      debugPrint('Cloudinary post upload error: $e');
      return null;
    }
  }

  // ── Delete helper (used by admin reject) ─────────────────────────────────

  /// Permanently deletes an image from Cloudinary using a signed API request.
  ///
  /// Requires [CLOUDINARY_API_KEY] and [CLOUDINARY_API_SECRET] in .env.
  /// Returns true if the deletion was acknowledged by Cloudinary.
  static Future<bool> deleteImage(String publicId) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
    final apiKey = dotenv.env['CLOUDINARY_API_KEY'] ?? '';
    final apiSecret = dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

    if (cloudName.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) {
      debugPrint('Cloudinary delete skipped: API key/secret not configured.');
      return false;
    }

    try {
      final timestamp =
          (DateTime.now().millisecondsSinceEpoch / 1000).round().toString();

      // Signature: SHA-256(public_id={id}&timestamp={ts}{api_secret})
      final toSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
      final signature =
          sha256.convert(utf8.encode(toSign)).toString();

      final response = await http.post(
        Uri.parse(
            'https://api.cloudinary.com/v1_1/$cloudName/image/destroy'),
        body: {
          'public_id': publicId,
          'api_key': apiKey,
          'timestamp': timestamp,
          'signature': signature,
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['result'] == 'ok';
      }
      return false;
    } catch (e) {
      debugPrint('Cloudinary delete error: $e');
      return false;
    }
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  /// Extracts the Cloudinary public_id from a full secure URL.
  ///
  /// Example:
  ///   https://res.cloudinary.com/cloud/image/upload/v123/posts/file.jpg
  ///   → posts/file
  static String? extractPublicId(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final uri = Uri.parse(imageUrl);
      final parts = uri.pathSegments;
      final uploadIdx = parts.indexOf('upload');
      if (uploadIdx == -1) return null;

      // Skip 'upload' and the version segment (starts with 'v' + digits)
      var start = uploadIdx + 1;
      if (start < parts.length &&
          RegExp(r'^v\d+$').hasMatch(parts[start])) {
        start++;
      }

      final remaining = parts.sublist(start);
      if (remaining.isEmpty) return null;

      // Strip file extension from last segment
      final last = remaining.last;
      final lastNoExt =
          last.contains('.') ? last.substring(0, last.lastIndexOf('.')) : last;

      return [
        ...remaining.sublist(0, remaining.length - 1),
        lastNoExt,
      ].join('/');
    } catch (_) {
      return null;
    }
  }
}
