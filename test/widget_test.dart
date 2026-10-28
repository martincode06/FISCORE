import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_basquet/app_widgets.dart';
import 'package:score_basquet/game.dart';
import 'package:score_basquet/main.dart';
import 'package:score_basquet/saved_teams.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? saved;
  String? clipboard;
  String? teamStore;
  bool failTeamSave = false;
  final nativeCalls = <String>[];
  setUp(() {
    saved = null;
    clipboard = null;
    teamStore = null;
    failTeamSave = false;
    nativeCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (call) async {
          nativeCalls.add(call.method);
          if (call.method == 'save') saved = call.arguments as String;
          if (call.method == 'appVersion') return '1.5.0';
          if (call.method == 'loadTeams') return teamStore;
          if (call.method == 'saveTeams') {
            if (failTeamSave) throw PlatformException(code: 'STORAGE');
            teamStore = call.arguments as String;
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });

  Future<void> open(WidgetTester tester, Game game, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ScoreApp(initialGame: game));
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tap(tester, find.byTooltip('Cerrar'));
  }

  Future<void> dispose(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }

  for (final size in [
    const Size(568, 280),
    const Size(640, 320),
    const Size(640, 360),
    const Size(800, 360),
    const Size(1000, 450),
    const Size(1280, 800),
  ]) {
    testWidgets('Interfaz y paneles utilizables en $size', (tester) async {
      await open(tester, Game(), size);
      expect(tester.takeException(), isNull);
      await tap(tester, find.text('Faltas + / −').first);
      expect(
        find.byKey(const ValueKey('foul-type')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('foul-plus-0-0')).hitTestable(),
        findsOneWidget,
      );
      final grid = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('foul-plus-0-11')),
        180,
        scrollable: grid,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('foul-plus-0-11')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await close(tester);
      await tap(tester, find.byTooltip('Configurar partido'));
      await tap(tester, find.byKey(const ValueKey('period-minutes-plus')));
      expect(find.byType(TextField), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      await tap(tester, find.text('Cancelar'));
      await tap(tester, find.text('Jugadores'));
      expect(find.text('Jugador 4'), findsWidgets);
      expect(tester.takeException(), isNull);
      expect(find.text('Registro'), findsNothing);
      expect(find.text('Guardado local · Sin conexión'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('credits-button')));
      await tap(tester, find.byKey(const ValueKey('copy-contact')));
      expect(find.text('Número copiado'), findsOneWidget);
      await close(tester);
      await tap(tester, find.byKey(const ValueKey('saved-teams-button')));
      await tap(tester, find.byKey(const ValueKey('save-team-0')));
      await tap(tester, find.byKey(const ValueKey('save-name')));
      expect(
        SavedTeams.fromJson(jsonDecode(teamStore!)).teams.single.players.length,
        12,
      );
      await close(tester);
      await dispose(tester);
    });
  }

  testWidgets('Anotar, deshacer y corregir con el interruptor independiente', (
    tester,
  ) async {
    final game = Game();
    game.teams[0].score = 5;
    game.teams[1].score = 7;
    await open(tester, game, const Size(640, 360));
    await tap(tester, find.byKey(const ValueKey('correct-points-0')));
    expect(find.text('−3'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
    await tap(tester, find.text('−3'));
    expect(game.teams[0].score, 2);
    expect(game.teams[1].score, 7);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '−3'))
          .onPressed,
      isNull,
    );
    await tap(tester, find.text('−2'));
    expect(game.teams[0].score, 0);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '−1'))
          .onPressed,
      isNull,
    );
    await tap(tester, find.byTooltip('Deshacer'));
    expect(game.teams[0].score, 2);
    await tap(tester, find.byKey(const ValueKey('correct-points-0')));
    await tap(tester, find.text('+1').first);
    expect(game.teams[0].score, 3);
    await dispose(tester);
  });

  testWidgets('Faltas directas: quinta, exclusión, menos y deshacer', (
    tester,
  ) async {
    final game = Game();
    await open(tester, game, const Size(800, 360));
    await tap(tester, find.text('INICIAR'));
    expect(game.running, isTrue);
    await tap(tester, find.text('Faltas + / −').first);
    expect(game.running, isFalse);
    for (var n = 0; n < 5; n++) {
      await tap(tester, find.byKey(const ValueKey('foul-plus-0-0')));
    }
    expect(game.teamFouls(0), 5);
    expect(game.isExcluded('0-0'), isTrue);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('foul-plus-0-0')))
          .onPressed,
      isNull,
    );
    await tap(tester, find.byKey(const ValueKey('foul-minus-0-0')));
    expect(game.teamFouls(0), 4);
    expect(game.isExcluded('0-0'), isFalse);
    await tap(tester, find.text('Deshacer'));
    expect(game.teamFouls(0), 5);
    await close(tester);
    await dispose(tester);
  });

  testWidgets(
    'Guardar minutos actualiza el reloj y sobrevive a la reapertura',
    (tester) async {
      final game = Game();
      await open(tester, game, const Size(800, 360));
      await tap(tester, find.byTooltip('Configurar partido'));
      await tap(tester, find.byKey(const ValueKey('period-minutes-plus')));
      await tap(tester, find.byKey(const ValueKey('save-settings')));
      expect(game.quarterMinutes, 11);
      expect(game.remainingMs, 660000);
      expect(find.text('11:00'), findsOneWidget);
      final restored = Game.fromJson(jsonDecode(saved!));
      expect(restored.quarterMinutes, 11);
      expect(restored.remainingMs, 660000);
      await tap(tester, find.byTooltip('Configurar partido'));
      expect(find.text('11'), findsOneWidget);
      await close(tester);
      await dispose(tester);
    },
  );

  testWidgets('Formato 2 por 10 y ajustes de reloj sin teclado', (
    tester,
  ) async {
    final game = Game();
    await open(tester, game, const Size(800, 360));
    await tap(tester, find.byTooltip('Configurar partido'));
    await tap(tester, find.byKey(const ValueKey('format-halves')));
    await tap(tester, find.byKey(const ValueKey('save-settings')));
    expect(game.periodCount, 2);
    expect(game.quarterMinutes, 10);
    expect(game.remainingMs, 600000);
    expect(find.text('TIEMPO 1 / 2'), findsOneWidget);
    await tap(tester, find.byTooltip('Ajustar reloj'));
    expect(find.byType(TextField), findsNothing);
    await tap(tester, find.byKey(const ValueKey('clock-minutes-plus')));
    await tap(tester, find.byKey(const ValueKey('clock-seconds-plus')));
    await tap(tester, find.text('Guardar'));
    expect(game.remainingMs, 661000);
    expect(tester.testTextInput.isVisible, isFalse);
    await dispose(tester);
  });

  testWidgets(
    'Posesión con pausa independiente y ajuste de segundos y décimas',
    (tester) async {
      final game = Game();
      await open(tester, game, const Size(800, 360));
      await tap(tester, find.text('14 s'));
      expect(game.shotRemainingMs, 14000);
      await tap(tester, find.text('INICIAR'));
      await tap(tester, find.byTooltip('Pausar posesión'));
      expect(game.shotHeld, isTrue);
      expect(game.running, isTrue);
      await tap(tester, find.text('PAUSAR'));
      await tap(tester, find.byTooltip('Opciones de posesión'));
      await tap(tester, find.text('Ajustar posesión'));
      expect(find.byType(TextField), findsNothing);
      final old = game.shotRemainingMs;
      await tap(tester, find.byKey(const ValueKey('shot-seconds-minus')));
      await tap(tester, find.byKey(const ValueKey('shot-tenths-plus')));
      await tap(tester, find.text('Guardar'));
      expect(game.shotRemainingMs, ((old / 100).round() - 10 + 1) * 100);
      await dispose(tester);
    },
  );

  for (final size in [const Size(568, 280), const Size(800, 360)]) {
    testWidgets('Más faltas arriba y controles conservan su jugador en $size', (
      tester,
    ) async {
      final game = Game();
      await open(tester, game, size);
      await tap(tester, find.text('Faltas + / −').first);
      final lastPlus = find.byKey(const ValueKey('foul-plus-0-11'));
      await tester.scrollUntilVisible(
        lastPlus,
        180,
        scrollable: find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        ),
      );
      await tap(tester, lastPlus);
      expect(lastPlus.hitTestable(), findsOneWidget);
      final gridTop = tester.getTopLeft(find.byType(GridView));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('0-11'))).dy,
        closeTo(gridTop.dy + 4, .5),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('0-11'))).dx,
        closeTo(gridTop.dx + 12, .5),
      );
      await tap(tester, lastPlus);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('foul-plus-0-1')),
        80,
        scrollable: find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        ),
      );
      await tap(tester, find.byKey(const ValueKey('foul-plus-0-1')));
      expect(game.playerFouls('0-11').length, 2);
      expect(game.playerFouls('0-1').length, 1);
      expect(game.playerFouls('0-0'), isEmpty);
      await tap(tester, find.byKey(const ValueKey('foul-minus-0-11')));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('0-1'))).dy,
        closeTo(gridTop.dy + 4, .5),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('0-1'))).dx,
        closeTo(gridTop.dx + 12, .5),
      );
      await tap(tester, find.text('Deshacer'));
      expect(game.playerFouls('0-11').length, 2);
      await close(tester);
      await tap(tester, find.text('Jugadores'));
      expect(
        tester.getTopLeft(lastPlus).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('foul-plus-0-1'))).dy,
        ),
      );
      await tap(tester, find.byKey(const ValueKey('foul-plus-0-1')));
      expect(game.playerFouls('0-1').length, 2);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('foul-plus-0-1'))).dy,
        lessThan(tester.getTopLeft(lastPlus).dy),
      );
      expect(game.teams[0].players.first.number, '4');
      expect(game.playerFouls('1-11'), isEmpty);
      expect(Game.fromJson(jsonDecode(saved!)).playerFouls('0-11').length, 2);
      await dispose(tester);
    });
  }

  testWidgets('Texto grande mantiene accesibles botones y ajustes', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, Game(), const Size(800, 360));
    expect(tester.takeException(), isNull);
    await tap(tester, find.text('Faltas + / −').first);
    await tap(tester, find.byKey(const ValueKey('foul-plus-0-0')));
    expect(tester.takeException(), isNull);
    await close(tester);
    await tap(tester, find.byTooltip('Configurar partido'));
    await tap(tester, find.byKey(const ValueKey('period-count-plus')));
    await tap(tester, find.byKey(const ValueKey('save-settings')));
    await dispose(tester);
  });

  testWidgets('Dorsal 88 en dos toques, validación, borrado y persistencia', (
    tester,
  ) async {
    final game = Game();
    await open(tester, game, const Size(800, 360));
    await tap(tester, find.text('Jugadores'));
    await tap(tester, find.byTooltip('Editar #4').first);
    expect(find.byType(TextField), findsNothing);
    await tap(tester, find.byKey(const ValueKey('jersey-key-8')));
    await tap(tester, find.byKey(const ValueKey('jersey-key-8')));
    expect(find.text('#88'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    await tap(tester, find.byKey(const ValueKey('save-player')));
    expect(game.teams[0].players.first.number, '88');
    expect(
      Game.fromJson(jsonDecode(saved!)).teams[0].players.first.number,
      '88',
    );
    await tester.scrollUntilVisible(
      find.byTooltip('Editar #88'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip('Editar #88').first);
    await tap(tester, find.byKey(const ValueKey('jersey-key-5')));
    await tap(tester, find.byKey(const ValueKey('save-player')));
    expect(find.textContaining('ya pertenece'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('jersey-key-back')));
    await tap(tester, find.byKey(const ValueKey('save-player')));
    expect(find.text('Escribe un dorsal.'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('jersey-key-00')));
    await tap(tester, find.byKey(const ValueKey('edit-player-name')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('name-input'));
    expect(tester.getRect(input).bottom, lessThanOrEqualTo(160));
    await tester.enterText(input, 'Martin Villy');
    await tap(tester, find.byKey(const ValueKey('save-name')));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('save-player')));
    final restored = Game.fromJson(jsonDecode(saved!));
    expect(restored.teams[0].players.first.number, '00');
    expect(restored.teams[0].players.first.name, 'Martin Villy');
    await dispose(tester);
  });

  for (final size in [
    const Size(568, 280),
    const Size(640, 320),
    const Size(800, 360),
  ]) {
    testWidgets('Nombre visible sobre teclado de 200 px en $size', (
      tester,
    ) async {
      await open(tester, Game(), size);
      final context = tester.element(find.byType(MatchScreen));
      String? result;
      final dialog = showDialog<String>(
        context: context,
        builder: (_) => const NameDialog(
          title: 'Nombre del jugador',
          value: 'Nombre anterior',
          maxLength: 28,
        ),
      );
      dialog.then((value) => result = value);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('name-input'));
      expect(
        tester.getRect(input).bottom,
        lessThanOrEqualTo(size.height - 200),
      );
      expect(input.hitTestable(), findsOneWidget);
      await tester.enterText(input, 'Jugador de nombre largo');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(result, 'Jugador de nombre largo');
      await dispose(tester);
    });
  }

  testWidgets(
    'Mis equipos: guardar, actualizar, recuperar y cargar sin faltas',
    (tester) async {
      final game = Game();
      game.teams[0].name = 'FIAI';
      game.teams[0].players.first.number = '88';
      game.teams[0].players.first.name = 'Ana';
      game.changeScore(0, 8);
      game.addFoul(0, game.teams[0].players.first, FoulType.personal);
      await open(tester, game, const Size(800, 360));
      await tap(tester, find.byKey(const ValueKey('saved-teams-button')));
      await tap(tester, find.byKey(const ValueKey('save-team-0')));
      await tap(tester, find.byKey(const ValueKey('save-name')));
      expect(
        SavedTeams.fromJson(jsonDecode(teamStore!)).teams.single.name,
        'FIAI',
      );
      await close(tester);
      game.teams[0].players.first.name = 'Ana María';
      await tap(tester, find.byKey(const ValueKey('saved-teams-button')));
      await tap(tester, find.byKey(const ValueKey('save-team-0')));
      await tap(tester, find.byKey(const ValueKey('save-name')));
      await tap(tester, find.text('Actualizar'));
      expect(SavedTeams.fromJson(jsonDecode(teamStore!)).teams.length, 1);
      await close(tester);
      game.newGame(keepTeams: false);
      game.teams[0].name = 'DERECHO';
      game.changeScore(0, 3);
      game.addFoul(0, game.teams[0].players.first, FoulType.personal);
      game.changeScore(1, 2);
      game.addFoul(1, game.teams[1].players.first, FoulType.personal);
      await tap(tester, find.byKey(const ValueKey('saved-teams-button')));
      await tap(tester, find.byKey(const ValueKey('use-team-fiai-1')));
      await tap(tester, find.text('Cancelar'));
      expect(game.teams[1].score, 2);
      await tap(tester, find.byKey(const ValueKey('use-team-fiai-1')));
      await tap(tester, find.text('Cargar equipo'));
      expect(game.teams[1].name, 'FIAI');
      expect(game.teams[1].score, 0);
      expect(game.teamFouls(1), 0);
      expect(game.teams[1].players.first.name, 'Ana María');
      expect(game.teams[1].players.first.number, '88');
      expect(game.teams[0].name, 'DERECHO');
      expect(game.teams[0].score, 3);
      expect(game.teamFouls(0), 1);
      expect(Game.fromJson(jsonDecode(saved!)).teams[1].name, 'FIAI');
      game.finish();
      await tap(tester, find.byKey(const ValueKey('saved-teams-button')));
      await tap(tester, find.byKey(const ValueKey('use-team-fiai-0')));
      await tap(tester, find.text('Nuevo partido'));
      expect(game.finished, isFalse);
      expect(game.teams[0].name, 'FIAI');
      expect(game.teams.map((t) => t.score), [0, 0]);
      expect(game.fouls, isEmpty);
      expect(SavedTeams.fromJson(jsonDecode(teamStore!)).teams.length, 1);
      await dispose(tester);
    },
  );

  testWidgets(
    'Fallo al guardar equipo permite reintentar sin perder la biblioteca',
    (tester) async {
      await open(tester, Game(), const Size(640, 320));
      await tap(tester, find.byKey(const ValueKey('saved-teams-button')));
      failTeamSave = true;
      await tap(tester, find.byKey(const ValueKey('save-team-0')));
      await tap(tester, find.byKey(const ValueKey('save-name')));
      expect(
        find.textContaining('No se pudo guardar el equipo'),
        findsOneWidget,
      );
      expect(teamStore, isNull);
      failTeamSave = false;
      await tap(tester, find.byKey(const ValueKey('save-team-0')));
      await tap(tester, find.byKey(const ValueKey('save-name')));
      expect(teamStore, isNotNull);
      await close(tester);
      await dispose(tester);
    },
  );

  testWidgets(
    'Biblioteca corrupta no se sobrescribe y permite volver a leerla',
    (tester) async {
      teamStore = '{datos dañados';
      await open(tester, Game(), const Size(568, 280));
      await tap(tester, find.byKey(const ValueKey('saved-teams-button')));
      expect(find.textContaining('No se pudieron leer'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('save-team-0')))
            .onPressed,
        isNull,
      );
      teamStore = null;
      await tap(tester, find.text('Reintentar'));
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('save-team-0')))
            .onPressed,
        isNotNull,
      );
      await close(tester);
      await dispose(tester);
    },
  );

  testWidgets('FISCORE: créditos, contacto copiado y prueba de chicharra', (
    tester,
  ) async {
    final game = Game();
    await open(tester, game, const Size(800, 360));
    expect(find.text('FISCORE'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('credits-button')));
    expect(find.text('Martin Villy'), findsOneWidget);
    expect(find.text('925 449 100'), findsOneWidget);
    expect(find.text('Versión 1.5.0'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('copy-contact')));
    expect(clipboard, '925449100');
    await close(tester);
    final clock = game.remainingMs;
    await tap(tester, find.byTooltip('Opciones'));
    await tap(tester, find.text('Probar chicharra'));
    expect(nativeCalls, contains('horn'));
    expect(game.remainingMs, clock);
    expect(game.running, isFalse);
    await dispose(tester);
  });
}
