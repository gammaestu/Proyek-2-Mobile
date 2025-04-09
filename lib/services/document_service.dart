import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class DocumentService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  Future<Map<String, dynamic>> getDocumentStats() async {
    try {
      final token = await _authService.getToken();

      if (token == null) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
          'data': {
            'submitted': 0,
            'signed': 0,
            'need_revision': 0,
            'revised': 0,
          }
        };
      }

      final baseUrl = AuthService.getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/ormawa/documents/stats'),
        headers: await _getHeaders(),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          // Map status dari backend ke frontend
          final stats = data['data'];
          return {
            'success': true,
            'data': {
              'submitted': stats['submitted'] ?? 0, // diajukan
              'signed': stats['signed'] ?? 0, // ditandatangani
              'need_revision': stats['need_revision'] ?? 0, // perlu_revisi
              'revised': stats['revised'] ?? 0, // sudah_direvisi
            },
          };
        } else {
          return {
            'success': false,
            'message': data['message'],
            'data': {
              'submitted': 0,
              'signed': 0,
              'need_revision': 0,
              'revised': 0,
            }
          };
        }
      } else {
        print('Error response: ${response.body}');
        throw Exception(
            'Failed to load document stats: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getDocumentStats: $e');
      return {
        'success': false,
        'message': e.toString(),
        'data': {
          'submitted': 0,
          'signed': 0,
          'need_revision': 0,
          'revised': 0,
        }
      };
    }
  }

  Future<Map<String, dynamic>> getDocumentStatsForDosen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AuthService.tokenKey);

      final response = await http.get(
        Uri.parse('${getBaseUrl()}/dosen/document-stats'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Gagal ambil data dokumen: ${response.body}');
        return {'data': {}};
      }
    } catch (e) {
      print('Error ambil dokumen dosen: $e');
      return {'data': {}};
    }
  }

  String getBaseUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    // For Android emulator and iOS simulator
    return Platform.isAndroid
        ? 'http://10.0.2.2:8000/api'
        : 'http://localhost:8000/api';
  }

  Future<Map<String, dynamic>> submitDocument({
    required String nomorSurat,
    required String tujuanPengajuan,
    required String hal,
    required List<int> fileBytes,
    required String fileName,
    String? catatan,
  }) async {
    try {
      final token = await _authService.getToken();

      if (token == null) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
        };
      }

      final baseUrl = AuthService.getBaseUrl();
      var uri = Uri.parse('$baseUrl/ormawa/documents/submit');

      var request = http.MultipartRequest('POST', uri);

      // Tambahkan header authorization
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Tambahkan field form
      request.fields['nomor_surat'] = nomorSurat;
      request.fields['tujuan_pengajuan'] = tujuanPengajuan;
      request.fields['hal'] = hal;
      if (catatan != null && catatan.isNotEmpty) {
        request.fields['catatan'] = catatan;
      }

      // Debug print untuk melihat file yang akan diunggah
      print('File name: $fileName');
      print('File size: ${fileBytes.length} bytes');

      // Tambahkan file
      var multipartFile = http.MultipartFile.fromBytes(
        'dokumen', // Menggunakan 'dokumen' sebagai field name
        fileBytes,
        filename: fileName,
      );
      request.files.add(multipartFile);

      print('Sending request to: $uri');
      print('Request fields: ${request.fields}');
      print('Request files: ${request.files.map((f) => f.filename).toList()}');

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      print('Response status: ${response.statusCode}');
      print('Response body: $responseBody');

      var data = jsonDecode(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Berhasil mengajukan dokumen',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal mengajukan dokumen',
        };
      }
    } catch (e, stackTrace) {
      print('Error in submitDocument: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Terjadi kesalahan: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> getDosenList() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
        };
      }

      final baseUrl = getBaseUrl();
      print('Fetching dosen from: $baseUrl/dosen'); // Debug print

      final response = await http.get(
        Uri.parse('$baseUrl/dosen'), // Changed from /ormawa/dosen to /dosen
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Dosen response status: ${response.statusCode}');
      print('Dosen response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData['data'] ??
              responseData, // Handle both response formats
        };
      }

      return {
        'success': false,
        'message': 'Gagal mengambil data dosen: ${response.statusCode}',
      };
    } catch (e) {
      print('Error in getDosenList: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getKemahasiswaanList() async {
    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/kemahasiswaan'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      }
      return {
        'success': false,
        'message': 'Gagal mengambil data kemahasiswaan',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan: $e',
      };
    }
  }
}