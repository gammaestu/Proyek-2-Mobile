import 'package:flutter/material.dart';
import '../services/document_service.dart';

class VerifyDocumentPage extends StatefulWidget {
  final String documentId;

  const VerifyDocumentPage({
    Key? key,
    required this.documentId,
  }) : super(key: key);

  @override
  State<VerifyDocumentPage> createState() => _VerifyDocumentPageState();
}

class _VerifyDocumentPageState extends State<VerifyDocumentPage> {
  final DocumentService _documentService = DocumentService();
  bool _isLoading = true;
  bool _isVerified = false;
  String _message = '';
  Map<String, dynamic>? _documentData;

  @override
  void initState() {
    super.initState();
    _verifyDocument();
  }

  Future<void> _verifyDocument() async {
    try {
      setState(() => _isLoading = true);
      
      final result = await _documentService.verifyDocument(widget.documentId);
      
      setState(() {
        _isLoading = false;
        _isVerified = result['success'] ?? false;
        _message = result['message'] ?? 'Verifikasi gagal';
        _documentData = result['data'];
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isVerified = false;
        _message = 'Error: ${e.toString()}';
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isVerified ? Colors.green : Colors.red,
                      ),
                      child: Icon(
                        _isVerified ? Icons.check : Icons.close,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      _isVerified 
                          ? 'Dokumen Terverifikasi' 
                          : 'Dokumen Tidak Valid',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _isVerified ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_isVerified && _documentData != null) ...[
                    _buildInfoItem('Nomor Dokumen', _documentData?['nomor_surat'] ?? '-'),
                    _buildInfoItem('Tanggal Pengesahan', _documentData?['tanggal_pengesahan'] ?? '-'),
                    _buildInfoItem('Disahkan Oleh', _documentData?['pengesah'] ?? '-'),
                    _buildInfoItem('Hal', _documentData?['hal'] ?? '-'),
                    
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final response = await _documentService.getDocumentFile(widget.documentId);
                            if (response['success'] && response['data'] != null) {
                              // Handle document viewing
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Dokumen berhasil dimuat')),
                              );
                            } else {
                              throw Exception(response['message']);
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          }
                        },
                        icon: const Icon(Icons.description),
                        label: const Text('Lihat Dokumen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (!_isVerified) ...[
                    const SizedBox(height: 32),
                    const Center(
                      child: Text(
                        'Dokumen ini tidak valid atau telah diubah setelah pengesahan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 