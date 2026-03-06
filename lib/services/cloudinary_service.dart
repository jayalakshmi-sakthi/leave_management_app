import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../utils/cloudinary_config.dart';
import 'package:http_parser/http_parser.dart'; // ✅ Added for MediaType

class CloudinaryService {
  static Future<String> uploadFile(XFile file, {String? publicId}) async {
    // Helper to perform the actual request
    Future<String> _doUpload({String? pid}) async {
      final uri = Uri.parse(CloudinaryConfig.uploadUrl);
      final bytes = await file.readAsBytes();
      
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = CloudinaryConfig.uploadPreset;
        
      if (pid != null) {
        request.fields['public_id'] = pid;
      }

      final String safeFilename = file.name.isNotEmpty 
          ? file.name 
          : 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';

      print("☁️ Cloudinary: Bytes: ${bytes.length}, Filename: $safeFilename");

      request.files.add(
        http.MultipartFile.fromBytes(
          'file', 
          bytes, 
          filename: safeFilename,
          contentType: MediaType('image', 'jpeg'), // ✅ Re-adding MediaType for safety since we have a name now
        ),
      );

      print("☁️ Cloudinary: Uploading... (Public ID: ${pid ?? 'Auto'})");
      final response = await request.send().timeout(const Duration(seconds: 45));
      final resBody = await response.stream.bytesToString();
      final data = jsonDecode(resBody);

      if (response.statusCode == 200) {
        return data['secure_url'];
      } else {
        throw Exception("Status ${response.statusCode}: ${data['error']['message']}");
      }
    }

    try {
      // 1. Try with Public ID (Overwrite)
      if (publicId != null) {
        try {
          return await _doUpload(pid: publicId);
        } catch (e) {
          print("⚠️ Overwrite failed ($e). Falling back to new file...");
          // Fallback proceeds below
        }
      }
      
      // 2. Fallback / Standard Upload
      return await _doUpload(pid: null);
      
    } catch (e) {
      print("☁️ Cloudinary Error: $e");
      rethrow;
    }
  }

  /// Upload file using bytes (for Web compatibility)
  static Future<String> uploadFileBytes(List<int> bytes, String filename) async {
    final uri = Uri.parse(CloudinaryConfig.uploadUrl);

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

    final response = await request.send();
    final resBody = await response.stream.bytesToString();
    final data = jsonDecode(resBody);

    if (response.statusCode == 200) {
      return data['secure_url'];
    } else {
      throw Exception(data['error']['message'] ?? 'Upload failed');
    }
  }
}
