import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

Future<void> savePdf(
    List<int> bytes,
    String fileName,
    ) async {
  final location = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: [
      const XTypeGroup(
        label: 'PDF files',
        extensions: ['pdf'],
        mimeTypes: ['application/pdf'],
      ),
    ],
  );

  if (location == null) {
    return;
  }

  final file = XFile.fromData(
    Uint8List.fromList(bytes),
    mimeType: 'application/pdf',
    name: fileName,
  );

  await file.saveTo(location.path);
}