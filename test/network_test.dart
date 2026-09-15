import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:excellent_thursday/game.dart';
import 'package:excellent_thursday/network.dart';

Future<void> until(bool Function() condition) async {
  final limit = DateTime.now().add(const Duration(seconds: 8));
  while (!condition()) {
    if (DateTime.now().isAfter(limit)) {
      fail('Timed out waiting for network state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

void main() {
  test(
    'real sockets: race, retry, reconnect, elimination, credential isolation',
    () async {
      final game = Game(['أ', 'ب', 'ج']);
      final server = HostServer(game, onChanged: () {}, discoveryPort: 0);
      await server.start(port: 0);
      addTearDown(server.close);
      PlayerClient make(int team) => PlayerClient(
        address: '127.0.0.1:${server.port}',
        code: server.code,
        name: 'لاعب $team',
        team: team,
        onChanged: () {},
      );
      final a = make(0), b = make(1);
      addTearDown(a.close);
      addTearDown(b.close);
      await Future.wait([a.connect(), b.connect()]);
      await until(() => a.connected && b.connected);
      expect(game.players.length, 2);
      expect(jsonEncode(game.publicState()).contains(a.token!), isFalse);
      game.arm();
      server.publish();
      await until(() => a.canBuzz && b.canBuzz);
      a.buzz();
      b.buzz();
      await until(() => game.pending != null);
      await until(
        () => a.state!['pending'] != null && b.state!['pending'] != null,
      );
      expect(
        (a.state!['pending'] as Map)['id'],
        (b.state!['pending'] as Map)['id'],
      );
      final scoringTeam = game.pending!.team;
      game.judge(false);
      server.publish();
      expect(game.scores[scoringTeam], -1);
      expect(game.judge(false), isFalse);
      game.arm();
      server.publish();
      await until(() => a.canBuzz && b.canBuzz);
      a.buzz();
      await until(() => game.pending != null);
      expect(game.pending!.team, 0);
      game.judge(true);
      server.publish();
      final oldToken = a.token;
      await a.close();
      await until(() => !game.players[a.id]!.online);
      final replacement = make(0)..token = oldToken;
      addTearDown(replacement.close);
      await replacement.connect();
      await until(() => replacement.connected);
      expect(replacement.id, a.id);
      expect(game.players.length, 2);
      expect(game.players[a.id]!.online, isTrue);
    },
  );

  test(
    'wrong room is rejected; players cannot submit score mutations or stale buzz',
    () async {
      final game = Game(['أ', 'ب']);
      final server = HostServer(game, onChanged: () {}, discoveryPort: 0);
      await server.start(port: 0);
      addTearDown(server.close);
      final bad = PlayerClient(
        address: '127.0.0.1:${server.port}',
        code: 'wrong',
        name: 'س',
        team: 0,
        onChanged: () {},
      );
      addTearDown(bad.close);
      await bad.connect();
      await until(() => bad.rejected);
      expect(game.players, isEmpty);
      final socket = await WebSocket.connect(
        'ws://127.0.0.1:${server.port}/play',
      );
      addTearDown(socket.close);
      socket.listen((_) {});
      socket.add(
        jsonEncode({
          'type': 'join',
          'code': server.code,
          'name': 'س',
          'team': 0,
        }),
      );
      await until(() => game.players.isNotEmpty);
      game.arm();
      final stale = game.window;
      game.closeBell();
      game.arm();
      server.publish();
      socket.add(jsonEncode({'type': 'judge', 'correct': true}));
      socket.add(jsonEncode({'type': 'buzz', 'window': stale}));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(game.scores, [0, 0]);
      expect(game.pending, isNull);
      socket.add(jsonEncode({'type': 'buzz', 'window': game.window}));
      await until(() => game.pending != null);
    },
  );

  test('player discovers host and reconnects after host resumes', () async {
    final game = Game(['أ', 'ب']);
    final server = HostServer(game, onChanged: () {}, discoveryPort: 0);
    await server.start(port: 0);
    addTearDown(server.close);
    var joined = false;
    var disconnectedAfterJoin = false;
    late final PlayerClient player;
    player = PlayerClient(
      code: server.code,
      name: 'مروان',
      team: 1,
      onChanged: () {
        if (joined && !player.connected) disconnectedAfterJoin = true;
      },
      discoveryPort: server.activeDiscoveryPort,
      discoveryHost: '127.0.0.1',
    );
    addTearDown(player.close);

    await player.connect();
    await until(() => player.connected);
    joined = true;

    expect(player.address, isNull);
    expect(player.resolvedAddress, '127.0.0.1:${server.port}');
    expect(game.players.values.single.name, 'مروان');
    expect(game.players.values.single.team, 1);

    final originalId = player.id;
    final originalCode = server.code;
    final originalPort = server.port;
    final originalDiscoveryPort = server.activeDiscoveryPort;
    game.arm();
    await server.suspend();
    expect(server.isListening, isFalse);
    expect(game.armed, isFalse);
    // Remain unavailable longer than a discovery timeout, exercising failed retries.
    await Future<void>.delayed(const Duration(seconds: 7));
    expect(player.resolvedAddress, '127.0.0.1:$originalPort');
    await server.resume();
    expect(server.port, originalPort);
    expect(server.activeDiscoveryPort, originalDiscoveryPort);
    expect(server.code, originalCode);
    await until(() => disconnectedAfterJoin);
    await until(() => player.connected);

    expect(player.id, originalId);
    expect(game.players.length, 1);
    expect(game.players.values.single.online, isTrue);
    game.arm();
    server.publish();
    await until(() => player.canBuzz);
    player.buzz();
    await until(() => game.pending != null);
    game.judge(true);
    server.publish();
    expect(game.scores, [0, 1]);

    // A new player must also discover the rebound UDP listener.
    final newcomer = PlayerClient(
      code: originalCode,
      name: 'New player',
      team: 0,
      onChanged: () {},
      discoveryPort: originalDiscoveryPort,
      discoveryHost: '127.0.0.1',
    );
    addTearDown(newcomer.close);
    await newcomer.connect();
    await until(() => newcomer.connected);
    await server.suspend();
    await until(() => !player.connected && !newcomer.connected);
    await Future.wait([server.resume(), server.resume()]);
    await until(() => player.connected && newcomer.connected);
    expect(player.id, originalId);
    expect(game.players.length, 2);
    expect(game.scores, [0, 1]);
  });
  test(
    'failed cached attempts keep retrying when discovery is unavailable',
    () async {
      final game = Game(['A', 'B']);
      final server = HostServer(game, onChanged: () {}, discoveryPort: 0);
      await server.start(port: 0);
      addTearDown(server.close);
      final unusedDiscovery = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(unusedDiscovery.close);
      final player = PlayerClient(
        code: server.code,
        name: 'Player',
        team: 0,
        onChanged: () {},
        discoveryHost: '127.0.0.1',
        discoveryPort: unusedDiscovery.port,
      )..resolvedAddress = '127.0.0.1:${server.port}';
      addTearDown(player.close);
      await player.connect();
      await until(() => player.connected);
      final id = player.id;
      final token = player.token;
      await server.suspend();
      await until(() => !player.connected);
      await Future<void>.delayed(const Duration(seconds: 7));
      expect(player.resolvedAddress, isNotNull);
      await server.resume();
      await until(() => player.connected);
      expect(player.id, id);
      expect(player.token, token);
      expect(game.players.length, 1);
    },
  );

  test(
    'resume can retry after a bind failure without replacing the session',
    () async {
      final server = HostServer(
        Game(['A', 'B']),
        onChanged: () {},
        discoveryPort: 0,
      );
      await server.start(port: 0);
      addTearDown(server.close);
      final code = server.code;
      final tcpPort = server.port;
      final udpPort = server.activeDiscoveryPort;
      await server.suspend();
      final blocker = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpPort,
        reuseAddress: false,
      );
      try {
        await expectLater(server.resume(), throwsA(isA<SocketException>()));
        expect(server.isListening, isFalse);
      } finally {
        blocker.close();
      }
      await server.resume();
      expect(server.isListening, isTrue);
      expect(server.code, code);
      expect(server.port, tcpPort);
      // Closing while a resume is queued must never leave a listener behind.
      final resuming = server.resume();
      await server.close();
      await resuming;
      expect(server.isListening, isFalse);
      final probe = await HttpServer.bind(InternetAddress.anyIPv4, tcpPort);
      await probe.close(force: true);
      final udpProbe = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpPort,
        reuseAddress: false,
      );
      udpProbe.close();
    },
  );

  test(
    'silent joined socket times out and retries without user action',
    () async {
      final host = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => host.close(force: true));
      final sockets = <WebSocket>[];
      addTearDown(() async {
        for (final socket in sockets) {
          await socket.close();
        }
      });
      var attempts = 0;
      host.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        attempts++;
        socket.listen((_) {
          if (attempts > 1) {
            socket.add(
              jsonEncode({'type': 'welcome', 'id': 'same', 'token': 'token'}),
            );
            socket.add(
              jsonEncode({
                'type': 'state',
                'state': Game(['A', 'B']).publicState(),
              }),
            );
          }
        });
      });
      final player = PlayerClient(
        address: '127.0.0.1:${host.port}',
        code: '123456',
        name: 'Player',
        team: 0,
        onChanged: () {},
      );
      addTearDown(player.close);
      await player.connect();
      await Future<void>.delayed(const Duration(seconds: 9));
      await until(() => player.connected);
      expect(attempts, 2);
    },
  );
}
