import 'file_saver_interface.dart';

class FileSaverStub implements FileSaverInterface {
  @override
  Future<void> saveFile({
    required List<int> bytes,
    required String fileName,
  }) async {
    throw UnimplementedError('FileSaver stub called');
  }
}

FileSaverInterface getSaver() => FileSaverStub();
