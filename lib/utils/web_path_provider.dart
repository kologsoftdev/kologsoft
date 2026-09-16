/// Web stub for path_provider package
/// This is used as a conditional import when running on web platform
/// where path_provider's getTemporaryDirectory is not available

class Directory {
  final String path;
  Directory(this.path);
}

/// Returns a dummy directory for web platform
/// On web, we don't use the file system - instead we use Blob/download
Future<Directory> getTemporaryDirectory() async {
  return Directory('/tmp');
}
