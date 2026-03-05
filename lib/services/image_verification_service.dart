import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ImageVerificationService {
  static const String _apiKey =
      'AIzaSyDRmaoStskD7Q413WddnzuvDB1C3zVc3bM'; // User needs to add their API key
  static const String _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  /// Verifies image from bytes (works on web and mobile)..
  static Future<bool> verifyTravelImageFromBytes(Uint8List bytes, String location) async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      return await _callGeminiAPIWithBytes(bytes, location);
    } catch (e) {
      print('Image verification failed: $e');
      return true;
    }
  }

  static Future<bool> _callGeminiAPIWithBytes(Uint8List bytes, String location) async {
    try {
      final base64Image = base64Encode(bytes);
      final payload = {
        'contents': [
          {
            'parts': [
              {
                'text': '''
              Analyze this image and determine if it shows a travel destination, monument, historical place, or tourist attraction related to "$location". 
              
              Respond with "VERIFIED" if the image shows:
              - A famous landmark or monument
              - A historical building or site
              - A travel destination or tourist attraction
              - Cultural or architectural heritage
              
              Respond with "REJECTED" if the image shows:
              - People only (without prominent landmarks)
              - Food, animals, or unrelated objects
              - Indoor scenes without historical significance
              - Random or inappropriate content
              
              Just respond with either "VERIFIED" or "REJECTED".
              '''
              },
              {
                'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image}
              }
            ]
          }
        ]
      };

      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
                ?.toString()
                .toUpperCase() ??
            '';
        return text.contains('VERIFIED');
      }
    } catch (e) {
      print('Gemini API error: $e');
    }
    return true;
  }

  static String getSetupInstructions() {
    return '''
To enable AI-powered image verification:

1. Get a Gemini API key from Google AI Studio (https://makersuite.google.com/app/apikey)
2. Replace 'YOUR_GEMINI_API_KEY' in image_verification_service.dart with your actual API key
3. The app will automatically verify travel images using AI

For now, all images are accepted for demo purposes.
''';
  }
}
