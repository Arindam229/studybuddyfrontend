import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:studybuddy_client/services/auth_service.dart';

class ApiService {
  static String get baseUrl {
    final url = dotenv.env['API_URL'] ?? 'http://localhost:3000/api';
    print('[API DEBUG] Current Base URL: $url');
    return url;
  }

  static final AuthService _authService = AuthService();

  // Helper method to get headers with the auth token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> uploadFile(
    List<int> bytes,
    String filename,
  ) async {
    try {
      final url = '$baseUrl/upload';
      print('[API DEBUG] Uploading file to: $url');
      var request = http.MultipartRequest('POST', Uri.parse(url));

      final token = await _authService.getIdToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      var multipartFile = http.MultipartFile.fromBytes(
        'image', // Backend still expects 'image' field for now
        bytes,
        filename: filename,
      );

      request.files.add(multipartFile);

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return jsonDecode(responseBody);
      } else {
        throw Exception('Failed to upload file: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error uploading file: $e');
    }
  }

  static Future<Map<String, dynamic>> uploadImage(XFile image) async {
    return uploadFile(await image.readAsBytes(), image.name);
  }

  static Future<Map<String, dynamic>> uploadChatImage(XFile image) async {
    try {
      final url = '$baseUrl/chat-upload';
      print('[API DEBUG] Uploading chat image to: $url');
      var request = http.MultipartRequest('POST', Uri.parse(url));

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
      print('[API DEBUG] Chat Upload Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(responseBody);
      } else {
        throw Exception('Failed to upload chat image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error uploading chat image: $e');
    }
  }

  static Future<Map<String, dynamic>> sendChat(
    String message, {
    String? screenshotText,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/chat';
      print('[API DEBUG] Sending chat to: $url');
      var response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'message': message,
          if (screenshotText != null) 'screenshot_text': screenshotText,
        }),
      );
      print('[API DEBUG] Chat Response: ${response.statusCode}');

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
      final url = '$baseUrl/history';
      print('[API DEBUG] Fetching history from: $url');
      var response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching history: $e');
    }
  }

  static Future<Map<String, dynamic>> getDocumentsHistory() async {
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/history/documents';
      print('[API DEBUG] Fetching document history from: $url');
      var response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch document history: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching document history: $e');
    }
  }

  static Future<Map<String, dynamic>> clearHistory() async {
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/history';
      print('[API DEBUG] Clearing history at: $url');
      var response = await http.delete(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to clear history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error clearing history: $e');
    }
  }

  // Group and Collaboration Endpoints
  static Future<Map<String, dynamic>> createGroup(
    String name,
    String summaryId,
  ) async {
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/groups/create';
      var response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({'name': name, 'summaryId': summaryId}),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create group: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating group: $e');
    }
  }

  static Future<Map<String, dynamic>> joinGroup(String inviteCode) async {
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/groups/join';
      var response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({'inviteCode': inviteCode}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to join group: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error joining group: $e');
    }
  }

  static Future<Map<String, dynamic>> getGroups() async {
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/groups/list';
      var response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch groups: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching groups: $e');
    }
  }

  static Future<Map<String, dynamic>> getVideoToken(String channelName) async {
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/video/token?channelName=$channelName';
      var response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch video token: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching video token: $e');
    }
  }

  static Future<Map<String, dynamic>> getDocumentById(String id) async {
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/history/document/$id';
      var response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch document: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching document: $e');
    }
  }

  static Future<Map<String, dynamic>> updateDocument(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/history/document/$id';
      print('[API DEBUG] Updating document at: $url');
      var response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update document: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating document: $e');
    }
  }
}
