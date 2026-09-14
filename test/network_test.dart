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
    server.refreshConnections();
    await until(() => disconnectedAfterJoin);
    await until(() => player.connected);

    expect(player.id, originalId);
    expect(game.players.length, 1);
    expect(game.players.values.single.online, isTrue);
  });
}
