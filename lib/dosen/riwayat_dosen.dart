import 'package:flutter/material.dart';
import '../component/navbar_dosen.dart';
import '../services/document_service.dart';
import '../component/appbar_dosen.dart';

class DosenRiwayatPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const DosenRiwayatPage({super.key, this.userData});

  @override
  State<DosenRiwayatPage> createState() => _DosenRiwayatPageState();
}

class _DosenRiwayatPageState extends State<DosenRiwayatPage> {
  final int _selectedIndex = 2;
  final _documentService = DocumentService();
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);

    try {
      final result = await _documentService.getAllDocuments();
      if (mounted) {
        final allDocuments = List<Map<String, dynamic>>.from(result['data'] ?? []);
        final filtered = _filterApprovedOrRejected(allDocuments);

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

  List<Map<String, dynamic>> _filterApprovedOrRejected(List<Map<String, dynamic>> docs) {
    return docs.where((doc) {
      final status = doc['status']?.toString().toLowerCase();
      return status == 'disahkan' || status == 'butuh revisi';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBarDosen(
        namaDosen: widget.userData?['nama'],
        title: "Riwayat",
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(child: Text('Tidak ada dokumen Disahkan/Revisi'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final document = _documents[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text('Nomor: ${document['nomor_surat'] ?? '-'}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hal: ${document['hal'] ?? '-'}'),
                            Text('Status: ${document['status'] ?? '-'}'),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _showDocumentDetail(context, document),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: NavbarDosen(
        currentIndex: _selectedIndex,
        userData: widget.userData,
      ),
    );
  }

  void _showDocumentDetail(
      BuildContext context, Map<String, dynamic> document) {
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
                Text('Status: ${document['status'] ?? '-'}'),
                Text('Tujuan: ${document['tujuan_pengajuan'] ?? '-'}'),
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
}
