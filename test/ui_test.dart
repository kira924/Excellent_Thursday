import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excellent_thursday/main.dart';
import 'package:excellent_thursday/network.dart';

Future<void> waitUntil(bool Function() condition) async {
  final limit = DateTime.now().add(const Duration(seconds: 8));
  while (!condition()) {
    if (DateTime.now().isAfter(limit)) {
      fail('Timed out waiting for UI network state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('player joins with code only and no host address field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ThursdayApp(prefs: prefs));
    await tester.pumpAndSettle();
    await tester.tap(find.text('داخل ألعب'));
    await tester.pumpAndSettle();

    expect(find.text('كود الجلسة'), findsOneWidget);
    expect(find.text('عنوان الهوست'), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(
      find.text('اتصل بنفس واي فاي الهوست، وخد منه الكود ورقم فريقك.'),
      findsOneWidget,
    );
  });

  testWidgets('Arabic mobile layout and host setup for eight teams', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final loader = FontLoader('NotoArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf'));
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ThursdayApp(prefs: prefs),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('أنا الهوست'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Future<void> capture(String filename) async {
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('artifacts/screenshots').create(recursive: true);
        await File(
          'artifacts/screenshots/$filename.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('home');
    await tester.tap(find.text('أنا الهوست'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '٨'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(8));
    await capture('setup');
    await tester.scrollUntilVisible(
      find.text('افتح الجلسة'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('افتح الجلسة'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });
    await tester.pumpAndSettle();
    expect(find.text('لوحة الهوست'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture('host-eight-teams');
    await tester.scrollUntilVisible(
      find.text('افتح الجرس للجميع'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('افتح الجرس للجميع'));
    await tester.pumpAndSettle();
    expect(find.text('الجرس مفتوح!'), findsOneWidget);
    await tester.tap(find.text('اقفل الجرس'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('إضافة أسئلة'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('إضافة أسئلة'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      '[{"question":"كم يومًا في الأسبوع؟","answer":"٧ أيام"}]',
    );
    await tester.tap(find.text('احفظ الأسئلة'));
    await tester.pumpAndSettle();
    expect(find.text('كم يومًا في الأسبوع؟'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture('host-questions');
    final host = tester.widget<HostScreen>(find.byType(HostScreen));
    final savedOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = savedOverrides);
    await tester.scrollUntilVisible(
      find.text('افتح الجرس للجميع'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.byIcon(Icons.copy_rounded),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    final roomCode = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .firstWhere((s) => RegExp(r'^\d{6}$').hasMatch(s));
    var joined = false;
    var disconnectedAfterResume = false;
    late final PlayerClient player;
    player = PlayerClient(
      address: '127.0.0.1:45873',
      code: roomCode,
      name: 'علي',
      team: 7,
      onChanged: () {
        if (joined && !player.connected) disconnectedAfterResume = true;
      },
    );
    addTearDown(player.close);
    await tester.runAsync(() async {
      await player.connect();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(player.connected, isTrue);
    joined = true;
    final originalPlayerId = player.id;
    await tester.runAsync(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await waitUntil(() => disconnectedAfterResume);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await waitUntil(() => player.connected);
    });
    await tester.pumpAndSettle();
    expect(player.id, originalPlayerId);

    await tester.tap(find.text('افتح الجرس للجميع'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      player.buzz();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('أول جرس وصل'), findsOneWidget);
    await capture('host-answer');
    await tester.tap(find.text('صح +١'));
    await tester.pumpAndSettle();
    expect(host.game.scores[7], 1);
    await tester.tap(find.text('افتح الجرس للجميع'));
    await tester.runAsync(() async {
      Navigator.of(tester.element(find.byType(HostScreen))).push(
        MaterialPageRoute<void>(
          builder: (_) => PlayerScreen(
            address: '127.0.0.1:45873',
            code: roomCode,
            name: 'مروان',
            team: 0,
          ),
        ),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    expect(find.text('متصل بالهوست'), findsOneWidget);
    expect(find.text('عارفها؟ اضغط!'), findsOneWidget);
    await capture('player');
    await tester.tap(find.widgetWithText(FilledButton, 'الجرس'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('الجرس ليك… جاوب!'), findsOneWidget);
    expect(host.game.pending?.team, 0);
    expect(tester.takeException(), isNull);
    await tester.runAsync(player.close);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  });
}
