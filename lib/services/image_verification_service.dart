import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:wanderlens/services/image_verification_config.dart';

// ── Result model ─────────────────────────────────────────────────────────────

enum ImageRejectionReason {
  none,

  /// Recognisable human faces detected — not allowed on WanderLens.
  facesWithoutDestination,

  /// The image does not contain travel / monument / landscape content.
  notATravelDestination,

  /// Cloud Vision SafeSearch flagged adult or violent content.
  inappropriateContent,

  /// The image is a screenshot, graphic, logo or document — not a real photo.
  nonPhotoContent,
}

class ImageVerificationResult {
  const ImageVerificationResult({
    required this.isApproved,
    this.rejectionReason = ImageRejectionReason.none,
    this.detectedLabels = const [],
    this.detectedLandmarks = const [],
    this.facesDetected = false,
  });

  final bool isApproved;
  final ImageRejectionReason rejectionReason;
  final List<String> detectedLabels;
  final List<String> detectedLandmarks;
  final bool facesDetected;

  static const ImageVerificationResult approved =
      ImageVerificationResult(isApproved: true);
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Verification cascade:
///
///   1. Cloud Vision API  (primary — accurate, cloud-based, works on all platforms)
///   2. ML Kit on-device  (fallback — mobile only, works offline / when API is down)
///   3. Fail open         (if both fail, allow the post so users are never stuck)
class ImageVerificationService {
  // ── ML Kit labeler (lazy-initialised, mobile only) ─────────────────────────
  static ImageLabeler? _labeler;

  static ImageLabeler _getLabeler() {
    _labeler ??= ImageLabeler(
      options: ImageLabelerOptions(
        confidenceThreshold: ImageVerificationConfig.mlKitMinConfidence,
      ),
    );
    return _labeler!;
  }

  static void dispose() {
    _labeler?.close();
    _labeler = null;
  }

  // ── Public entry point ────────────────────────────────────────────────────

  static Future<ImageVerificationResult> verifyPostImage(
    Uint8List imageBytes,
    String locationName,
  ) async {
    // ── Tier 1: Cloud Vision API ─────────────────────────────────────────────
    final apiKey = dotenv.env['CLOUD_VISION_API_KEY'] ?? '';
    if (apiKey.isNotEmpty) {
      try {
        final result = await _verifyWithCloudVision(imageBytes, apiKey);
        return result;
      } catch (_) {
        // Cloud Vision failed (network/timeout/parse) → fall through to ML Kit
      }
    }

    // ── Tier 2: ML Kit on-device (mobile only) ───────────────────────────────
    if (!kIsWeb) {
      try {
        return await _verifyWithMlKit(imageBytes);
      } catch (_) {
        // ML Kit failed → fall through to open pass
      }
    }

    // ── Tier 3: Fail open ────────────────────────────────────────────────────
    // Neither service was available. Allow the post so users are never
    // permanently blocked by an infrastructure or connectivity issue.
    return ImageVerificationResult.approved;
  }

  // ── Tier 1: Cloud Vision API ──────────────────────────────────────────────

  static Future<ImageVerificationResult> _verifyWithCloudVision(
    Uint8List imageBytes,
    String apiKey,
  ) async {
    final response = await http
        .post(
          Uri.parse(
              'https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'requests': [
              {
                'image': {'content': base64Encode(imageBytes)},
                'features': [
                  {'type': 'LANDMARK_DETECTION', 'maxResults': 5},
                  {'type': 'LABEL_DETECTION', 'maxResults': 20},
                  {'type': 'FACE_DETECTION', 'maxResults': 5},
                  {'type': 'SAFE_SEARCH_DETECTION'},
                  // TEXT_DETECTION catches cards, invitations, posters,
                  // menus, screenshots — anything text-heavy that is clearly
                  // not a travel photograph.
                  {'type': 'TEXT_DETECTION', 'maxResults': 1},
                ],
              }
            ]
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Cloud Vision HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final responses = (body['responses'] as List<dynamic>?) ?? [];
    if (responses.isEmpty) throw Exception('Empty Cloud Vision response');

    final data = responses.first as Map<String, dynamic>;

    // ── Gate 1: Safe-search (adult / violent content) ────────────────────────
    final safeSearch = data['safeSearchAnnotation'] as Map<String, dynamic>?;
    if (safeSearch != null) {
      const flagged = {'LIKELY', 'VERY_LIKELY'};
      if (flagged.contains(safeSearch['adult']) ||
          flagged.contains(safeSearch['violence'])) {
        return const ImageVerificationResult(
          isApproved: false,
          rejectionReason: ImageRejectionReason.inappropriateContent,
        );
      }
    }

    // ── Gate 2: Text gate (cards, invitations, posters, screenshots) ─────────
    // The first element in textAnnotations is the concatenated full-image text.
    // If it exceeds the threshold the image is text-heavy and not a travel photo.
    final textAnnotations =
        (data['textAnnotations'] as List<dynamic>?) ?? [];
    if (textAnnotations.isNotEmpty) {
      final fullText =
          ((textAnnotations.first as Map<String, dynamic>)['description']
                  as String? ??
              '')
              .trim();
      if (fullText.length > ImageVerificationConfig.maxAllowedTextLength) {
        return const ImageVerificationResult(
          isApproved: false,
          rejectionReason: ImageRejectionReason.nonPhotoContent,
        );
      }
    }

    // ── Labels ───────────────────────────────────────────────────────────────
    final labels = ((data['labelAnnotations'] as List<dynamic>?) ?? [])
        .map((l) =>
            ((l as Map<String, dynamic>)['description'] as String? ?? '')
                .toLowerCase()
                .trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final hasRejectedLabel = labels.any((l) =>
        ImageVerificationConfig.rejectedKeywords.any((kw) => l.contains(kw)));
    if (hasRejectedLabel) {
      return ImageVerificationResult(
        isApproved: false,
        rejectionReason: ImageRejectionReason.nonPhotoContent,
        detectedLabels: labels,
      );
    }

    // ── Landmarks ────────────────────────────────────────────────────────────
    final landmarks = ((data['landmarkAnnotations'] as List<dynamic>?) ?? [])
        .map((l) =>
            ((l as Map<String, dynamic>)['description'] as String? ?? '')
                .trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // ── Faces ────────────────────────────────────────────────────────────────
    final facesDetected =
        ((data['faceAnnotations'] as List<dynamic>?) ?? []).isNotEmpty;

    // ── Travel labels ────────────────────────────────────────────────────────
    final hasTravelLabel = labels.any((l) =>
        ImageVerificationConfig.travelKeywords.any((kw) => l.contains(kw)));

    return _applyRules(
      labels: labels,
      landmarks: landmarks,
      facesDetected: facesDetected,
      hasTravelLabel: hasTravelLabel,
    );
  }

  // ── Tier 2: ML Kit on-device ──────────────────────────────────────────────

  static Future<ImageVerificationResult> _verifyWithMlKit(
      Uint8List imageBytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
        '${tempDir.path}/mlkit_verify_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(imageBytes);

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final mlLabels = await _getLabeler().processImage(inputImage);

      final labels =
          mlLabels.map((l) => l.label.toLowerCase().trim()).toList();

      final hasRejectedLabel = labels.any((l) =>
          ImageVerificationConfig.rejectedKeywords.any((kw) => l.contains(kw)));
      if (hasRejectedLabel) {
        return ImageVerificationResult(
          isApproved: false,
          rejectionReason: ImageRejectionReason.nonPhotoContent,
          detectedLabels: labels,
        );
      }

      // ML Kit does not provide face or landmark detection in the basic labeler,
      // so we rely on keyword matching for both face and travel content.
      final hasFace = labels.any((l) =>
          ['person', 'human', 'face', 'portrait', 'selfie', 'man', 'woman']
              .any((fw) => l.contains(fw)));

      final hasTravelLabel = labels.any((l) =>
          ImageVerificationConfig.travelKeywords.any((kw) => l.contains(kw)));

      return _applyRules(
        labels: labels,
        landmarks: const [],
        facesDetected: hasFace,
        hasTravelLabel: hasTravelLabel,
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  // ── Shared decision rules ─────────────────────────────────────────────────

  static ImageVerificationResult _applyRules({
    required List<String> labels,
    required List<String> landmarks,
    required bool facesDetected,
    required bool hasTravelLabel,
  }) {
    // RULE 1 — Any face → always reject.
    // WanderLens is about destinations, not people.
    if (facesDetected) {
      return ImageVerificationResult(
        isApproved: false,
        rejectionReason: ImageRejectionReason.facesWithoutDestination,
        detectedLabels: labels,
        detectedLandmarks: landmarks,
        facesDetected: true,
      );
    }

    // RULE 2 — Recognised landmark + no faces → approve.
    if (landmarks.isNotEmpty) {
      return ImageVerificationResult(
        isApproved: true,
        detectedLabels: labels,
        detectedLandmarks: landmarks,
      );
    }

    // RULE 3 — Travel / landscape labels + no faces → approve.
    if (hasTravelLabel) {
      return ImageVerificationResult(
        isApproved: true,
        detectedLabels: labels,
      );
    }

    // RULE 4 — No travel content detected → reject.
    return ImageVerificationResult(
      isApproved: false,
      rejectionReason: ImageRejectionReason.notATravelDestination,
      detectedLabels: labels,
    );
  }
}
