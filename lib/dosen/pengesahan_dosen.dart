import 'package:flutter/material.dart';
import '../component/navbar_dosen.dart';
import 'dart:convert';
import 'dart:typed_data'; // Import for Uint8List
import 'package:http/http.dart' as http;
import '../services/document_service.dart';
import 'pdf_viewer_page.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'qr_code_positioning_screen.dart';
import 'document_verification_screen.dart';

class DosenPengesahanPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const DosenPengesahanPage({super.key, this.userData});

  @override
  State<DosenPengesahanPage> createState() => _DosenPengesahanPageState();
}

class _DosenPengesahanPageState extends State<DosenPengesahanPage> {
  final int _selectedIndex = 1;
  final _documentService = DocumentService();
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;

  final Map<String, String> _statusOptions = {
    'Semua': 'Semua',
    'diajukan': 'Diajukan',
    'sudah_direvisi': 'Sudah Direvisi',
    'disahkan': 'Disahkan',
    'ditandatangani': 'Ditandatangani',
  };

  String _selectedStatusFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _fetchDocuments(); // Panggil fungsi baru
  }

  Future<void> _fetchDocuments() async {
    setState(() => _isLoading = true);

    try {
      final result = await _documentService.getAllDocuments();
      if (mounted) {
        final allDocuments =
            List<Map<String, dynamic>>.from(result['data'] ?? []);
        final filtered = _filterPendingDocuments(allDocuments);

        setState(() {
          _documents = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _documents = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _filterPendingDocuments(
      List<Map<String, dynamic>> docs) {
    return docs.where((doc) {
      final status = doc['status']?.toString().toLowerCase();
      return status == 'diajukan' ||
          status == 'sudah_direvisi' ||
          status == 'disahkan' ||
          status == 'ditandatangani';
    }).toList();
  }

  List<Map<String, dynamic>> _filteredDocuments() {
    if (_selectedStatusFilter == 'Semua') return _documents;
    return _documents.where((doc) {
      final status = (doc['status'] ?? '').toString().toLowerCase().trim();
      return status == _selectedStatusFilter;
    }).toList();
  }

  void _showDocumentDetail(
      BuildContext context, Map<String, dynamic> document) {
    final bool isSubmitted = document['status'] == 'diajukan';
    final bool isRevisi = document['status'] == 'perlu_revisi';
    final bool isSudahDirevisi = document['status'] == 'sudah_direvisi';
    final bool isSigned = document['status'] == 'ditandatangani';
    final String docId = document['id'].toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Detail Dokumen'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nomor Surat: ${document['nomor_surat'] ?? '-'}'),
                Text('Hal: ${document['hal'] ?? '-'}'),
                Text('Tujuan: ${document['tujuan_pengajuan'] ?? '-'}'),
                Text(
                  'Status: ${_formatStatus(document['status'])}',
                  style: TextStyle(
                    color: _getStatusColor(document['status']),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('Pengaju: ${document['namaMahasiswa'] ?? '-'}'),
                if (document['keterangan'] != null)
                  Text('Keterangan: ${document['keterangan']}'),
                Text('Tanggal Pengajuan: ${document['created_at'] ?? '-'}'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      child: ElevatedButton(
                        onPressed: () {
                          // Close dialog first then view document
                          Navigator.pop(context);
                          _viewDocumentWithActions(
                              docId, isSubmitted || isSudahDirevisi);
                        },
                        child: const Text('Lihat'),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _markForRevision(document['id']);
                        },
                        child: const Text('Revisi'),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadDocument(document['id']);
                        },
                        child: const Text('Download'),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: ElevatedButton(
                        onPressed: (isSubmitted || isSudahDirevisi)
                            ? () {
                                Navigator.pop(context);
                                _addQrCode(document['id']);
                              }
                            : null,
                        child: const Text('QR Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (isSubmitted || isSudahDirevisi)
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                    ),
                    if (isSigned)
                      SizedBox(
                        width: 100,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _verifyDocument(docId);
                          },
                          child: const Text('Verifikasi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Tanggal Disetujui: ${document['updated_at'] ?? '-'}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _viewDocument(String documentId) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Memuat dokumen...")
              ],
            ),
          );
        },
      );

      print('=== MULAI MEMUAT PDF ===');
      print('Document ID: $documentId');

      // Panggil API untuk mendapatkan file PDF
      final response = await _documentService.getDocumentFile(documentId);
      print('Response dari server:');
      print('Success: ${response['success']}');
      print('Message: ${response['message']}');
      print('Data length: ${response['data']?.length ?? 0}');

      // Close loading dialog
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (response['success'] == true && response['data'] != null) {
        final base64String = response['data'] as String;
        print('Panjang string base64: ${base64String.length}');

        if (base64String.isEmpty) {
          throw Exception('Data PDF kosong');
        }

        // Sanitize base64 string to ensure it's valid
        String sanitizedBase64 = base64String.trim();
        // Remove data URL prefix if present (e.g. "data:application/pdf;base64,")
        if (sanitizedBase64.contains(',')) {
          sanitizedBase64 = sanitizedBase64.split(',').last;
        }

        Uint8List bytes;
        try {
          bytes = base64.decode(sanitizedBase64);
          print('Panjang bytes yang didecode: ${bytes.length}');
        } catch (e) {
          print('Base64 decode error: $e');
          _showMessage('Error decoding PDF data: ${e.toString()}');
          return;
        }

        if (!mounted) return;

        // Use the improved PDFViewerPage to display the document
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFViewerPage(
              pdfBytes: bytes,
              title: 'Dokumen PDF',
            ),
          ),
        );
      } else {
        print('=== ERROR RESPONSE SERVER ===');
        print('Message: ${response['message']}');

        // Show error dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Gagal Memuat Dokumen'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Server tidak dapat memberikan dokumen:'),
                    SizedBox(height: 10),
                    Text(
                      response['message'] ?? 'Format response tidak valid',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('=== ERROR UMUM ===');
      print('Error: $e');
      print('Stack trace: ${StackTrace.current}');

      // Close loading dialog if it's showing
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka dokumen: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('=== SELESAI MEMUAT PDF ===');
    }
  }

  Future<void> _markForRevision(String documentId) async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keterangan Revisi'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration:
              const InputDecoration(hintText: 'Masukkan keterangan revisi'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              if (controller.text.isEmpty) {
                _showMessage('Keterangan revisi tidak boleh kosong');
                return;
              }

              try {
                final response = await http.post(
                  Uri.parse(
                      '${_documentService.getBaseUrl()}/dosen/documents/$documentId/revisi'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'keterangan': controller.text}),
                );
                final result = jsonDecode(response.body);
                Navigator.pop(context);

                if (result['success']) {
                  _showMessage('Dokumen berhasil ditandai untuk revisi');
                  _fetchDocuments();
                } else {
                  _showMessage(result['message'] ?? 'Gagal menyimpan revisi');
                }
              } catch (e) {
                _showMessage('Error: ${e.toString()}');
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadDocument(String documentId) async {
    try {
      final result = await _documentService.downloadDocument(documentId);
      if (result['success']) {
        print('Download document: ${result['filename']}');
      } else {
        _showMessage(result['message'] ?? 'Gagal mengunduh dokumen');
      }
    } catch (e) {
      _showMessage('Error: ${e.toString()}');
    }
  }

  Future<void> _addQrCode(String documentId) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Memuat dokumen...")
              ],
            ),
          );
        },
      );

      print('=== START QR CODE FLOW ===');
      print('Document ID type: ${documentId.runtimeType}');
      print('Document ID: $documentId');

      // Ensure documentId is a string
      final String docIdString = documentId.toString();
      print('Document ID after toString(): $docIdString');

      // First, get the document to preview
      final docResponse = await _documentService.getDocumentFile(docIdString);
      print('Document file response success: ${docResponse['success']}');
      print('Document file response: $docResponse');

      // Close loading dialog
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (!docResponse['success']) {
        _showMessage(docResponse['message'] ?? 'Gagal memuat dokumen');
        return;
      }

      final base64String = docResponse['data'] as String;
      print('Base64 string length: ${base64String.length}');

      if (base64String.isEmpty) {
        _showMessage('Data PDF kosong');
        return;
      }

      // Sanitize base64 string to ensure it's valid
      String sanitizedBase64 = base64String.trim();
      // Remove data URL prefix if present (e.g. "data:application/pdf;base64,")
      if (sanitizedBase64.contains(',')) {
        sanitizedBase64 = sanitizedBase64.split(',').last;
      }

      Uint8List bytes;
      try {
        bytes = base64.decode(sanitizedBase64);
        print('Decoded bytes length: ${bytes.length}');
      } catch (e) {
        print('Base64 decode error: $e');
        print(
            'First 100 chars of base64: ${sanitizedBase64.substring(0, sanitizedBase64.length > 100 ? 100 : sanitizedBase64.length)}');

        _showMessage('Error decoding PDF data: ${e.toString()}');
        return;
      }

      if (bytes.isEmpty) {
        _showMessage('Decoded PDF data kosong');
        return;
      }

      if (!mounted) return;

      print('Navigating to QR code positioning screen...');

      // Navigate to QR code positioning screen - use push instead of await Navigator.push
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QrCodePositioningScreen(
            documentId: docIdString,
            documentBytes: bytes,
          ),
        ),
      ).then((result) {
        print('Returned from QR code screen with result: $result');

        if (result == true) {
          // Force refresh the documents list to show updated status
          _fetchDocuments();
          _showMessage('Dokumen berhasil ditandatangani dan disahkan',
              isSuccess: true);
        }
      });
    } catch (e) {
      // Close loading dialog if it's showing
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Error in _addQrCode: $e');
      print('Stack trace: ${StackTrace.current}');

      // Show detailed error dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Terjadi kesalahan saat memuat dokumen:'),
                  SizedBox(height: 10),
                  Text(e.toString(),
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          );
        },
      );

      _showMessage('Error: ${e.toString()}');
    }
  }

  void _showMessage(String message, {bool isSuccess = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : null,
        duration: Duration(seconds: isSuccess ? 3 : 2),
      ));
    }
  }

  Future<void> _downloadPdf(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      print('HTTP Status Code: ${response.statusCode}');
      if (response.statusCode == 200) {
        // File berhasil diunduh
      } else {
        print('Error: ${response.reasonPhrase}');
        throw Exception('Failed to download PDF');
      }
    } catch (e) {
      _showMessage('Error: ${e.toString()}');
    }
  }

  Future<void> _verifyDocument(String documentId) async {
    try {
      final result = await _documentService.verifyDocument(documentId);

      if (result['success']) {
        // Show verification screen
        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentVerificationScreen(
              documentId: documentId,
              verificationData: result['data'],
            ),
          ),
        );
      } else {
        _showMessage(result['message'] ?? 'Gagal memverifikasi dokumen');
      }
    } catch (e) {
      _showMessage('Error: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _fetchDocuments,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Perlu Pengesahan",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text("Filter: "),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _selectedStatusFilter,
                    items: _statusOptions.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedStatusFilter = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_filteredDocuments().isEmpty)
                const Center(child: Text('Tidak ada dokumen'))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _documents.length,
                    itemBuilder: (_, index) {
                      final doc = _documents[index];
                      return _buildDocumentCard(doc);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavbarDosen(
        currentIndex: _selectedIndex,
        userData: widget.userData,
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.blue,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("SIGNIX",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          Row(
            children: [
              Text(widget.userData?['nama'] ?? "Dosen",
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(width: 10),
              const CircleAvatar(
                backgroundColor: Colors.white,
                radius: 16,
                child: Icon(Icons.person, color: Colors.blue, size: 20),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // DEBUG: Debug button to open the API configuration dialog
        IconButton(
          icon: Icon(Icons.settings, color: Colors.white),
          onPressed: _showDebugInfoDialog,
        ),
      ],
    );
  }

  // Debug method to show connection info and allow testing QR code flow
  void _showDebugInfoDialog() {
    final baseUrl = _documentService.getBaseUrl();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Debug Info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('API URL: $baseUrl'),
              SizedBox(height: 16),
              Text('Server connection:'),
              SizedBox(height: 8),
              _buildServerTestButton(),
              SizedBox(height: 16),
              Text('Test QR code flow:'),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  // Use the first document if available
                  if (_documents.isNotEmpty) {
                    String docId = _documents.first['id'].toString();
                    _addQrCode(docId);
                  } else {
                    _showMessage('Tidak ada dokumen untuk diuji');
                  }
                },
                child: Text('Uji QR Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildServerTestButton() {
    return ElevatedButton(
      onPressed: () async {
        try {
          final url = '${_documentService.getBaseUrl()}/ping';
          final response =
              await http.get(Uri.parse(url)).timeout(Duration(seconds: 5));

          String message = 'Server merespon: ${response.statusCode}';
          if (response.statusCode == 200) {
            message += '\nServer online dan merespon!';
          }

          _showMessage(message, isSuccess: response.statusCode == 200);
        } catch (e) {
          _showMessage('Gagal terhubung ke server: ${e.toString()}');
        }
      },
      child: Text('Tes koneksi server'),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'diajukan':
        return Colors.orange;
      case 'ditandatangani':
      case 'disahkan':
        return Colors.green;
      case 'perlu_revisi':
      case 'butuh revisi':
        return Colors.red;
      case 'sudah_direvisi':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDocumentCard(Map<String, dynamic> document) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        title: Text(
          document['nomor_surat'] ?? 'No. Surat tidak ada',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hal: ${document['hal'] ?? '-'}'),
            Text(
              'Status: ${_formatStatus(document['status'])}',
              style: TextStyle(
                color: _getStatusColor(document['status']),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _showDocumentDetail(context, document),
          child: const Text('Detail'),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'diajukan':
        return 'Diajukan';
      case 'sudah_direvisi':
        return 'Sudah Direvisi';
      case 'ditandatangani':
        return 'Ditandatangani';
      case 'disahkan':
        return 'Disahkan';
      case 'perlu_revisi':
        return 'Perlu Revisi';
      case 'butuh revisi':
        return 'Butuh Revisi';
      default:
        return 'Tidak Diketahui';
    }
  }

  // Method for document viewing with QR code action button
  Future<void> _viewDocumentWithActions(
      String documentId, bool canAddQrCode) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Memuat dokumen...")
              ],
            ),
          );
        },
      );

      print('=== MULAI MEMUAT PDF DENGAN AKSI ===');
      print('Document ID: $documentId');

      // Panggil API untuk mendapatkan file PDF
      final response = await _documentService.getDocumentFile(documentId);
      print('Response dari server:');
      print('Success: ${response['success']}');
      print('Message: ${response['message']}');
      print('Data length: ${response['data']?.length ?? 0}');

      // Close loading dialog
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (response['success'] == true && response['data'] != null) {
        final base64String = response['data'] as String;
        print('Panjang string base64: ${base64String.length}');

        if (base64String.isEmpty) {
          throw Exception('Data PDF kosong');
        }

        // Sanitize base64 string to ensure it's valid
        String sanitizedBase64 = base64String.trim();
        // Remove data URL prefix if present (e.g. "data:application/pdf;base64,")
        if (sanitizedBase64.contains(',')) {
          sanitizedBase64 = sanitizedBase64.split(',').last;
        }

        Uint8List bytes;
        try {
          bytes = base64.decode(sanitizedBase64);
          print('Panjang bytes yang didecode: ${bytes.length}');
        } catch (e) {
          print('Base64 decode error: $e');
          _showMessage('Error decoding PDF data: ${e.toString()}');
          return;
        }

        if (!mounted) return;

        // Create a custom PDF viewer with QR code button
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Dokumen PDF'),
                actions: canAddQrCode
                    ? [
                        // Add QR code button if document can have QR code
                        IconButton(
                          icon: Icon(Icons.qr_code),
                          tooltip: 'Tambahkan QR Code',
                          onPressed: () {
                            Navigator.pop(context); // Close PDF viewer
                            _addQrCode(
                                documentId); // Open QR Code positioning screen
                          },
                        ),
                      ]
                    : null,
              ),
              body: SfPdfViewer.memory(
                bytes,
                enableDocumentLinkAnnotation: true,
                enableHyperlinkNavigation: true,
                pageSpacing: 0,
                onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                  print('=== ERROR PDF VIEWER ===');
                  print('Error: ${details.error}');
                  print('Description: ${details.description}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal memuat PDF: ${details.description}'),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      } else {
        print('=== ERROR RESPONSE SERVER ===');
        print('Message: ${response['message']}');

        // Show error dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Gagal Memuat Dokumen'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Server tidak dapat memberikan dokumen:'),
                    SizedBox(height: 10),
                    Text(
                      response['message'] ?? 'Format response tidak valid',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('=== ERROR UMUM ===');
      print('Error: $e');
      print('Stack trace: ${StackTrace.current}');

      // Close loading dialog if it's showing
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka dokumen: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('=== SELESAI MEMUAT PDF DENGAN AKSI ===');
    }
  }
}
