import 'package:flutter/material.dart';
import '../services/document_service.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:convert';
import 'dart:typed_data';

class DocumentVerificationScreen extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic>? verificationData;

  const DocumentVerificationScreen({
    Key? key,
    required this.documentId,
    this.verificationData,
  }) : super(key: key);

  @override
  _DocumentVerificationScreenState createState() =>
      _DocumentVerificationScreenState();
}

class _DocumentVerificationScreenState
    extends State<DocumentVerificationScreen> {
  final DocumentService _documentService = DocumentService();
  bool _isLoading = true;
  bool _loadingDocument = true;
  Map<String, dynamic> _docData = {};
  String? _errorMessage;
  Uint8List? _documentBytes;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // If verification data was passed, use it directly
      if (widget.verificationData != null) {
        setState(() {
          _docData = widget.verificationData!;
          _isLoading = false;
        });
      } else {
        // Otherwise fetch verification data
        final result = await _documentService.verifyDocument(widget.documentId);
        if (result['success']) {
          setState(() {
            _docData = result['data'] ?? {};
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = result['message'] ?? 'Gagal memverifikasi dokumen';
            _isLoading = false;
          });
        }
      }

      // Load the document file
      _loadDocumentFile();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDocumentFile() async {
    setState(() {
      _loadingDocument = true;
    });

    try {
      final docResponse =
          await _documentService.getDocumentFile(widget.documentId);

      if (docResponse['success']) {
        final base64String = docResponse['data'] as String;
        if (base64String.isNotEmpty) {
          setState(() {
            _documentBytes = base64Decode(base64String);
            _loadingDocument = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Data PDF kosong';
            _loadingDocument = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = docResponse['message'] ?? 'Gagal memuat dokumen';
          _loadingDocument = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error memuat dokumen: ${e.toString()}';
        _loadingDocument = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi Dokumen'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Verification information
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Dokumen',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildInfoRow('Nomor Surat', _docData['nomor_surat'] ?? '-'),
                  _buildInfoRow('Hal', _docData['hal'] ?? '-'),
                  _buildInfoRow('Tujuan', _docData['tujuan_pengajuan'] ?? '-'),
                  _buildInfoRow('Status', _formatStatus(_docData['status'])),
                  _buildInfoRow('Diajukan oleh',
                      _docData['ormawa']?['namaMahasiswa'] ?? '-'),
                  _buildInfoRow('NIM', _docData['ormawa']?['nim'] ?? '-'),
                  _buildInfoRow(
                      'Organisasi', _docData['ormawa']?['namaOrmawa'] ?? '-'),
                  const SizedBox(height: 8),
                  const Divider(),
                  const Text(
                    'Informasi Pengesahan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                      'Disahkan oleh', _docData['dosen']?['namaDosen'] ?? '-'),
                  _buildInfoRow('NIP', _docData['dosen']?['nip'] ?? '-'),
                  _buildInfoRow('Tanggal Pengesahan',
                      _formatDate(_docData['updated_at'])),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Dokumen Sah',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Document preview
        Expanded(
          child: _loadingDocument
              ? const Center(child: CircularProgressIndicator())
              : _documentBytes != null
                  ? SfPdfViewer.memory(_documentBytes!)
                  : const Center(child: Text('Dokumen tidak tersedia')),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
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
      default:
        return status ?? 'Tidak Diketahui';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';

    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
