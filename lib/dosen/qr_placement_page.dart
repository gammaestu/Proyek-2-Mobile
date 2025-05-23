import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/document_service.dart';
import 'dart:typed_data';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:convert';
import 'dart:math';

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
  double _qrSize = 120.0; // Default QR code size
  bool _isResizing = false;
  GlobalKey _qrKey = GlobalKey();

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

      if (confirm != true) {
        setState(() => _isLoading = false);
        return;
      }

      // Use minimal QR size for better compatibility
      setState(() {
        _qrSize = 80.0;
      });
      
      // Allow UI to update with new size
      await Future.delayed(const Duration(milliseconds: 100));

      // Get position values
      final x = _qrPosition.dx.toString();
      final y = _qrPosition.dy.toString();
      final page = _currentPage.toString();
      final size = _qrSize.toString();
      
      // Try with our specialized method that handles data_qr field
      final result = await _documentService.approveDocumentWithQrData(
        widget.documentId, x, y, page, size,
      );
      
      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dokumen berhasil disahkan'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
        return;
      }
      
      // If that failed, show error
      throw Exception('Gagal mengesahkan dokumen. ${result['message']}');
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengesahkan dokumen: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Coba Lagi',
              onPressed: () {
                // Try again with smallest QR size
                setState(() {
                  _qrSize = 80.0;
                });
                _approveDocument();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Capture QR code as PNG bytes with optimized small size
  Future<Uint8List?> _captureQrCodeAsPng() async {
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      // Use the smallest possible pixel ratio to reduce file size
      final pixelRatio = 1.0;
      
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      
      // Use lowest quality PNG format
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) return null;
      
      final bytes = byteData.buffer.asUint8List();
      print('QR image size: ${bytes.length} bytes');
      
      return bytes;
    } catch (e) {
      print('Error capturing QR code: $e');
      return null;
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
      body: GestureDetector(
        // Allow tapping anywhere on screen to place QR code
        onTapDown: (details) {
          if (!_isDragging && !_isResizing) {
            setState(() {
              _qrPosition = details.localPosition;
            });
          }
        },
        child: Stack(
          children: [
            SfPdfViewer.memory(
              widget.pdfBytes,
              controller: _pdfViewerController,
              onPageChanged: (PdfPageChangedDetails details) {
                setState(() => _currentPage = details.newPageNumber);
              },
            ),
            // QR Code and Controls
            Positioned(
              left: _qrPosition.dx,
              top: _qrPosition.dy,
              child: Column(
                children: [
                  // Draggable QR Code
                  GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _qrPosition = Offset(
                          _qrPosition.dx + details.delta.dx,
                          _qrPosition.dy + details.delta.dy,
                        );
                      });
                    },
                    child: _buildQrCode(isDragging: _isDragging),
                  ),
                  // Size Controls - always visible
                  Container(
                    width: _qrSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _qrSize = max(80, _qrSize - 10);
                            });
                          },
                          child: const Icon(Icons.zoom_out, size: 16, color: Colors.blue),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                              trackHeight: 4,
                              overlayShape: SliderComponentShape.noOverlay,
                            ),
                            child: Slider(
                              value: _qrSize,
                              min: 80,
                              max: 250,
                              divisions: 17,
                              activeColor: Colors.blue,
                              inactiveColor: Colors.blue.shade100,
                              onChanged: (value) {
                                setState(() {
                                  _qrSize = value;
                                });
                              },
                              onChangeStart: (_) => setState(() => _isResizing = true),
                              onChangeEnd: (_) => setState(() => _isResizing = false),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _qrSize = min(250, _qrSize + 10);
                            });
                          },
                          child: const Icon(Icons.zoom_in, size: 16, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Drag hint
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
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCode({bool isDragging = false}) {
    final url = DocumentService.getVerificationUrl(widget.documentId);
    
    return RepaintBoundary(
      key: _qrKey,
      child: Container(
        width: _qrSize,
        height: _qrSize,
        decoration: BoxDecoration(
          border: Border.all(
            color: isDragging ? Colors.blue.shade300 : Colors.blue,
            width: 2,
          ),
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isDragging ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ] : null,
        ),
        padding: const EdgeInsets.all(8),
        child: QrImageView(
          data: url,
          version: QrVersions.auto,
          size: _qrSize - 16,
          backgroundColor: Colors.white,
          errorStateBuilder: (context, error) {
            return const Center(
              child: Text(
                'Error generating QR code',
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
      ),
    );
  }
}