import 'package:flutter/material.dart';
import '../component/navbar_dosen.dart';
import '../component/appbar_dosen.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../services/document_service.dart';
import 'qr_code_page.dart';
import 'pdf_viewer_page.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_file/open_file.dart';
import 'dart:math';
import '../services/auth_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'qr_placement_page.dart';

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
    'sudah direvisi': 'Sudah Direvisi',
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Detail Dokumen'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nomor Surat : ${document['nomor_surat'] ?? '-'}'),
              Text('Perihal : ${document['hal'] ?? '-'}'),
              Text('Status: ${document['status'] ?? '-'}'), // Gunakan kunci status
              Text('Pengaju: ${document['namaMahasiswa'] ?? '-'}'),
              if (document['keterangan'] != null)
                Text('Keterangan: ${document['keterangan']}'),
              Text('Tanggal Pengajuan: ${document['tanggal_pengajuan'] ?? '-'}'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    child: ElevatedButton(
                      onPressed: () => _viewDocument(document['id'].toString()),
                      child: const Text('Lihat'),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: ElevatedButton(
                      onPressed: () => _markForRevision(document['id'].toString()),
                      child: const Text('Revisi'),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: ElevatedButton(
                      onPressed: () => _downloadDocument(document['id']),
                      child: const Text('Download'),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Close detail dialog first
                      Navigator.pop(dialogContext);

                      // Show loading indicator in a separate dialog
                      BuildContext? loadingContext;
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) {
                          loadingContext = ctx;
                          return const Center(child: CircularProgressIndicator());
                        },
                      );

                      try {
                        final response = await _documentService.getDocumentFile(
                          document['id'].toString(),
                          role: 'dosen'
                        );

                        // Close loading dialog safely
                        if (loadingContext != null && Navigator.canPop(loadingContext!)) {
                          Navigator.pop(loadingContext!);
                        }

                        if (response['success'] && response['data'] != null) {
                          if (!mounted) return;

                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QrPlacementPage(
                                documentId: document['id'].toString(),
                                pdfBytes: response['data'],
                                fileName: 'Dokumen #${document['id']}',
                              ),
                            ),
                          );

                          // Refresh documents list if needed
                          if (mounted) {
                            await _fetchDocuments();
                          }
                        } else {
                          throw Exception(response['message'] ?? 'Gagal memuat dokumen');
                        }
                      } catch (e) {
                        // Close loading dialog if still showing
                        if (loadingContext != null && Navigator.canPop(loadingContext!)) {
                          Navigator.pop(loadingContext!);
                        }

                        if (!mounted) return;

                        // Show error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.qr_code),
                    label: const Text('QR Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
        ],
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

  void _showToast(String fileName, String filePath) {
    Fluttertoast.showToast(
      msg: 'File $fileName berhasil diunduh',
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> _addQrCode(dynamic documentId) async {
    try {
      setState(() => _isLoading = true);
      
      // Konversi documentId ke String
      final String docId = documentId.toString();
      
      // Ambil file PDF terlebih dahulu
      final response = await _documentService.getDocumentFile(docId);
      print('Response from getDocumentFile: $response'); // Debug print
      
      if (!mounted) return;
      
      if (response['success'] && response['data'] != null) {
        // Convert bytes to base64
        final bytes = response['data'] as List<int>;
        final base64Pdf = base64Encode(bytes);
        
        // Navigasi ke QR Code Page
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QrCodePage(
              documentId: docId,
              base64Pdf: base64Pdf,
            ),
          ),
        );

        // Handle result dari QR Code Page
        if (result == true) {
          await _fetchDocuments(); // Refresh dokumen
          _showMessage('QR Code berhasil ditambahkan');
        }
      } else {
        throw Exception(response['message'] ?? 'Gagal mengambil file dokumen');
      }
    } catch (e) {
      print('Error dalam _addQrCode: $e');
      _showMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBarDosen(
        namaDosen: widget.userData?['nama'],
        title: "Pengesahan",
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
