import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiConfig {
  // Pusat konfigurasi API yang dapat diakses dari mana saja
  static String baseIp = "192.168.1.6"; // Ganti dengan IP server Anda
  static String port = "8000"; // Port default Laravel

  // URL lengkap dengan port
  static String get baseUrl => "http://$baseIp:$port";

  // URL dengan endpoint API
  static String get apiUrl => "$baseUrl/api";

  // Mengubah IP dan port
  static void updateConfig({String? ip, String? portNum}) {
    if (ip != null) baseIp = ip;
    if (portNum != null) port = portNum;
    print("API URL diperbarui: $apiUrl");
  }
}

class AuthService {
  // Konstanta key untuk SharedPreferences
  static const String tokenKey = 'token';
  static const String userKey = 'user';

  // URL kustom untuk override konfigurasi default
  static String? _customBaseUrl; // Untuk menyimpan URL kustom

  // Setter untuk mengubah base URL
  static void setCustomBaseUrl(String url) {
    _customBaseUrl = url;
    print('Custom Base URL diatur ke: $_customBaseUrl');
  }

  // Reset custom URL dan gunakan konfigurasi default
  static void resetCustomUrl() {
    _customBaseUrl = null;
    print('Reset ke URL default: ${ApiConfig.apiUrl}');
  }

  // Mendapatkan Base URL sesuai platform
  static String getBaseUrl() {
    if (_customBaseUrl != null) {
      // Pastikan URL berakhir dengan /api
      if (!_customBaseUrl!.endsWith('/api')) {
        return '$_customBaseUrl/api';
      }
      return _customBaseUrl!;
    }

    if (kIsWeb) {
      return 'http://localhost:${ApiConfig.port}/api';
    }

    if (Platform.isAndroid) {
      // Untuk emulator Android
      if (Platform.environment.containsKey('ANDROID_EMU_REDIRECT_TO_HOST')) {
        return 'http://10.0.2.2:${ApiConfig.port}/api';
      }
    }

    // Untuk device fisik, gunakan URL dari ApiConfig
    return ApiConfig.apiUrl;
  }

  // Fungsi login untuk berbagai role
  Future<Map<String, dynamic>> login({
    required String role,
    required String password,
    String? nim,
    String? nip,
  }) async {
    try {
      final baseUrl = getBaseUrl();
      String endpoint = '';
      Map<String, dynamic> body = {};

      print('Login attempt - Role: $role'); // Debug print
      print('Menggunakan base URL: $baseUrl'); // Debug print untuk URL

      // Tentukan endpoint & request body berdasarkan role
      switch (role) {
        case 'ormawa':
          endpoint = '/ormawa/login';
          body = {'nim': nim, 'password': password};
          break;
        case 'dosen':
          endpoint = '/dosen/login';
          body = {'nip': nip, 'password': password};
          break;
        case 'kemahasiswaan':
          endpoint = '/kemahasiswaan/login';
          body = {'nip': nip, 'password': password};
          break;
        default:
          return {'success': false, 'message': 'Role tidak dikenali'};
      }

      print('Attempting login to: $baseUrl$endpoint'); // Debug print
      print('Request body: ${jsonEncode(body)}'); // Debug print

      final response = await http
          .post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('Connection timeout'); // Debug print
          throw TimeoutException('Koneksi timeout. Periksa koneksi Anda.');
        },
      );

      print('Response status code: ${response.statusCode}'); // Debug print
      print('Response body: ${response.body}'); // Debug print

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();

        final token = data['data']?['token'];
        print('Received token: ${token != null}'); // Debug print

        late final dynamic userData;
        if (role.toLowerCase() == 'ormawa') {
          userData = data['data']?['ormawa'];
        } else if (role.toLowerCase() == 'dosen') {
          userData = data['data']?['dosen'];
        } else {
          userData = data['data']?['kemahasiswaan'];
        }

        print('User data received: ${userData != null}'); // Debug print

        if (token != null && userData != null) {
          await prefs.setString(tokenKey, token);
          await prefs.setString(userKey, jsonEncode(userData));
          print(
              'Login successful - Data saved to SharedPreferences'); // Debug print

          return {
            'success': true,
            'user': userData,
            'token': token,
          };
        }

        print('Login failed - Incomplete data received'); // Debug print
        return {
          'success': false,
          'message': 'Data login tidak lengkap',
        };
      } else {
        print('Login failed - HTTP ${response.statusCode}'); // Debug print
        print('Error response: ${response.body}'); // Debug print

        var message = 'Terjadi kesalahan';
        try {
          final data = jsonDecode(response.body);
          message = data['message'] ?? message;
        } catch (e) {
          print('Error parsing response: $e'); // Debug print
        }
        return {
          'success': false,
          'message': message,
        };
      }
    } catch (e) {
      print('Login error: $e'); // Debug print
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: ${e.toString()}',
      };
    }
  }

  // Mengambil token dari penyimpanan lokal
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  // Mengambil data user dari penyimpanan lokal
  Future<Map<String, dynamic>?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(tokenKey);
      final userStr = prefs.getString(userKey);

      print('Token tersedia: ${token != null}');
      print('Data user tersedia: ${userStr != null}');

      if (token == null || userStr == null) return null;

      final userData = jsonDecode(userStr) as Map<String, dynamic>;
      print('Data user yang diambil: $userData');
      return userData;
    } catch (e) {
      print('Error saat mengambil data user: $e');
      return null;
    }
  }

  // Logout dan hapus data lokal
  Future<Map<String, dynamic>> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      await prefs.remove(userKey);
      return {'success': true, 'message': 'Berhasil logout'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal logout: $e'};
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String namaMahasiswa,
    required String email,
    required String noHp,
  }) async {
    final token = await getToken();
    final baseUrl = getBaseUrl();
    final response = await http.put(
      Uri.parse('$baseUrl/ormawa/profile'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'namaMahasiswa': namaMahasiswa,
        'email': email,
        'noHp': noHp,
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final token = await getToken();
    final baseUrl = getBaseUrl();
    final response = await http.put(
      Uri.parse('$baseUrl/ormawa/profile/password'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': confirmPassword,
      }),
    );
    return jsonDecode(response.body);
  }
}
