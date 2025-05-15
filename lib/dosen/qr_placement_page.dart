import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/document_service.dart';
import 'dart:typed_data';

class QrPlacementPage extends StatefulWidget {
  final String documentId;
  final Uint8List pdfBytes;
  final String fileName;

  const QrPlacementPage({
    Key? key,
    required this.documentId,
    required this.pdfBytes,
    required this.fileName,
  }) : super(key: key);

  @override
  State<QrPlacementPage> createState() => _QrPlacementPageState();
}

class _QrPlacementPageState extends State<QrPlacementPage> {
  final DocumentService _documentService = DocumentService();
  Offset _qrPosition = const Offset(100, 100);
  int _currentPage = 1;
  bool _isLoading = false;
  bool _isDragging = false;
  late PdfViewerController _pdfViewerController;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  Future<void> _approveDocument() async {
    try {
      setState(() => _isLoading = true);

      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Konfirmasi Pengesahan'),
          content: const Text(
            'Dokumen akan ditandatangani dengan QR Code pada posisi yang dipilih. '
            'Status dokumen akan berubah menjadi "Disahkan".\n\n'
            'Apakah Anda yakin?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('Ya, Sahkan'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      final position = {
        'x': _qrPosition.dx,
        'y': _qrPosition.dy,
        'page': _currentPage,
      };

      final result = await _documentService.addQrCode(widget.documentId, position);

      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dokumen berhasil disahkan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengesahkan dokumen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pengesahan - ${widget.fileName}'),
        actions: [
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _approveDocument,
            icon: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue,
                  ),
                )
              : const Icon(Icons.check_circle, color: Colors.blue),
            label: Text(
              _isLoading ? 'Memproses...' : 'Sahkan',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8), // Add padding at the end
        ],
      ),
      body: Stack(
        children: [
          SfPdfViewer.memory(
            widget.pdfBytes,
            controller: _pdfViewerController,
            onPageChanged: (PdfPageChangedDetails details) {
              setState(() => _currentPage = details.newPageNumber);
            },
          ),
          Positioned(
            left: _qrPosition.dx,
            top: _qrPosition.dy,
            child: Draggable(
              feedback: _buildQrPreview(isDragging: true),
              childWhenDragging: Container(),
              onDragStarted: () => setState(() => _isDragging = true),
              onDragEnd: (details) {
                setState(() {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final localPosition = box.globalToLocal(details.offset);
                  _qrPosition = localPosition;
                  _isDragging = false;
                });
              },
              child: _buildQrPreview(isDragging: false),
            ),
          ),
          // Helper text
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.black.withOpacity(0.7),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Seret QR Code ke posisi yang diinginkan, lalu klik "Sahkan" untuk mengesahkan dokumen',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrPreview({required bool isDragging}) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        border: Border.all(
          color: isDragging ? Colors.blue.shade300 : Colors.blue,
          width: 2,
        ),
        color: Colors.white.withOpacity(isDragging ? 0.9 : 0.7),
        borderRadius: BorderRadius.circular(8),
        boxShadow: isDragging ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ] : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_2,
            size: 50,
            color: isDragging ? Colors.blue.shade300 : Colors.blue,
          ),
          const SizedBox(height: 4),
          Text(
            'QR Code',
            style: TextStyle(
              fontSize: 12,
              color: isDragging ? Colors.blue.shade300 : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}