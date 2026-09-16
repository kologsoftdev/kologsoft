/// Web stub for dart:io File class
/// This is used as a conditional import when running on web platform

class File {
  final String path;
  File(this.path);

  Future<void> writeAsBytes(List<int> bytes) async {
    // No-op on web - we handle file operations differently using Blob
  }
}

class Directory {
  final String path;
  Directory(this.path);
}
