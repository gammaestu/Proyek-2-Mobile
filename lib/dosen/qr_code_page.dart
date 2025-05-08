import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:convert';
import '../services/document_service.dart';

class QrCodePage extends StatefulWidget {
  final String documentId;
  final String base64Pdf;

  const QrCodePage({
    Key? key,
    required this.documentId,
    required this.base64Pdf,
  }) : super(key: key);

  @override
  State<QrCodePage> createState() => _QrCodePageState();
}

class _QrCodePageState extends State<QrCodePage> {
  final DocumentService _documentService = DocumentService();
  Offset _qrPosition = const Offset(100, 100);
  int _currentPage = 1;
  late PdfViewerController _pdfViewerController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  Future<void> _saveQrPosition() async {
    setState(() => _isLoading = true);
    try {
      final position = {
        'x': _qrPosition.dx,
        'y': _qrPosition.dy,
        'page': _currentPage,
      };

      final result = await _documentService.addQrCode(widget.documentId, position);
      
      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR Code berhasil ditambahkan')),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan QR Code: $e')),
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
        title: const Text('Tambah QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveQrPosition,
          ),
        ],
      ),
      body: Stack(
        children: [
          SfPdfViewer.memory(
            base64Decode(widget.base64Pdf),
            controller: _pdfViewerController,
            onPageChanged: (PdfPageChangedDetails details) {
              setState(() => _currentPage = details.newPageNumber);
            },
          ),
          Positioned(
            left: _qrPosition.dx,
            top: _qrPosition.dy,
            child: Draggable(
              feedback: _buildQrCode(),
              childWhenDragging: Container(),
              onDragEnd: (details) {
                setState(() {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final localPosition = box.globalToLocal(details.offset);
                  _qrPosition = localPosition;
                });
              },
              child: _buildQrCode(),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildQrCode() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        color: Colors.white.withOpacity(0.8),
      ),
      child: const Center(
        child: Icon(Icons.qr_code, size: 60),
      ),
    );
  }
}