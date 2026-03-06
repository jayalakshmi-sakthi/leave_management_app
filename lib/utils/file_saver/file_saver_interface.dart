abstract class FileSaverInterface {
  Future<void> saveFile({
    required List<int> bytes,
    required String fileName,
  });
}
