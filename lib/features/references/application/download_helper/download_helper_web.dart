import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'dart:typed_data';

Future<void> downloadBytes(Uint8List bytes, String filename) async {
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
    
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  
  web.URL.revokeObjectURL(url);
}
