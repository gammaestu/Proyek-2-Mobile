import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Konstanta key untuk SharedPreferences
  static const String tokenKey = 'token';
  static const String userKey = 'user';

  // Mendapatkan Base URL sesuai platform
  static String getBaseUrl() {
    const bool kIsWeb = identical(0, 0.0);
    return kIsWeb
        ? 'http://localhost:8000/api' // Untuk Flutter Web
        : 'http://192.168.104.8:8000/api'; // Untuk Android (gunakan IP jaringan WiFi kamu)
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

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw TimeoutException('Koneksi timeout. Periksa koneksi Anda.'),
      );

      print('Status Response: ${response.statusCode}');
      print('Isi Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();

         final token = data['data']?['token'];
          late final dynamic userData;
            if (role.toLowerCase() == 'ormawa') {
              userData = data['data']?['ormawa'];
            } else if (role.toLowerCase() == 'dosen') {
              userData = data['data']?['dosen'];
            } else {
              userData = data['data']?['kemahasiswaan'];
            }


        if (token != null && userData != null) {
          await prefs.setString(tokenKey, token);
          await prefs.setString(userKey, jsonEncode(userData));

          return {
            'success': true,
            'user': userData,
            'token': token,
          };
        }

        return {
          'success': false,
          'message': 'Data login tidak lengkap',
        };
      } else {
        print('Login gagal dengan status: ${response.statusCode}');
        print('Response body: ${response.body}');
        var message = 'Terjadi kesalahan';
        try {
          final data = jsonDecode(response.body);
          message = data['message'] ?? message;
        } catch (_) {}
        return {
          'success': false,
          'message': message,
        };
      }
    } catch (e) {
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
}
