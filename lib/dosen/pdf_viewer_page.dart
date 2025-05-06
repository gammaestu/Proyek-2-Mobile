import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';

class PDFViewerPage extends StatefulWidget {
  final String? url;
  final Uint8List? pdfBytes;
  final String title;

  PDFViewerPage({
    this.url,
    this.pdfBytes,
    this.title = 'Dokumen PDF',
  }) : assert(url != null || pdfBytes != null,
            'Either url or pdfBytes must be provided');

  @override
  _PDFViewerPageState createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  String? localPath;
  Uint8List? pdfData;
  bool isLoading = true;
  String? errorMessage;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  int currentPage = 1;
  int totalPages = 0;

  @override
  void initState() {
    super.initState();
    if (widget.pdfBytes != null) {
      setState(() {
        pdfData = widget.pdfBytes;
        isLoading = false;
      });
    } else if (widget.url != null) {
      downloadAndSavePDF();
    }
  }

  Future<void> downloadAndSavePDF() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await http
          .get(Uri.parse(widget.url!))
          .timeout(Duration(seconds: 30), onTimeout: () {
        throw TimeoutException('Connection timed out');
      });

      if (response.statusCode == 200) {
        // Check if response is a PDF
        final contentType = response.headers['content-type'] ?? '';
        if (!contentType.contains('pdf') &&
            !contentType.contains('octet-stream')) {
          final responseBody = response.body.length > 100
              ? '${response.body.substring(0, 100)}...'
              : response.body;

          print('Unexpected content type: $contentType');
          print('Response preview: $responseBody');

          // Try to parse as JSON to check if it's an API response
          try {
            final jsonResponse = json.decode(response.body);
            if (jsonResponse['data'] != null &&
                jsonResponse['data'] is String) {
              // Try to decode base64
              final base64Data = jsonResponse['data'] as String;
              pdfData = base64.decode(base64Data);
            } else {
              throw Exception('Response is not a PDF file');
            }
          } catch (e) {
            throw Exception(
                'Received content type: $contentType, expected PDF');
          }
        } else {
          // Regular PDF binary data
          pdfData = response.bodyBytes;
        }

        // For compatibility, still save a local copy
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/document.pdf');
        await file.writeAsBytes(pdfData!);

        if (mounted) {
          setState(() {
            localPath = file.path;
            isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading PDF: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Halaman: $currentPage / $totalPages',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Memuat dokumen...'),
        ],
      ));
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 60),
            SizedBox(height: 16),
            Text(
              'Gagal memuat dokumen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.url != null ? downloadAndSavePDF : null,
              child: Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    // PDF Viewer from memory if pdfData is available
    if (pdfData != null && pdfData!.isNotEmpty) {
      return SfPdfViewer.memory(
        pdfData!,
        key: _pdfViewerKey,
        enableDocumentLinkAnnotation: true,
        enableHyperlinkNavigation: true,
        pageSpacing: 0,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          print('PDF document loaded, pages: ${details.document.pages.count}');
          setState(() {
            totalPages = details.document.pages.count;
          });
        },
        onPageChanged: (PdfPageChangedDetails details) {
          setState(() {
            currentPage = details.newPageNumber;
          });
        },
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          print('Failed to load PDF: ${details.error}');
          print('Description: ${details.description}');
          setState(() {
            errorMessage = details.description;
          });
        },
      );
    }

    // PDF Viewer from file if localPath is available
    if (localPath != null) {
      return SfPdfViewer.file(
        File(localPath!),
        key: _pdfViewerKey,
        enableDocumentLinkAnnotation: true,
        enableHyperlinkNavigation: true,
        pageSpacing: 0,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          print('PDF document loaded, pages: ${details.document.pages.count}');
          setState(() {
            totalPages = details.document.pages.count;
          });
        },
        onPageChanged: (PdfPageChangedDetails details) {
          setState(() {
            currentPage = details.newPageNumber;
          });
        },
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          print('Failed to load PDF: ${details.error}');
          print('Description: ${details.description}');
          setState(() {
            errorMessage = details.description;
          });
        },
      );
    }

    return Center(child: Text('Tidak ada dokumen untuk ditampilkan'));
  }
}
