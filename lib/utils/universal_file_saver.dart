import 'file_saver/file_saver_interface.dart';
import 'file_saver/file_saver_stub.dart'
    if (dart.library.io) 'file_saver/file_saver_mobile.dart'
    if (dart.library.html) 'file_saver/file_saver_web.dart'
    if (dart.library.js_interop) 'file_saver/file_saver_web.dart';

/// A utility to save or download files across Web, Android, and iOS.
class UniversalFileSaver {
  /// Saves file bytes and handles platform-specific download/sharing.
  static Future<void> saveFile({
    required List<int> bytes,
    required String fileName,
  }) async {
    await getSaver().saveFile(
      bytes: bytes,
      fileName: fileName,
    );
  }
}
