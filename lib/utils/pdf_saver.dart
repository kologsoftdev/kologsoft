import 'pdf_saver_stub.dart'
if (dart.library.html) 'pdf_saver_web.dart'
if (dart.library.io) 'pdf_saver_desktop.dart';

Future<void> savePdfFile(
    List<int> bytes,
    String fileName,
    ) {
  return savePdf(bytes, fileName);
}