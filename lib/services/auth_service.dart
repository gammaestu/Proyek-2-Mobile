// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Update with your Laravel backend URL
  static const String baseUrl = 'http://localhost:8000/api';
  
  Future<Map<String, dynamic>> login({
    required String role,
    required String password,
    String? email,
    String? nim,
    String? nip,
  }) async {
    try {
      // Prepare the login data based on role
      Map<String, dynamic> loginData = {
        'role': role,
        'password': password,
      };

      // Add credentials based on role
      switch (role) {
        case 'admin':
          if (email == null) throw Exception('Email is required for admin login');
          loginData['email'] = email;
          break;
        case 'ormawa':
          if (nim == null) throw Exception('NIM is required for ormawa login');
          loginData['nim'] = nim;
          break;
        case 'dosen':
          if (nip == null) throw Exception('NIP is required for dosen login');
          loginData['nip'] = nip;
          break;
        default:
          throw Exception('Invalid role');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(loginData),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Save the token and user data
        await _saveToken(responseData['token']);
        await _saveUserData(responseData['user']);
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(userData));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      return jsonDecode(userDataString);
    }
    return null;
  }
}