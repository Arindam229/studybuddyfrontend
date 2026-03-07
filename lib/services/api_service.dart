import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:studybuddy_client/services/auth_service.dart';

class ApiService {
  // Use --dart-define=API_URL=https://your-api.vercel.app/api during build
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue:
        'https://studybuddybackend-dmbadabedrdyfqcw.southeastasia-01.azurewebsites.net/api',
  );
  static final AuthService _authService = AuthService();

  // Helper method to get headers with the auth token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> uploadImage(XFile image) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));

      // Add Authorization header to the multipart request
      final token = await _authService.getIdToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      var bytes = await image.readAsBytes();
      var multipartFile = http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: image.name,
      );

      request.files.add(multipartFile);

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return jsonDecode(responseBody);
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  static Future<Map<String, dynamic>> sendChat(String message) async {
    try {
      final headers = await _getHeaders();
      var response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: headers,
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to send chat message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error sending chat: $e');
    }
  }

  static Future<Map<String, dynamic>> getHistory() async {
    try {
      final headers = await _getHeaders();
      // Notice we drop the studentId from the path, the backend gets it from the token
      var response = await http.get(
        Uri.parse('$baseUrl/history'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching history: $e');
    }
  }
}
