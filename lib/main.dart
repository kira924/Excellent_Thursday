import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game.dart';
import 'network.dart';

const lime = Color(0xFFD7FA70);
const ink = Color(0xFF10151C);
const muted = Color(0xFFA8B2C1);
const teamColors = [
  lime,
  Color(0xFFFFAF80),
  Color(0xFF91BFFF),
  Color(0xFFE9A6ED),
  Color(0xFF73DDD0),
  Color(0xFFFFD16F),
  Color(0xFFFF92A6),
  Color(0xFFB6ADF9),
];
String number(Object value) => value.toString().replaceAllMapped(
  RegExp('[0-9]'),
  (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
);
String latin(String value) => value.replaceAllMapped(
  RegExp('[٠-٩]'),
  (m) => '٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!).toString(),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ThursdayApp(prefs: prefs));
}

class ThursdayApp extends StatelessWidget {
  const ThursdayApp({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'الخميس الممتاز',
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'NotoArabic',
      scaffoldBackgroundColor: ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lime,
        brightness: Brightness.dark,
        primary: lime,
        onPrimary: ink,
        surface: const Color(0xFF1B222C),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ink,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF222B36),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          textStyle: const TextStyle(
            fontFamily: 'NotoArabic',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ),
    home: HomeScreen(prefs: prefs),
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color ?? const Color(0xFF1B222C),
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
          children: children,
        ),
      ),
    ),
  );
}

Widget gap([double height = 16]) => SizedBox(height: height);
Widget title(String text, [double size = 24]) => Text(
  text,
  style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, height: 1.5),
);
Widget hint(String text) =>
    Text(text, style: const TextStyle(color: muted, fontSize: 13, height: 1.8));
void notice(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

Future<bool> confirm(BuildContext context, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تمام'),
          ),
        ],
      ),
    ) ??
    false;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBody(
      children: [
        gap(24),
        Row(
          children: [
            const Icon(Icons.wifi_rounded, color: lime, size: 19),
            const SizedBox(width: 8),
            hint('نفس الشبكة. نفس اللمة.'),
          ],
        ),
        gap(34),
        const Align(
          alignment: Alignment.centerRight,
          child: DecoratedBox(
            decoration: BoxDecoration(color: lime, shape: BoxShape.circle),
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Icon(
                Icons.notifications_active_rounded,
                size: 48,
                color: ink,
              ),
            ),
          ),
        ),
        gap(20),
        title('الخميس\nالممتاز', 48),
        gap(8),
        hint('اللمة عليكم، والجرس علينا.\nكوّنوا الفرق… وأسرع إجابة تكسب.'),
        gap(30),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SetupScreen(prefs: prefs)),
          ),
          icon: const Icon(Icons.tune_rounded),
          label: const Text('أنا الهوست'),
        ),
        gap(12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const JoinScreen()),
          ),
          icon: const Icon(Icons.touch_app_rounded),
          label: const Text('داخل ألعب'),
        ),
        gap(30),
        const Row(
          children: [
            Expanded(child: RuleTile('صح', '+1', lime)),
            SizedBox(width: 10),
            Expanded(child: RuleTile('غلط', '−1', Color(0xFFFFAF80))),
            SizedBox(width: 10),
            Expanded(child: RuleTile('المكسب', '+5', Color(0xFF91BFFF))),
          ],
        ),
        gap(16),
        hint('عند −٥ الفريق يخرج. تقدر تحاول تاني كل ما الهوست يفتح الجرس.'),
      ],
    ),
  );
}

class RuleTile extends StatelessWidget {
  const RuleTile(this.label, this.value, this.color, {super.key});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        hint(label),
      ],
    ),
  );
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int count = 2;
  final names = List.generate(
    8,
    (i) => TextEditingController(text: 'فريق ${number(i + 1)}'),
  );
  @override
  void dispose() {
    for (final n in names) {
      n.dispose();
    }
    super.dispose();
  }

  void start(Game game) => Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => HostScreen(game: game, prefs: widget.prefs),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('جهّز اللمة')),
    body: PageBody(
      children: [
        title('مين ضد مين؟', 30),
        hint('اختار من ٢ إلى ٨ فرق. كل واحد هيدخل برقم فريقه.'),
        gap(24),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title('عدد الفرق', 18),
              gap(12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  7,
                  (i) => ChoiceChip(
                    label: Text(number(i + 2)),
                    selected: count == i + 2,
                    onSelected: (_) => setState(() => count = i + 2),
                  ),
                ),
              ),
              gap(20),
              ...List.generate(
                count,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: names[i],
                    maxLength: 20,
                    decoration: InputDecoration(
                      counterText: '',
                      prefixIcon: Icon(
                        Icons.circle,
                        color: teamColors[i],
                        size: 15,
                      ),
                      labelText: 'اسم الفريق ${number(i + 1)}',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        gap(20),
        FilledButton(
          onPressed: () {
            final chosen = names.take(count).map((n) => n.text.trim()).toList();
            if (chosen.any((n) => n.isEmpty) ||
                chosen.toSet().length != count) {
              notice(context, 'اكتب اسم مختلف لكل فريق.');
              return;
            }
            start(Game(chosen));
          },
          child: const Text('افتح الجلسة'),
        ),
        if (widget.prefs.containsKey('savedGame')) ...[
          gap(12),
          TextButton.icon(
            icon: const Icon(Icons.history_rounded),
            label: const Text('استكمل آخر نتيجة محفوظة'),
            onPressed: () {
              try {
                start(Game.restore(widget.prefs.getString('savedGame')!));
              } catch (_) {
                notice(context, 'النتيجة المحفوظة مش متاحة. ابدأ جلسة جديدة.');
              }
            },
          ),
          hint('اللاعبين هيدخلوا من جديد. النقاط وأسماء الفرق محفوظة.'),
        ],
      ],
    ),
  );
}

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final name = TextEditingController(), code = TextEditingController();
  int team = 0;
  @override
  void dispose() {
    name.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ادخل الجلسة')),
    body: PageBody(
      children: [
        title('جهّز صباعك.', 32),
        hint('اتصل بنفس واي فاي الهوست، وخد منه الكود ورقم فريقك.'),
        gap(24),
        TextField(
          controller: name,
          maxLength: 24,
          decoration: const InputDecoration(labelText: 'اسمك', counterText: ''),
        ),
        gap(),
        TextField(
          controller: code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'كود الجلسة',
            counterText: '',
          ),
        ),
        gap(),
        DropdownButtonFormField<int>(
          initialValue: team,
          decoration: const InputDecoration(labelText: 'رقم فريقك'),
          items: List.generate(
            8,
            (i) => DropdownMenuItem(
              value: i,
              child: Text('الفريق ${number(i + 1)}'),
            ),
          ),
          onChanged: (value) => setState(() => team = value!),
        ),
        gap(24),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty ||
                !RegExp(r'^\d{6}$').hasMatch(latin(code.text))) {
              notice(context, 'اكتب اسمك وكود الجلسة المكوّن من ٦ أرقام.');
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerScreen(
                  code: latin(code.text),
                  name: name.text.trim(),
                  team: team,
                ),
              ),
            );
          },
          child: const Text('يلا نلعب'),
        ),
        gap(16),
        hint(
          'لو الاتصال مش شغال: اتأكدوا إنكم على نفس الشبكة، واقفلوا VPN. بعض شبكات الضيوف بتمنع اتصال الأجهزة ببعض.',
        ),
      ],
    ),
  );
}

class Scoreboard extends StatelessWidget {
  const Scoreboard({
    super.key,
    required this.teams,
    required this.scores,
    this.winner,
  });
  final List<String> teams;
  final List<int> scores;
  final int? winner;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(
        teams.length,
        (i) => SizedBox(
          width: (constraints.maxWidth - 10) / 2,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: teamColors[i].withValues(
                alpha: scores[i] <= -5 ? .04 : .10,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: teamColors[i].withValues(alpha: winner == i ? 1 : .18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${number(i + 1)}  ·  ${teams[i]}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: teamColors[i],
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  scores[i] > 0 ? '+${scores[i]}' : '${scores[i]}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 38,
                    height: 1.5,
                    color: teamColors[i],
                    fontWeight: FontWeight.w800,
                  ),
                ),
                hint(
                  winner == i
                      ? 'كسب الراوند 🏆'
                      : scores[i] <= -5
                      ? 'خرج من الراوند'
                      : 'الهدف +٥',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class HostScreen extends StatefulWidget {
  const HostScreen({super.key, required this.game, required this.prefs});
  final Game game;
  final SharedPreferences prefs;
  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> with WidgetsBindingObserver {
  late final HostServer server;
  bool ready = false, reveal = false, leaving = false;
  String? error;
  String? lastPending;
  List<Question> questions = [];
  int questionIndex = 0;
  Future<void> saveQueue = Future.value();
  Game get game => widget.game;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      questions = Question.parse(widget.prefs.getString('questions') ?? '[]');
    } catch (_) {
      questions = [];
    }
    questionIndex = (widget.prefs.getInt('questionIndex') ?? 0).clamp(
      0,
      questions.isEmpty ? 0 : questions.length - 1,
    );
    server = HostServer(game, onChanged: changed);
    start();
  }

  Future<void> start() async {
    try {
      await server.start();
      if (!mounted) {
        await server.close();
        return;
      }
      setState(() => ready = true);
      changed();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'مش قادرين نفتح الجلسة. اتأكد من الواي فاي وصلاحية الشبكة المحلية، وارجع جرّب تاني.',
        );
      }
    }
  }

  void changed() {
    if (!mounted) return;
    final pending = game.pending?.id;
    if (pending != null && pending != lastPending) {
      unawaited(SystemSound.play(SystemSoundType.alert));
      unawaited(HapticFeedback.heavyImpact());
    }
    lastPending = pending;
    setState(() {});
    final snapshot = game.save();
    saveQueue = saveQueue
        .then((_) async {
          final saved = await widget.prefs.setString('savedGame', snapshot);
          if (!saved) throw StateError('save failed');
        })
        .catchError((Object _) {
          if (mounted) notice(context, 'تعذّر حفظ النتيجة على الجهاز.');
        });
  }

  void mutate(void Function() action) {
    action();
    server.publish();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && game.armed) {
      game.closeBell();
      server.publish();
    }
    if (state == AppLifecycleState.resumed && ready) {
      server.refreshConnections();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(server.close());
    super.dispose();
  }

  Future<void> leave() async {
    if (leaving ||
        !await confirm(
          context,
          'تقفل الجلسة؟ النتيجة محفوظة، واللاعبين هيفصلوا.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    await server.close();
    if (mounted) Navigator.pop(context);
  }

  Future<void> importQuestions() async {
    final result = await showDialog<List<Question>>(
      context: context,
      builder: (_) => const QuestionImportDialog(),
    );
    if (result == null || !mounted) return;
    mutate(() {
      game.closeBell();
      questions = result;
      questionIndex = 0;
      reveal = false;
    });
    await widget.prefs.setString(
      'questions',
      jsonEncode(questions.map((q) => q.toJson()).toList()),
    );
    await widget.prefs.setInt('questionIndex', 0);
  }

  @override
  Widget build(BuildContext context) {
    final pending = game.pending;
    return PopScope(
      canPop: leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(leave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة الهوست'),
          leading: IconButton(
            onPressed: leave,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          actions: [
            IconButton(
              tooltip: 'تراجع عن آخر نتيجة',
              onPressed: game.canUndo ? () => mutate(game.undo) : null,
              icon: const Icon(Icons.undo_rounded),
            ),
          ],
        ),
        body: PageBody(
          children: [
            if (!ready)
              Panel(
                child: error == null
                    ? const Center(child: CircularProgressIndicator())
                    : Text(error!),
              ),
            if (ready) ...[
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wifi_rounded, color: lime, size: 18),
                        const SizedBox(width: 8),
                        hint('الجلسة مفتوحة'),
                        const Spacer(),
                        hint(
                          '${number(game.players.values.where((p) => p.online).length)} متصل',
                        ),
                      ],
                    ),
                    gap(8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              hint('كود الدخول'),
                              Text(
                                server.code,
                                style: const TextStyle(
                                  fontSize: 34,
                                  color: lime,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'نسخ كود الجلسة',
                          onPressed: () {
                            unawaited(
                              Clipboard.setData(
                                ClipboardData(text: server.code),
                              ),
                            );
                            notice(context, 'اتنسخ كود الجلسة.');
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                    hint(
                      'اللاعب يكتب الكود فقط، والتطبيق هيلاقي الهوست تلقائيًا.',
                    ),
                  ],
                ),
              ),
              gap(18),
              if (game.finished)
                Panel(
                  color: lime.withValues(alpha: .14),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: lime,
                        size: 48,
                      ),
                      title('${game.teams[game.winner!]} كسبوا!'),
                      hint('راوند ممتاز. جاهزين لواحد كمان؟'),
                      gap(),
                      FilledButton(
                        onPressed: () async {
                          if (await confirm(
                                context,
                                'نبدأ راوند جديد ونصفّر النقاط؟',
                              ) &&
                              mounted) {
                            mutate(game.reset);
                          }
                        },
                        child: const Text('راوند جديد'),
                      ),
                    ],
                  ),
                )
              else
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (pending != null) ...[
                        hint('أول جرس وصل'),
                        title(pending.name, 30),
                        Text(
                          game.teams[pending.team],
                          style: TextStyle(color: teamColors[pending.team]),
                        ),
                        gap(18),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => mutate(() => game.judge(true)),
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('صح +١'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFAF80),
                                ),
                                onPressed: () =>
                                    mutate(() => game.judge(false)),
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('غلط −١'),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => mutate(game.closeBell),
                          child: const Text('إلغاء الضغطة من غير نقاط'),
                        ),
                      ] else ...[
                        Icon(
                          game.armed
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_paused_rounded,
                          color: game.armed ? lime : muted,
                          size: 38,
                        ),
                        gap(10),
                        Center(
                          child: title(
                            game.armed ? 'الجرس مفتوح!' : 'الكل مستني إشارتك',
                            22,
                          ),
                        ),
                        gap(14),
                        FilledButton(
                          onPressed: () => mutate(() {
                            if (game.armed) {
                              game.closeBell();
                            } else {
                              game.arm();
                            }
                          }),
                          child: Text(
                            game.armed ? 'اقفل الجرس' : 'افتح الجرس للجميع',
                          ),
                        ),
                        gap(8),
                        hint('نفس اللاعب يقدر يحاول تاني بعد فتح الجرس.'),
                      ],
                    ],
                  ),
                ),
              gap(18),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: title('كارت السؤال', 18)),
                        TextButton(
                          onPressed: pending == null && !game.armed
                              ? importQuestions
                              : null,
                          child: const Text('إضافة أسئلة'),
                        ),
                      ],
                    ),
                    if (questions.isEmpty)
                      hint(
                        'وضع الجرس فقط شغال. ضيف أسئلتك هنا، أو اقرأها من أي مكان.',
                      )
                    else ...[
                      hint(
                        'سؤال ${number(questionIndex + 1)} من ${number(questions.length)} · للهوست فقط',
                      ),
                      gap(12),
                      title(questions[questionIndex].question, 21),
                      if (reveal) ...[
                        gap(),
                        Text(
                          questions[questionIndex].answer,
                          style: const TextStyle(color: lime, fontSize: 18),
                        ),
                      ],
                      gap(8),
                      TextButton.icon(
                        onPressed: () => setState(() => reveal = !reveal),
                        icon: Icon(
                          reveal
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        label: Text(reveal ? 'اخفي الإجابة' : 'ورّيني الإجابة'),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed:
                                questionIndex > 0 &&
                                    pending == null &&
                                    !game.armed
                                ? () => changeQuestion(-1)
                                : null,
                            child: const Text('السابق'),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed:
                                questionIndex < questions.length - 1 &&
                                    pending == null &&
                                    !game.armed
                                ? () => changeQuestion(1)
                                : null,
                            child: const Text('السؤال التالي'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              gap(18),
              Scoreboard(
                teams: game.teams,
                scores: game.scores,
                winner: game.winner,
              ),
              gap(18),
              if (game.players.isNotEmpty)
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title('الشباب في الجلسة', 18),
                      gap(12),
                      ...game.players.values.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 9,
                                color: p.online ? lime : muted,
                              ),
                              const SizedBox(width: 9),
                              Expanded(child: Text(p.name)),
                              Flexible(
                                child: Text(
                                  game.teams[p.team],
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: teamColors[p.team]),
                                ),
                              ),
                              if (!p.online)
                                const Text(
                                  ' · فصل',
                                  style: TextStyle(color: muted),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (game.history.isNotEmpty) ...[
                gap(18),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title('آخر الإجابات', 18),
                      gap(12),
                      ...game.history
                          .take(5)
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${e['name']} · ${game.teams[e['team'] as int]} · ${e['delta'] == 1 ? 'صح +١' : 'غلط −١'}',
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
              gap(12),
              hint(
                'خلّي شاشة الهوست مفتوحة طول اللعب. عند الخروج منها الجرس المفتوح بيتقفل.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  void changeQuestion(int delta) {
    mutate(() {
      game.closeBell();
      questionIndex += delta;
      reveal = false;
    });
    unawaited(widget.prefs.setInt('questionIndex', questionIndex));
  }
}

class QuestionImportDialog extends StatefulWidget {
  const QuestionImportDialog({super.key});
  @override
  State<QuestionImportDialog> createState() => _QuestionImportDialogState();
}

class _QuestionImportDialogState extends State<QuestionImportDialog> {
  final source = TextEditingController();
  String? error;
  static const prompt =
      'اكتب ٢٠ سؤال معلومات عامة بالعربي بإجابات واضحة وغير ملتبسة. '
      'أعد قائمة JSON فقط بهذا الشكل: [{"question":"نص السؤال","answer":"الإجابة"}]. '
      'بدون أي شرح خارج القائمة.';
  @override
  void dispose() {
    source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('أسئلة السهرة'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            hint(
              'انسخ الطلب لأي شات AI قبل اللعب. راجع الإجابات، والصق الرد كاملًا هنا حتى لو فيه شرح أو JSON داخل code block.',
            ),
            TextButton.icon(
              onPressed: () {
                unawaited(Clipboard.setData(const ClipboardData(text: prompt)));
                notice(context, 'اتنسخ طلب الأسئلة.');
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('انسخ طلب الأسئلة'),
            ),
            gap(8),
            TextField(
              controller: source,
              minLines: 6,
              maxLines: 12,
              maxLength: 200000,
              decoration: InputDecoration(
                labelText: 'الصق رد الـAI كاملًا',
                counterText: '',
                errorText: error,
              ),
            ),
            gap(8),
            hint(
              'مثال: [{"question":"كم يومًا في الأسبوع؟","answer":"٧ أيام"}]',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          try {
            Navigator.pop(context, Question.parse(source.text));
          } on FormatException catch (exception) {
            setState(() => error = exception.message.toString());
          } catch (_) {
            setState(
              () =>
                  error = 'حصلت مشكلة أثناء قراءة الأسئلة. جرّب نسخ الرد تاني.',
            );
          }
        },
        child: const Text('احفظ الأسئلة'),
      ),
    ],
  );
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    this.address,
    required this.code,
    required this.name,
    required this.team,
  });
  final String? address;
  final String code, name;
  final int team;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlayerClient client;
  String? lastPending;
  @override
  void initState() {
    super.initState();
    client = PlayerClient(
      address: widget.address,
      code: widget.code,
      name: widget.name,
      team: widget.team,
      onChanged: () {
        if (!mounted) return;
        final id = (client.state?['pending'] as Map?)?['id'] as String?;
        if (id != null && id != lastPending && id == client.id) {
          unawaited(HapticFeedback.heavyImpact());
        }
        lastPending = id;
        setState(() {});
      },
    );
    unawaited(client.connect());
  }

  @override
  void dispose() {
    unawaited(client.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = client.state;
    final teams = state == null
        ? <String>[]
        : List<String>.from(state['teams'] as List);
    final scores = state == null
        ? <int>[]
        : List<int>.from(state['scores'] as List);
    final pending = state?['pending'] as Map?;
    final winner = state?['winner'] as int?;
    final eliminated = scores.length > widget.team && scores[widget.team] <= -5;
    final color = teamColors[widget.team];
    final status = !client.connected
        ? 'بنوصل بالجلسة'
        : winner != null
        ? '${teams[winner]} كسبوا!'
        : eliminated
        ? 'فريقك خرج من الراوند'
        : pending != null
        ? pending['id'] == client.id
              ? 'الجرس ليك… جاوب!'
              : '${pending['name']} سبقك!'
        : client.canBuzz
        ? 'عارفها؟ اضغط!'
        : client.sentWindow != null
        ? 'بنوصل ضغطتك…'
        : 'استنى الهوست يفتح الجرس';
    return Scaffold(
      appBar: AppBar(title: const Text('جرسك')),
      body: PageBody(
        children: [
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 9,
                color: client.connected ? lime : const Color(0xFFFFAF80),
              ),
              const SizedBox(width: 9),
              Expanded(child: hint(client.status)),
            ],
          ),
          gap(22),
          title('أهلاً يا ${widget.name}', 28),
          Text(
            teams.length > widget.team
                ? teams[widget.team]
                : 'الفريق ${number(widget.team + 1)}',
            style: TextStyle(color: color, fontSize: 18),
          ),
          gap(30),
          Center(
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
          ),
          gap(24),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 290),
              child: AspectRatio(
                aspectRatio: 1,
                child: Semantics(
                  button: true,
                  label: 'اضغط الجرس',
                  enabled: client.canBuzz,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(
                          alpha: client.canBuzz ? .55 : .12,
                        ),
                        width: 2,
                      ),
                      boxShadow: client.canBuzz
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: .12),
                                blurRadius: 45,
                                spreadRadius: 8,
                              ),
                            ]
                          : [],
                    ),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: color,
                        disabledBackgroundColor: const Color(0xFF252E3A),
                        disabledForegroundColor: muted,
                      ),
                      onPressed: client.canBuzz
                          ? () {
                              unawaited(HapticFeedback.lightImpact());
                              client.buzz();
                            }
                          : null,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            winner != null
                                ? Icons.emoji_events_rounded
                                : Icons.notifications_active_rounded,
                            size: 76,
                          ),
                          gap(8),
                          const Text(
                            'الجرس',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          gap(30),
          if (client.rejected)
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ارجع وعدّل بيانات الدخول'),
            ),
          if (teams.isNotEmpty)
            Scoreboard(teams: teams, scores: scores, winner: winner),
          gap(18),
          hint(
            'كل إجابة صح +١، وكل إجابة غلط −١.\nتقدر تحاول تاني في كل مرة الجرس يتفتح فيها.',
          ),
        ],
      ),
    );
  }
}
