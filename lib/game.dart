import 'dart:math';

enum FoulType {
  personal('P', 'Personal'),
  technical('T', 'Técnica'),
  unsportsmanlike('U', 'Antideportiva'),
  disqualifying('D', 'Descalificante');

  const FoulType(this.code, this.label);
  final String code;
  final String label;
}

class Player {
  Player({required this.id, required this.number, this.name = ''});
  final String id;
  String number;
  String name;
  String get label => '#$number${name.isEmpty ? '' : ' · $name'}';
  Map<String, dynamic> toJson() => {'id': id, 'number': number, 'name': name};
  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['id'] as String,
    number: json['number'] as String,
    name: json['name'] as String,
  );
}

class Team {
  Team({required this.name, required this.players, this.score = 0});
  String name;
  int score;
  final List<Player> players;
  Map<String, dynamic> toJson() => {
    'name': name,
    'score': score,
    'players': players.map((p) => p.toJson()).toList(),
  };
  factory Team.fromJson(Map<String, dynamic> json) => Team(
    name: json['name'] as String,
    score: json['score'] as int,
    players: (json['players'] as List)
        .map((p) => Player.fromJson(Map<String, dynamic>.from(p)))
        .toList(),
  );
}

class Foul {
  Foul({
    required this.id,
    required this.team,
    required this.playerId,
    required this.period,
    required this.type,
    required this.clockMs,
    this.countsForTeam = true,
  });
  final int id;
  final int team;
  final String playerId;
  final int period;
  final FoulType type;
  final int clockMs;
  final bool countsForTeam;
  Map<String, dynamic> toJson() => {
    'id': id,
    'team': team,
    'playerId': playerId,
    'period': period,
    'type': type.name,
    'clockMs': clockMs,
    'countsForTeam': countsForTeam,
  };
  factory Foul.fromJson(Map<String, dynamic> json) => Foul(
    id: json['id'] as int,
    team: json['team'] as int,
    playerId: json['playerId'] as String,
    period: json['period'] as int,
    type: FoulType.values.byName(json['type'] as String),
    clockMs: json['clockMs'] as int,
    countsForTeam: json['countsForTeam'] as bool,
  );
}

/// Clock updates are supplied by a monotonic stopwatch in the UI.
class Game {
  Game()
    : teams = List.generate(
        2,
        (t) => Team(
          name: t == 0 ? 'LOCAL' : 'VISITANTE',
          players: List.generate(
            12,
            (p) => Player(id: '$t-$p', number: '${p + 4}'),
          ),
        ),
      );

  List<Team> teams;
  List<Foul> fouls = [];
  int period = 1;
  int periodCount = 4;
  int quarterMinutes = 10;
  int overtimeMinutes = 5;
  int remainingMs = 600000;
  int shotRemainingMs = 24000;
  bool shotEnabled = true;
  bool shotHeld = false;
  bool shotExpired = false;
  bool running = false;
  bool finished = false;
  int _nextId = 1;
  final List<Map<String, dynamic>> _undo = [];

  bool get isOvertime => period > periodCount;
  String get periodNoun => periodCount == 4 ? 'cuarto' : 'tiempo';
  String get periodLabel => isOvertime
      ? 'PRÓRROGA ${period - periodCount}'
      : '${periodNoun.toUpperCase()} $period / $periodCount';
  String labelForPeriod(int value) => value > periodCount
      ? 'PR${value - periodCount}'
      : '${periodCount == 4 ? 'C' : 'T'}$value';
  bool get canUndo => _undo.isNotEmpty && !finished;
  bool get tied => teams[0].score == teams[1].score;
  bool get shotRunning =>
      running && shotEnabled && !shotHeld && shotRemainingMs > 0;
  int get periodDurationMs =>
      (isOvertime ? overtimeMinutes : quarterMinutes) * 60000;

  int teamFouls(int team) => fouls
      .where(
        (f) =>
            f.team == team &&
            f.countsForTeam &&
            min(f.period, periodCount) == min(period, periodCount),
      )
      .length;
  bool inPenalty(int team) => teamFouls(team) >= 4;
  List<Foul> playerFouls(String id) =>
      fouls.where((f) => f.playerId == id).toList();

  /// A display copy: sorting must never change player IDs or saved roster slots.
  List<Player> playersByFouls(int team) {
    final totals = <String, int>{};
    for (final foul in fouls) {
      totals.update(foul.playerId, (count) => count + 1, ifAbsent: () => 1);
    }
    return List<Player>.of(teams[team].players)..sort((a, b) {
      final byFouls = (totals[b.id] ?? 0).compareTo(totals[a.id] ?? 0);
      if (byFouls != 0) return byFouls;
      final byNumber = (int.tryParse(a.number) ?? 100).compareTo(
        int.tryParse(b.number) ?? 100,
      );
      if (byNumber != 0) return byNumber;
      // 0 precedes 00; IDs make even legacy duplicate dorsals deterministic.
      final byLength = a.number.length.compareTo(b.number.length);
      return byLength != 0 ? byLength : a.id.compareTo(b.id);
    });
  }

  bool isDisqualified(String id) {
    final entries = playerFouls(id);
    final technical = entries.where((f) => f.type == FoulType.technical).length;
    final unsportsmanlike = entries
        .where((f) => f.type == FoulType.unsportsmanlike)
        .length;
    return entries.any((f) => f.type == FoulType.disqualifying) ||
        technical >= 2 ||
        unsportsmanlike >= 2 ||
        (technical >= 1 && unsportsmanlike >= 1);
  }

  bool isExcluded(String id) =>
      playerFouls(id).length >= 5 || isDisqualified(id);

  void _checkpoint() {
    _undo.add({
      'scores': teams.map((t) => t.score).toList(),
      'fouls': fouls.map((f) => f.toJson()).toList(),
    });
    if (_undo.length > 50) _undo.removeAt(0);
  }

  void changeScore(int team, int delta) {
    if (finished || teams[team].score + delta < 0 || delta == 0) return;
    _checkpoint();
    teams[team].score += delta;
  }

  bool addFoul(
    int team,
    Player player,
    FoulType type, {
    bool countsForTeam = true,
  }) {
    if (finished ||
        isExcluded(player.id) ||
        !teams[team].players.contains(player)) {
      return false;
    }
    _checkpoint();
    fouls.add(
      Foul(
        id: _nextId++,
        team: team,
        playerId: player.id,
        period: period,
        type: type,
        clockMs: remainingMs,
        countsForTeam: countsForTeam,
      ),
    );
    return true;
  }

  void removeFoul(int id) {
    if (finished || !fouls.any((f) => f.id == id)) return;
    _checkpoint();
    fouls.removeWhere((f) => f.id == id);
  }

  bool removeLatestFoul(int team, String playerId, FoulType type) {
    if (finished) return false;
    final entries = fouls.where(
      (f) => f.team == team && f.playerId == playerId && f.type == type,
    );
    if (entries.isEmpty) return false;
    removeFoul(entries.last.id);
    return true;
  }

  /// Preserve elapsed play, including old saves whose clock exceeded duration.
  bool configure({
    required int periods,
    required int minutes,
    required int overtime,
  }) {
    if (running ||
        finished ||
        periods < 1 ||
        periods > 12 ||
        minutes < 1 ||
        minutes > 99 ||
        overtime < 1 ||
        overtime > 30) {
      return false;
    }
    if (isOvertime ? periods != periodCount : periods < period) return false;
    final elapsedPlay = max(0, periodDurationMs - remainingMs);
    periodCount = periods;
    quarterMinutes = minutes;
    overtimeMinutes = overtime;
    remainingMs = (periodDurationMs - elapsedPlay).clamp(0, 5999000);
    return true;
  }

  void undo() {
    if (!canUndo) return;
    final previous = _undo.removeLast();
    final scores = previous['scores'] as List;
    for (var t = 0; t < teams.length; t++) {
      teams[t].score = scores[t] as int;
    }
    fouls = (previous['fouls'] as List)
        .map((f) => Foul.fromJson(Map<String, dynamic>.from(f)))
        .toList();
  }

  bool elapse(int milliseconds) {
    if (!running || finished || milliseconds <= 0) return false;
    final gameBefore = remainingMs;
    if (shotRunning) {
      final shotBefore = shotRemainingMs;
      shotRemainingMs = max(0, shotRemainingMs - min(milliseconds, gameBefore));
      // At a simultaneous expiry the period signal takes precedence.
      if (shotRemainingMs == 0 && shotBefore < gameBefore) shotExpired = true;
    }
    remainingMs = max(0, remainingMs - milliseconds);
    if (remainingMs == 0) {
      running = false;
      return true;
    }
    return false;
  }

  void setClock(int milliseconds) {
    if (running || finished) return;
    remainingMs = milliseconds.clamp(0, 99 * 60000 + 59000);
  }

  void resetShotClock(int seconds) {
    if (finished || (seconds != 14 && seconds != 24)) return;
    shotRemainingMs = seconds * 1000;
    shotHeld = false;
    shotExpired = false;
    // A fresh possession longer than the remaining period needs no display.
    shotEnabled = remainingMs >= shotRemainingMs;
  }

  void holdShotClock() {
    if (finished || !shotEnabled || shotRemainingMs == 0) return;
    shotHeld = !shotHeld;
  }

  void disableShotClock() {
    if (finished) return;
    shotEnabled = false;
    shotExpired = false;
  }

  void setShotClock(int milliseconds) {
    if (finished || running) return;
    shotRemainingMs = milliseconds.clamp(0, 24000);
    shotEnabled = true;
    shotHeld = false;
    shotExpired = false;
  }

  bool nextPeriod() {
    if (running ||
        finished ||
        remainingMs != 0 ||
        (period >= periodCount && !tied)) {
      return false;
    }
    period++;
    remainingMs = periodDurationMs;
    resetShotClock(24);
    _undo.clear();
    return true;
  }

  void finish() {
    running = false;
    finished = true;
    _undo.clear();
  }

  void newGame({bool keepTeams = true}) {
    if (!keepTeams) teams = Game().teams;
    for (final t in teams) {
      t.score = 0;
    }
    fouls.clear();
    period = 1;
    remainingMs = quarterMinutes * 60000;
    running = false;
    finished = false;
    resetShotClock(24);
    _undo.clear();
    _nextId = 1;
  }

  bool replaceTeam(int slot, Team template) {
    if (running || finished || slot < 0 || slot > 1) return false;
    teams[slot] = Team(
      name: template.name,
      players: [
        for (var i = 0; i < template.players.length; i++)
          Player(
            id: '$slot-$i',
            number: template.players[i].number,
            name: template.players[i].name,
          ),
      ],
    );
    fouls.removeWhere((f) => f.team == slot);
    // Old undo snapshots must not restore the replaced team's match statistics.
    _undo.clear();
    return true;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'teams': teams.map((t) => t.toJson()).toList(),
    'fouls': fouls.map((f) => f.toJson()).toList(),
    'period': period,
    'periodCount': periodCount,
    'quarterMinutes': quarterMinutes,
    'overtimeMinutes': overtimeMinutes,
    'remainingMs': remainingMs,
    'shotRemainingMs': shotRemainingMs,
    'shotEnabled': shotEnabled,
    'shotHeld': shotHeld,
    'shotExpired': shotExpired,
    'finished': finished,
    'nextId': _nextId,
    'undo': _undo,
  };

  factory Game.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Versión desconocida');
    }
    final game = Game()
      ..teams = (json['teams'] as List)
          .map((t) => Team.fromJson(Map<String, dynamic>.from(t)))
          .toList()
      ..fouls = (json['fouls'] as List)
          .map((f) => Foul.fromJson(Map<String, dynamic>.from(f)))
          .toList()
      ..period = json['period'] as int
      ..periodCount = (json['periodCount'] as int?) ?? 4
      ..quarterMinutes = json['quarterMinutes'] as int
      ..overtimeMinutes = json['overtimeMinutes'] as int
      ..remainingMs = json['remainingMs'] as int
      ..shotRemainingMs = (json['shotRemainingMs'] as int?) ?? 24000
      ..shotEnabled = (json['shotEnabled'] as bool?) ?? true
      ..shotHeld = (json['shotHeld'] as bool?) ?? false
      ..shotExpired = (json['shotExpired'] as bool?) ?? false
      ..finished = json['finished'] as bool
      .._nextId = json['nextId'] as int;
    if (game.teams.length != 2 ||
        game.period < 1 ||
        game.periodCount < 1 ||
        game.periodCount > 12 ||
        game.quarterMinutes < 1 ||
        game.quarterMinutes > 99 ||
        game.overtimeMinutes < 1 ||
        game.overtimeMinutes > 30 ||
        game.remainingMs < 0 ||
        game.shotRemainingMs < 0 ||
        game.shotRemainingMs > 24000) {
      throw const FormatException('Partido inválido');
    }
    game._undo.addAll(
      (json['undo'] as List? ?? []).map((a) => Map<String, dynamic>.from(a)),
    );
    // Interrupted matches always reopen paused.
    return game;
  }
}

String shotClockText(int milliseconds) {
  if (milliseconds > 0 && milliseconds < 5000) {
    final deciseconds = (milliseconds / 100).ceil();
    return '${deciseconds ~/ 10}.${deciseconds % 10}';
  }
  return (milliseconds / 1000).ceil().toString().padLeft(2, '0');
}

String clockText(int milliseconds, {bool tenths = false}) {
  final seconds = (milliseconds / 1000).ceil();
  if (tenths && milliseconds > 0 && milliseconds < 60000) {
    final deciseconds = (milliseconds / 100).ceil();
    return '${(deciseconds ~/ 10).toString().padLeft(2, '0')}.${deciseconds % 10}';
  }
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}
