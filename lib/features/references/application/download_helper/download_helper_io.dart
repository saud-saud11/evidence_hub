import 'dart:typed_data';

Future<void> downloadBytes(Uint8List bytes, String filename) async {
  throw Exception('Direct file download is only supported on Web in this context. Use share or file_saver packages for mobile/desktop.');
}
