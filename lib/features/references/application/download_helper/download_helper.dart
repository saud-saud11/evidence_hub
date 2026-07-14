import 'dart:typed_data';
import 'download_helper_io.dart' if (dart.library.html) 'download_helper_web.dart';

Future<void> triggerDownload(Uint8List bytes, String filename) async {
  await downloadBytes(bytes, filename);
}
