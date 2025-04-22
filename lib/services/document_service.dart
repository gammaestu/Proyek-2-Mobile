import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dio/dio.dart';

class DocumentService {
  final AuthService _authService = AuthService();
  late final Dio _dio;

  DocumentService() {
    _dio = Dio(BaseOptions(
      baseUrl: AuthService.getBaseUrl(),
    ));
    _setupDio();
  }

  Future<void> _setupDio() async {
    final token = await _authService.getToken();
    _dio.options.headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

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
            'perlu_revisi': 0,
            'sudah_direvisi': 0,
          }
        };
      }

      final baseUrl = AuthService.getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/ormawa/documents/stats'),
        headers: await _getHeaders(),
      );

      print('Response status: ${response.statusCode}');
      print('Raw response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Raw API Response: ${response.body}');
        print('Parsed data: $data');

        if (data['success']) {
          final stats = data['data'] as Map<String, dynamic>;
          print('Stats from backend (raw): $stats');
          print('Available keys in stats: ${stats.keys.toList()}');

          // Convert all values to integers
          final convertedStats = stats.map((key, value) {
            print('Converting key: $key, value: $value');
            return MapEntry(key, int.tryParse(value?.toString() ?? '0') ?? 0);
          });

          print('Final converted stats: $convertedStats');

          return {
            'success': true,
            'data': convertedStats,
          };
        }

        return {
          'success': false,
          'message': data['message'] ?? 'Gagal mendapatkan statistik dokumen',
          'data': {
            'submitted': 0,
            'signed': 0,
            'perlu_revisi': 0,
            'sudah_direvisi': 0,
          }
        };
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
          'perlu_revisi': 0,
          'sudah_direvisi': 0,
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

  Future<Map<String, dynamic>> getAllDocuments() async {
    try {
      await _setupDio();
      print('Fetching documents from API...');
      print('Token available: ${await _authService.getToken() != null}');

      final response = await _dio.get(
        '/ormawa/documents',
        options: Options(
          validateStatus: (status) =>
              true, // Accept all status codes for debugging
        ),
      );

      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');

      if (response.statusCode == 200) {
        if (response.data['success'] == true) {
          return {
            'success': true,
            'data': response.data['data'] ?? [],
            'message': response.data['message'] ?? 'Success',
          };
        } else {
          print('API returned success: false - ${response.data['message']}');
          return {
            'success': false,
            'message': response.data['message'] ?? 'Failed to load documents',
            'data': [],
          };
        }
      } else {
        print('Error response: ${response.data}');
        return {
          'success': false,
          'message': 'Failed to load documents: ${response.statusCode}',
          'data': [],
        };
      }
    } catch (e) {
      print('Error in getAllDocuments: $e');
      if (e is DioException) {
        print('DioError details: ${e.response?.data}');
        print('DioError message: ${e.message}');
        print('DioError type: ${e.type}');
        print('DioError requestOptions: ${e.requestOptions.path}');
      }
      return {
        'success': false,
        'message': e.toString(),
        'data': [],
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

  Future<Map<String, dynamic>> getDocumentsByStatus(String status) async {
    try {
      await _setupDio(); // Ensure token is up to date
      final response = await _dio
          .get('/ormawa/documents', queryParameters: {'status': status});
      return response.data;
    } catch (e) {
      print('Error in getDocumentsByStatus: $e');
      return {
        'success': false,
        'message': e.toString(),
        'data': [],
      };
    }
  }

  // Method untuk melihat detail dokumen
  Future<Map<String, dynamic>> getDocumentDetail(String documentId) async {
    try {
      final token = await _authService.getToken();

      if (token == null) {
        print('Token is null');
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
        };
      }

      final baseUrl = AuthService.getBaseUrl();
      final url = '$baseUrl/ormawa/documents/$documentId';
      print('Requesting document detail from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      print('Document detail response status: ${response.statusCode}');
      print('Document detail response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          print('Document detail retrieved successfully');
          return {
            'success': true,
            'data': data['data'],
          };
        }
        print('API returned success: false - ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal mendapatkan detail dokumen',
        };
      } else {
        print('Error response: ${response.body}');
        throw Exception(
            'Failed to load document detail: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getDocumentDetail: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Method untuk menandai dokumen perlu revisi
  Future<Map<String, dynamic>> markDocumentForRevision(
      String documentId, String keterangan) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${getBaseUrl()}/documents/$documentId/revision'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'keterangan': keterangan,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Gagal menandai dokumen untuk revisi',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Method untuk download dokumen
  Future<Map<String, dynamic>> downloadDocument(String documentId) async {
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/documents/$documentId/download'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.bodyBytes,
          'filename': response.headers['content-disposition'] ?? 'document.pdf',
        };
      } else {
        return {
          'success': false,
          'message': 'Gagal mengunduh dokumen',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Method untuk menambah QR code
  Future<Map<String, dynamic>> addQrCode(
      String documentId, Map<String, dynamic> position) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${getBaseUrl()}/documents/$documentId/qr-code'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'position': position,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Gagal menambahkan QR code',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Method untuk verifikasi dokumen
  Future<Map<String, dynamic>> verifyDocument(String documentId) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${getBaseUrl()}/documents/$documentId/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Gagal memverifikasi dokumen',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> getDocumentFile(String documentId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
        };
      }

      final response = await _dio.get(
        '/ormawa/documents/$documentId/file',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final bytes = response.data as List<int>;
        final base64String = base64Encode(bytes);

        return {
          'success': true,
          'data': base64String,
        };
      } else {
        return {
          'success': false,
          'message': 'Gagal mengambil file dokumen',
        };
      }
    } catch (e) {
      print('Error in getDocumentFile: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}
