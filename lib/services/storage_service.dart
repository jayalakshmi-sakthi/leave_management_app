import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload signed form for approved leaves
  Future<String> uploadSignedForm(String leaveId, File file) async {
    try {
      final ext = p.extension(file.path);
      final ref = _storage.ref().child(
          'signed_forms/$leaveId/${DateTime.now().millisecondsSinceEpoch}$ext');

      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();
      return url;
    } catch (e) {
      throw Exception('Failed to upload signed form: $e');
    }
  }

  /// Upload any generic file (from ImagePicker)
  Future<String> uploadFile({
    required XFile file,
    required String path, // e.g., leaveProofs/2024-2025/appId.jpg
  }) async {
    try {
      final f = File(file.path);
      final ref = _storage.ref().child(path);

      final task = await ref.putFile(f);
      final url = await task.ref.getDownloadURL();
      return url;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Optional: Upload with progress callback
  Future<String> uploadFileWithProgress({
    required XFile file,
    required String path,
    void Function(double progress)? onProgress,
  }) async {
    final f = File(file.path);
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putFile(f);

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        final prog = event.bytesTransferred / event.totalBytes;
        onProgress(prog);
      });
    }

    final taskSnapshot = await uploadTask;
    return await taskSnapshot.ref.getDownloadURL();
  }
}
