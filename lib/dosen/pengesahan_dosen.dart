import 'package:flutter/material.dart';
import '../component/navbar_dosen.dart';
import '../component/appbar_dosen.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../services/document_service.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'dart:math' show min;
import 'package:open_file/open_file.dart';
import '../services/auth_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'qr_placement_page.dart';

class DosenPengesahanPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final String? initialStatusFilter;
  const DosenPengesahanPage({super.key, this.userData, this.initialStatusFilter});

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
    'sudah direvisi': 'Sudah Direvisi',
  };

  String _selectedStatusFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _selectedStatusFilter = widget.initialStatusFilter ?? 'Semua';
    _fetchDocuments(); // Panggil fungsi baru
  }

  Future<void> _fetchDocuments() async {
    setState(() => _isLoading = true);

    try {
      final result = await _documentService.getAllDocuments();
      if (mounted) {
        if (result['success'] == true) {
          final allDocuments = List<Map<String, dynamic>>.from(result['data'] ?? []);
          setState(() {
            _documents = allDocuments;
            _isLoading = false;
          });
          print('Dokumen berhasil dimuat: ${_documents.length}'); // Debug print
        } else {
          throw Exception(result['message'] ?? 'Gagal mengambil data');
        }
      }
    } catch (e) {
      print('Error dalam _fetchDocuments: $e'); // Debug print
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

  List<Map<String, dynamic>> _filterPendingDocuments(List<Map<String, dynamic>> docs) {
    return docs.where((doc) {
      final status = (doc['status'] ?? '').toString().toLowerCase().trim();
      print('Filtering document with status: $status'); // Debug print
      // Perbaiki kondisi untuk mencakup 'sudah direvisi'
      return status == 'diajukan' || status == 'sudah direvisi' || status == 'sudah_direvisi';
    }).toList();
  }

  List<Map<String, dynamic>> _filteredDocuments() {
    if (_selectedStatusFilter == 'Semua') return _documents;
    
    return _documents.where((doc) {
      final status = (doc['status'] ?? '').toString().toLowerCase().trim();
      // Normalisasi status dari database
      final normalizedStatus = status.replaceAll(' ', '_');
      print('Status from DB: $status');
      print('Normalized status: $normalizedStatus');
      print('Selected filter: $_selectedStatusFilter');
      
      if (_selectedStatusFilter.toLowerCase() == 'sudah direvisi') {
        // Cek kedua format untuk 'sudah direvisi'
        return status == 'sudah direvisi' || normalizedStatus == 'sudah_direvisi';
      }
      
      return normalizedStatus == _selectedStatusFilter.toLowerCase() ||
             status == _selectedStatusFilter.toLowerCase();
    }).toList();
  }
  void _showDocumentDetail(BuildContext context, Map<String, dynamic> document) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.95,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Detail Dokumen',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogContext),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Document Info Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Nomor Surat', document['nomor_surat'] ?? '-'),
                            const SizedBox(height: 12),
                            _buildDetailRow('Perihal', document['hal'] ?? '-'),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Status',
                              document['status']?.toString().toUpperCase() ?? '-',
                              valueColor: _getStatusColor(document['status']),
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow('Pengaju', document['namaMahasiswa'] ?? '-'),
                            if (document['keterangan'] != null) ...[
                              const SizedBox(height: 12),
                              _buildDetailRow('Keterangan', document['keterangan']),
                            ],
                            const SizedBox(height: 12),
                            _buildDetailRow('Tanggal Pengajuan', document['tanggal_pengajuan'] ?? '-'),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.visibility_outlined,
                                  label: 'Lihat',
                                  color: Colors.blue,
                                  onPressed: () => _viewDocument(document['id'].toString()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.edit_note_outlined,
                                  label: 'Revisi',
                                  color: Colors.orange,
                                  onPressed: () => _markForRevision(document['id'].toString()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.download_outlined,
                                  label: 'Download',
                                  color: Colors.green,
                                  onPressed: () => _downloadDocument(document['id']),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.qr_code_rounded,
                                  label: 'Bubuhkan QR',
                                  color: Colors.blueAccent,
                                  onPressed: () async {
                                    Navigator.pop(dialogContext);
                                    // Tampilkan dialog loading
                                    BuildContext? loadingDialogCtx;
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (ctx) {
                                        loadingDialogCtx = ctx;
                                        return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent)));
                                      },
                                    );

                                    try {
                                      final String docId = document['id'].toString();

                                      // 1. Minta URL gambar QR dari server
                                      final qrResult = await _documentService.generateQrCodeForDocument(docId);

                                      if (!qrResult['success']) { // Jika gagal membuat QR
                                        throw Exception(qrResult['message'] ?? 'Gagal membuat QR Code');
                                      }
                                      final String qrImageUrl = qrResult['qr_code_url']; // Ambil URL gambar QR

                                      // 2. Ambil data byte dari file PDF
                                      final pdfResponse = await _documentService.getDocumentFile(docId, role: 'dosen');
                                      if (!pdfResponse['success'] || pdfResponse['data'] == null) {
                                        throw Exception(pdfResponse['message'] ?? 'Gagal memuat file PDF');
                                      }
                                      final Uint8List pdfBytes = pdfResponse['data'];

                                      // Tutup dialog loading dengan aman
                                      if (loadingDialogCtx != null && Navigator.canPop(loadingDialogCtx!)) {
                                        Navigator.pop(loadingDialogCtx!);
                                      }
                                      loadingDialogCtx = null;

                                      if (!mounted) return;

                                      // 3. Pindah ke halaman QrPlacementPage
                                      final placementResult = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => QrPlacementPage(
                                            documentId: docId,
                                            pdfBytes: pdfBytes,
                                            qrImageUrl: qrImageUrl,
                                            fileName: 'Dokumen #${document['nomor_surat'] ?? docId}',
                                          ),
                                        ),
                                      );

                                      if (placementResult == true) {
                                        _fetchDocuments();
                                        _showMessage('Dokumen berhasil disahkan dengan Kode QR.');
                                      }
                                    } catch (e) {
                                      print("Error pada alur Kode QR: $e");
                                      if (loadingDialogCtx != null && Navigator.canPop(loadingDialogCtx!)) {
                                        Navigator.pop(loadingDialogCtx!);
                                      }
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: ${e.toString()}')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _viewDocument(String documentId) async {
    if (_isLoading) return; // Cegah klik ganda
    setState(() => _isLoading = true);

    // Tampilkan loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      print('=== MULAI MEMUAT PDF ===');
      print('Document ID: $documentId');

      final response = await _documentService.getDocumentFile(documentId);

      if (!mounted) return;

      if (response['success'] && response['data'] != null) {
        final Uint8List bytes = response['data'];

        // Tutup loading dialog sebelum push halaman baru
        if (mounted) Navigator.pop(context);

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text('Dokumen'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: Container(
                color: Colors.white,
                child: SfPdfViewer.memory(
                  bytes,
                  canShowScrollHead: true,
                  enableDocumentLinkAnnotation: false,
                  enableTextSelection: true,
                  onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                    print('Error loading PDF: ${details.error}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal memuat PDF: ${details.error}')),
                    );
                  },
                  onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                    print('PDF loaded successfully');
                  },
                ),
              ),
            ),
          ),
        );
      } else {
        if (mounted) Navigator.pop(context); // Tutup loading dialog
        throw Exception(response['message'] ?? 'Gagal memuat dokumen');
      }
    } catch (e) {
      print('=== ERROR UMUM ===');
      print('Error: $e');
      if (mounted) {
        Navigator.pop(context); // Tutup loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
          decoration: const InputDecoration(hintText: 'Masukkan keterangan revisi'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              if (controller.text.isEmpty) {
                _showMessage('Keterangan revisi tidak boleh kosong');
                return;
              }

              try {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );
                
                // Get auth token
                final token = await AuthService().getToken();
                if (token == null) {
                  // Close loading dialog
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  _showMessage('Tidak dapat mengambil token autentikasi. Silakan login kembali.');
                  return;
                }
                
                // Gunakan endpoint yang benar sesuai dengan route di Laravel
                final url = '${DocumentService.getBaseUrl()}/dosen/documents/$documentId/submitRevisi';
                print('Sending request to: $url');
                print('Request headers: ${{"Content-Type": "application/json", "Accept": "application/json", "Authorization": "Bearer ${token.substring(0, min(10, token.length))}..."}}');
                print('Request body: ${jsonEncode({'keterangan': controller.text})}');
                
                final response = await http.post(
                  Uri.parse(url),
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({
                    'keterangan': controller.text,
                    // Tidak perlu status karena diatur di backend
                  }),
                );
                
                // Print debug info
                print('Response status: ${response.statusCode}');
                print('Response body: ${response.body}');
                
                // Close loading dialog
                if (context.mounted) {
                  Navigator.pop(context);
                }
                
                // Close revision dialog
                if (context.mounted) {
                  Navigator.pop(context);
                }

                if (response.statusCode == 200) {
                  try {
                    final Map<String, dynamic> result = jsonDecode(response.body);
                    if (result['success'] == true) {
                      _showMessage('Dokumen berhasil ditandai untuk revisi');
                      _fetchDocuments();
                    } else {
                      _showMessage(result['message'] ?? 'Gagal menyimpan revisi');
                    }
                  } catch (e) {
                    print('Error parsing response: $e');
                    _showMessage('Gagal memproses respons dari server');
                  }
                } else {
                  _showMessage('Gagal mengirim revisi. Status: ${response.statusCode}');
                }
              } catch (e) {
                // Close dialogs if error
                if (context.mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                if (context.mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                print('Error in markForRevision: $e');
                _showMessage('Error: ${e.toString()}');
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadDocument(dynamic documentId) async {
    try {
      setState(() => _isLoading = true);

      // Request multiple permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();

      if (!statuses[Permission.storage]!.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin penyimpanan diperlukan untuk mengunduh file'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final String docId = documentId.toString();
      final result = await _documentService.downloadDocument(docId);

      if (result['success'] && result['data'] != null) {
        final bytes = result['data'] as Uint8List;
        final fileName = result['filename'] ?? 'document.pdf';

        // Get the Downloads directory using path_provider
        final directory = await getExternalStorageDirectory();
        String downloadPath = directory!.path.replaceAll("Android/data/com.example.your_app_name/files", "Download");
        
        final dir = Directory(downloadPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File berhasil disimpan di Download/$fileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Buka',
                textColor: Colors.white,
                onPressed: () async {
                  try {
                    final result = await OpenFile.open(file.path);
                    if (result.type != ResultType.done) {
                      throw Exception(result.message);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal membuka file: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal mengunduh dokumen'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Download error: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }


  // Future<void> _addQrCode(dynamic documentId) async {
  //   try {
  //     setState(() => _isLoading = true);
      
  //     // Konversi documentId ke String
  //     final String docId = documentId.toString();
      
  //     // Ambil file PDF terlebih dahulu
  //     final response = await _documentService.getDocumentFile(docId);
  //     print('Response from getDocumentFile: $response'); // Debug print
      
  //     if (!mounted) return;
      
  //     if (response['success'] && response['data'] != null) {
  //       // Convert bytes to base64
  //       final bytes = response['data'] as List<int>;
  //       final base64Pdf = base64Encode(bytes);
        
  //       // Navigasi ke QR Code Page
  //       final result = await Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => QrCodePage(
  //             documentId: docId,
  //             base64Pdf: base64Pdf,
  //           ),
  //         ),
  //       );

  //       // Handle result dari QR Code Page
  //       if (result == true) {
  //         await _fetchDocuments(); // Refresh dokumen
  //         _showMessage('QR Code berhasil ditambahkan');
  //       }
  //     } else {
  //       throw Exception(response['message'] ?? 'Gagal mengambil file dokumen');
  //     }
  //   } catch (e) {
  //     print('Error dalam _addQrCode: $e');
  //     _showMessage('Error: ${e.toString()}');
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isLoading = false);
  //     }
  //   }
  // }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        )
      );
    }
  }
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    // Mengatur width label berdasarkan panjang labelnya
    final double labelWidth = label == 'Tanggal Pengajuan' ? 130 : 85;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            ': ',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),      appBar: AppBarDosen(
        userData: widget.userData,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDocuments,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Perlu Pengesahan",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.filter_alt, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        labelText: "Filter Status",
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
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
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 5, color: Colors.blueAccent),
                  ),
                )
              else if (_filterPendingDocuments(_filteredDocuments()).isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        const Text(
                          'Tidak ada dokumen',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _filterPendingDocuments(_filteredDocuments()).length,
                    itemBuilder: (_, index) {
                      final doc = _filterPendingDocuments(_filteredDocuments())[index];
                      final statusColor = _getStatusColor(doc['status']);
                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: statusColor.withOpacity(0.15),
                                child: Icon(Icons.description, color: statusColor),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Nomor: ${doc['nomor_surat'] ?? '-'}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Hal: ${doc['hal'] ?? '-'}'),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.circle, color: statusColor, size: 12),
                                        const SizedBox(width: 6),
                                        Text(
                                          doc['status']?.toString().toUpperCase() ?? '-',
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _showDocumentDetail(context, doc),
                                icon: const Icon(Icons.visibility, size: 18),
                                label: const Text("Detail"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blueAccent,
                                  side: const BorderSide(color: Colors.blueAccent),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
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
      case 'sudah direvisi':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
