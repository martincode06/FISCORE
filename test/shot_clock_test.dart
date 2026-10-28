import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_basquet/game.dart';

void main() {
  test('Posesión y partido cuentan el mismo tiempo y se pausan juntos', () {
    final game = Game()..running = true;
    game.elapse(1350);
    expect(game.remainingMs, 598650);
    expect(game.shotRemainingMs, 22650);
    game.running = false;
    game.elapse(8000);
    expect(game.shotRemainingMs, 22650);
    game.running = true;
    game.elapse(650);
    expect(game.shotRemainingMs, 22000);
  });

  test('Reinicios a 24 y 14 no alteran el reloj ni el marcador', () {
    final game = Game()..running = true;
    game.changeScore(0, 2);
    game.elapse(19000);
    game.resetShotClock(14);
    expect(game.shotRemainingMs, 14000);
    expect(game.remainingMs, 581000);
    expect(game.running, isTrue);
    expect(game.shotRunning, isTrue);
    game.elapse(1500);
    game.resetShotClock(24);
    expect(game.shotRemainingMs, 24000);
    expect(game.remainingMs, 579500);
    expect(game.teams[0].score, 2);
  });

  test(
    'Se puede detener solo la posesión y conservar el partido en marcha',
    () {
      final game = Game()..running = true;
      game.elapse(1000);
      game.holdShotClock();
      game.elapse(4000);
      expect(game.remainingMs, 595000);
      expect(game.shotRemainingMs, 23000);
      expect(game.shotRunning, isFalse);
      game.holdShotClock();
      game.elapse(1000);
      expect(game.shotRemainingMs, 22000);
    },
  );

  test(
    'Al agotar posesión se señala una sola vez y no se decide la infracción',
    () {
      final game = Game()..running = true;
      expect(game.elapse(24100), isFalse);
      expect(game.shotRemainingMs, 0);
      expect(game.shotExpired, isTrue);
      expect(game.shotRunning, isFalse);
      expect(game.running, isTrue);
      game.elapse(5000);
      expect(game.shotRemainingMs, 0);
      expect(game.remainingMs, 570900);
      game.resetShotClock(14);
      expect(game.shotExpired, isFalse);
      expect(game.shotRunning, isTrue);
    },
  );

  test('El fin de período tiene prioridad sobre la posesión', () {
    for (final ms in [12000, 24000]) {
      final game = Game()..remainingMs = ms;
      game.running = true;
      expect(game.elapse(30000), isTrue);
      expect(game.shotExpired, isFalse);
      expect(game.running, isFalse);
    }
    final game = Game()..remainingMs = 25000;
    game.running = true;
    game.elapse(24000);
    expect(game.shotExpired, isTrue);
    expect(game.remainingMs, 1000);
  });

  test('Nueva cuenta con menos tiempo de partido se apaga', () {
    final game = Game()..remainingMs = 13000;
    game.resetShotClock(24);
    expect(game.shotEnabled, isFalse);
    game.resetShotClock(14);
    expect(game.shotEnabled, isFalse);
    game.running = true;
    game.elapse(1000);
    expect(game.shotRemainingMs, 14000);
    game.running = false;
    game.remainingMs = 20000;
    game.resetShotClock(14);
    expect(game.shotEnabled, isTrue);
  });

  test(
    'La cuenta existente sigue siendo válida con menos de 14 de partido',
    () {
      final game = Game()..remainingMs = 20000;
      game.setShotClock(15000);
      game.running = true;
      game.elapse(10000);
      expect(game.remainingMs, 10000);
      expect(game.shotEnabled, isTrue);
      expect(game.shotRemainingMs, 5000);
      game.elapse(5000);
      expect(game.shotExpired, isTrue);
    },
  );

  test('Apagar posesión deja correr únicamente el partido', () {
    final game = Game()..running = true;
    game.disableShotClock();
    game.elapse(30000);
    expect(game.shotRemainingMs, 24000);
    expect(game.shotExpired, isFalse);
    expect(game.remainingMs, 570000);
    game.resetShotClock(24);
    expect(game.shotEnabled, isTrue);
    expect(game.shotRunning, isTrue);
  });

  test('Ajustes, nuevo período y nuevo partido respetan el estado', () {
    final game = Game();
    game.setShotClock(7600);
    expect(game.shotRemainingMs, 7600);
    game.running = true;
    game.setShotClock(10000);
    expect(game.shotRemainingMs, 7600);
    game.running = false;
    game.setClock(0);
    game.nextPeriod();
    expect(game.shotRemainingMs, 24000);
    game.setShotClock(6500);
    game.newGame();
    expect(game.shotRemainingMs, 24000);
    expect(game.shotHeld, isFalse);
    game.finish();
    game.resetShotClock(14);
    expect(game.shotRemainingMs, 24000);
  });

  test('Anotar puntos o faltas y deshacer no reinicia posesión', () {
    final game = Game()..running = true;
    game.elapse(8000);
    game.changeScore(0, 2);
    game.addFoul(0, game.teams[0].players.first, FoulType.personal);
    game.undo();
    expect(game.shotRemainingMs, 16000);
  });

  test('Guardado de posesión y compatibilidad con versión 1.0', () {
    final game = Game();
    game.setShotClock(6200);
    game.holdShotClock();
    game.running = true;
    final restored = Game.fromJson(jsonDecode(jsonEncode(game.toJson())));
    expect(restored.shotRemainingMs, 6200);
    expect(restored.shotHeld, isTrue);
    expect(restored.running, isFalse);
    final legacy = game.toJson()
      ..removeWhere((key, _) => key.startsWith('shot'));
    final oldGame = Game.fromJson(legacy);
    expect(oldGame.shotRemainingMs, 24000);
    expect(oldGame.shotEnabled, isTrue);
    expect(oldGame.running, isFalse);
  });

  test(
    'El contador muestra enteros y décimas en los últimos cinco segundos',
    () {
      expect(shotClockText(24000), '24');
      expect(shotClockText(14100), '15');
      expect(shotClockText(5000), '05');
      expect(shotClockText(4300), '4.3');
      expect(shotClockText(1), '0.1');
      expect(shotClockText(0), '00');
    },
  );
}
