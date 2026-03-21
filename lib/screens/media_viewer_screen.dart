import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class MediaViewerScreen extends StatelessWidget {
  final String url;
  final String title;

  const MediaViewerScreen({
    super.key,
    required this.url,
    this.title = "View Document",
  });

  bool get _isPdf => url.toLowerCase().contains(".pdf") || url.toLowerCase().contains("/raw/upload/");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _isPdf
            ? SfPdfViewer.network(
                url,
                enableDoubleTapZooming: true,
              )
            : InteractiveViewer(
                child: Image.network(
                  url,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                ),
              ),
      ),
    );
  }
}
