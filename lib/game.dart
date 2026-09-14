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
    final text = source.trim().replaceFirst('\ufeff', '');
    if (text.isEmpty) {
      throw const FormatException('الصق رد الـAI الأول.');
    }
    FormatException? lastError;
    for (final candidate in _jsonCandidates(text)) {
      for (final variant in <String>{
        candidate,
        _removeTrailingCommas(candidate),
        _removeTrailingCommas(
          candidate.replaceAll('“', '"').replaceAll('”', '"'),
        ),
      }) {
        try {
          return _questionsFromDecoded(jsonDecode(variant));
        } on FormatException catch (error) {
          lastError = error;
        } catch (_) {
          lastError = const FormatException(
            'لقيت JSON، لكن شكل الأسئلة مش مفهوم.',
          );
        }
      }
    }
    throw lastError ??
        const FormatException(
          'ملقتش قائمة JSON في الرد. انسخ الرد كاملًا وجرب تاني.',
        );
  }

  static List<Question> _questionsFromDecoded(dynamic decoded) {
    dynamic rows = decoded;
    if (decoded is Map) {
      rows = _firstValue(decoded, const [
        'questions',
        'items',
        'data',
        'الأسئلة',
        'الاسئلة',
      ]);
      if (rows == null && _questionText(decoded) != null) rows = [decoded];
    }
    if (rows is! List || rows.isEmpty || rows.length > 500) {
      throw const FormatException('محتاجين قائمة من ١ إلى ٥٠٠ سؤال.');
    }
    final questions = <Question>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      if (row is! Map) {
        throw FormatException('السؤال رقم ${index + 1} مش مكتوب كعنصر JSON.');
      }
      final question = _questionText(row)?.trim();
      final answer = _answerText(row)?.trim();
      if (question == null || answer == null) {
        throw FormatException(
          'السؤال رقم ${index + 1} لازم يحتوي سؤال وإجابة.',
        );
      }
      if (question.isEmpty ||
          answer.isEmpty ||
          question.length > 2000 ||
          answer.length > 2000) {
        throw FormatException(
          'السؤال رقم ${index + 1} أو إجابته فاضي أو طويل جدًا.',
        );
      }
      questions.add(Question(question, answer));
    }
    return questions;
  }

  static String? _questionText(Map row) => _firstString(row, const [
    'question',
    'q',
    'prompt',
    'text',
    'السؤال',
    'سؤال',
  ]);

  static String? _answerText(Map row) => _firstString(row, const [
    'answer',
    'a',
    'answertext',
    'الإجابة',
    'الاجابة',
    'إجابة',
    'اجابة',
    'الجواب',
  ]);

  static String? _firstString(Map row, List<String> acceptedKeys) {
    final value = _firstValue(row, acceptedKeys);
    return value is String ? value : null;
  }

  static dynamic _firstValue(Map row, List<String> acceptedKeys) {
    for (final entry in row.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      if (acceptedKeys.contains(key)) return entry.value;
    }
    return null;
  }

  static Iterable<String> _jsonCandidates(String source) sync* {
    final seen = <String>{};
    final fences = RegExp(
      r'```(?:json)?\s*(.*?)```',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    for (final match in fences.allMatches(source)) {
      final candidate = match.group(1)?.trim();
      if (candidate != null && candidate.isNotEmpty && seen.add(candidate)) {
        yield candidate;
      }
    }
    if (seen.add(source)) yield source;

    int? start;
    final stack = <String>[];
    var inString = false;
    var escaped = false;
    for (var index = 0; index < source.length; index++) {
      final character = source[index];
      if (start == null) {
        if (character == '[' || character == '{') {
          start = index;
          stack.add(character);
        }
        continue;
      }
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (character == '\\') {
          escaped = true;
        } else if (character == '"') {
          inString = false;
        }
        continue;
      }
      if (character == '"') {
        inString = true;
      } else if (character == '[' || character == '{') {
        stack.add(character);
      } else if (character == ']' || character == '}') {
        final expected = character == ']' ? '[' : '{';
        if (stack.isEmpty || stack.last != expected) {
          start = null;
          stack.clear();
          continue;
        }
        stack.removeLast();
        if (stack.isEmpty) {
          final candidate = source.substring(start, index + 1).trim();
          if (seen.add(candidate)) yield candidate;
          start = null;
        }
      }
    }
  }

  static String _removeTrailingCommas(String source) {
    final output = StringBuffer();
    var inString = false;
    var escaped = false;
    for (var index = 0; index < source.length; index++) {
      final character = source[index];
      if (inString) {
        output.write(character);
        if (escaped) {
          escaped = false;
        } else if (character == '\\') {
          escaped = true;
        } else if (character == '"') {
          inString = false;
        }
        continue;
      }
      if (character == '"') {
        inString = true;
        output.write(character);
        continue;
      }
      if (character == ',') {
        var lookAhead = index + 1;
        while (lookAhead < source.length &&
            RegExp(r'\s').hasMatch(source[lookAhead])) {
          lookAhead++;
        }
        if (lookAhead < source.length &&
            (source[lookAhead] == ']' || source[lookAhead] == '}')) {
          continue;
        }
      }
      output.write(character);
    }
    return output.toString();
  }
}
