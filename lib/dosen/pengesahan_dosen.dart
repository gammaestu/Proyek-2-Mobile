import 'package:flutter/material.dart';
import '../component/navbar_dosen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/document_service.dart';
import 'pdf_viewer_page.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
        final allDocuments = List<Map<String, dynamic>>.from(result['data'] ?? []);
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

  List<Map<String, dynamic>> _filterPendingDocuments(List<Map<String, dynamic>> docs) {
    return docs.where((doc) {
      final status = doc['status']?.toString().toLowerCase();
      return status == 'diajukan' || status == 'sudah direvisi'; // Filter dokumen dengan status tertentu
    }).toList();
  }

  List<Map<String, dynamic>> _filteredDocuments() {
    if (_selectedStatusFilter == 'Semua') return _documents;
    return _documents.where((doc) {
      final status = (doc['status'] ?? '').toString().toLowerCase().trim();
      return status == _selectedStatusFilter;
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
                Text('Nomor Surat: ${document['nomor_surat'] ?? '-'}'),
                Text('Hal: ${document['hal'] ?? '-'}'),
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
                        onPressed: () => _markForRevision(document['id']),
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
                final response = await http.post(
                  Uri.parse('${_documentService.getBaseUrl()}/dosen/documents/$documentId/revisi'),
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
      final position = {'x': 100, 'y': 100, 'page': 1};
      final result = await _documentService.addQrCode(documentId, position);
      if (result['success']) {
        _showMessage('QR Code berhasil ditambahkan');
        _fetchDocuments();
      } else {
        _showMessage(result['message'] ?? 'Gagal menambahkan QR Code');
      }
    } catch (e) {
      _showMessage('Error: ${e.toString()}');
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      case 'sudah_direvisi':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
