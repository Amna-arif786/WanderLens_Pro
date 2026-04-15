import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:wanderlens/services/image_verification_config.dart';
import 'package:wanderlens/storage/cloudinary_service.dart';

// ── Verification status ───────────────────────────────────────────────────────

enum VerificationStatus { approved, pending, hardRejected }

// ── Result model ──────────────────────────────────────────────────────────────

enum ImageRejectionReason {
  none,
  facesDetected,
  notATravelDestination,
  inappropriateContent,
  nonPhotoContent,
}

class ImageVerificationResult {
  const ImageVerificationResult({
    required this.verificationStatus,
    this.rejectionReason = ImageRejectionReason.none,
    this.detectedLabels = const [],
    this.detectedLandmarks = const [],
    this.faceCount = 0,
    this.topLandmarkConfidence = 0.0,
    this.verificationSource = VerificationSource.none,
  });

  final VerificationStatus verificationStatus;
  final ImageRejectionReason rejectionReason;
  final List<String> detectedLabels;
  final List<String> detectedLandmarks;
  final int faceCount;
  final double topLandmarkConfidence;
  final VerificationSource verificationSource;

  bool get isApproved => verificationStatus == VerificationStatus.approved;
  bool get isPending => verificationStatus == VerificationStatus.pending;
  bool get isHardRejected =>
      verificationStatus == VerificationStatus.hardRejected;

  static const ImageVerificationResult pending = ImageVerificationResult(
    verificationStatus: VerificationStatus.pending,
    verificationSource: VerificationSource.none,
  );
}

// ── Service ───────────────────────────────────────────────────────────────────

enum VerificationSource { cloudinaryAI, mlKit, cloudVision, manual, none }

class ImageVerificationService {
  static ImageLabeler? _labeler;
  static FaceDetector? _faceDetector;

  static ImageLabeler _getLabeler() {
    _labeler ??= ImageLabeler(
      options: ImageLabelerOptions(
        confidenceThreshold: ImageVerificationConfig.mlKitMinConfidence,
      ),
    );
    return _labeler!;
  }

  static FaceDetector _getFaceDetector() {
    _faceDetector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false,
        enableLandmarks: false,
        enableTracking: false,
        minFaceSize: 0.10,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    return _faceDetector!;
  }

  static void dispose() {
    _labeler?.close();
    _labeler = null;
    _faceDetector?.close();
    _faceDetector = null;
  }

  static Future<ImageVerificationResult> verifyPostImage(
    Uint8List imageBytes,
    String locationName, {
    String? imageUrl,
    CloudinaryUploadResult? cloudinaryUpload,
  }) async {
    // ── Tier 1: Cloudinary AI ────────────────────────────────────────────────
    if (cloudinaryUpload != null && cloudinaryUpload.aiTags.isNotEmpty) {
      debugPrint('[Verify] Tier 1 — Cloudinary AI');
      return _verifyFromCloudinaryAI(cloudinaryUpload);
    }

    // ── Tier 2 (mobile): ML Kit ──────────────────────────────────────────────
    if (!kIsWeb) {
      try {
        debugPrint('[Verify] Tier 2 — ML Kit');
        final result = await _verifyWithMlKit(imageBytes);
        if (result.isHardRejected || result.isApproved) return result;
      } catch (e) {
        debugPrint('[Verify] ML Kit failed: $e');
      }
    }

    // ── Tier 3: Cloud Vision API ─────────────────────────────────────────────
    final apiKey = dotenv.env['CLOUD_VISION_API_KEY'] ?? '';
    if (apiKey.isNotEmpty) {
      try {
        debugPrint('[Verify] Tier 3 — Cloud Vision');
        return await _verifyWithCloudVision(
          apiKey,
          imageUrl: imageUrl,
          imageBytes: imageBytes,
        );
      } catch (e) {
        debugPrint('[Verify] Cloud Vision failed: $e');
      }
    }

    // Default to pending instead of hard reject
    return ImageVerificationResult.pending;
  }

  static const _faceKeywords = [
    'person', 'people', 'human', 'face', 'portrait', 'selfie',
    'man', 'woman', 'boy', 'girl', 'child', 'crowd',
  ];

  static ImageVerificationResult _verifyFromCloudinaryAI(
      CloudinaryUploadResult upload) {
    final labels = upload.aiTags.map((t) => t.tag).toList();

    // Only hard reject if face is absolutely certain
    final hasFaceTag = labels.any((l) => ['selfie', 'portrait', 'person'].any((kw) => l.contains(kw)));
    if (upload.faceCount > 0 || hasFaceTag) {
      return ImageVerificationResult(
        verificationStatus: VerificationStatus.hardRejected,
        rejectionReason: ImageRejectionReason.facesDetected,
        faceCount: upload.faceCount > 0 ? upload.faceCount : 1,
        verificationSource: VerificationSource.cloudinaryAI,
      );
    }

    double topTravelScore = 0.0;
    for (final tag in upload.aiTags) {
      if (ImageVerificationConfig.travelKeywords.any((kw) => tag.tag.contains(kw))) {
        if (tag.confidence > topTravelScore) topTravelScore = tag.confidence;
      }
    }

    return _applyRules(
      labels: labels,
      landmarks: const [],
      faceCount: 0,
      hasTravelLabel: topTravelScore > 0,
      topLandmarkConfidence: 0.0,
      topTravelLabelScore: topTravelScore,
      source: VerificationSource.cloudinaryAI,
    );
  }

  static Future<ImageVerificationResult> _verifyWithCloudVision(
    String apiKey, {
    String? imageUrl,
    required Uint8List imageBytes,
  }) async {
    final Map<String, dynamic> imageField =
        (imageUrl != null && imageUrl.isNotEmpty)
            ? {'source': {'imageUri': imageUrl}}
            : {'content': base64Encode(imageBytes)};

    final response = await http
        .post(
          Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'requests': [
              {
                'image': imageField,
                'features': [
                  {'type': 'LANDMARK_DETECTION', 'maxResults': 5},
                  {'type': 'LABEL_DETECTION', 'maxResults': 20},
                  {'type': 'FACE_DETECTION', 'maxResults': 5},
                  {'type': 'SAFE_SEARCH_DETECTION'},
                ],
              }
            ]
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) throw Exception('Vision API Error');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['responses'] as List).first as Map<String, dynamic>;

    final faceCount = (data['faceAnnotations'] as List?)?.length ?? 0;
    if (faceCount > 0) {
      return ImageVerificationResult(
        verificationStatus: VerificationStatus.hardRejected,
        rejectionReason: ImageRejectionReason.facesDetected,
        faceCount: faceCount,
        verificationSource: VerificationSource.cloudVision,
      );
    }

    final rawLabels = (data['labelAnnotations'] as List?) ?? [];
    final labels = rawLabels.map((l) => (l['description'] as String).toLowerCase()).toList();

    double topTravelLabelScore = 0.0;
    for (final l in rawLabels) {
      final desc = (l['description'] as String).toLowerCase();
      final score = (l['score'] as num).toDouble();
      if (ImageVerificationConfig.travelKeywords.any((kw) => desc.contains(kw))) {
        if (score > topTravelLabelScore) topTravelLabelScore = score;
      }
    }

    final rawLandmarks = (data['landmarkAnnotations'] as List?) ?? [];
    final landmarks = rawLandmarks.map((l) => l['description'] as String).toList();
    final topLandmarkScore = rawLandmarks.isEmpty ? 0.0 : (rawLandmarks.first['score'] as num).toDouble();

    return _applyRules(
      labels: labels,
      landmarks: landmarks,
      faceCount: 0,
      hasTravelLabel: topTravelLabelScore > 0,
      topLandmarkConfidence: topLandmarkScore,
      topTravelLabelScore: topTravelLabelScore,
      source: VerificationSource.cloudVision,
    );
  }

  static Future<ImageVerificationResult> _verifyWithMlKit(Uint8List imageBytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/mlkit_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(imageBytes);

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _getFaceDetector().processImage(inputImage);
      if (faces.isNotEmpty) {
        return ImageVerificationResult(
          verificationStatus: VerificationStatus.hardRejected,
          rejectionReason: ImageRejectionReason.facesDetected,
          faceCount: faces.length,
          verificationSource: VerificationSource.mlKit,
        );
      }

      final mlLabels = await _getLabeler().processImage(inputImage);
      final labels = mlLabels.map((l) => l.label.toLowerCase()).toList();

      double topTravelScore = 0.0;
      for (final ml in mlLabels) {
        if (ImageVerificationConfig.travelKeywords.any((kw) => ml.label.toLowerCase().contains(kw))) {
          if (ml.confidence > topTravelScore) topTravelScore = ml.confidence;
        }
      }

      return _applyRules(
        labels: labels,
        landmarks: const [],
        faceCount: 0,
        hasTravelLabel: topTravelScore > 0,
        topLandmarkConfidence: 0.0,
        topTravelLabelScore: topTravelScore,
        source: VerificationSource.mlKit,
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  static ImageVerificationResult _applyRules({
    required List<String> labels,
    required List<String> landmarks,
    required int faceCount,
    required bool hasTravelLabel,
    required double topLandmarkConfidence,
    required double topTravelLabelScore,
    required VerificationSource source,
  }) {
    if (faceCount > 0) {
      return ImageVerificationResult(
        verificationStatus: VerificationStatus.hardRejected,
        rejectionReason: ImageRejectionReason.facesDetected,
        faceCount: faceCount,
        verificationSource: source,
      );
    }

    // Approved if confidence is high
    if ((landmarks.isNotEmpty && topLandmarkConfidence >= 0.70) || (hasTravelLabel && topTravelLabelScore >= 0.70)) {
      return ImageVerificationResult(
        verificationStatus: VerificationStatus.approved,
        detectedLabels: labels,
        detectedLandmarks: landmarks,
        topLandmarkConfidence: topLandmarkConfidence > topTravelLabelScore ? topLandmarkConfidence : topTravelLabelScore,
        verificationSource: source,
      );
    }

    // Always go to PENDING if there is any travel signal, NEVER hard reject
    return ImageVerificationResult(
      verificationStatus: VerificationStatus.pending,
      detectedLabels: labels,
      detectedLandmarks: landmarks,
      topLandmarkConfidence: topTravelLabelScore,
      verificationSource: source,
    );
  }
}
