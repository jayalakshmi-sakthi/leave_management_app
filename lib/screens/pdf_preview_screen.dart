import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import '../services/pdf_service.dart';

class PdfPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const PdfPreviewScreen({super.key, required this.requestData});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  Uint8List? _imageBytes; // For the preview image
  Uint8List? _pdfBytes;   // For the actual PDF file
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateAndRasterize();
  }

  Future<void> _generateAndRasterize() async {
    try {
      // 1. Generate PDF Bytes
      final pdfBytes = await PdfService().generatePdfBytes(widget.requestData);
      
      // 2. Rasterize the first page to an image for zooming
      // Note: We only expect 1 page for the application form usually.
      final raster = Printing.raster(pdfBytes, pages: [0], dpi: 200); // Scale via DPI (72 is default, 200 is good quality)
      final image = await raster.first;
      
      final pngBytes = await image.toPng();
      
      if (mounted) {
        setState(() {
          _pdfBytes = pdfBytes;
          _imageBytes = pngBytes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _printOrShare() async {
    if (_pdfBytes == null) return;
    final name = "Application_${widget.requestData['applicationId'] ?? 'Form'}";
    await Printing.layoutPdf(
      onLayout: (_) async => _pdfBytes!,
      name: name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Application Preview"),
        centerTitle: true,
        actions: [
          if (!_loading && _pdfBytes != null)
            IconButton(
              icon: const Icon(Icons.print_rounded),
              onPressed: _printOrShare,
              tooltip: "Print / Save as PDF",
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Error: $_error"))
              : Center(
                  child: InteractiveViewer(
                    panEnabled: true, // Allow panning
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 1.0,
                    maxScale: 5.0, // ✅ Allow Deep Zoom
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ]
                      ),
                      child: Image.memory(
                        _imageBytes!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
      floatingActionButton: !_loading && _pdfBytes != null ? FloatingActionButton.extended(
        onPressed: _printOrShare,
        icon: const Icon(Icons.download_rounded),
        label: const Text("Download / Print PDF"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ) : null,
    );
  }
}
