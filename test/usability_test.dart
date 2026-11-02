import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_basquet/game.dart';
import 'package:score_basquet/main.dart' as app;

// Advance the same monotonic source used by the production clock, without
// sleeping or assuming that pumping a frame advances a real Stopwatch.
class ManualStopwatch implements Stopwatch {
  int milliseconds = 0;
  @override
  bool isRunning = false;
  void advance(int value) {
    if (isRunning) milliseconds += value;
  }

  @override
  void start() => isRunning = true;
  @override
  void stop() => isRunning = false;
  @override
  void reset() => milliseconds = 0;
  @override
  int get elapsedMilliseconds => milliseconds;
  @override
  int get elapsedMicroseconds => milliseconds * 1000;
  @override
  int get elapsedTicks => elapsedMicroseconds;
  @override
  Duration get elapsed => Duration(milliseconds: milliseconds);
  @override
  int get frequency => 1000000;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? saved;
  setUp(() {
    saved = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(app.native, (call) async {
          if (call.method == 'save') saved = call.arguments as String;
          if (call.method == 'appVersion') return '1.6.1';
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  Future<void> open(
    WidgetTester tester,
    Game game,
    Size size, {
    ManualStopwatch? watch,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const previewFont = String.fromEnvironment('FISCORE_PREVIEW_FONT');
    if (const bool.fromEnvironment('FISCORE_PREVIEW') &&
        previewFont.isNotEmpty) {
      await tester.runAsync(() async {
        final bytes = await File(previewFont).readAsBytes();
        for (final family in ['sans-serif', 'Roboto']) {
          await (FontLoader(
            family,
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        }
        const icons = String.fromEnvironment('FISCORE_PREVIEW_ICONS');
        if (icons.isNotEmpty) {
          final data = await File(icons).readAsBytes();
          await (FontLoader(
            'MaterialIcons',
          )..addFont(Future.value(ByteData.sublistView(data)))).load();
        }
      });
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture'),
        child: app.ScoreApp(initialGame: game, stopwatch: watch),
      ),
    );
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('FISCORE_PREVIEW')) {
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/yape-donaciones.png'),
          tester.element(find.byType(app.ScoreApp)),
        ),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> close(WidgetTester tester) =>
      tap(tester, find.byTooltip('Cerrar').last);
  Future<void> dispose(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('FISCORE_PREVIEW')) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')),
      );
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/previews').create(recursive: true);
      await File(
        'build/previews/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('Inicio solicita exclusivamente orientación horizontal', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await app.main();
    await tester.pumpAndSettle();
    expect(
      calls
          .singleWhere(
            (call) => call.method == 'SystemChrome.setPreferredOrientations',
          )
          .arguments,
      ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
    );
    await dispose(tester);
  });

  for (final size in [
    const Size(568, 320),
    const Size(844, 390),
    const Size(720, 540),
    const Size(960, 600),
    const Size(1366, 768),
    const Size(1024, 600),
    const Size(1280, 800),
    const Size(1920, 1080),
    const Size(700, 240),
  ]) {
    testWidgets('Ventana adaptable y controles accesibles $size', (
      tester,
    ) async {
      final game = Game();
      await open(tester, game, size);
      final left = tester.getRect(find.text('LOCAL').first);
      final right = tester.getRect(find.text('VISITANTE').last);
      expect(left.center.dx, lessThan(right.center.dx));
      expect(left.top, closeTo(right.top, .1));
      await capture(
        tester,
        'tablero-${size.width.toInt()}x${size.height.toInt()}',
      );
      await tap(tester, find.byKey(const ValueKey('possession-0')));
      expect(game.possessionTeam, 0);
      await capture(
        tester,
        'flecha-${size.width.toInt()}x${size.height.toInt()}',
      );
      await tap(tester, find.text('+2').first);
      expect(game.teams[0].score, 2);
      await tap(tester, find.text('Faltas + / −').first);
      await tap(tester, find.byKey(const ValueKey('foul-plus-0-0')));
      expect(game.teamFouls(0), 1);
      await close(tester);
      await tap(tester, find.byKey(const ValueKey('credits-button')));
      await tap(tester, find.byKey(const ValueKey('copy-contact')));
      expect(find.text('Correo copiado'), findsOneWidget);
      expect(find.textContaining('925'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('donation-qr')));
      await capture(
        tester,
        'yape-${size.width.toInt()}x${size.height.toInt()}',
      );
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await close(tester);
      await close(tester);
      await tap(tester, find.text('Jugadores'));
      await tap(tester, find.byTooltip('Editar #4').first);
      await tap(tester, find.byKey(const ValueKey('jersey-key-8')));
      await close(tester);
      await tap(tester, find.byTooltip('Configurar partido'));
      await tap(tester, find.byKey(const ValueKey('period-minutes-plus')));
      await tap(tester, find.byKey(const ValueKey('save-settings')));
      await dispose(tester);
    });
  }

  testWidgets('Opciones, faltas, plantillas y créditos no pausan los relojes', (
    tester,
  ) async {
    final game = Game();
    final watch = ManualStopwatch();
    await open(tester, game, const Size(1024, 600), watch: watch);
    await tap(tester, find.text('INICIAR'));
    Future<void> advances() async {
      final before = game.remainingMs;
      final shotBefore = game.shotRemainingMs;
      watch.advance(1000);
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.running, isTrue);
      expect(game.remainingMs, before - 1000);
      expect(game.shotRemainingMs, shotBefore - 1000);
    }

    await tap(tester, find.text('Faltas + / −').first);
    await advances();
    await tap(tester, find.byKey(const ValueKey('foul-plus-0-0')));
    await advances();
    await close(tester);
    await tap(tester, find.byKey(const ValueKey('saved-teams-button')));
    await advances();
    await close(tester);
    await tap(tester, find.byKey(const ValueKey('credits-button')));
    await advances();
    await close(tester);
    await tap(tester, find.byTooltip('Opciones'));
    await tap(tester, find.text('Reglas de faltas'));
    await advances();
    await tap(tester, find.text('Entendido'));
    await tap(tester, find.byTooltip('Opciones de posesión'));
    await tap(tester, find.text('Ajustar posesión'));
    await advances();
    await tap(tester, find.text('Cancelar'));
    await advances();
    await tap(tester, find.byTooltip('Opciones de posesión'));
    await tap(tester, find.text('Ajustar posesión'));
    await tap(tester, find.byKey(const ValueKey('shot-seconds-minus')));
    await tap(tester, find.text('Guardar'));
    await advances();
    await tap(tester, find.byKey(const ValueKey('possession-1')));
    await advances();
    await tap(tester, find.byTooltip('Configurar partido'));
    await advances();
    await tap(tester, find.byTooltip('Opciones'));
    await tap(tester, find.text('Nuevo partido'));
    await advances();
    await tap(tester, find.text('Cancelar'));
    await tap(tester, find.text('Jugadores'));
    await tap(tester, find.byKey(const ValueKey('foul-plus-0-0')));
    await advances();
    await tap(tester, find.byKey(const ValueKey('foul-minus-0-0')));
    await advances();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await advances();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tap(tester, find.text('Marcador'));
    await tap(tester, find.text('PAUSAR'));
    final paused = game.remainingMs;
    watch.advance(1000);
    await tester.pump(const Duration(seconds: 1));
    expect(game.remainingMs, paused);
    expect(Game.fromJson(jsonDecode(saved!)).possessionTeam, 1);
    await dispose(tester);
  });

  testWidgets('Texto ampliado y nombres largos en tablet', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final game = Game();
    game.teams[0].name = 'UNIVERSIDAD DE LA SELVA';
    game.teams[1].name = 'VISITANTE CON NOMBRE LARGO';
    await open(tester, game, const Size(1024, 600));
    await tap(tester, find.byKey(const ValueKey('possession-1')));
    await tap(tester, find.text('+3').last);
    await tap(tester, find.byKey(const ValueKey('credits-button')));
    await tap(tester, find.byKey(const ValueKey('copy-contact')));
    await close(tester);
    await dispose(tester);
  });

  testWidgets('Fin de período sobre un panel y pausa al ocultar la app', (
    tester,
  ) async {
    final game = Game()..setClock(2000);
    final watch = ManualStopwatch();
    await open(tester, game, const Size(1024, 600), watch: watch);
    await tap(tester, find.text('INICIAR'));
    await tap(tester, find.text('Faltas + / −').first);
    watch.advance(3000);
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.remainingMs, 0);
    expect(game.running, isFalse);
    await close(tester);
    await tap(tester, find.text('SIGUIENTE TIEMPO'));
    await tap(tester, find.text('Preparar período'));
    await tap(tester, find.text('INICIAR'));
    watch.advance(1000);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(game.running, isFalse);
    final remaining = game.remainingMs;
    watch.advance(3000);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.remainingMs, remaining);
    expect(game.running, isFalse);
    await dispose(tester);
  });

  testWidgets('Redimensionar conserva el partido y la flecha', (tester) async {
    final game = Game()
      ..changeScore(0, 12)
      ..setPossessionTeam(1);
    await open(tester, game, const Size(1280, 800));
    for (final size in [
      const Size(320, 640),
      const Size(1366, 768),
      const Size(1024, 600),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(game.teams[0].score, 12);
      expect(game.possessionTeam, 1);
      await tap(tester, find.byKey(const ValueKey('possession-0')));
      await tap(tester, find.byKey(const ValueKey('possession-1')));
    }
    await dispose(tester);
  });

  test('Flecha independiente, compatible y conservada entre períodos', () {
    final game = Game();
    expect(game.possessionTeam, isNull);
    game.setPossessionTeam(0);
    game.changeScore(1, 3);
    game.resetShotClock(14);
    game.addFoul(0, game.teams[0].players.first, FoulType.personal);
    game.undo();
    game.setClock(0);
    game.nextPeriod();
    expect(game.possessionTeam, 0);
    expect(Game.fromJson(game.toJson()).possessionTeam, 0);
    final legacy = game.toJson()..remove('possessionTeam');
    expect(Game.fromJson(legacy).possessionTeam, isNull);
    game.setPossessionTeam(1);
    game.finish();
    game.setPossessionTeam(0);
    expect(game.possessionTeam, 1);
    game.newGame();
    expect(game.possessionTeam, isNull);
  });
}
