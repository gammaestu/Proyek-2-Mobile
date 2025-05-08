import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class PDFViewerPage extends StatefulWidget {
  final String url;

  const PDFViewerPage({Key? key, required this.url}) : super(key: key);

  @override
  State<PDFViewerPage> createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  String? localPath;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadDocument();
  }

  Future<void> loadDocument() async {
    setState(() {
      isLoading = true;
    });

    try {
      if (kIsWeb) {
        setState(() {
          localPath = widget.url;
          isLoading = false;
        });
      } else {
        // Handle mobile platforms
        final file = File(widget.url);
        if (await file.exists()) {
          setState(() {
            localPath = file.path;
            isLoading = false;
          });
        } else {
          throw Exception('File tidak ditemukan');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : localPath != null
              ? SfPdfViewer.file(
                  File(localPath!),
                  onDocumentLoadFailed: (details) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${details.description}')),
                    );
                  },
                )
              : const Center(child: Text('Tidak dapat memuat PDF')),
    );
  }
}
