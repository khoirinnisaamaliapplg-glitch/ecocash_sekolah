import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Live channel for the user's machine session.
///
/// Contract (`docs/user-deposit-waste-quickstart.md`): connect once to the
/// `/sessions` namespace with the user JWT and keep it open.
///
///  * `session:started` — `{ sessionId, status, machineId, startedAt }`
///  * `session:item`    — `{ sessionId, seq, item: { id, wasteTypeId,
///                          wasteType, weight, pricePerKg, totalPrice,
///                          createdAt } }`
///  * `session:state`   — `{ sessionId, status, summary? , earned?, balance? }`
///
/// The socket does **not** replace the HTTP snapshot: nothing is replayed for
/// events that were emitted while the socket was down. Whenever this class
/// reports `connected == true` (first connect and every reconnect) the caller
/// must re-read `GET /machine-sessions/current` (or `/:id`). When it reports
/// `connected == false` the caller should fall back to polling, because a proxy
/// without the WebSocket upgrade headers can still block the connection.
class SessionSocket {
  SessionSocket({
    this.onStarted,
    this.onItem,
    this.onState,
    this.onConnectionChanged,
  });

  final void Function(Map<String, dynamic> event)? onStarted;
  final void Function(Map<String, dynamic> event)? onItem;
  final void Function(Map<String, dynamic> event)? onState;

  /// `true` on connect/reconnect, `false` when the connection drops or fails.
  final void Function(bool connected)? onConnectionChanged;

  io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  /// Connects with [ApiConfig.userToken]. Does nothing when there is no token.
  void connect() {
    final String? token = ApiConfig.userToken?.trim();

    if (token == null || token.isEmpty) {
      debugPrint('SOCKET /sessions skipped: no token');

      return;
    }

    disconnect();

    final io.Socket socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder().setAuth({'token': token}).disableAutoConnect().build(),
    );

    socket.onConnect((_) {
      debugPrint('SOCKET /sessions connected');

      onConnectionChanged?.call(true);
    });

    socket.onDisconnect((_) {
      debugPrint('SOCKET /sessions disconnected');

      onConnectionChanged?.call(false);
    });

    socket.onConnectError((error) {
      debugPrint('SOCKET /sessions connect error: $error');

      onConnectionChanged?.call(false);
    });

    socket.onError((error) {
      debugPrint('SOCKET /sessions error: $error');
    });

    socket.on('session:started', (data) => _dispatch(onStarted, data));

    socket.on('session:item', (data) => _dispatch(onItem, data));

    socket.on('session:state', (data) => _dispatch(onState, data));

    _socket = socket;

    socket.connect();
  }

  void disconnect() {
    final io.Socket? socket = _socket;

    _socket = null;

    if (socket == null) {
      return;
    }

    socket.off('session:started');
    socket.off('session:item');
    socket.off('session:state');

    socket.dispose();
  }

  void _dispatch(
    void Function(Map<String, dynamic> event)? handler,
    dynamic data,
  ) {
    if (handler == null) {
      return;
    }

    if (data is Map) {
      handler(Map<String, dynamic>.from(data));

      return;
    }

    handler(<String, dynamic>{});
  }
}
