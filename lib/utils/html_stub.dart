/// Stub for dart:html on non-web platforms
/// This is used as a conditional import when running on mobile/desktop

class Blob {
  Blob(List<dynamic> parts, String type);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) {
    return '';
  }

  static void revokeObjectUrl(String url) {}
}

class Window {
  dynamic open(String url, String target) {
    return null;
  }

  void print() {}
}

class WindowBase {
  void print() {}
}

/// Minimal stub for CSS style used in dart:html
class CssStyleDeclaration {
  String? display;
  String? position;
  String? width;
  String? height;
  String? border;

  // Provide bracket-like assignment for defensive compatibility
  void operator []=(String key, String value) {
    switch (key) {
      case 'display':
        display = value;
        break;
      case 'position':
        position = value;
        break;
      case 'width':
        width = value;
        break;
      case 'height':
        height = value;
        break;
      case 'border':
        border = value;
        break;
      default:
        break;
    }
  }
}

class AnchorElement {
  String href = '';
  String download = '';
  CssStyleDeclaration style = CssStyleDeclaration();

  void click() {}
}

class IFrameElement {
  String src = '';
  CssStyleDeclaration style = CssStyleDeclaration();
  WindowBase? contentWindow;
  Stream<dynamic> get onLoad => Stream.empty();
}

class Document {
  HtmlElement? body;

  dynamic createElement(String tag) {
    if (tag == 'iframe') {
      return IFrameElement();
    }
    return AnchorElement();
  }
}

class HtmlElement {
  List<dynamic> children = [];
}

final window = Window();
final document = Document();
