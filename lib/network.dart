import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'game.dart';

String _token() {
  final random = Random.secure();
  return List.generate(
    24,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class HostServer {
  HostServer(this.game, {required this.onChanged, this.discoveryPort = 45874});
  final Game game;
  final void Function() onChanged;
  final int discoveryPort;
  final String code = (100000 + Random.secure().nextInt(900000)).toString();
  HttpServer? _server;
  RawDatagramSocket? _discovery;
  final Map<String, WebSocket> _clients = {};
  final Set<WebSocket> _sockets = {};
  final Map<String, String> _credentials = {};
  List<String> addresses = [];
  int get port => _server?.port ?? 0;
  int get activeDiscoveryPort => _discovery?.port ?? discoveryPort;
  bool _closed = false;

  Future<void> start({int port = 45873}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    addresses = (await NetworkInterface.list(type: InternetAddressType.IPv4))
        .expand((i) => i.addresses)
        .where((a) => !a.isLoopback)
        .map((a) => '${a.address}:${_server!.port}')
        .toList();
    try {
      _discovery = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: false,
      );
      _discovery!.listen(_discoveryEvent, onError: (_) {});
    } catch (_) {
      await _server?.close(force: true);
      _server = null;
      rethrow;
    }
    _server!.listen(_request, onError: (_) {});
  }

  void _discoveryEvent(RawSocketEvent event) {
    if (_closed || event != RawSocketEvent.read) return;
    Datagram? datagram;
    while ((datagram = _discovery?.receive()) != null) {
      final packet = datagram!;
      if (packet.data.length > 512) continue;
      try {
        final request = jsonDecode(
          utf8.decode(packet.data, allowMalformed: false),
        );
        if (request is! Map ||
            request['type'] != 'excellent_thursday_discover_v1' ||
            request['code'] != code) {
          continue;
        }
        final response = utf8.encode(
          jsonEncode({
            'type': 'excellent_thursday_host_v1',
            'code': code,
            'port': port,
          }),
        );
        _discovery?.send(response, packet.address, packet.port);
      } catch (_) {
        // Ignore unrelated broadcast traffic on the local network.
      }
    }
  }

  Future<void> _request(HttpRequest request) async {
    if (_closed ||
        request.uri.path != '/play' ||
        !WebSocketTransformer.isUpgradeRequest(request) ||
        _sockets.length >= 64) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    try {
      final socket = await WebSocketTransformer.upgrade(request);
      if (_closed) {
        await socket.close();
        return;
      }
      _sockets.add(socket);
      socket.pingInterval = const Duration(seconds: 15);
      String? playerId;
      final deadline = Timer(const Duration(seconds: 8), () {
        if (playerId == null) unawaited(socket.close());
      });
      socket.listen(
        (raw) {
          try {
            if (raw is! String || raw.length > 4096) {
              unawaited(socket.close());
              return;
            }
            final data = jsonDecode(raw) as Map<String, dynamic>;
            if (playerId == null) {
              if (data['type'] != 'join' || data['code'] != code) {
                socket.add(
                  jsonEncode({
                    'type': 'error',
                    'message': 'كود الجلسة مش صحيح.',
                  }),
                );
                unawaited(socket.close());
                return;
              }
              final reconnect = data['token'];
              String credential;
              if (reconnect is String && _credentials.containsKey(reconnect)) {
                credential = reconnect;
                playerId = _credentials[reconnect];
                final old = _clients[playerId];
                _clients[playerId!] = socket;
                if (old != null) unawaited(old.close());
                game.players[playerId]!.online = true;
              } else {
                final name = (data['name'] as String).trim();
                final team = data['team'] as int;
                if (game.players.length >= 64) throw const FormatException();
                final newId = _token();
                game.addPlayer(Player(newId, name, team));
                playerId = newId;
                credential = _token();
                _credentials[credential] = newId;
                _clients[newId] = socket;
              }
              deadline.cancel();
              socket.add(
                jsonEncode({
                  'type': 'welcome',
                  'token': credential,
                  'id': playerId,
                }),
              );
              publish();
            } else if (data['type'] == 'buzz' &&
                identical(_clients[playerId], socket) &&
                data['window'] is int) {
              final accepted = game.buzz(playerId!, data['window'] as int);
              if (accepted) {
                publish();
              } else {
                socket.add(
                  jsonEncode({'type': 'state', 'state': game.publicState()}),
                );
              }
            }
          } catch (_) {
            if (socket.readyState == WebSocket.open) {
              socket.add(
                jsonEncode({
                  'type': 'error',
                  'message': 'راجع اسمك ورقم فريقك وحاول تاني.',
                }),
              );
              unawaited(socket.close());
            }
          }
        },
        onDone: () {
          deadline.cancel();
          _sockets.remove(socket);
          if (identical(_clients[playerId], socket)) {
            _clients.remove(playerId);
            game.players[playerId]?.online = false;
            if (!_closed) publish();
          }
        },
        onError: (_) {
          unawaited(socket.close());
        },
      );
    } catch (_) {
      /* A client may disappear during the HTTP upgrade. */
    }
  }

  void publish() {
    if (_closed) return;
    final message = jsonEncode({'type': 'state', 'state': game.publicState()});
    for (final socket in _clients.values.toList()) {
      if (socket.readyState != WebSocket.open) continue;
      try {
        socket.add(message);
      } catch (_) {
        unawaited(socket.close());
      }
    }
    onChanged();
  }

  void refreshConnections() {
    if (_closed) return;
    final staleSockets = _sockets.toList();
    _clients.clear();
    for (final player in game.players.values) {
      player.online = false;
    }
    for (final socket in staleSockets) {
      if (socket.readyState == WebSocket.open) {
        unawaited(socket.close(WebSocketStatus.goingAway, 'Host resumed'));
      }
    }
    publish();
  }

  Future<void> close() async {
    _closed = true;
    _discovery?.close();
    await _server?.close(force: true);
    await Future.wait(_sockets.toList().map((s) => s.close()));
    _clients.clear();
    _sockets.clear();
  }
}

class PlayerClient {
  PlayerClient({
    this.address,
    required this.code,
    required this.name,
    required this.team,
    required this.onChanged,
    this.discoveryPort = 45874,
    this.discoveryHost = '255.255.255.255',
  });
  final String? address;
  final String code, name;
  final int team;
  final int discoveryPort;
  final String discoveryHost;
  final void Function() onChanged;
  WebSocket? _socket;
  RawDatagramSocket? _finder;
  Timer? _retry;
  Timer? _discoveryTimer;
  String? resolvedAddress;
  String? token;
  String? id;
  Map<String, dynamic>? state;
  bool connected = false;
  bool _closed = false;
  bool _connecting = false;
  bool rejected = false;
  String status = 'بنوصل بالهوست…';
  int? sentWindow;

  static Uri endpoint(String address) {
    final cleaned = address.trim();
    final uri = Uri.tryParse('ws://$cleaned/play');
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.path != '/play' ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('اكتب عنوان الهوست بالشكل 192.168.1.5:45873');
    }
    return uri.replace(port: uri.hasPort ? uri.port : 45873);
  }

  Future<void> connect() async {
    if (_closed || _connecting || rejected || connected) return;
    _connecting = true;
    WebSocket? socket;
    try {
      status = resolvedAddress == null && address?.trim().isNotEmpty != true
          ? 'بندور على الهوست في الشبكة…'
          : 'بنوصل بالهوست…';
      onChanged();
      final manualAddress = address?.trim();
      if (manualAddress?.isNotEmpty == true) {
        final target = endpoint(manualAddress!);
        socket = await _openSocket(target);
        resolvedAddress = '${target.host}:${target.port}';
      } else if (resolvedAddress != null) {
        final cachedTarget = endpoint(resolvedAddress!);
        try {
          socket = await _openSocket(cachedTarget);
        } catch (_) {
          resolvedAddress = null;
          status = 'بندور على الهوست في الشبكة…';
          onChanged();
          final discoveredTarget = await _discoverHost();
          socket = await _openSocket(discoveredTarget);
          resolvedAddress = '${discoveredTarget.host}:${discoveredTarget.port}';
        }
      } else {
        final discoveredTarget = await _discoverHost();
        socket = await _openSocket(discoveredTarget);
        resolvedAddress = '${discoveredTarget.host}:${discoveredTarget.port}';
      }
      if (_closed) {
        await socket.close();
        return;
      }
      _socket = socket;
      socket.pingInterval = const Duration(seconds: 15);
      socket.add(
        jsonEncode({
          'type': 'join',
          'code': code,
          'name': name,
          'team': team,
          'token': token,
        }),
      );
      socket.listen(
        (raw) {
          if (_closed || !identical(_socket, socket)) return;
          try {
            final message = jsonDecode(raw as String) as Map<String, dynamic>;
            if (message['type'] == 'welcome') {
              token = message['token'] as String;
              id = message['id'] as String;
            } else if (message['type'] == 'state') {
              state = Map<String, dynamic>.from(message['state'] as Map);
              connected = true;
              status = 'متصل بالهوست';
              if (state!['window'] != sentWindow) sentWindow = null;
            } else if (message['type'] == 'error') {
              status = message['message'] as String;
              rejected = true;
              connected = false;
            }
            onChanged();
          } catch (_) {
            unawaited(socket!.close());
          }
        },
        onDone: () => _disconnected(socket),
        onError: (_) => _disconnected(socket),
      );
    } catch (_) {
      if (!_closed) {
        status = 'مش لاقيين الجلسة. راجع الكود والشبكة، وبنحاول تاني…';
        onChanged();
        _scheduleRetry();
      }
    } finally {
      _connecting = false;
    }
  }

  Future<WebSocket> _openSocket(Uri target) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      return await WebSocket.connect(
        target.toString(),
        customClient: client,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      client.close(force: true);
      rethrow;
    }
  }

  Future<Uri> _discoverHost() async {
    final finder = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: false,
    );
    _finder = finder;
    finder.broadcastEnabled = true;
    final completer = Completer<Uri>();
    late final StreamSubscription<RawSocketEvent> subscription;
    subscription = finder.listen((event) {
      if (event != RawSocketEvent.read || completer.isCompleted) return;
      Datagram? datagram;
      while ((datagram = finder.receive()) != null) {
        final packet = datagram!;
        if (packet.data.length > 512) continue;
        try {
          final response = jsonDecode(
            utf8.decode(packet.data, allowMalformed: false),
          );
          final port = response is Map ? response['port'] : null;
          if (response is! Map ||
              response['type'] != 'excellent_thursday_host_v1' ||
              response['code'] != code ||
              port is! int ||
              port < 1 ||
              port > 65535) {
            continue;
          }
          completer.complete(
            Uri(
              scheme: 'ws',
              host: packet.address.address,
              port: port,
              path: '/play',
            ),
          );
          return;
        } catch (_) {
          // Ignore unrelated UDP packets and keep searching.
        }
      }
    }, onError: (_) {});

    final request = utf8.encode(
      jsonEncode({'type': 'excellent_thursday_discover_v1', 'code': code}),
    );
    void sendRequest() {
      if (_closed || completer.isCompleted) return;
      try {
        finder.send(request, InternetAddress(discoveryHost), discoveryPort);
      } catch (_) {
        // A retry will run if the network interface is still starting.
      }
    }

    _discoveryTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => sendRequest(),
    );
    sendRequest();
    try {
      return await completer.future.timeout(const Duration(seconds: 5));
    } finally {
      _discoveryTimer?.cancel();
      _discoveryTimer = null;
      await subscription.cancel();
      finder.close();
      if (identical(_finder, finder)) _finder = null;
    }
  }

  void _disconnected(WebSocket? socket) {
    if (_closed || !identical(socket, _socket)) return;
    connected = false;
    _socket = null;
    sentWindow = null;
    if (!rejected) {
      status = 'الاتصال فصل… بنحاول نرجع لنفس الفريق';
      _scheduleRetry();
    }
    onChanged();
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (!_closed && !rejected) {
      _retry = Timer(const Duration(milliseconds: 750), connect);
    }
  }

  bool get canBuzz {
    if (!connected ||
        state == null ||
        state!['armed'] != true ||
        state!['winner'] != null ||
        sentWindow == state!['window']) {
      return false;
    }
    final scores = state!['scores'] as List;
    return team < scores.length && (scores[team] as int) > -5;
  }

  void buzz() {
    if (!canBuzz) return;
    sentWindow = state!['window'] as int;
    _socket?.add(jsonEncode({'type': 'buzz', 'window': sentWindow}));
    onChanged();
  }

  Future<void> close() async {
    _closed = true;
    _retry?.cancel();
    _discoveryTimer?.cancel();
    _finder?.close();
    await _socket?.close();
    connected = false;
  }
}
