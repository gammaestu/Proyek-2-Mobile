import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/document_service.dart';
import 'dart:convert';
import 'dart:typed_data';

class QrCodePositioningScreen extends StatefulWidget {
  final String documentId;
  final Uint8List documentBytes;

  const QrCodePositioningScreen(
      {Key? key, required this.documentId, required this.documentBytes})
      : super(key: key);

  @override
  _QrCodePositioningScreenState createState() =>
      _QrCodePositioningScreenState();
}

class _QrCodePositioningScreenState extends State<QrCodePositioningScreen> {
  final DocumentService _documentService = DocumentService();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  // QR Code position
  double xPosition = 100.0;
  double yPosition = 100.0;
  int currentPage = 1;
  int totalPages = 1;

  // QR code size - default and adjustable
  double qrSize = 80.0;
  double minSize = 50.0;
  double maxSize = 150.0;

  bool _isProcessing = false;
  bool _isErrorLoadingPdf = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    print('QrCodePositioningScreen initialized');
    print(
        'Document ID: ${widget.documentId} (${widget.documentId.runtimeType})');
    print('Document bytes length: ${widget.documentBytes.length}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanda Tangani Dokumen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed:
                _isProcessing || _isErrorLoadingPdf ? null : _applyQrCode,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isErrorLoadingPdf) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 60),
            SizedBox(height: 16),
            Text(
              'Gagal memuat dokumen PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Kembali'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // PDF Viewer
        SfPdfViewer.memory(
          widget.documentBytes,
          key: _pdfViewerKey,
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            print(
                'PDF document loaded, pages: ${details.document.pages.count}');
            setState(() {
              totalPages = details.document.pages.count;
              // Position QR code in the center of the page initially
              xPosition = MediaQuery.of(context).size.width / 2 - qrSize / 2;
              yPosition = MediaQuery.of(context).size.height / 3 - qrSize / 2;
            });
          },
          onPageChanged: (PdfPageChangedDetails details) {
            print('Page changed to: ${details.newPageNumber}');
            setState(() {
              currentPage = details.newPageNumber;
            });
          },
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
            print('Failed to load PDF: ${details.error}');
            print('Description: ${details.description}');
            setState(() {
              _isErrorLoadingPdf = true;
              _errorMessage = details.description;
            });
          },
        ),

        // QR Code preview (draggable)
        Positioned(
          left: xPosition,
          top: yPosition,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                xPosition += details.delta.dx;
                yPosition += details.delta.dy;

                // Keep QR code within screen bounds
                if (xPosition < 0) xPosition = 0;
                if (yPosition < 0) yPosition = 0;
                if (xPosition > MediaQuery.of(context).size.width - qrSize) {
                  xPosition = MediaQuery.of(context).size.width - qrSize;
                }
                if (yPosition >
                    MediaQuery.of(context).size.height - qrSize - 100) {
                  yPosition = MediaQuery.of(context).size.height - qrSize - 100;
                }
              });
            },
            child: Container(
              width: qrSize,
              height: qrSize,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                color: Colors.blue.withOpacity(0.3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code,
                      color: Colors.blue.shade800, size: qrSize * 0.4),
                  const SizedBox(height: 4),
                  Text('Tanda Tangan',
                      style: TextStyle(
                          fontSize: qrSize * 0.12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),

        // Size adjustment controls
        Positioned(
          bottom: 80,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: Column(
              children: [
                const Text('Ukuran QR',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        setState(() {
                          if (qrSize > minSize) qrSize -= 10;
                        });
                      },
                    ),
                    Text('${qrSize.toInt()}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        setState(() {
                          if (qrSize < maxSize) qrSize += 10;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Instructions overlay
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: const Text(
              'Tarik dan posisikan QR code pada halaman dokumen yang diinginkan. '
              'Anda dapat mengatur ukuran QR code menggunakan tombol + dan -.',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        if (!_isErrorLoadingPdf) // Show bottom navigation bar only if PDF loaded successfully
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('Halaman: $currentPage / $totalPages',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 20),
                      Text(
                          'Posisi: (${xPosition.toInt()}, ${yPosition.toInt()})'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _applyQrCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isProcessing
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white)),
                                SizedBox(width: 12),
                                Text('Memproses...',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            )
                          : const Text('Bubuhkan Tanda Tangan',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _applyQrCode() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Show processing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Sedang memproses QR code...")
              ],
            ),
          );
        },
      );

      print(
          'QR Code position: x=${xPosition.toInt()}, y=${yPosition.toInt()}, page=$currentPage');
      print('Applying QR code to document ID: ${widget.documentId}');

      // Prepare position data
      final position = {
        'x': xPosition.toInt(),
        'y': yPosition.toInt(),
        'page': currentPage,
        'size': qrSize.toInt(),
      };

      // Call API to add QR code
      print('Calling addQrCode service method...');
      final result =
          await _documentService.addQrCode(widget.documentId, position);
      print('QR code API response: $result');

      // Close processing dialog
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (result['success'] == true) {
        print('QR code added successfully');
        // Return success to previous screen
        if (mounted) {
          // Show a success message before returning
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dokumen berhasil ditandatangani dan disahkan!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Wait a moment to show the success message
          await Future.delayed(const Duration(seconds: 1));

          Navigator.pop(context, true);
        }
      } else {
        // Show error dialog with more details
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Gagal Menambahkan QR Code'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result['message'] ?? 'Terjadi kesalahan'),
                      SizedBox(height: 10),
                      if (result['error_details'] != null)
                        Text('Detail: ${result['error_details']}',
                            style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('OK'),
                  ),
                ],
              );
            },
          );
        }
        _showErrorMessage(result['message'] ?? 'Gagal menambahkan QR Code');
      }
    } catch (e) {
      // Close processing dialog if it's showing
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Error in _applyQrCode: $e');
      print('Stack trace: ${StackTrace.current}');

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Error'),
              content: SingleChildScrollView(
                child: Text('Terjadi kesalahan: ${e.toString()}'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }

      _showErrorMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showErrorMessage(String message) {
    print('Error: $message');
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
