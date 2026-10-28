import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'match_panels.dart';
import 'app_credits.dart';
import 'player_editor.dart';
import 'saved_teams_panel.dart';

const native = MethodChannel('pe.marti.score_basquet/device');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAudioCredit();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  Game game = Game();
  String? warning;
  try {
    final stored = await native.invokeMethod<String>('load');
    if (stored != null) game = Game.fromJson(jsonDecode(stored));
  } catch (_) {
    warning =
        'No se pudo recuperar el partido guardado. Revisa el marcador antes de empezar.';
  }
  runApp(ScoreApp(initialGame: game, initialWarning: warning));
}

class ScoreApp extends StatelessWidget {
  const ScoreApp({super.key, required this.initialGame, this.initialWarning});
  final Game initialGame;
  final String? initialWarning;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'FISCORE',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: amber,
        brightness: Brightness.dark,
        surface: surface,
        primary: amber,
      ),
      useMaterial3: true,
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      fontFamily: 'sans-serif',
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    ),
    home: MatchScreen(game: initialGame, initialWarning: initialWarning),
  );
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, required this.game, this.initialWarning});
  final Game game;
  final String? initialWarning;
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with WidgetsBindingObserver {
  Game get game => widget.game;
  final stopwatch = Stopwatch();
  Timer? ticker;
  int lastElapsed = 0;
  int lastSave = 0;
  int page = 0;
  int rosterTeam = 0;
  final rosterScroll = List.generate(2, (_) => ScrollController());
  bool saveFailed = false;
  final List<bool> correctingPoints = [false, false];
  Future<void> saveQueue = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
    if (widget.initialWarning != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _message(widget.initialWarning!),
      );
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    for (final controller in rosterScroll) {
      controller.dispose();
    }
    stopwatch.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (game.running) {
        _tick();
        game.running = false;
        stopwatch.stop();
        if (mounted) setState(() {});
      }
      _persist();
    }
  }

  void _tick() {
    if (!mounted || !game.running) return;
    final elapsed = stopwatch.elapsedMilliseconds;
    final shotWasExpired = game.shotExpired;
    final ended = game.elapse(elapsed - lastElapsed);
    lastElapsed = elapsed;
    setState(() {});
    if (ended) {
      stopwatch.stop();
      unawaited(_horn());
      _persist();
      _message(
        'Fin del ${game.isOvertime ? 'tiempo extra' : game.periodNoun}. Reloj en 00:00.',
      );
    } else if (!shotWasExpired && game.shotExpired) {
      unawaited(_horn(possession: true));
      _persist();
      _message(
        'Posesión agotada. Pausa el partido si corresponde la infracción; el árbitro decide.',
      );
    } else if (elapsed - lastSave >= 1000) {
      lastSave = elapsed;
      _persist();
    }
  }

  Future<void> _horn({bool possession = false}) async {
    try {
      await native.invokeMethod<void>(possession ? 'shotHorn' : 'horn');
    } catch (_) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  void _persist() {
    final snapshot = jsonEncode(game.toJson());
    // Serialize saves to prevent an older write from replacing a newer one.
    saveQueue = saveQueue.then((_) async {
      try {
        await native.invokeMethod<void>('save', snapshot);
        if (saveFailed && mounted) setState(() => saveFailed = false);
      } catch (_) {
        if (!saveFailed && mounted) {
          setState(() => saveFailed = true);
          _message(
            'No se pudo guardar. Mantén abierta la app y revisa el almacenamiento.',
          );
        }
      }
    });
  }

  void _change(VoidCallback action) {
    setState(action);
    _persist();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _toggleClock() {
    if (game.finished || game.remainingMs == 0) return;
    if (game.running) {
      _tick();
      game.running = false;
      stopwatch.stop();
    } else {
      stopwatch.reset();
      lastElapsed = 0;
      lastSave = 0;
      game.running = true;
      stopwatch.start();
    }
    _change(() {});
  }

  void _resetShot(int seconds) {
    // Account for elapsed time before changing only the possession clock.
    _tick();
    _change(() => game.resetShotClock(seconds));
    if (!game.shotEnabled) {
      _message(
        'Posesión sin cuenta: queda menos tiempo de partido que $seconds segundos.',
      );
    }
  }

  void _holdShot() {
    _tick();
    _change(game.holdShotClock);
  }

  Future<void> _editShot() async {
    if (game.finished) return;
    if (game.running) _toggleClock();
    var tenths = (game.shotRemainingMs / 100).round();
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => MatchPanel(
          title: 'Ajustar posesión',
          maxWidth: 640,
          maxHeight: 340,
          actions: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, tenths * 100),
                child: const Text('Guardar'),
              ),
            ],
          ),
          child: PanelScroll(
            child: Column(
              children: [
                Text(
                  shotClockText(tenths * 100),
                  style: const TextStyle(
                    color: amber,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                NumberStepper(
                  id: 'shot-seconds',
                  label: 'Segundos',
                  value: '${tenths ~/ 10}',
                  onMinus: tenths < 10
                      ? null
                      : () => update(() => tenths -= 10),
                  onPlus: tenths >= 240
                      ? null
                      : () =>
                            update(() => tenths = (tenths + 10).clamp(0, 240)),
                ),
                const SizedBox(height: 8),
                NumberStepper(
                  id: 'shot-tenths',
                  label: 'Décimas',
                  value: '${tenths % 10}',
                  onMinus: tenths <= 0 ? null : () => update(() => tenths--),
                  onPlus: tenths >= 240 ? null : () => update(() => tenths++),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (value != null && mounted) _change(() => game.setShotClock(value));
  }

  Future<bool> _confirm(String title, String body, String label) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(label),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _nextPeriod() async {
    if (game.running || game.remainingMs != 0 || game.finished) return;
    if (game.period >= game.periodCount && !game.tied) {
      await _finish();
      return;
    }
    final next = game.period < game.periodCount
        ? '${game.periodNoun} ${game.period + 1}'
        : 'prórroga ${game.period - game.periodCount + 1}';
    if (await _confirm(
      'Comenzar $next',
      game.period < game.periodCount
          ? 'Se conserva el marcador y las faltas personales. Las faltas de equipo del nuevo cuarto empiezan en cero.'
          : 'Se conserva el marcador, las faltas personales y las faltas de equipo del último tiempo reglamentario.',
      'Preparar período',
    )) {
      _change(() {
        game.nextPeriod();
      });
    }
  }

  Future<void> _finish() async {
    if (await _confirm(
      'Finalizar partido',
      '${game.teams[0].name} ${game.teams[0].score} — ${game.teams[1].score} ${game.teams[1].name}\n'
          'Se guardará este resultado y se bloquearán las anotaciones.',
      'Finalizar',
    )) {
      stopwatch.stop();
      _change(game.finish);
    }
  }

  Future<void> _newGame() async {
    if (await _confirm(
      'Nuevo partido',
      'Se borrarán el marcador, el reloj y todas las faltas del partido actual. Se conservarán los nombres y las plantillas.',
      'Nuevo partido',
    )) {
      stopwatch.stop();
      _change(() {
        game.newGame();
        correctingPoints.fillRange(0, correctingPoints.length, false);
        page = 0;
      });
    }
  }

  Future<void> _editClock() async {
    if (game.running || game.finished) return;
    var seconds = (game.remainingMs / 1000).ceil();
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => MatchPanel(
          title: 'Ajustar reloj',
          maxWidth: 640,
          maxHeight: 340,
          actions: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, seconds * 1000),
                child: const Text('Guardar'),
              ),
            ],
          ),
          child: PanelScroll(
            child: Column(
              children: [
                Text(
                  clockText(seconds * 1000),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 12),
                NumberStepper(
                  id: 'clock-minutes',
                  label: 'Minutos',
                  value: '${seconds ~/ 60}',
                  onMinus: seconds < 60
                      ? null
                      : () => update(() => seconds -= 60),
                  onPlus: seconds >= 5940
                      ? null
                      : () => update(
                          () => seconds = (seconds + 60).clamp(0, 5999),
                        ),
                ),
                const SizedBox(height: 8),
                NumberStepper(
                  id: 'clock-seconds',
                  label: 'Segundos',
                  value: '${seconds % 60}',
                  onMinus: seconds <= 0 ? null : () => update(() => seconds--),
                  onPlus: seconds >= 5999
                      ? null
                      : () => update(() => seconds++),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (value != null && mounted) _change(() => game.setClock(value));
  }

  Future<void> _settings() async {
    if (game.running) {
      _message('Pausa el reloj para configurar el partido.');
      return;
    }
    if (game.finished) return;
    await showDialog<void>(
      context: context,
      builder: (_) => SettingsPanel(
        game: game,
        onSave: () async {
          if (!mounted) return false;
          _change(() {});
          await saveQueue;
          return !saveFailed;
        },
      ),
    );
  }

  Future<void> _editPlayer(int team, Player player) async {
    await showDialog<void>(
      context: context,
      builder: (_) => PlayerEditorPanel(
        game: game,
        team: team,
        player: player,
        onSave: () async {
          if (!mounted) return false;
          _change(() {});
          await saveQueue;
          return !saveFailed;
        },
      ),
    );
  }

  Future<void> _savedTeams() async {
    if (game.running) _toggleClock();
    await showDialog<void>(
      context: context,
      builder: (_) => SavedTeamsPanel(
        currentTeams: game.teams,
        read: () => native.invokeMethod<String>('loadTeams'),
        store: (value) => native.invokeMethod<void>('saveTeams', value),
        use: (team, slot) async {
          final needsNewGame = game.finished;
          if (needsNewGame ||
              game.teams[slot].score != 0 ||
              game.fouls.any((f) => f.team == slot)) {
            final confirmed = await _confirm(
              needsNewGame
                  ? 'Nuevo partido con ${team.name}'
                  : 'Cargar ${team.name}',
              needsNewGame
                  ? 'Se iniciará otro partido en cero, con ${team.name} como ${slot == 0 ? 'local' : 'visitante'}.'
                  : 'Se reemplazarán los jugadores, puntos y faltas del equipo ${slot == 0 ? 'local' : 'visitante'}. El otro equipo y el reloj se conservan.',
              needsNewGame ? 'Nuevo partido' : 'Cargar equipo',
            );
            if (!mounted || !confirmed) return false;
          }
          var replaced = false;
          _change(() {
            if (needsNewGame) {
              game.newGame();
              correctingPoints.fillRange(0, 2, false);
            }
            replaced = game.replaceTeam(slot, team.forMatch(slot));
            if (replaced) {
              correctingPoints[slot] = false;
              page = 1;
              rosterTeam = slot;
            }
          });
          await saveQueue;
          return replaced && !saveFailed;
        },
      ),
    );
  }

  Future<void> _foulDialog(int team, {Player? initial}) async {
    if (game.finished) return;
    if (game.running) _toggleClock();
    await showDialog<void>(
      context: context,
      builder: (_) => FoulsPanel(
        game: game,
        team: team,
        initial: initial,
        onChanged: () {
          if (mounted) _change(() {});
        },
      ),
    );
  }

  Future<void> _credits() async {
    String? version;
    try {
      version = await native.invokeMethod<String>('appVersion');
    } catch (_) {
      // The creator and contact remain available if version lookup fails.
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => CreditsPanel(version: version),
    );
  }

  void _rules() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Faltas · criterio FIBA'),
      content: const SingleChildScrollView(
        child: SizedBox(
          width: 540,
          child: Text(
            '• El jugador acumula sus faltas durante todo el partido y queda excluido al llegar a 5.\n\n'
            '• Dos técnicas, dos antideportivas, una técnica y una antideportiva, o una descalificante implican descalificación.\n\n'
            '• Tras 4 faltas de equipo en un cuarto, el equipo queda en penalización. Desde la quinta, las personales defensivas que correspondan se penalizan con tiros libres. Las faltas de control de equipo tienen otra sanción.\n\n'
            '• Las faltas de equipo se reinician en los cuartos 2, 3 y 4. Las prórrogas acumulan con el cuarto período.\n\n'
            '• Para técnicas u otras faltas de un sustituto, desactiva «Jugador en cancha». Las técnicas de entrenadores y banco no se registran aquí.\n\n'
            'El árbitro decide la sanción. La aplicación lleva los conteos y no concede puntos ni tiros libres automáticamente.\n\n'
            'Referencia: Reglas Oficiales FIBA 2024, artículos 8, 36, 37, 40 y 41.',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !game.running,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && game.running) _toggleClock();
    },
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(child: page == 1 ? _players() : _board()),
          ],
        ),
      ),
    ),
  );

  Widget _header() => LayoutBuilder(
    builder: (context, constraints) => Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF243149))),
      ),
      child: Row(
        children: [
          const Icon(Icons.sports_basketball, color: amber, size: 24),
          if (constraints.maxWidth >= 720)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'FISCORE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ),
          const SizedBox(width: 8),
          ...List.generate(
            2,
            (i) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TextButton(
                  onPressed: () => setState(() => page = i),
                  style: TextButton.styleFrom(
                    foregroundColor: page == i ? amber : muted,
                    backgroundColor: page == i
                        ? amber.withValues(alpha: .10)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      ['Marcador', 'Jugadores'][i],
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('saved-teams-button'),
            tooltip: 'Mis equipos',
            onPressed: _savedTeams,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.groups_outlined, size: 23),
          ),
          IconButton(
            tooltip: 'Configurar partido',
            onPressed: game.finished ? null : _settings,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.tune, size: 22),
          ),
          IconButton(
            key: const ValueKey('credits-button'),
            tooltip: 'Créditos y contacto',
            onPressed: _credits,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.help_outline, size: 23),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            onSelected: (value) {
              if (value == 'new') _newGame();
              if (value == 'finish') _finish();
              if (value == 'rules') _rules();
              if (value == 'sound') _horn();
              if (value == 'teams') _savedTeams();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'teams', child: Text('Mis equipos')),
              PopupMenuItem(
                value: 'sound',
                enabled: !game.running,
                child: const Text('Probar chicharra'),
              ),
              const PopupMenuItem(
                value: 'rules',
                child: Text('Reglas de faltas'),
              ),
              if (!game.finished)
                const PopupMenuItem(
                  value: 'finish',
                  child: Text('Finalizar partido'),
                ),
              const PopupMenuItem(value: 'new', child: Text('Nuevo partido')),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _board() => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth < 560) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              SizedBox(
                height: 280,
                child: Row(
                  children: [
                    Expanded(child: _teamCard(0, compact: false)),
                    const SizedBox(width: 8),
                    Expanded(child: _teamCard(1, compact: false)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(height: 280, child: _clockPanel(compact: false)),
            ],
          ),
        );
      }
      final compact = box.maxHeight < 270;
      final board = Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: _teamCard(0, compact: compact)),
            const SizedBox(width: 8),
            Expanded(flex: 4, child: _clockPanel(compact: compact)),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: _teamCard(1, compact: compact)),
          ],
        ),
      );
      return box.maxHeight < 240
          ? SingleChildScrollView(child: SizedBox(height: 260, child: board))
          : board;
    },
  );

  Widget _teamCard(int team, {required bool compact}) {
    final color = teamColors[team];
    final count = game.teamFouls(team);
    final correcting = correctingPoints[team] && !game.finished;
    final actionColor = correcting ? amber : color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 7),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(top: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        children: [
          if (!compact)
            Text(
              team == 0 ? 'EQUIPO LOCAL' : 'EQUIPO VISITANTE',
              style: TextStyle(color: color, letterSpacing: 1, fontSize: 10),
            ),
          Text(
            game.teams[team].name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  game.teams[team].score.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 120,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: color,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: Row(
              children: [1, 2, 3]
                  .map(
                    (points) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 44),
                            backgroundColor: actionColor.withValues(alpha: .14),
                            foregroundColor: actionColor,
                          ),
                          onPressed:
                              game.finished ||
                                  (correcting &&
                                      game.teams[team].score < points)
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  _change(
                                    () => game.changeScore(
                                      team,
                                      correcting ? -points : points,
                                    ),
                                  );
                                },
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${correcting ? '−' : '+'}$points',
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Corregir',
                        style: TextStyle(
                          color: correcting ? amber : muted,
                          fontSize: 11,
                        ),
                      ),
                      if (correcting)
                        const Text(
                          'RESTAR',
                          style: TextStyle(
                            color: amber,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Corregir puntos de ${game.teams[team].name}',
                  child: SizedBox(
                    width: 48,
                    child: Switch(
                      key: ValueKey('correct-points-$team'),
                      value: correcting,
                      activeThumbColor: amber,
                      activeTrackColor: amber.withValues(alpha: .3),
                      onChanged: game.finished
                          ? null
                          : (value) {
                              HapticFeedback.selectionClick();
                              setState(() => correctingPoints[team] = value);
                            },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 4, color: Color(0xFF2A3549)),
          SizedBox(
            height: 26,
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'FALTAS',
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                        const SizedBox(width: 6),
                        ...List.generate(
                          5,
                          (i) => Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: count > i
                                    ? (count >= 4 ? amber : color)
                                    : const Color(0xFF2B374C),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (!compact)
            SizedBox(
              height: 15,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  count >= 4
                      ? 'EQUIPO EN PENALIZACIÓN'
                      : game.isOvertime
                      ? 'ACUMULADAS DEL ÚLTIMO TIEMPO'
                      : 'DE ESTE ${game.periodNoun.toUpperCase()}',
                  style: TextStyle(
                    color: count >= 4 ? amber : muted,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
          SizedBox(
            height: 40,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: game.finished ? null : () => _foulDialog(team),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                minimumSize: const Size(40, 40),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              icon: const Icon(Icons.groups_outlined, size: 17),
              label: const Text(
                'Faltas + / −',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clockPanel({required bool compact}) => Column(
    children: [
      SizedBox(
        height: compact ? 20 : 24,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            game.finished ? 'RESULTADO FINAL' : game.periodLabel,
            style: const TextStyle(
              color: amber,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              fontSize: 13,
            ),
          ),
        ),
      ),
      Expanded(
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              clockText(game.remainingMs, tenths: true),
              style: TextStyle(
                color: game.remainingMs == 0
                    ? const Color(0xFFFF7C7C)
                    : Colors.white,
                fontSize: 92,
                height: 1.05,
                fontWeight: FontWeight.w300,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
      SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(40, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: game.finished
                    ? _newGame
                    : game.remainingMs == 0
                    ? _nextPeriod
                    : _toggleClock,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    game.finished
                        ? 'NUEVO PARTIDO'
                        : game.remainingMs == 0
                        ? (game.period < game.periodCount
                              ? 'SIGUIENTE TIEMPO'
                              : game.tied
                              ? 'PRÓRROGA'
                              : 'FINALIZAR')
                        : game.running
                        ? 'PAUSAR'
                        : 'INICIAR',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Ajustar reloj',
              onPressed: game.running || game.finished ? null : _editClock,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.timer_outlined, size: 22),
            ),
            IconButton(
              tooltip: 'Deshacer',
              onPressed: game.canUndo ? () => _change(game.undo) : null,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.undo, size: 22),
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      _shotPanel(compact: compact),
    ],
  );

  Widget _shotPanel({required bool compact}) {
    final color = game.shotExpired ? const Color(0xFFFF7C7C) : amber;
    final status = !game.shotEnabled
        ? 'SIN CUENTA'
        : game.shotExpired
        ? 'AGOTADA'
        : game.shotRunning
        ? 'EN MARCHA'
        : 'EN PAUSA';
    return Container(
      height: compact ? 96 : 106,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: game.shotExpired ? .8 : .25),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'POSESIÓN',
                          style: TextStyle(
                            color: muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          status,
                          style: TextStyle(color: color, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Semantics(
                    label: 'Reloj de posesión',
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        game.shotEnabled
                            ? shotClockText(game.shotRemainingMs)
                            : '—',
                        style: TextStyle(
                          color: color,
                          fontSize: compact ? 32 : 40,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: IconButton(
                    tooltip: game.shotHeld
                        ? 'Reanudar posesión'
                        : 'Pausar posesión',
                    onPressed:
                        game.finished ||
                            !game.shotEnabled ||
                            game.shotRemainingMs == 0
                        ? null
                        : _holdShot,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      game.shotHeld
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 23,
                    ),
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: PopupMenuButton<String>(
                    tooltip: 'Opciones de posesión',
                    enabled: !game.finished,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      if (value == 'edit') _editShot();
                      if (value == 'off') {
                        _tick();
                        _change(game.disableShotClock);
                      }
                      if (value == 'help') _shotRules();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Ajustar posesión'),
                      ),
                      const PopupMenuItem(
                        value: 'off',
                        child: Text('Apagar cuenta de posesión'),
                      ),
                      const PopupMenuItem(
                        value: 'help',
                        child: Text('Ayuda: 24 y 14 segundos'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: game.finished ? null : () => _resetShot(24),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                      backgroundColor: amber.withValues(alpha: .14),
                      foregroundColor: amber,
                    ),
                    child: const Text('24 s'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: game.finished ? null : () => _resetShot(14),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('14 s'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shotRules() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reloj de posesión · 24 / 14 s'),
      content: const SingleChildScrollView(
        child: SizedBox(
          width: 540,
          child: Text(
            '24 s: nueva posesión cuando corresponde un período completo.\n\n'
            '14 s: por ejemplo, cuando el mismo equipo recupera el balón después de que toque el aro; también en determinados saques en pista delantera.\n\n'
            'Una interrupción no siempre reinicia la cuenta. Conserva el tiempo si así lo indica el árbitro. Los reinicios 24/14 son manuales y no se hacen al sumar puntos ni anotar faltas.\n\n'
            'INICIAR / PAUSAR controla el partido y la posesión. El botón junto al contador permite detener solo la posesión, por ejemplo mientras el balón está en el aire después de tocar el aro.\n\n'
            'Si al reiniciar queda menos tiempo de partido que la cuenta elegida, el contador se apaga. También puedes apagarlo desde sus opciones.\n\n'
            'La señal de posesión es distinta de la del período. No se declara una infracción automáticamente: si el balón ya está en el aire puede continuar la jugada. Pausa el partido cuando corresponda.\n\n'
            'Referencia: FIBA 2024, artículos 29, 49 y 50.',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
  Widget _players() => LayoutBuilder(
    builder: (_, constraints) {
      if (constraints.maxWidth < 650) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: List.generate(
                  2,
                  (team) => Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => rosterTeam = team),
                      style: TextButton.styleFrom(
                        foregroundColor: rosterTeam == team
                            ? teamColors[team]
                            : muted,
                      ),
                      child: Text(
                        game.teams[team].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: _roster(rosterTeam)),
          ],
        );
      }
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(child: _roster(0)),
            const SizedBox(width: 10),
            Expanded(child: _roster(1)),
          ],
        ),
      );
    },
  );

  Widget _roster(int team) {
    final players = game.playersByFouls(team);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    game.teams[team].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: teamColors[team],
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${game.teamFouls(team)} de equipo',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              key: ValueKey('roster-$team'),
              controller: rosterScroll[team],
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              itemCount: players.length,
              findItemIndexCallback: (key) {
                final index = players.indexWhere((p) => ValueKey(p.id) == key);
                return index < 0 ? null : index;
              },
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final player = players[i];
                return SizedBox(
                  key: ValueKey(player.id),
                  height: 66,
                  child: PlayerFoulTile(
                    game: game,
                    team: team,
                    player: player,
                    type: FoulType.personal,
                    onEdit: game.finished
                        ? null
                        : () => _editPlayer(team, player),
                    onPlus: game.finished || game.isExcluded(player.id)
                        ? null
                        : () {
                            if (game.running) _toggleClock();
                            _change(
                              () =>
                                  game.addFoul(team, player, FoulType.personal),
                            );
                            rosterScroll[team].jumpTo(0);
                          },
                    onMinus:
                        game.finished ||
                            !game
                                .playerFouls(player.id)
                                .any((f) => f.type == FoulType.personal)
                        ? null
                        : () {
                            if (game.running) _toggleClock();
                            _change(
                              () => game.removeLatestFoul(
                                team,
                                player.id,
                                FoulType.personal,
                              ),
                            );
                            rosterScroll[team].jumpTo(0);
                          },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
