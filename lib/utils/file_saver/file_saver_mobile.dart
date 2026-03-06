import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'file_saver_interface.dart';

class FileSaverMobile implements FileSaverInterface {
  @override
  Future<void> saveFile({
    required List<int> bytes,
    required String fileName,
  }) async {
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/$fileName";
    final file = File(path);
    await file.writeAsBytes(bytes);
    
    // Use Share for mobile (handles Excel docs better than Printing)
    await Share.shareXFiles(
      [XFile(path, name: fileName)],
      subject: 'Leave Report',
    );
  }
}

FileSaverInterface getSaver() => FileSaverMobile();
