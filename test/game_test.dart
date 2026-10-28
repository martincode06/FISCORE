import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_basquet/game.dart';

void main() {
  test(
    'Más faltas primero, empate por dorsal, corrección y plantilla intacta',
    () {
      final g = Game();
      final players = g.teams[0].players;
      players[0].number = '88';
      players[2].number = '00';
      players[3].number = '0';
      final ids = players.map((p) => p.id).toList();
      g.addFoul(0, players[0], FoulType.personal);
      g.addFoul(0, players[0], FoulType.personal);
      g.addFoul(0, players[1], FoulType.personal);
      g.addFoul(0, players[2], FoulType.technical, countsForTeam: false);
      g.addFoul(0, players[2], FoulType.unsportsmanlike);
      g.addFoul(1, g.teams[1].players.last, FoulType.personal);
      expect(g.playersByFouls(0).take(4).map((p) => p.number), [
        '00',
        '88',
        '5',
        '0',
      ]);
      expect(g.playersByFouls(1).first.number, '15');
      expect(players.map((p) => p.id), ids);
      g.removeLatestFoul(0, players[0].id, FoulType.personal);
      expect(g.playersByFouls(0).take(3).map((p) => p.number), [
        '00',
        '5',
        '88',
      ]);
      g.undo();
      final restored = Game.fromJson(jsonDecode(jsonEncode(g.toJson())));
      expect(restored.playersByFouls(0).take(3).map((p) => p.number), [
        '00',
        '88',
        '5',
      ]);
      expect(restored.teams[0].players.map((p) => p.id), ids);
      final clean = Game();
      clean.teams[0].players[0].number = '00';
      clean.teams[0].players[1].number = '0';
      expect(clean.playersByFouls(0).take(2).map((p) => p.number), ['0', '00']);
    },
  );

  test('La quinta falta excluye al jugador y se contabiliza al equipo', () {
    final g = Game();
    final p = g.teams[0].players.first;
    for (var i = 0; i < 5; i++) {
      expect(g.addFoul(0, p, FoulType.personal), isTrue);
    }
    expect(g.playerFouls(p.id).length, 5);
    expect(g.teamFouls(0), 5);
    expect(g.teamFouls(1), 0);
    expect(g.isExcluded(p.id), isTrue);
    expect(g.addFoul(0, p, FoulType.personal), isFalse);
    g.removeFoul(g.fouls.last.id);
    expect(g.isExcluded(p.id), isFalse);
    expect(g.teamFouls(0), 4);
    expect(g.inPenalty(0), isTrue);
  });

  test('El nuevo cuarto reinicia faltas de equipo y conserva individuales', () {
    final g = Game();
    final p = g.teams[0].players.first;
    g.addFoul(0, p, FoulType.personal);
    g.changeScore(0, 3);
    g.setClock(0);
    expect(g.nextPeriod(), isTrue);
    expect(g.teamFouls(0), 0);
    expect(g.playerFouls(p.id).length, 1);
    expect(g.teams[0].score, 3);
    expect(g.remainingMs, 600000);
  });

  test('Las prórrogas conservan las faltas del cuarto período', () {
    final g = Game()..period = 4;
    g.addFoul(0, g.teams[0].players[0], FoulType.personal);
    g.setClock(0);
    expect(g.nextPeriod(), isTrue);
    expect(g.period, 5);
    expect(g.remainingMs, 300000);
    expect(g.teamFouls(0), 1);
    g.addFoul(0, g.teams[0].players[1], FoulType.personal);
    g.setClock(0);
    expect(g.nextPeriod(), isTrue);
    expect(g.teamFouls(0), 2);
  });

  test('No se avanza con reloj en marcha o con tiempo pendiente', () {
    final g = Game();
    expect(g.nextPeriod(), isFalse);
    g.running = true;
    g.remainingMs = 0;
    expect(g.nextPeriod(), isFalse);
    g.running = false;
    g.period = 4;
    g.changeScore(0, 1);
    expect(g.nextPeriod(), isFalse);
  });

  test('El reloj conserva fracciones y se detiene exactamente en cero', () {
    final g = Game()..remainingMs = 1200;
    g.running = true;
    expect(g.elapse(350), isFalse);
    expect(g.remainingMs, 850);
    g.running = false;
    g.elapse(10000);
    expect(g.remainingMs, 850);
    g.running = true;
    expect(g.elapse(1000), isTrue);
    expect(g.remainingMs, 0);
    expect(g.running, isFalse);
    expect(clockText(59900, tenths: true), '59.9');
    expect(clockText(600000), '10:00');
  });

  test('Deshacer corrige marcador y faltas sin alterar el reloj', () {
    final g = Game();
    g.changeScore(0, -1);
    expect(g.teams[0].score, 0);
    g.changeScore(1, 3);
    g.addFoul(1, g.teams[1].players.first, FoulType.personal);
    g.remainingMs = 42100;
    g.undo();
    expect(g.teamFouls(1), 0);
    expect(g.teams[1].score, 3);
    expect(g.remainingMs, 42100);
    g.undo();
    expect(g.teams[1].score, 0);
  });

  test('Técnicas y antideportivas combinadas descalifican antes de cinco', () {
    for (final combination in [
      [FoulType.technical, FoulType.technical],
      [FoulType.unsportsmanlike, FoulType.unsportsmanlike],
      [FoulType.technical, FoulType.unsportsmanlike],
      [FoulType.disqualifying],
    ]) {
      final g = Game();
      final p = g.teams[0].players.first;
      for (final type in combination) {
        g.addFoul(0, p, type);
      }
      expect(g.isDisqualified(p.id), isTrue);
      expect(g.isExcluded(p.id), isTrue);
    }
  });

  test('Falta de sustituto no añade una falta de equipo', () {
    final g = Game();
    final p = g.teams[0].players.last;
    g.addFoul(0, p, FoulType.technical, countsForTeam: false);
    expect(g.playerFouls(p.id).length, 1);
    expect(g.teamFouls(0), 0);
  });

  test('Se restaura todo el partido pausado y con opción de deshacer', () {
    final g = Game();
    g.teams[0].name = 'LIMA';
    g.teams[0].players.first.name = 'Ana';
    g.changeScore(0, 2);
    g.addFoul(0, g.teams[0].players.first, FoulType.personal);
    g.remainingMs = 19999;
    g.running = true;
    final restored = Game.fromJson(jsonDecode(jsonEncode(g.toJson())));
    expect(restored.running, isFalse);
    expect(restored.remainingMs, 19999);
    expect(restored.teams[0].name, 'LIMA');
    expect(restored.teams[0].players.first.name, 'Ana');
    expect(restored.teamFouls(0), 1);
    restored.undo();
    expect(restored.teamFouls(0), 0);
    expect(restored.teams[0].score, 2);
  });

  test(
    'Un partido finalizado bloquea modificaciones y uno nuevo mantiene plantillas',
    () {
      final g = Game();
      g.teams[0].name = 'LIMA';
      g.changeScore(0, 3);
      g.finish();
      g.changeScore(0, 1);
      expect(
        g.addFoul(0, g.teams[0].players.first, FoulType.personal),
        isFalse,
      );
      expect(g.teams[0].score, 3);
      g.newGame();
      expect(g.teams[0].name, 'LIMA');
      expect(g.teams[0].score, 0);
      expect(g.remainingMs, 600000);
      expect(g.finished, isFalse);
    },
  );
}
