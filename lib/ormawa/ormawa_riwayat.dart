import 'package:flutter/material.dart';
import '../component/navbar_ormawa.dart';
import '../component/appbar_ormawa.dart';
import '../services/document_service.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_file/open_file.dart';
import 'package:file_picker/file_picker.dart';

class OrmawaRiwayatPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final String? statusFilter;
  const OrmawaRiwayatPage({super.key, this.userData, this.statusFilter});

  @override
  State<OrmawaRiwayatPage> createState() => _OrmawaRiwayatPageState();
}

class _OrmawaRiwayatPageState extends State<OrmawaRiwayatPage> {
  final int _selectedIndex = 2;
  final _documentService = DocumentService();
  Map<String, dynamic>? _documentStats;
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  bool _isPdfLoading = true;
  String? _currentFilter;
  String? _error;
  PlatformFile? _selectedRevisiFile;
  bool _isUploadingRevisi = false;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.statusFilter;
    _loadDocumentStats();
    _loadDocuments();
  }

  Future<void> _showDownloadToast(String fileName, String filePath) async {
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

  Future<void> _loadDocumentStats() async {
    try {
      final result = await _documentService.getDocumentStats();
      if (mounted) {
        setState(() {
          _documentStats = result['data'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _documentService.getAllDocuments();
      print('API Response: $result');

      if (mounted) {
        if (result['success'] == true && result['data'] != null) {
          final allDocuments = List<Map<String, dynamic>>.from(result['data']);
          print('All documents: $allDocuments');
          print('Current filter: $_currentFilter');

          // Filter documents based on status if filter is set
          final filteredDocuments = _currentFilter != null
              ? allDocuments.where((doc) {
                  final docStatus = doc['status']?.toString().toLowerCase();
                  final filterStatus = _currentFilter?.toLowerCase();
                  print(
                      'Document status: $docStatus, Filter status: $filterStatus');

                  // Handle multiple status values for the same filter
                  switch (filterStatus) {
                    case 'submitted':
                      return docStatus == 'diajukan';
                    case 'signed':
                      return docStatus == 'ditandatangani' ||
                          docStatus == 'disahkan';
                    case 'perlu_revisi':
                      return docStatus == 'butuh revisi';
                    case 'sudah_direvisi':
                      return docStatus == 'sudah direvisi';
                    default:
                      return false;
                  }
                }).toList()
              : allDocuments;

          print('Filtered documents: $filteredDocuments');

          setState(() {
            _documents = filteredDocuments;
            _isLoading = false;
          });
        } else {
          print('API returned error or no data: ${result['message']}');
          setState(() {
            _documents = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading documents: $e');
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

  void _applyFilter(String? filter) {
    setState(() {
      _currentFilter = filter;
    });
    _loadDocuments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBarOrmawa(userData: widget.userData),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadDocumentStats(),
            _loadDocuments(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Cards
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusCard(
                      "Dokumen Diajukan",
                      _documentStats?['submitted'] ?? 0,
                      Colors.orange,
                      Icons.pending_actions,
                    ),
                    _buildStatusCard(
                      "Dokumen Tertanda",
                      _documentStats?['signed'] ?? 0,
                      Colors.green,
                      Icons.check_circle,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusCard(
                      "Perlu Direvisi",
                      _documentStats?['perlu_revisi'] ?? 0,
                      Colors.red,
                      Icons.cancel,
                    ),
                    _buildStatusCard(
                      "Sudah Direvisi",
                      _documentStats?['sudah_direvisi'] ?? 0,
                      Colors.blue,
                      Icons.edit_document,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Riwayat Section
                const Text(
                  "Riwayat",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                // Filter Buttons
                Row(
                  children: [
                    _buildFilterButton(
                      "Filter",
                      Icons.filter_list,
                      () {
                        _showFilterDialog();
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildFilterButton(
                      "Urutkan",
                      Icons.sort,
                      () {
                        // TODO: Implement sort
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Daftar Dokumen
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_documents.isEmpty)
                  const Center(child: Text('Tidak ada dokumen'))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final document = _documents[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Nomor: ${document['nomor_surat'] ?? '-'}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "Hal: ${document['hal'] ?? '-'}",
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        "Status: ${document['status'] ?? '-'}",
                                        style: TextStyle(
                                          color: _getStatusColor(
                                              document['status']),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      _showDocumentDetail(context, document),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                  ),
                                  child: const Text(
                                    "Lihat Detail",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavbarOrmawa(
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
      case 'sudah_direvisi':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showDocumentDetail(
      BuildContext context, Map<String, dynamic> document) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final status = (document['status'] ?? '').toString().toLowerCase();
        final isRevisi = status == 'butuh revisi';
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Detail Dokumen'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nomor Surat: ${document['nomor_surat'] ?? '-'}'),
                    const SizedBox(height: 8),
                    Text('Hal: ${document['hal'] ?? '-'}'),
                    const SizedBox(height: 8),
                    Text('Status: ${document['status'] ?? '-'}'),
                    const SizedBox(height: 8),
                    Text('Tujuan: ${document['tujuan_pengajuan'] ?? '-'}'),
                    if (document['keterangan'] != null) ...[
                      const SizedBox(height: 8),
                      Text('Keterangan: ${document['keterangan']}'),
                    ],
                    if (isRevisi) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.yellow[50],
                          border: Border(
                              left: BorderSide(color: Colors.amber, width: 4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Keterangan Revisi:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange),
                            ),
                            Text(document['keterangan'] ?? '-',
                                style: const TextStyle(color: Colors.brown)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                                _selectedRevisiFile?.name ?? 'No file chosen'),
                          ),
                          ElevatedButton(
                            onPressed: _isUploadingRevisi
                                ? null
                                : () async {
                                    final result =
                                        await FilePicker.platform.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['pdf', 'doc', 'docx'],
                                      withData: true,
                                    );
                                    if (result != null &&
                                        result.files.isNotEmpty) {
                                      setStateDialog(() {
                                        _selectedRevisiFile =
                                            result.files.first;
                                      });
                                    }
                                  },
                            child: const Text('Choose File'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isUploadingRevisi ||
                                  _selectedRevisiFile == null
                              ? null
                              : () async {
                                  setStateDialog(() {
                                    _isUploadingRevisi = true;
                                  });
                                  final res = await _documentService
                                      .uploadRevisiDocument(
                                    documentId: document['id'].toString(),
                                    fileBytes: _selectedRevisiFile!.bytes!,
                                    fileName: _selectedRevisiFile!.name,
                                  );
                                  setStateDialog(() {
                                    _isUploadingRevisi = false;
                                  });
                                  if (res['success']) {
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Dokumen berhasil diupdate!'),
                                            backgroundColor: Colors.green),
                                      );
                                      _loadDocuments();
                                      _loadDocumentStats();
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(res['message'] ??
                                              'Gagal update dokumen'),
                                          backgroundColor: Colors.red),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue),
                          child: _isUploadingRevisi
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Update Dokumen',
                                  style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => _viewDocument(
                              document['id'].toString(),
                              document['filename'] ?? 'Dokumen'),
                          child: const Text('Lihat'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              _downloadDocument(document['id'].toString()),
                          child: const Text('Download'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue),
                        ),
                      ],
                    ),
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
      },
    );
  }

  Future<void> _viewDocument(String documentId, String fileName) async {
    try {
      setState(() {
        _isPdfLoading = true;
        _error = null;
      });

      print('=== MULAI MEMUAT PDF ===');
      print('Document ID: $documentId');
      print('File Name: $fileName');

      final response = await _documentService.getDocumentFile(documentId);
      print('Response dari server:');
      print('Success: ${response['success']}');
      print('Message: ${response['message']}');
      print('Data length: ${response['data']?.length ?? 0}');

      if (response['success'] == true && response['data'] != null) {
        final base64String = response['data'] as String;
        print('Panjang string base64: ${base64String.length}');

        try {
          if (base64String.isEmpty) {
            throw Exception('Data PDF kosong');
          }

          final bytes = base64.decode(base64String);
          print('Panjang bytes yang didecode: ${bytes.length}');

          if (!mounted) return;

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  title: Text(fileName),
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
                          content:
                              Text('Gagal memuat PDF: ${details.description}'),
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
        } catch (e) {
          print('=== ERROR MEMPROSES PDF ===');
          print('Error: $e');
          print('Stack trace: ${StackTrace.current}');
          throw Exception('Gagal memproses file PDF: $e');
        }
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
        setState(() {
          _error = 'Gagal membuka dokumen: $e';
        });
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
          _isPdfLoading = false;
        });
      }
      print('=== SELESAI MEMUAT PDF ===');
    }
  }

  Future<void> _downloadDocument(String documentId) async {
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

      final result = await _documentService.downloadDocument(documentId);

      if (result['success'] && result['data'] != null) {
        final base64String = result['data'] as String;
        final bytes = base64.decode(base64String);
        final fileName = result['filename'] ?? 'document.pdf';

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
            _showDownloadToast(fileName, '');
          }
        } else {
          // For mobile platform
          try {
            // Get the public Downloads directory
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
                  content:
                      Text('File berhasil disimpan di:\nDownload/$fileName'),
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
            if (mounted) {
              Navigator.pop(context); // Close loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Gagal menyimpan file: $e\nCoba periksa izin penyimpanan'),
                  backgroundColor: Colors.red,
                ),
              );
            }
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

  Widget _buildStatusCard(String title, int count, Color color, IconData icon) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.44,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(
      String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: () {
        if (label == "Filter") {
          _showFilterDialog();
        } else {
          onPressed();
        }
      },
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        side: const BorderSide(color: Colors.grey),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Dokumen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Semua'),
              selected: _currentFilter == null,
              onTap: () {
                Navigator.pop(context);
                _applyFilter(null);
              },
            ),
            ListTile(
              title: const Text('Diajukan'),
              selected: _currentFilter == 'submitted',
              onTap: () {
                Navigator.pop(context);
                _applyFilter('submitted');
              },
            ),
            ListTile(
              title: const Text('Ditandatangani'),
              selected: _currentFilter == 'signed',
              onTap: () {
                Navigator.pop(context);
                _applyFilter('signed');
              },
            ),
            ListTile(
              title: const Text('Butuh Revisi'),
              selected: _currentFilter == 'perlu_revisi',
              onTap: () {
                Navigator.pop(context);
                _applyFilter('perlu_revisi');
              },
            ),
            ListTile(
              title: const Text('Sudah Direvisi'),
              selected: _currentFilter == 'sudah_direvisi',
              onTap: () {
                Navigator.pop(context);
                _applyFilter('sudah_direvisi');
              },
            ),
          ],
        ),
      ),
    );
  }
}
