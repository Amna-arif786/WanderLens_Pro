import 'dart:io';
import 'dart:typed_data';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';

/// CloudinaryService handles image uploads to Cloudinary storage..
/// It provides separate methods for profile and post images to keep storage organized..
class CloudinaryService {
  static final _cloudinary = CloudinaryPublic(
    'dnkuxlhcs', // Your Cloudinary Cloud Name..
    'wanderlens_preset', // Your Cloudinary Upload Preset..
    cache: false,
  );

  /// Uploads a profile picture to a specific 'profiles' folder in Cloudinary..
  /// Returns the secure URL of the uploaded image..
  static Future<String?> uploadProfileImage(File imageFile) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: 'profiles', // Separate folder for profile images..
        ),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint('Cloudinary Profile Image Upload Error: $e');
      return null;
    }
  }

  /// Uploads post image from bytes (works on web and mobile)..
  static Future<String?> uploadPostImageFromBytes(Uint8List bytes) async {
    try {
      final cloudinaryFile = CloudinaryFile.fromBytesData(
        bytes,
        identifier: 'post_${DateTime.now().millisecondsSinceEpoch}.jpg',
        folder: 'posts',
      );
      final response = await _cloudinary.uploadFile(cloudinaryFile);
      return response.secureUrl;
    } catch (e) {
      debugPrint('Cloudinary Post Image Upload Error: $e');
      return null;
    }
  }

  /// Uploads a travel post image from File (mobile only)..
  static Future<String?> uploadPostImage(File imageFile) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: 'posts', // Separate folder for travel posts..
        ),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint('Cloudinary Post Image Upload Error: $e');
      return null;
    }
  }
}
