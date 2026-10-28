import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_basquet/game.dart';
import 'package:score_basquet/saved_teams.dart';

void main() {
  test(
    'Plantillas conservan nombres y dorsales, sin estadísticas ni referencias compartidas',
    () {
      final game = Game();
      game.teams[1].name = 'FIAI';
      game.teams[1].players[0].number = '88';
      game.teams[1].players[0].name = 'Ana';
      game.changeScore(1, 40);
      game.addFoul(1, game.teams[1].players[0], FoulType.personal);
      final saved = SavedTeam.capture(game.teams[1]);
      final encoded = jsonEncode(SavedTeams().withTeam(saved).toJson());
      expect(encoded, isNot(contains('score')));
      expect(encoded, isNot(contains('fouls')));
      game.teams[1].players[0].name = 'Otro nombre';
      final restored = SavedTeams.fromJson(jsonDecode(encoded)).teams.single;
      final otherMatch = Game();
      otherMatch.teams[1].name = 'DERECHO';
      otherMatch.changeScore(1, 12);
      otherMatch.addFoul(1, otherMatch.teams[1].players[0], FoulType.personal);
      otherMatch.changeScore(0, 9);
      otherMatch.addFoul(0, otherMatch.teams[0].players[0], FoulType.personal);
      otherMatch.remainingMs = 123000;
      expect(otherMatch.replaceTeam(0, restored.forMatch(0)), isTrue);
      expect(otherMatch.teams[0].name, 'FIAI');
      expect(otherMatch.teams[0].players[0].number, '88');
      expect(otherMatch.teams[0].players[0].name, 'Ana');
      expect(otherMatch.teams[0].players[0].id, '0-0');
      expect(otherMatch.teams[0].score, 0);
      expect(otherMatch.teamFouls(0), 0);
      expect(otherMatch.teams[1].name, 'DERECHO');
      expect(otherMatch.teams[1].score, 12);
      expect(otherMatch.teamFouls(1), 1);
      expect(otherMatch.remainingMs, 123000);
      expect(otherMatch.canUndo, isFalse);
      otherMatch.teams[0].players[0].name = 'Editar en este partido';
      expect(restored.players[0].name, 'Ana');
      expect(otherMatch.replaceTeam(1, restored.forMatch(1)), isTrue);
      expect(otherMatch.teams[1].players[0].id, '1-0');
      expect(otherMatch.fouls, isEmpty);
    },
  );

  test(
    'Actualizar por nombre no duplica el equipo y la biblioteca sobrevive nuevos partidos',
    () {
      final game = Game();
      final first = SavedTeam.capture(game.teams[0], name: 'FIAI');
      final initial = SavedTeams().withTeam(first);
      game.teams[0].players[0].name = 'Nueva jugadora';
      final updated = initial.withTeam(
        SavedTeam.capture(game.teams[0], name: ' fiai '),
      );
      expect(initial.teams.single.players.first.name, isEmpty);
      expect(updated.teams.length, 1);
      expect(updated.teams.single.players.first.name, 'Nueva jugadora');
      game.newGame(keepTeams: false);
      expect(updated.teams.single.players.first.name, 'Nueva jugadora');
      game.running = true;
      expect(game.replaceTeam(0, first.forMatch(0)), isFalse);
      game.finish();
      expect(game.replaceTeam(0, first.forMatch(0)), isFalse);
    },
  );

  test(
    'Bibliotecas corruptas, dorsales repetidos y versiones desconocidas se rechazan',
    () {
      expect(
        () => SavedTeams.fromJson({'version': 7, 'teams': []}),
        throwsFormatException,
      );
      final team = Game().teams[0];
      team.players[0].number = team.players[1].number;
      expect(() => SavedTeam.capture(team), throwsFormatException);
      final valid = SavedTeam.capture(Game().teams[0]);
      expect(
        () => SavedTeams.fromJson({
          'version': 1,
          'teams': [valid.toJson(), valid.toJson()],
        }),
        throwsFormatException,
      );
    },
  );
}
