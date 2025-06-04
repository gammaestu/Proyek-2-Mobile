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
      final token = await _authService.getToken();
      print('Token untuk stats dosen: $token'); // Debug print

      final baseUrl = getBaseUrl();
      print(
          'URL untuk stats dosen: $baseUrl/dosen/document-stats'); // Debug print

      final response = await http.get(
        Uri.parse('$baseUrl/dosen/document-stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Response status: ${response.statusCode}'); // Debug print
      print('Response body: ${response.body}'); // Debug print

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': {
            'diajukan': data['data']['diajukan'] ?? 0,
            'disahkan': data['data']['disahkan'] ?? 0,
            'butuh revisi': data['data']['butuh revisi'] ?? 0,
            'sudah direvisi': data['data']['sudah direvisi'] ?? 0,
          }
        };
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return {'success': false, 'data': {}};
      }
    } catch (e) {
      print('Error dalam getDocumentStatsForDosen: $e');
      return {'success': false, 'data': {}};
    }
  }

  static String getBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:8000/api';
    }
    if (Platform.isAndroid) {
      // Untuk emulator Android
      if (Platform.environment.containsKey('ANDROID_EMU_REDIRECT_TO_HOST')) {
        return 'http://10.0.2.2:8000/api';
      }
      // Untuk device fisik, gunakan IP komputer Anda
      return 'http://192.168.35.8:8000/api'; // Ganti dengan IP komputer Anda
    }
    return 'http://localhost:8000/api';
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
      final role = await _getUserType(); // Get user role
      print('Fetching documents for role: $role');

      // Pilih endpoint berdasarkan role
      final endpoint =
          role == 'dosen' ? '/dosen/documents' : '/ormawa/documents';

      final response = await _dio.get(
        endpoint,
        options: Options(
          headers: {
            'X-User-Type': role, // Tambahkan header X-User-Type
          },
          validateStatus: (status) => true,
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
      return {
        'success': false,
        'message': e.toString(),
        'data': [],
      };
    }
  }

  // Helper method to get user type
  Future<String> _getUserType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_type') ?? 'unknown';
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
      if (token == null) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
        };
      }

      final response = await _dio.get(
        '/dosen/documents/$documentId/download',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/pdf',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        String fileName = 'document_$documentId.pdf';
        if (response.headers.map.containsKey('content-disposition')) {
          final disposition = response.headers.value('content-disposition');
          if (disposition != null && disposition.contains('filename=')) {
            fileName = disposition.split('filename=').last.replaceAll('"', '');
          }
        }

        return {
          'success': true,
          'data': response.data,
          'filename': fileName,
        };
      }

      return {
        'success': false,
        'message': 'Gagal mengunduh dokumen: ${response.statusCode}',
      };
    } catch (e) {
      print('Error in downloadDocument: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // New direct method using multipart form data
  Future<Map<String, dynamic>> multipartApproveDocument(
      String documentId, String x, String y, String page, String size) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak ditemukan'};
      }

      // Get base URL for the API
      final baseUrl = getBaseUrl();
      final endpoint = '$baseUrl/dosen/documents/$documentId/approve';

      print('Making multipart form request to: $endpoint');

      // Create verification URL for QR code
      final verificationUrl = getVerificationUrl(documentId);

      // Create a multipart request
      var request = http.MultipartRequest('POST', Uri.parse(endpoint));

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Add form fields - trying different formats for the position data
      // Format 1: Nested fields using bracket notation
      request.fields['qr_position[x]'] = x.trim();
      request.fields['qr_position[y]'] = y.trim();
      request.fields['qr_position[page]'] = page.trim();
      request.fields['qr_position[size]'] = size.trim();

      // Add data_qr field - try both formats
      request.fields['data_qr'] = jsonEncode({"url": verificationUrl});

      print('Sending multipart request with fields: ${request.fields}');

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Multipart response status: ${response.statusCode}');
      print('Multipart response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Dokumen berhasil disahkan'};
      }

      // If failed, try with flat field structure
      print('First multipart attempt failed, trying flat structure...');

      var request2 = http.MultipartRequest('POST', Uri.parse(endpoint));
      request2.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Format 2: Flat fields
      request2.fields['x'] = x.trim();
      request2.fields['y'] = y.trim();
      request2.fields['page'] = page.trim();
      request2.fields['size'] = size.trim();
      request2.fields['data_qr'] = verificationUrl; // Use plain URL

      print('Sending second multipart request with fields: ${request2.fields}');

      final streamedResponse2 = await request2.send();
      final response2 = await http.Response.fromStream(streamedResponse2);

      print('Second multipart response status: ${response2.statusCode}');
      print('Second multipart response body: ${response2.body}');

      if (response2.statusCode == 200 || response2.statusCode == 201) {
        return {'success': true, 'message': 'Dokumen berhasil disahkan'};
      }

      // Extract error message if possible
      String errorMessage = "Gagal mengesahkan dokumen";
      try {
        final errorData = jsonDecode(response2.body);
        errorMessage = errorData['message'] ?? errorMessage;
      } catch (e) {
        // Use default message
      }

      return {'success': false, 'message': errorMessage};
    } catch (e) {
      print('Error in multipartApproveDocument: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Direct HTTP POST method for document approval - bypassing Dio
  Future<Map<String, dynamic>> directApproveDocument(
      String documentId, String x, String y, String page, String size) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak ditemukan'};
      }

      // Get base URL for the API
      final baseUrl = getBaseUrl();
      final endpoint = '$baseUrl/dosen/documents/$documentId/approve';

      print('Making direct HTTP POST request to: $endpoint');

      // Create verification URL for QR code - ensure it's properly formatted and encoded
      final verificationUrl = getVerificationUrl(documentId);
      final qrData = jsonEncode({"url": verificationUrl});

      // Create request body - streamline to use the simplest structure that's most likely to work
      final Map<String, String> body = {
        'qr_position[x]': x.trim(),
        'qr_position[y]': y.trim(),
        'qr_position[page]': page.trim(),
        'qr_position[size]': size.trim(),
        'data_qr': qrData
      };

      print('Request body: $body');

      // Make direct HTTP request
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type':
              'application/x-www-form-urlencoded', // Use form URL encoded
        },
        body: body,
      );

      print('Direct HTTP response status: ${response.statusCode}');
      print('Direct HTTP response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic> responseData = {};
        try {
          responseData = jsonDecode(response.body);
          if (responseData['success'] == true) {
            return {'success': true, 'message': 'Dokumen berhasil disahkan'};
          }
        } catch (e) {
          print('Error parsing response: $e');
        }

        // Even if parsing fails, assume success based on status code
        return {'success': true, 'message': 'Dokumen berhasil disahkan'};
      }

      // Try a different approach with raw URL instead of JSON object
      print('Direct method failed, trying with raw URL as data_qr...');

      final simplestBody = {
        'qr_position[x]': x.trim(),
        'qr_position[y]': y.trim(),
        'qr_position[page]': page.trim(),
        'qr_position[size]': size.trim(),
        'data_qr': verificationUrl
      };

      final simplestResponse = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: simplestBody,
      );

      if (simplestResponse.statusCode == 200 ||
          simplestResponse.statusCode == 201) {
        return {'success': true, 'message': 'Dokumen berhasil disahkan'};
      }

      // If all attempts failed, return error message
      String errorMessage = "Gagal mengesahkan dokumen";
      try {
        final errorData = jsonDecode(simplestResponse.body);
        errorMessage = errorData['message'] ?? errorMessage;
      } catch (e) {
        // Use default message
      }

      return {'success': false, 'message': errorMessage};
    } catch (e) {
      print('Error in directApproveDocument: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Update approveDocumentWithQrData to try the direct HTTP method first
  Future<Map<String, dynamic>> approveDocumentWithQrData(
      String documentId, String x, String y, String page, String size) async {
    try {
      // First try with multipart form-data method
      final multipartResult =
          await multipartApproveDocument(documentId, x, y, page, size);
      if (multipartResult['success'] == true) {
        return multipartResult;
      }

      // Then try with direct HTTP method
      final directResult =
          await directApproveDocument(documentId, x, y, page, size);
      if (directResult['success'] == true) {
        return directResult;
      }

      // If direct method failed, try with the original approaches
      final token = await _authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak ditemukan'};
      }

      // Based on the error logs, we need to provide a value for data_qr
      // Create a default QR data string if none is available
      final defaultQrData = '{"url":"${getVerificationUrl(documentId)}"}';

      // Define multiple attempts with different data structures
      final List<dynamic> attempts = [
        // Attempt 1: Direct qr_position and data_qr
        {
          'qr_position': {
            'x': x,
            'y': y,
            'page': page,
            'size': size,
          },
          'data_qr': defaultQrData
        },

        // Attempt 2: Flat structure
        {'x': x, 'y': y, 'page': page, 'size': size, 'data_qr': defaultQrData},

        // Attempt 3: Direct properties under qr_position
        {
          'qr_position': {
            'x': x,
            'y': y,
            'page': page,
            'size': size,
            'data_qr': defaultQrData
          }
        },

        // Attempt 4: Use FormData approach
        () async {
          return FormData.fromMap({
            'qr_position[x]': x,
            'qr_position[y]': y,
            'qr_position[page]': page,
            'qr_position[size]': size,
            'data_qr': defaultQrData
          });
        }
      ];

      // Setup options
      final options = Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        validateStatus: (status) =>
            true, // Accept all status codes for debugging
      );

      // Try each attempt
      for (int i = 0; i < attempts.length; i++) {
        try {
          print('Attempting approach ${i + 1}');
          dynamic data = attempts[i];

          // Handle function that returns FormData
          if (data is Function) {
            data = await data();
            // Override content type for FormData
            options.headers?['Content-Type'] = 'multipart/form-data';
          } else {
            options.headers?['Content-Type'] = 'application/json';
          }

          final response = await _dio.post(
            '/dosen/documents/$documentId/approve',
            data: data,
            options: options,
          );

          print(
              'Response for attempt ${i + 1}: status=${response.statusCode}, data=${response.data}');

          if (response.statusCode == 200 ||
              response.statusCode == 201 ||
              (response.data is Map && response.data['success'] == true)) {
            print('Attempt ${i + 1} successful!');
            return {'success': true, 'message': 'Dokumen berhasil disahkan'};
          }
        } catch (e) {
          print('Error in attempt ${i + 1}: $e');
        }
      }

      // If all attempts failed, return error
      return {
        'success': false,
        'message': 'Gagal mengesahkan dokumen, server mungkin sedang bermasalah'
      };
    } catch (e) {
      print('Error in approveDocumentWithQrData: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Override approveDocument to use our new direct method first
  Future<Map<String, dynamic>> approveDocument(String documentId, String x,
      String y, String page, String size, String? qrImage) async {
    try {
      // First try with the direct method that addresses the data_qr field requirement
      final result =
          await approveDocumentWithQrData(documentId, x, y, page, size);
      if (result['success'] == true) {
        return result;
      }

      // If that failed and we have a QR image, try with the image
      if (qrImage != null) {
        // Try with the QR image included
        final token = await _authService.getToken();
        if (token == null) {
          return {'success': false, 'message': 'Token tidak ditemukan'};
        }

        final defaultQrData = '{"url":"${getVerificationUrl(documentId)}"}';

        // Create payload with both position and QR data
        final payload = {
          'x': x,
          'y': y,
          'page': page,
          'size': size,
          'data_qr': defaultQrData,
          'qr_image': qrImage
        };

        final options = Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => true,
        );

        final response = await _dio.post(
          '/dosen/documents/$documentId/approve',
          data: payload,
          options: options,
        );

        if (response.statusCode == 200 ||
            response.statusCode == 201 ||
            (response.data is Map && response.data['success'] == true)) {
          return {'success': true, 'message': 'Dokumen berhasil disahkan'};
        }
      }

      // If all attempts failed
      return {
        'success': false,
        'message': 'Gagal mengesahkan dokumen. Coba lagi nanti.'
      };
    } catch (e) {
      print('Error in approveDocument: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getDocumentFile(String documentId,
      {String role = 'dosen'}) async {
    try {
      final token = await _authService.getToken();
      print('Getting document file for ID: $documentId with role: $role');

      if (token == null) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
        };
      }

      // Tentukan endpoint berdasarkan role
      final endpoint = '/$role/documents/$documentId/view';
      print('Using endpoint: $endpoint');

      final response = await _dio.get(
        endpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/pdf',
          },
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 180),
          sendTimeout: const Duration(seconds: 180),
        ),
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.data,
        };
      }

      return {
        'success': false,
        'message': 'Gagal mengambil file: ${response.statusCode}'
      };
    } catch (e) {
      print('Error getting document file: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

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

  Future<String?> getDocumentFileUrl(String documentId) async {
    final baseUrl = getBaseUrl(); // misalnya https://yourdomain.com/api
    try {
      final url = '$baseUrl/documents/$documentId/file';
      return url;
    } catch (e) {
      print('Error generating file URL: $e');
      return null;
    }
  }

  // Get verification URL for a document
  static String getVerificationUrl(String documentId) {
    final baseUrl = getBaseUrl().replaceAll('/api', '');
    // Ensure the base URL doesn't have trailing slashes
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$cleanBaseUrl/verify/$documentId';
  }

  // Method untuk upload revisi dokumen
  Future<Map<String, dynamic>> uploadRevisiDocument({
    required String documentId,
    required List<int> fileBytes,
    required String fileName,
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
      var uri =
          Uri.parse('$baseUrl/ormawa/documents/' + documentId + '/revisi');
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      var multipartFile = http.MultipartFile.fromBytes(
        'dokumen',
        fileBytes,
        filename: fileName,
      );
      request.files.add(multipartFile);

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = jsonDecode(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Berhasil update dokumen revisi',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal update dokumen revisi',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan: ${e.toString()}',
      };
    }
  }

  // Method untuk menambah QR code
  Future<Map<String, dynamic>> addQrCode(
      String documentId, Map<String, dynamic> position) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak ditemukan'};
      }

      final baseUrl = getBaseUrl();
      final url = Uri.parse('$baseUrl/dosen/documents/$documentId/approve');

      // Create verification URL for QR code
      final verificationUrl = '$baseUrl/verify/$documentId';

      // Format position data correctly
      final requestData = {
        'qr_position_x': position['x'].toString(),
        'qr_position_y': position['y'].toString(),
        'qr_position_page': (position['page'] ?? 1).toString(),
        'qr_position_size': position['size'].toString(),
        'data_qr': verificationUrl,
      };

      print('Sending request to: $url');
      print('Request data: $requestData');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: requestData,
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'QR Code berhasil ditambahkan'};
      }

      final errorMsg = response.body.isNotEmpty
          ? jsonDecode(response.body)['message']
          : 'Gagal menambahkan QR Code';
      return {'success': false, 'message': errorMsg};
    } catch (e) {
      print('Error in addQrCode: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> generateQrCodeForDocument(
      String documentId) async {
    try {
      await _setupDio();
      print('Generating QR code for document: $documentId'); // Debug log

      final response = await _dio.post(
        '/dosen/dokumen/$documentId/generate-qr',
        options: Options(
          validateStatus: (status) =>
              true, // Accept all status codes for debugging
        ),
      );

      print('Generate QR response status: ${response.statusCode}'); // Debug log
      print('Generate QR response data: ${response.data}'); // Debug log

      if (response.statusCode == 200) {
        if (response.data['success'] == true) {
          return {
            'success': true,
            'qr_code_url': response.data['qr_code_url'],
            'message': response.data['message'] ?? 'Kode QR berhasil dibuat.',
          };
        } else {
          return {
            'success': false,
            'message': response.data['message'] ??
                'Server mengembalikan status error.',
          };
        }
      } else {
        final message = response.data is Map
            ? response.data['message'] ??
                'Gagal membuat kode QR (${response.statusCode})'
            : 'Gagal membuat kode QR (${response.statusCode})';
        return {
          'success': false,
          'message': message,
        };
      }
    } catch (e) {
      print('Error in generateQrCodeForDocument: $e'); // Debug log
      return {
        'success': false,
        'message': 'Terjadi kesalahan saat membuat kode QR: ${e.toString()}',
      };
    }
  }

  // Fungsi untuk mengirim informasi penempatan QR ke server agar ditempelkan ke PDF
  Future<Map<String, dynamic>> embedQrCodeOnDocument({
    required String documentId,
    required double xPercent,
    required double yPercent,
    required double widthPercent,
    required double heightPercent,
    required int pageNumber,
  }) async {
    try {
      await _setupDio();

      // Format data sesuai dengan ekspektasi backend
      final Map<String, dynamic> payload = {
        'x_percent': xPercent,
        'y_percent': yPercent,
        'width_percent': widthPercent,
        'height_percent': heightPercent,
        'page_number': pageNumber,
        'qr_data': {
          'url': getVerificationUrl(documentId),
        },
        'document_id': documentId,
      };

      print('Embedding QR code for document: $documentId'); // Debug log
      print('Payload: $payload'); // Debug log

      final response = await _dio.post(
        '/dosen/dokumen/$documentId/embed-qr',
        data: payload,
        options: Options(
          validateStatus: (status) => true,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      print('Embed QR response status: ${response.statusCode}'); // Debug log
      print('Embed QR response data: ${response.data}'); // Debug log

      if (response.statusCode == 200) {
        if (response.data['success'] == true) {
          return {
            'success': true,
            'message':
                response.data['message'] ?? 'QR Code berhasil ditempelkan',
            'signed_document_url': response.data['signed_document_url'],
          };
        } else {
          return {
            'success': false,
            'message':
                response.data['message'] ?? 'Server mengembalikan status error',
          };
        }
      } else {
        String errorMsg = 'Gagal menempelkan QR Code';
        if (response.data is Map && response.data['message'] != null) {
          errorMsg = response.data['message'];
        }
        return {
          'success': false,
          'message': '$errorMsg (${response.statusCode})',
        };
      }
    } catch (e) {
      print('Error in embedQrCodeOnDocument: $e'); // Debug log
      return {
        'success': false,
        'message':
            'Terjadi kesalahan saat menempelkan QR Code: ${e.toString()}',
      };
    }
  }
}
