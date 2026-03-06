import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'dart:typed_data';

class CropScreen extends StatefulWidget {
  final Uint8List image;
  const CropScreen({super.key, required this.image});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final _cropController = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Crop Profile Picture", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Padding(
             padding: const EdgeInsets.all(20),
             child: Crop(
                image: widget.image,
                controller: _cropController,
                onCropped: (image) {
                  Navigator.pop(context, image); // Return cropped bytes
                },
                aspectRatio: 1, // Square for Profile
                withCircleUi: true, // Circular mask for preview
                baseColor: Colors.black,
                maskColor: Colors.black.withOpacity(0.6),
                initialSize: 0.8,
              ),
          ),
          if (_isCropping)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
               TextButton(
                 onPressed: () => Navigator.pop(context), 
                 child: const Text("Cancel", style: TextStyle(color: Colors.grey))
               ),
               ElevatedButton(
                 onPressed: _isCropping ? null : () {
                   setState(() => _isCropping = true);
                   _cropController.crop();
                 },
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFF7C3AED),
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                 ),
                 child: const Text("Save"),
               )
            ],
          ),
        ),
      ),
    );
  }
}
