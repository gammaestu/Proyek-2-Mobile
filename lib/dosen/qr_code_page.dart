import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:convert';
import '../services/document_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'dart:math';

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
  double _qrSize = 120.0; // Default QR code size
  bool _isResizing = false;
  final String _baseUrl = DocumentService.getBaseUrl().replaceAll('/api', '');
  GlobalKey _qrKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  Future<void> _saveQrPosition() async {
    setState(() => _isLoading = true);
    try {
      // Set QR size to the smallest value for better compatibility
      setState(() {
        _qrSize = 80.0;
      });

      // Allow UI to update with new size
      await Future.delayed(const Duration(milliseconds: 100));

      // Get position values and ensure they are properly formatted as strings
      final x = _qrPosition.dx.toString().trim();
      final y = _qrPosition.dy.toString().trim();
      final page = _currentPage.toString().trim();
      final size = _qrSize.toString().trim();

      print('Attempting to save QR code with position: x=$x, y=$y, page=$page, size=$size');

      // Maximum retry attempts
      const maxRetries = 3;
      Exception? lastError;
      
      // Try multiple times with decreasing QR sizes if needed
      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          // Decrease size on each retry to improve chances of success
          if (attempt > 0) {
            final newSize = max(80.0, _qrSize - (attempt * 10.0));
            setState(() => _qrSize = newSize);
            await Future.delayed(const Duration(milliseconds: 100));
            print('Retry #${attempt+1}: Trying with smaller QR size: $_qrSize');
          }
          
          // Use the specialized method that handles data_qr field
          final result = await _documentService.approveDocumentWithQrData(
            widget.documentId, x, y, page, _qrSize.toString().trim()
          );
          
          if (result['success'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR Code berhasil ditambahkan')),
              );
              Navigator.pop(context, true);
            }
            return;
          } else {
            lastError = Exception(result['message'] ?? 'Gagal menyimpan QR Code');
            print('Save attempt ${attempt+1} failed: ${result['message']}');
          }
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          print('Error in save attempt ${attempt+1}: $e');
        }
      }
      
      // If we get here, all attempts failed
      throw lastError ?? Exception('Gagal menyimpan QR Code setelah beberapa percobaan');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan QR Code: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Coba Lagi',
              onPressed: () {
                _saveQrPosition();
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

  // Generate the verification URL for this document
  String _getVerificationUrl() {
    return DocumentService.getVerificationUrl(widget.documentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: _testQrCode,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveQrPosition,
          ),
        ],
      ),
      body: GestureDetector(
        // Allow tapping anywhere on screen to place QR code
        onTapDown: (details) {
          if (!_isResizing) {
            setState(() {
              _qrPosition = details.localPosition;
            });
          }
        },
        child: Stack(
          children: [
            SfPdfViewer.memory(
              base64Decode(widget.base64Pdf),
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
                    child: _buildQrCode(isDragging: false),
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
            // Helper instruction
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.black.withOpacity(0.7),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Seret QR Code ke posisi yang diinginkan, lalu klik Simpan untuk menyimpan',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  // Method to test QR code by launching URL
  Future<void> _testQrCode() async {
    final url = _getVerificationUrl();
    final uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tidak dapat membuka URL: $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildQrCode({bool isDragging = false}) {
    final url = _getVerificationUrl();
    
    return RepaintBoundary(
      key: _qrKey,
      child: Container(
        width: _qrSize,
        height: _qrSize,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue),
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
          // Use lower error correction level for smaller file size
          errorCorrectionLevel: QrErrorCorrectLevel.L,
          // Add padding for better scanning
          padding: const EdgeInsets.all(0),
          // Use embeddedImage to add extra visual protection against server errors
          embeddedImageStyle: const QrEmbeddedImageStyle(
            size: Size(0, 0), // No embedded image for better compatibility
          ),
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