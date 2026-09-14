import 'package:flutter_test/flutter_test.dart';
import 'package:excellent_thursday/game.dart';

void main() {
  late Game game;
  setUp(() {
    game = Game(['أ', 'ب', 'ج']);
    for (var i = 0; i < 3; i++) {
      game.addPlayer(Player('$i', 'لاعب $i', i));
    }
  });
  void answer(String id, bool correct) {
    expect(game.arm(), isTrue);
    expect(game.buzz(id, game.window), isTrue);
    expect(game.judge(correct), isTrue);
  }

  test('one accepted buzz, no repeat scoring, same player retries', () {
    game.arm();
    expect(game.buzz('0', game.window), isTrue);
    expect(game.buzz('1', game.window), isFalse);
    expect(game.judge(false), isTrue);
    expect(game.judge(false), isFalse);
    answer('0', false);
    answer('0', true);
    expect(game.scores, [-1, 0, 0]);
  });
  test('stale windows and disconnected players cannot buzz', () {
    game.arm();
    final oldWindow = game.window;
    game.closeBell();
    game.arm();
    expect(game.buzz('0', oldWindow), isFalse);
    game.players['0']!.online = false;
    expect(game.buzz('0', game.window), isFalse);
    expect(game.buzz('unknown', game.window), isFalse);
  });
  test('five correct answers win and freeze the round', () {
    for (var i = 0; i < 5; i++) {
      answer('0', true);
    }
    expect(game.winner, 0);
    expect(game.arm(), isFalse);
    game.undo();
    expect(game.winner, isNull);
    expect(game.scores[0], 4);
    expect(game.pending, isNull);
    answer('1', true);
  });
  test('minus five eliminates only that team, last remaining wins', () {
    for (var i = 0; i < 5; i++) {
      answer('0', false);
    }
    expect(game.eliminated(0), isTrue);
    expect(game.winner, isNull);
    game.arm();
    expect(game.buzz('0', game.window), isFalse);
    game.closeBell();
    for (var i = 0; i < 5; i++) {
      answer('1', false);
    }
    expect(game.winner, 2);
    game.undo();
    expect(game.eliminated(1), isFalse);
    expect(game.winner, isNull);
  });
  test('reset keeps players; restoration keeps scores but closes bell', () {
    answer('0', false);
    game.arm();
    final restored = Game.restore(game.save());
    expect(restored.scores, [-1, 0, 0]);
    expect(restored.armed, isFalse);
    expect(restored.players, isEmpty);
    game.reset();
    expect(game.players.length, 3);
    expect(game.scores, [0, 0, 0]);
    expect(game.canUndo, isFalse);
  });
  test('question import validates full list and accepts AI code fences', () {
    final wrapped = Question.parse(
      'أكيد، دي الأسئلة:\n'
      '```json\n'
      '{"questions":[{"question":"س؟","answer":"ج",},],}\n'
      '```\n'
      'أتمنى لكم سهرة سعيدة.',
    );
    expect(wrapped.single.question, 'س؟');
    expect(wrapped.single.answer, 'ج');
    final arabicKeys = Question.parse(
      '[{"السؤال":"عاصمة مصر؟","الإجابة":"القاهرة"}]',
    );
    expect(arabicKeys.single.answer, 'القاهرة');
    final shortKeys = Question.parse('{“items”:[{“q”:“٢ + ٢؟”,“a”:“٤”}]}');
    expect(shortKeys.single.question, '٢ + ٢؟');
    expect(
      () => Question.parse('[{"question":"س؟","answer":null}]'),
      throwsFormatException,
    );
    expect(() => Question.parse('[]'), throwsFormatException);
    expect(
      () => Question.parse('[{"question":" ","answer":"ج"}]'),
      throwsFormatException,
    );
    expect(game.publicState().containsKey('questions'), isFalse);
  });
}
