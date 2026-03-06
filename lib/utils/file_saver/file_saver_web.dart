import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'file_saver_interface.dart';

class FileSaverWeb implements FileSaverInterface {
  @override
  Future<void> saveFile({
    required List<int> bytes,
    required String fileName,
  }) async {
    // On Web, Share.shareXFiles triggers a download for any file type effectively
    await Share.shareXFiles(
      [XFile.fromData(Uint8List.fromList(bytes), name: fileName, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: 'Leave Report',
    );
  }
}

FileSaverInterface getSaver() => FileSaverWeb();
