import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AuthService {
  // Base URL untuk koneksi API
  static String getBaseUrl() {
    // Cek apakah aplikasi berjalan di web
    const bool kIsWeb = identical(0, 0.0);

    if (kIsWeb) {
      // Untuk Flutter Web
      return 'http://localhost:8000/api';
    } else {
      // Untuk Android - gunakan IP WiFi yang benar
      return 'http://192.168.104.8:8000/api';
    }
  }

  static const String tokenKey = 'token';
  static const String userKey = 'user';

  Future<Map<String, dynamic>> login(String nim, String password) async {
    try {
      final baseUrl = getBaseUrl();
      print('Data Login - NIM: $nim');

      final response = await http
          .post(
        Uri.parse('$baseUrl/ormawa/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'nim': nim,
          'password': password,
        }),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Koneksi timeout. Periksa koneksi Anda.');
        },
      );

      print('Status Response: ${response.statusCode}');
      print('Isi Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();

        // Simpan token
        if (data['data'] != null && data['data']['token'] != null) {
          await prefs.setString(tokenKey, data['data']['token']);
          print('Token berhasil disimpan');
        }

        // Simpan data lengkap ormawa
        if (data['data'] != null && data['data']['ormawa'] != null) {
          final ormawaData = data['data']['ormawa'];
          print('Data mentah dari server: $ormawaData');

          // Pastikan data yang disimpan sesuai dengan model
          final userData = {
            'id': ormawaData['id'],
            'namaMahasiswa': ormawaData['namaMahasiswa'],
            'namaOrmawa': ormawaData['namaOrmawa'],
            'nim': ormawaData['nim'],
            'email': ormawaData['email'],
            'noHp': ormawaData['noHp'],
            'profile': ormawaData['profile']
          };

          print('Data yang akan disimpan: $userData');
          await prefs.setString(userKey, jsonEncode(userData));
          print('Data berhasil disimpan ke penyimpanan');

          return {
            'success': true,
            'data': {'token': data['data']['token'], 'ormawa': userData},
          };
        }

        return {
          'success': false,
          'message': 'Data ormawa tidak ditemukan',
        };
      } else {
        var message = 'Terjadi kesalahan';
        try {
          final data = jsonDecode(response.body);
          message = data['message'] ?? message;
        } catch (_) {}
        print('Login gagal: $message');
        return {
          'success': false,
          'message': message,
        };
      }
    } catch (e) {
      print('Error saat login: ${e.toString()}');
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: ${e.toString()}',
      };
    }
  }

  // Helper method untuk mengambil nilai dengan aman
  dynamic _getSafeValue(Map<String, dynamic>? data, String key) {
    if (data == null) return null;
    return data[key];
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  Future<Map<String, dynamic>?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(tokenKey);
      final userStr = prefs.getString(userKey);

      print('Token tersedia: ${token != null}');
      print('Data user tersedia: ${userStr != null}');

      if (token == null) {
        print('Token tidak ditemukan');
        return null;
      }

      if (userStr != null) {
        final userData = jsonDecode(userStr) as Map<String, dynamic>;
        print('Data user yang diambil: $userData');
        return userData;
      }

      print('Data user tidak ditemukan');
      return null;
    } catch (e) {
      print('Error saat mengambil data user: $e');
      return null;
    }
  }

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
}
