import 'dart:convert';

class Player {
  Player(this.id, this.name, this.team, {this.online = true});
  final String id;
  final String name;
  final int team;
  bool online;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'team': team,
    'online': online,
  };
}

/// Only the host mutates state. A window identifies one opening of the bell.
class Game {
  Game(List<String> names)
    : teams = List.unmodifiable(names),
      scores = List.filled(names.length, 0) {
    if (names.length < 2 ||
        names.length > 8 ||
        names.any((n) => n.trim().isEmpty)) {
      throw ArgumentError('اختار من فريقين إلى ٨ فرق، واكتب اسم كل فريق.');
    }
  }
  final List<String> teams;
  List<int> scores;
  final Map<String, Player> players = {};
  final List<Map<String, dynamic>> history = [];
  final List<Map<String, dynamic>> _undo = [];
  bool armed = false;
  int window = 0;
  int? winner;
  Player? pending;
  bool get finished => winner != null;
  bool get canUndo => _undo.isNotEmpty;
  bool eliminated(int team) => scores[team] <= -5;

  void addPlayer(Player player) {
    if (player.team < 0 ||
        player.team >= teams.length ||
        player.name.trim().isEmpty ||
        player.name.length > 24) {
      throw ArgumentError('بيانات اللاعب غير صحيحة.');
    }
    players[player.id] = player;
  }

  bool arm() {
    if (finished || pending != null || armed) return false;
    window++;
    armed = true;
    return true;
  }

  void closeBell() {
    armed = false;
    pending = null;
    window++;
  }

  bool buzz(String playerId, int requestedWindow) {
    final player = players[playerId];
    if (!armed ||
        finished ||
        pending != null ||
        requestedWindow != window ||
        player == null ||
        !player.online ||
        eliminated(player.team)) {
      return false;
    }
    pending = player;
    armed = false;
    return true;
  }

  bool judge(bool correct) {
    final player = pending;
    if (player == null || finished) return false;
    _undo.add({
      'scores': List<int>.from(scores),
      'winner': winner,
      'history': history.map((e) => Map<String, dynamic>.from(e)).toList(),
    });
    if (_undo.length > 100) _undo.removeAt(0);
    scores[player.team] += correct ? 1 : -1;
    history.insert(0, {
      'name': player.name,
      'team': player.team,
      'delta': correct ? 1 : -1,
      'score': scores[player.team],
    });
    if (history.length > 30) history.removeLast();
    if (scores[player.team] >= 5) {
      winner = player.team;
    } else {
      final remaining = List.generate(
        teams.length,
        (i) => i,
      ).where((i) => !eliminated(i)).toList();
      if (remaining.length == 1) winner = remaining.single;
    }
    closeBell();
    return true;
  }

  void undo() {
    if (!canUndo) return;
    final previous = _undo.removeLast();
    scores = List<int>.from(previous['scores'] as List);
    winner = previous['winner'] as int?;
    history
      ..clear()
      ..addAll(
        (previous['history'] as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
    closeBell();
  }

  void reset() {
    scores = List.filled(teams.length, 0);
    winner = null;
    history.clear();
    _undo.clear();
    closeBell();
  }

  Map<String, dynamic> publicState() => {
    'teams': teams,
    'scores': scores,
    'armed': armed,
    'window': window,
    'winner': winner,
    'pending': pending?.toJson(),
    'players': players.values.map((p) => p.toJson()).toList(),
    'history': history,
  };

  String save() => jsonEncode({
    'teams': teams,
    'scores': scores,
    'winner': winner,
    'history': history,
  });

  factory Game.restore(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    final game = Game(List<String>.from(data['teams'] as List));
    final savedScores = List<int>.from(data['scores'] as List);
    if (savedScores.length != game.teams.length ||
        savedScores.any((s) => s < -5 || s > 5)) {
      throw const FormatException('نتيجة محفوظة غير صالحة');
    }
    game.scores = savedScores;
    final winner = data['winner'] as int?;
    if (winner != null && (winner < 0 || winner >= game.teams.length)) {
      throw const FormatException('فريق غير صالح');
    }
    game.winner = winner;
    game.history.addAll(
      (data['history'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    return game;
  }
}

class Question {
  const Question(this.question, this.answer);
  final String question;
  final String answer;
  Map<String, String> toJson() => {'question': question, 'answer': answer};

  static List<Question> parse(String source) {
    var text = source.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
    }
    final data = jsonDecode(text);
    if (data is! List || data.isEmpty || data.length > 500) {
      throw const FormatException('محتاجين قائمة من ١ إلى ٥٠٠ سؤال.');
    }
    return data.map((row) {
      if (row is! Map ||
          row['question'] is! String ||
          row['answer'] is! String) {
        throw const FormatException(
          'كل سؤال لازم يحتوي question و answer كنص.',
        );
      }
      final q = (row['question'] as String).trim();
      final a = (row['answer'] as String).trim();
      if (q.isEmpty || a.isEmpty || q.length > 2000 || a.length > 2000) {
        throw const FormatException(
          'السؤال والإجابة لازم يكونوا من ١ إلى ٢٠٠٠ حرف.',
        );
      }
      return Question(q, a);
    }).toList();
  }
}
