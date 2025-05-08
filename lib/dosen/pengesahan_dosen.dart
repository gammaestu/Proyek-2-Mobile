import 'package:flutter/material.dart';
import '../component/navbar_dosen.dart';
import 'dart:convert';
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
      final status = doc['status']?.toString().toLowerCase();
      // Hanya tampilkan dokumen dengan status yang sesuai
      return status == 'diajukan' || status == 'sudah direvisi';
    }).toList();
  }

  List<Map<String, dynamic>> _filteredDocuments() {
    if (_selectedStatusFilter == 'Semua') return _documents;
    
    return _documents.where((doc) {
      final status = (doc['status'] ?? '').toString().toLowerCase().trim();
      // Konversi status dari database ke format yang sesuai
      final normalizedStatus = status.replaceAll(' ', '_');
      print('Status dokumen: $status, Filter: $_selectedStatusFilter'); // Debug print
      return normalizedStatus == _selectedStatusFilter.toLowerCase();
    }).toList();
  }

  void _showDocumentDetail(BuildContext context, Map<String, dynamic> document) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
                    SizedBox(
                      width: 100,
                      child: ElevatedButton(
                        onPressed: () => _addQrCode(document['id']),
                        child: const Text('QR Code'),
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
      setState(() {
        _isLoading = true;
      });

      print('=== MULAI MEMUAT PDF ===');
      print('Document ID: $documentId');

      // Panggil API untuk mendapatkan file PDF
      final response = await _documentService.getDocumentFile(documentId);
      print('Response dari server:');
      print('Success: ${response['success']}');
      print('Message: ${response['message']}');
      print('Data length: ${response['data']?.length ?? 0}');

      if (response['success'] == true && response['data'] != null) {
        final base64String = response['data'] as String;
        print('Panjang string base64: ${base64String.length}');

        if (base64String.isEmpty) {
          throw Exception('Data PDF kosong');
        }

        final bytes = base64.decode(base64String);
        print('Panjang bytes yang didecode: ${bytes.length}');

        if (!mounted) return;

        // Navigasi ke halaman PDF Viewer
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Dokumen PDF'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
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
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal memuat PDF: ${details.description}'),
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                },
                onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                  print('=== PDF BERHASIL DIMUAT ===');
                  print('Jumlah halaman: ${details.document.pages.count}');
                },
              ),
            ),
          ),
        );
      } else {
        print('=== ERROR RESPONSE SERVER ===');
        print('Message: ${response['message']}');
        throw Exception(response['message'] ?? 'Format response tidak valid');
      }
    } catch (e) {
      print('=== ERROR UMUM ===');
      print('Error: $e');
      print('Stack trace: ${StackTrace.current}');
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
      setState(() {
        _isLoading = true;
      });

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Konversi documentId ke String jika diperlukan
      final String docId = documentId.toString();
      
      print('Downloading document with ID: $docId');

      final result = await _documentService.downloadDocument(docId);

      if (result['success'] && result['data'] != null) {
        final base64String = result['data'] as String;
        
        // Log untuk debugging
        print('Base64 string length: ${base64String.length}');
        print('Base64 string sample (first 20 chars): ${base64String.substring(0, min(20, base64String.length))}');
        
        try {
          final bytes = base64.decode(base64String);
          final fileName = result['filename'] ?? 'document.pdf';
          
          print('Successfully decoded base64 to ${bytes.length} bytes');

          if (kIsWeb) {
            // For web platform
            final blob = html.Blob([bytes]);
            final url = html.Url.createObjectUrlFromBlob(blob);
            final anchor = html.AnchorElement(href: url)
              ..setAttribute("download", fileName)
              ..click();
            html.Url.revokeObjectUrl(url);

            if (mounted) {
              Navigator.pop(context); // Close loading dialog
              _showToast(fileName, '');
            }
          } else {
            // For mobile platform
            try {
              // Get the Downloads directory
              final directory = Directory('/storage/emulated/0/Download');
              if (!await directory.exists()) {
                await directory.create(recursive: true);
              }

              final file = File('${directory.path}/$fileName');
              await file.writeAsBytes(bytes);

              if (mounted) {
                Navigator.pop(context); // Close loading dialog

                // Show toast with file location
                Fluttertoast.showToast(
                  msg: 'File disimpan di: Download/$fileName',
                  toastLength: Toast.LENGTH_LONG,
                  gravity: ToastGravity.BOTTOM,
                  timeInSecForIosWeb: 5,
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                  fontSize: 16.0,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('File berhasil disimpan di:\nDownload/$fileName'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: 'Buka File',
                      onPressed: () async {
                        final result = await OpenFile.open(file.path);
                        print('Open file result: $result');
                      },
                    ),
                  ),
                );
              }
            } catch (e) {
              print('Error saving file: $e');
              if (mounted) {
                Navigator.pop(context); // Close loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal menyimpan file: $e\nCoba periksa izin penyimpanan'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        } catch (e) {
          print('Error decoding base64: $e');
          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal memproses file: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
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
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
        String base64Pdf = response['data'];
        
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
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _fetchDocuments,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Perlu Pengesahan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text('Nomor: ${doc['nomor_surat'] ?? '-'}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hal: ${doc['hal'] ?? '-'}'),
                              Text('Status: ${doc['status'] ?? '-'}', style: TextStyle(color: _getStatusColor(doc['status']))),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _showDocumentDetail(context, doc),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            child: const Text("Lihat Detail", style: TextStyle(color: Colors.white)),
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

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.blue,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("SIGNIX", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Row(
            children: [
              Text(widget.userData?['nama'] ?? "Dosen", style: const TextStyle(color: Colors.white)),
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
