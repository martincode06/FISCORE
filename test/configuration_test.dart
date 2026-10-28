import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_basquet/game.dart';

void main() {
  test('Guardar corrige el reloj desincronizado de versiones anteriores', () {
    final game = Game()..quarterMinutes = 1;
    expect(game.remainingMs, 600000);
    expect(game.configure(periods: 4, minutes: 1, overtime: 5), isTrue);
    expect(game.remainingMs, 60000);
  });
  test('Dos tiempos de 15 se aplican al reloj y se guardan completos', () {
    final game = Game();
    expect(game.configure(periods: 2, minutes: 15, overtime: 5), isTrue);
    expect(game.periodCount, 2);
    expect(game.remainingMs, 900000);
    expect(game.periodLabel, 'TIEMPO 1 / 2');
    final restored = Game.fromJson(jsonDecode(jsonEncode(game.toJson())));
    expect(restored.periodCount, 2);
    expect(restored.quarterMinutes, 15);
    expect(restored.remainingMs, 900000);
    restored.setClock(0);
    expect(restored.nextPeriod(), isTrue);
    expect(restored.periodLabel, 'TIEMPO 2 / 2');
    expect(restored.remainingMs, 900000);
  });

  test('Cambiar duración conserva el tiempo jugado y los registros', () {
    final game = Game();
    game.running = true;
    game.elapse(120000);
    game.running = false;
    game.changeScore(0, 3);
    game.addFoul(0, game.teams[0].players.first, FoulType.personal);
    expect(game.configure(periods: 2, minutes: 15, overtime: 3), isTrue);
    expect(game.remainingMs, 780000);
    expect(game.teams[0].score, 3);
    expect(game.teamFouls(0), 1);
    expect(game.configure(periods: 2, minutes: 1, overtime: 3), isTrue);
    expect(game.remainingMs, 0);
  });

  test(
    'Cantidad se puede aumentar antes de la prórroga y no cambia tiempo',
    () {
      final game = Game();
      game.configure(periods: 2, minutes: 15, overtime: 5);
      game.setClock(0);
      game.nextPeriod();
      expect(game.configure(periods: 3, minutes: 15, overtime: 5), isTrue);
      expect(game.remainingMs, 900000);
      expect(game.periodLabel, 'TIEMPO 2 / 3');
      expect(game.configure(periods: 1, minutes: 15, overtime: 5), isFalse);
    },
  );

  test(
    'Formato personalizado: fin, prórroga y acumulado del último tiempo',
    () {
      final game = Game();
      game.configure(periods: 2, minutes: 15, overtime: 3);
      game.setClock(0);
      game.nextPeriod();
      game.addFoul(0, game.teams[0].players.first, FoulType.personal);
      game.setClock(0);
      expect(game.nextPeriod(), isTrue);
      expect(game.isOvertime, isTrue);
      expect(game.periodLabel, 'PRÓRROGA 1');
      expect(game.remainingMs, 180000);
      expect(game.teamFouls(0), 1);
      expect(game.labelForPeriod(3), 'PR1');
      expect(game.configure(periods: 3, minutes: 15, overtime: 3), isFalse);
      game.changeScore(0, 2);
      game.setClock(0);
      expect(game.nextPeriod(), isFalse);
    },
  );

  test(
    'Nuevo partido conserva el formato y versión anterior conserva 4 cuartos',
    () {
      final game = Game();
      game.configure(periods: 2, minutes: 15, overtime: 4);
      game.changeScore(0, 3);
      game.newGame();
      expect(game.periodCount, 2);
      expect(game.remainingMs, 900000);
      final legacy = Game().toJson()..remove('periodCount');
      expect(Game.fromJson(legacy).periodCount, 4);
    },
  );

  test('Las correcciones quitan el tipo correcto del jugador correcto', () {
    final game = Game();
    final a = game.teams[0].players[0];
    final b = game.teams[0].players[1];
    game.addFoul(0, a, FoulType.personal);
    game.addFoul(0, a, FoulType.technical);
    game.addFoul(0, b, FoulType.personal);
    expect(game.removeLatestFoul(0, a.id, FoulType.personal), isTrue);
    expect(game.playerFouls(a.id).single.type, FoulType.technical);
    expect(game.playerFouls(b.id).length, 1);
    expect(game.teamFouls(0), 2);
    expect(game.removeLatestFoul(0, a.id, FoulType.personal), isFalse);
    game.undo();
    expect(game.teamFouls(0), 3);
  });
}
