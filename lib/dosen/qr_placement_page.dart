import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/document_service.dart';
import '../services/auth_service.dart';
import 'dart:typed_data';
// import 'package:qr_flutter/qr_flutter.dart';
// import 'dart:ui' as ui;
// import 'package:flutter/rendering.dart';


class QrPlacementPage extends StatefulWidget {
  final String documentId;
  final Uint8List pdfBytes; // Data PDF
  final String qrImageUrl;   // URL gambar QR dari server (BARU)
  final String fileName;

  const QrPlacementPage({
    Key? key,
    required this.documentId,
    required this.pdfBytes,
    required this.qrImageUrl, // Parameter baru
    required this.fileName,
  }) : super(key: key);

  @override
  State<QrPlacementPage> createState() => _QrPlacementPageState();
}

class _QrPlacementPageState extends State<QrPlacementPage> {
  final DocumentService _documentService = DocumentService();
  final AuthService _authService = AuthService();
  
  // Posisi QR dalam piksel di layar
  Offset _qrScreenPosition = const Offset(50, 50);
  // Ukuran QR dalam piksel di layar
  double _qrScreenSize = 100.0;
  String? _fullQrUrl;

  int _currentPageNumber = 1; // `onPageChanged` di SfPdfViewer menggunakan basis 1
  bool _isLoading = false;
  late PdfViewerController _pdfViewerController;
  GlobalKey _pdfViewerKey = GlobalKey(); // Kunci untuk mendapatkan ukuran area PDF viewer

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _setupQrUrl();
    // Atur posisi awal QR, misalnya di tengah atau pojok
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pdfViewerKey.currentContext != null) {
        final RenderBox pdfArea = _pdfViewerKey.currentContext!.findRenderObject() as RenderBox;
         setState(() {
           _qrScreenPosition = Offset(
             pdfArea.size.width * 0.1,  // Mulai dari 10% dari kiri
             pdfArea.size.height * 0.7, // Mulai dari 70% dari atas (agak ke bawah)
           );
         });
      } else {
         // Posisi default jika ukuran area belum diketahui
         _qrScreenPosition = const Offset(30, 30);
      }
    });
  }

  void _setupQrUrl() {
    if (widget.qrImageUrl.startsWith('http')) {
      _fullQrUrl = widget.qrImageUrl;
    } else {
      final baseUrl = DocumentService.getBaseUrl().replaceAll('/api', '');
      _fullQrUrl = '$baseUrl/storage/${widget.qrImageUrl.replaceAll('/storage/', '')}';
    }
    print('Full QR URL: $_fullQrUrl'); // Debug print
  }

  // Fungsi untuk mengirim data penempatan QR ke server
  Future<void> _approveDocumentAndEmbedQr() async {
    if (_pdfViewerKey.currentContext == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Area PDF Viewer belum siap. Mohon tunggu.')),
      );
      return;
    }

    // Dapatkan ukuran area tempat PDF ditampilkan (dalam piksel)
    final RenderBox pdfAreaRenderBox = _pdfViewerKey.currentContext!.findRenderObject() as RenderBox;
    final Size pdfViewAreaSize = pdfAreaRenderBox.size;

    if (pdfViewAreaSize.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat menentukan ukuran area tampilan PDF.')),
      );
      return;
    }

    // Hitung posisi dan ukuran QR dalam bentuk persentase relatif terhadap area tampilan PDF
    final double xPercent = (_qrScreenPosition.dx / pdfViewAreaSize.width) * 100;
    final double yPercent = (_qrScreenPosition.dy / pdfViewAreaSize.height) * 100;
    final double widthPercent = (_qrScreenSize / pdfViewAreaSize.width) * 100;
    final double heightPercent = (_qrScreenSize / pdfViewAreaSize.width) * 100;

    // Pastikan nilai persentase valid (0-100, lebar/tinggi > 0)
    final clampedXPercent = xPercent.clamp(0.0, 100.0 - widthPercent.clamp(1.0,100.0));
    final clampedYPercent = yPercent.clamp(0.0, 100.0 - heightPercent.clamp(1.0,100.0));
    final clampedWidthPercent = widthPercent.clamp(1.0, 100.0);
    final clampedHeightPercent = heightPercent.clamp(1.0, 100.0);

    // Dialog konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Anda yakin ingin mengesahkan dokumen dengan posisi QR code ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Panggil API untuk menempelkan QR code dan mengesahkan dokumen
      final result = await _documentService.embedQrCodeOnDocument(
        documentId: widget.documentId,
        xPercent: clampedXPercent,
        yPercent: clampedYPercent,
        widthPercent: clampedWidthPercent,
        heightPercent: clampedHeightPercent,
        pageNumber: _currentPageNumber,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dokumen berhasil disahkan')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Terjadi kesalahan saat mengesahkan dokumen')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pengesahan - ${widget.fileName}'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _approveDocumentAndEmbedQr, // Panggil fungsi yang benar
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent)))
                : const Icon(Icons.check_circle_outline, color: Colors.blueAccent),
            label: Text(_isLoading ? 'Memproses...' : 'Sahkan', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 16)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Widget untuk menampilkan PDF
          Container(
            key: _pdfViewerKey, // Berikan GlobalKey ke container PDF viewer
            child: SfPdfViewer.memory(
              widget.pdfBytes,
              controller: _pdfViewerController,
              onPageChanged: (PdfPageChangedDetails details) {
                setState(() {
                  _currentPageNumber = details.newPageNumber; // SfPdfViewer page number is 1-based
                });
              },
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                // Setelah dokumen dimuat, kita bisa coba set posisi awal QR berdasarkan ukuran view
                 if (mounted && _pdfViewerKey.currentContext != null) {
                    final RenderBox pdfArea = _pdfViewerKey.currentContext!.findRenderObject() as RenderBox;
                    setState(() {
                      _qrScreenPosition = Offset(
                        pdfArea.size.width * 0.1,
                        pdfArea.size.height * 0.7,
                      );
                    });
                 }
              }
            ),
          ),
          // Widget untuk QR Code yang bisa digeser dan diubah ukurannya
          Positioned(
            left: _qrScreenPosition.dx,
            top: _qrScreenPosition.dy,
            child: GestureDetector(
              onPanUpdate: (details) { // Untuk menggeser QR
                if (_pdfViewerKey.currentContext != null) {
                  final RenderBox pdfAreaRenderBox = _pdfViewerKey.currentContext!.findRenderObject() as RenderBox;
                  final Size pdfViewAreaSize = pdfAreaRenderBox.size;
                  setState(() {
                    // Batasi pergerakan QR agar tetap di dalam area PDF viewer
                    _qrScreenPosition = Offset(
                      (_qrScreenPosition.dx + details.delta.dx).clamp(0.0, pdfViewAreaSize.width - _qrScreenSize),
                      (_qrScreenPosition.dy + details.delta.dy).clamp(0.0, pdfViewAreaSize.height - _qrScreenSize),
                    );
                  });
                }
              },
              child: Column( // Kolom untuk QR dan kontrol ukurannya
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Menampilkan gambar QR dari URL
                  Container(
                    width: _qrScreenSize,
                    height: _qrScreenSize,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueAccent, width: 2),
                      color: Colors.white.withOpacity(0.8), // Agak transparan agar PDF di bawahnya terlihat
                    ),
                    child: Image.network( // Gunakan Image.network
                      _fullQrUrl ?? '',   // URL gambar QR dari parameter widget
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) { // Tampilkan loading saat gambar QR dimuat
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) { // Tampilkan error jika gambar QR gagal dimuat
                        print('Error memuat gambar QR: $error');
                        return const Center(child: Icon(Icons.error_outline, color: Colors.red, size: 40));
                      },
                    ),
                  ),
                  // Kontrol untuk mengubah ukuran QR
                  Container(
                     width: _qrScreenSize + 40, // Buat kontrol sedikit lebih lebar dari QR
                     padding: const EdgeInsets.only(top:4),
                     child: Material(
                       color: Colors.transparent,
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           IconButton(
                            icon: Icon(Icons.remove_circle_outline, color: Colors.blueGrey.shade700),
                            iconSize: 20, // Ukuran ikon
                            // Kecilkan ukuran QR, minimal 50.0
                            onPressed: () => setState(() => _qrScreenSize = (_qrScreenSize - 10).clamp(50.0, 300.0)),
                           ),
                           Expanded(
                             child: Slider(
                               value: _qrScreenSize,
                               min: 50.0, // Ukuran minimal QR
                               max: 300.0, // Ukuran maksimal QR
                               divisions: 25, // Jumlah pembagian slider ((300-50)/10)
                               activeColor: Colors.blueAccent,
                               inactiveColor: Colors.grey.shade300,
                               label: _qrScreenSize.round().toString(), // Label saat slider digeser
                               onChanged: (double value) {
                                 setState(() {
                                   _qrScreenSize = value;
                                 });
                               },
                             ),
                           ),
                           IconButton(
                            icon: Icon(Icons.add_circle_outline, color: Colors.blueGrey.shade700),
                            iconSize: 20,
                            // Besarkan ukuran QR, maksimal 300.0
                            onPressed: () => setState(() => _qrScreenSize = (_qrScreenSize + 10).clamp(50.0, 300.0)),
                           ),
                         ],
                       ),
                     ),
                  ),
                ],
              ),
            ),
          ),
           // Indikator Halaman
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Text(
                // Tampilkan nomor halaman saat ini dan total halaman
                // _pdfViewerController.pageCount mungkin null jika dokumen belum sepenuhnya dimuat
                "Halaman: $_currentPageNumber / ${_pdfViewerController.pageCount}",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          // Tampilan loading overlay jika sedang memproses
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent))),
            ),
        ],
      ),
    );
  }
}