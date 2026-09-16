typedef SendPort = _WebSendPort;

typedef ReceiveCallback = void Function(dynamic message);

class _WebSendPort {
  final void Function(dynamic message) _send;

  const _WebSendPort(this._send);

  void send(dynamic message) => _send(message);
}

class ReceivePort {
  final List<dynamic> _pendingMessages = <dynamic>[];
  ReceiveCallback? _listener;
  void Function()? _onDone;
  bool _closed = false;

  SendPort get sendPort => _WebSendPort(_receive);

  void _receive(dynamic message) {
    if (_closed) return;
    if (_listener == null) {
      _pendingMessages.add(message);
    } else {
      _listener!(message);
    }
  }

  void listen(
    ReceiveCallback onData, {
    Function? onError,
    void Function()? onDone,
  }) {
    if (_closed) return;
    _listener = onData;
    _onDone = onDone;
    for (final message in List<dynamic>.from(_pendingMessages)) {
      onData(message);
    }
    _pendingMessages.clear();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _pendingMessages.clear();
    _onDone?.call();
  }
}

class Isolate {
  static Future<Isolate> spawn(
    void Function(Map<String, dynamic> payload) entryPoint,
    Map<String, dynamic> message, {
    dynamic debugName,
    dynamic errorsAreFatal,
    dynamic onExit,
    dynamic onError,
    dynamic paused,
    dynamic priority,
  }) async {
    entryPoint(message);
    return Isolate._();
  }

  Isolate._();

  void kill({dynamic priority}) {}
}
