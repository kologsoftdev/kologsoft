import 'package:flutter/foundation.dart';

class DomainDetector {
  const DomainDetector._();

  /// On Flutter Web this is the current hostname (e.g. "app.example.com").
  /// On non-web platforms this is usually empty.
  static String get host {
    final host = Uri.base.host.trim().toLowerCase();
    if (host.isEmpty) return '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  static int get port => Uri.base.port;

  static bool get isWeb => kIsWeb;

  static bool get isLocalhost {
    final h = host;
    return h == 'localhost' || h == '127.0.0.1' || h == '0.0.0.0';
  }
}
