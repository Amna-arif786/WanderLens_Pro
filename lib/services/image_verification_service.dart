import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wanderlens/services/image_verification_config.dart';

class ImageVerificationService {
  static ImageLabeler? _labeler;

  static void _initLabeler() {
    if (_labeler == null) {
      final options = ImageLabelerOptions(confidenceThreshold: ImageVerificationConfig.minConfidence);
      _labeler = ImageLabeler(options: options);
    }
  }

  /// Verifies image by actually "looking" at it using On-Device AI
  static Future<Map<String, dynamic>> verifyLandmark(Uint8List imageBytes, String location) async {
    _initLabeler();

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/temp_verify_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(imageBytes);

      final inputImage = InputImage.fromFilePath(file.path);
      final List<ImageLabel> labels = await _labeler!.processImage(inputImage);

      final detectedLabels = labels.map((l) => l.label.toLowerCase()).toList();
      print('AI Analysis Labels: $detectedLabels');

      // 1. Hard Rejects (Graphics/Logos)
      bool hasRejectedContent = detectedLabels.any((label) => 
        ImageVerificationConfig.rejectedKeywords.any((rejected) => label.contains(rejected))
      );

      // 2. Nature/Travel Context (Paharr, Darakht, etc.)
      bool hasTravelContent = detectedLabels.any((label) => 
        ImageVerificationConfig.allowedKeywords.any((allowed) => label.contains(allowed))
      );

      // 3. Human Presence
      bool hasHuman = detectedLabels.any((label) => 
        ['person', 'human', 'face', 'portrait', 'selfie', 'man', 'woman'].contains(label)
      );

      if (await file.exists()) await file.delete();

      if (hasRejectedContent) {
        return {
          "status": "REJECTED",
          "message": "AI detected graphics/text. Please upload a real travel photo. (Found: ${detectedLabels.take(2).join(', ')})"
        };
      }

      // If it has travel content, we accept it (even if a person is in it, like a traveler)
      if (hasTravelContent) {
        return {
          "status": "VERIFIED",
          "message": "Valid travel context detected."
        };
      }

      // If ONLY a human is detected without any nature/travel context
      if (hasHuman && !hasTravelContent) {
        return {
          "status": "REJECTED",
          "message": "This looks like a personal selfie. Please share the destination!"
        };
      }

      return {
        "status": "REJECTED",
        "message": "AI couldn't verify this travel spot. Detected: ${detectedLabels.take(3).join(', ')}"
      };

    } catch (e) {
      print('ML Kit Error: $e');
      // If AI model fails, we allow it for now so user doesn't get stuck
      return {"status": "VERIFIED", "message": "Bypassed due to error."};
    }
  }

  static Future<bool> verifyTravelImageFromBytes(Uint8List bytes, String location) async {
    if (location.trim().length < 2) return false;
    final result = await verifyLandmark(bytes, location);
    return result['status'] == "VERIFIED";
  }

  static void dispose() {
    _labeler?.close();
    _labeler = null;
  }
}
