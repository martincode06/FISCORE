import 'game.dart';

/// Reusable templates contain names and dorsals only, never match statistics.
class SavedPlayer {
  const SavedPlayer({required this.number, required this.name});
  final String number;
  final String name;
  Map<String, dynamic> toJson() => {'number': number, 'name': name};
  factory SavedPlayer.fromJson(Map<String, dynamic> json) => SavedPlayer(
    number: json['number'] as String,
    name: json['name'] as String,
  );
}

class SavedTeam {
  SavedTeam({required this.name, required List<SavedPlayer> players})
    : players = List.unmodifiable(players) {
    final numbers = players.map((p) => p.number).toSet();
    if (name.trim().isEmpty ||
        name.length > 22 ||
        players.length != 12 ||
        numbers.length != players.length ||
        players.any(
          (p) =>
              !RegExp(r'^(00|0|[1-9][0-9]?)$').hasMatch(p.number) ||
              p.name.length > 28,
        )) {
      throw const FormatException('Plantilla de equipo inválida');
    }
  }
  final String name;
  final List<SavedPlayer> players;
  String get id => name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  factory SavedTeam.capture(Team team, {String? name}) => SavedTeam(
    name: (name ?? team.name).trim(),
    players: team.players
        .map((p) => SavedPlayer(number: p.number, name: p.name))
        .toList(),
  );
  Team forMatch(int slot) => Team(
    name: name,
    players: [
      for (var i = 0; i < players.length; i++)
        Player(
          id: '$slot-$i',
          number: players[i].number,
          name: players[i].name,
        ),
    ],
  );
  Map<String, dynamic> toJson() => {
    'name': name,
    'players': players.map((p) => p.toJson()).toList(),
  };
  factory SavedTeam.fromJson(Map<String, dynamic> json) => SavedTeam(
    name: json['name'] as String,
    players: (json['players'] as List)
        .map((p) => SavedPlayer.fromJson(Map<String, dynamic>.from(p)))
        .toList(),
  );
}

class SavedTeams {
  SavedTeams([List<SavedTeam> teams = const []])
    : teams = List.unmodifiable(teams);
  final List<SavedTeam> teams;
  bool contains(String id) => teams.any((t) => t.id == id);
  SavedTeams withTeam(SavedTeam team) => SavedTeams(
    [...teams.where((t) => t.id != team.id), team]
      ..sort((a, b) => a.id.compareTo(b.id)),
  );
  Map<String, dynamic> toJson() => {
    'version': 1,
    'teams': teams.map((t) => t.toJson()).toList(),
  };
  factory SavedTeams.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Biblioteca desconocida');
    }
    final teams = (json['teams'] as List)
        .map((t) => SavedTeam.fromJson(Map<String, dynamic>.from(t)))
        .toList();
    if (teams.map((t) => t.id).toSet().length != teams.length) {
      throw const FormatException('Equipos duplicados');
    }
    return SavedTeams(teams);
  }
}
