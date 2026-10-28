import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'game.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.game, required this.onSave});
  final Game game;
  final Future<bool> Function() onSave;
  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late int periods = widget.game.periodCount;
  late int minutes = widget.game.quarterMinutes;
  late int overtime = widget.game.overtimeMinutes;
  late String local = widget.game.teams[0].name;
  late String visitor = widget.game.teams[1].name;
  bool saving = false;
  String? error;

  Future<void> _rename(bool home) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => NameDialog(
        title: home ? 'Nombre del equipo local' : 'Nombre del visitante',
        value: home ? local : visitor,
        maxLength: 22,
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        if (home) {
          local = result;
        } else {
          visitor = result;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      error = null;
    });
    final accepted = widget.game.configure(
      periods: periods,
      minutes: minutes,
      overtime: overtime,
    );
    if (!accepted) {
      setState(() {
        saving = false;
        error = 'No se puede aplicar este formato al período actual.';
      });
      return;
    }
    widget.game.teams[0].name = local;
    widget.game.teams[1].name = visitor;
    final stored = await widget.onSave();
    if (!mounted) return;
    if (stored) {
      Navigator.pop(context);
    } else {
      setState(() {
        saving = false;
        error = 'No se pudo guardar. Vuelve a intentarlo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final minimumPeriods = game.isOvertime ? game.periodCount : game.period;
    final maximumPeriods = game.isOvertime ? game.periodCount : 12;
    final names = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _nameButton('LOCAL', local, () => _rename(true)),
        const SizedBox(height: 6),
        _nameButton('VISITANTE', visitor, () => _rename(false)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              key: const ValueKey('format-fiba'),
              label: const Text('4 × 10 min'),
              selected: periods == 4 && minutes == 10,
              onSelected: saving || minimumPeriods > 4 || maximumPeriods < 4
                  ? null
                  : (_) => setState(() {
                      periods = 4;
                      minutes = 10;
                    }),
            ),
            ChoiceChip(
              key: const ValueKey('format-halves'),
              label: const Text('2 × 10 min'),
              selected: periods == 2 && minutes == 10,
              onSelected: saving || minimumPeriods > 2 || maximumPeriods < 2
                  ? null
                  : (_) => setState(() {
                      periods = 2;
                      minutes = 10;
                    }),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          periods == 4 && minutes == 10
              ? 'Formato FIBA'
              : 'Formato personalizado · faltas de equipo por tiempo',
          style: const TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
    final numbers = Column(
      children: [
        NumberStepper(
          id: 'period-count',
          label: 'Cantidad de tiempos',
          value: '$periods',
          onMinus: saving || periods <= minimumPeriods
              ? null
              : () => setState(() => periods--),
          onPlus: saving || periods >= maximumPeriods
              ? null
              : () => setState(() => periods++),
        ),
        const SizedBox(height: 8),
        NumberStepper(
          id: 'period-minutes',
          label: 'Minutos por tiempo',
          value: '$minutes',
          onMinus: saving || minutes <= 1
              ? null
              : () => setState(() => minutes--),
          onPlus: saving || minutes >= 99
              ? null
              : () => setState(() => minutes++),
        ),
        const SizedBox(height: 8),
        NumberStepper(
          id: 'overtime-minutes',
          label: 'Minutos de prórroga',
          value: '$overtime',
          onMinus: saving || overtime <= 1
              ? null
              : () => setState(() => overtime--),
          onPlus: saving || overtime >= 30
              ? null
              : () => setState(() => overtime++),
        ),
      ],
    );
    return MatchPanel(
      title: 'Configurar partido',
      subtitle: 'Ajusta con + / −. El teclado solo se usa al editar nombres.',
      actions: Row(
        children: [
          Expanded(
            child: Text(
              '$periods × $minutes min',
              style: const TextStyle(color: amber, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const ValueKey('save-settings'),
            onPressed: saving ? null : _save,
            child: Text(saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (_, constraints) => PanelScroll(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (constraints.maxWidth >= 640)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: names),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: numbers),
                  ],
                )
              else ...[
                names,
                const SizedBox(height: 12),
                numbers,
              ],
              if (game.isOvertime)
                const Text(
                  'La cantidad de tiempos no se cambia durante una prórroga.',
                  style: TextStyle(color: amber, fontSize: 12),
                ),
              if (error != null)
                Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nameButton(String label, String value, VoidCallback edit) =>
      OutlinedButton(
        onPressed: saving ? null : edit,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 18),
          ],
        ),
      );
}

class PlayerFoulTile extends StatelessWidget {
  const PlayerFoulTile({
    super.key,
    required this.game,
    required this.team,
    required this.player,
    required this.type,
    required this.onPlus,
    required this.onMinus,
    this.onEdit,
    this.highlight = false,
  });
  final Game game;
  final int team;
  final Player player;
  final FoulType type;
  final VoidCallback? onPlus;
  final VoidCallback? onMinus;
  final VoidCallback? onEdit;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final entries = game.playerFouls(player.id);
    final count = entries.where((f) => f.type == type).length;
    final excluded = game.isExcluded(player.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? teamColors[team] : const Color(0xFF243149),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '#${player.number}',
                style: TextStyle(
                  color: teamColors[team],
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name.isEmpty
                      ? 'Jugador ${player.number}'
                      : player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  excluded
                      ? (game.isDisqualified(player.id)
                            ? 'DESCALIFICADO'
                            : 'EXCLUIDO · 5 FALTAS')
                      : '${type.label}: $count',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: excluded ? teamColors[1] : muted,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Editar ${player.label}',
              onPressed: onEdit,
              constraints: const BoxConstraints.tightFor(width: 36, height: 44),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.edit_outlined, size: 16, color: muted),
            ),
          IconButton(
            key: ValueKey('foul-minus-${player.id}'),
            tooltip: 'Quitar ${type.label.toLowerCase()} a ${player.label}',
            onPressed: onMinus,
            color: muted,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.remove_circle_outline, size: 27),
          ),
          SizedBox(
            width: 32,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${entries.length}/5',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: excluded ? teamColors[1] : Colors.white,
                ),
              ),
            ),
          ),
          IconButton(
            key: ValueKey('foul-plus-${player.id}'),
            tooltip: 'Sumar ${type.label.toLowerCase()} a ${player.label}',
            onPressed: onPlus,
            color: teamColors[team],
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.add_circle, size: 29),
          ),
        ],
      ),
    );
  }
}

class FoulsPanel extends StatefulWidget {
  const FoulsPanel({
    super.key,
    required this.game,
    required this.team,
    required this.onChanged,
    this.initial,
  });
  final Game game;
  final int team;
  final VoidCallback onChanged;
  final Player? initial;
  @override
  State<FoulsPanel> createState() => _FoulsPanelState();
}

class _FoulsPanelState extends State<FoulsPanel> {
  FoulType type = FoulType.personal;
  bool onCourt = true;
  int edits = 0;
  String? lastEditedId;
  String status = 'Toca + para anotar y − para corregir. Guardado automático.';
  final scroll = ScrollController();
  Game get game => widget.game;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void _edit(Player player, bool adding) {
    final changed = adding
        ? game.addFoul(widget.team, player, type, countsForTeam: onCourt)
        : game.removeLatestFoul(widget.team, player.id, type);
    if (!changed) return;
    HapticFeedback.selectionClick();
    widget.onChanged();
    setState(() {
      edits++;
      lastEditedId = player.id;
      status = game.isExcluded(player.id)
          ? '${player.label}: ${game.isDisqualified(player.id) ? 'descalificado' : 'excluido por 5 faltas'}'
          : '${type.label} ${adding ? 'anotada a' : 'retirada de'} ${player.label} · Guardado';
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final players = game.playersByFouls(widget.team);
    return MatchPanel(
      title: 'Faltas · ${game.teams[widget.team].name}',
      subtitle:
          '${game.periodLabel} · ${game.teamFouls(widget.team)} de equipo · Más faltas primero',
      actions: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF67DDB2),
            size: 17,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 11),
            ),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: edits > 0 && game.canUndo
                ? () {
                    game.undo();
                    widget.onChanged();
                    setState(() {
                      edits--;
                      status = 'Último cambio deshecho · Guardado';
                    });
                    if (scroll.hasClients) scroll.jumpTo(0);
                  }
                : null,
            icon: const Icon(Icons.undo, size: 17),
            label: const Text('Deshacer', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<FoulType>(
                    key: const ValueKey('foul-type'),
                    initialValue: type,
                    isExpanded: true,
                    dropdownColor: surface,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de falta',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    items: FoulType.values
                        .map(
                          (f) => DropdownMenuItem(
                            value: f,
                            child: Text(
                              '${f.code} · ${f.label}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          type = value;
                          if (type == FoulType.personal) onCourt = true;
                        });
                      }
                    },
                  ),
                ),
                if (type != FoulType.personal) ...[
                  const SizedBox(width: 10),
                  const Text('En cancha', style: TextStyle(fontSize: 11)),
                  Switch(
                    value: onCourt,
                    onChanged: (value) => setState(() => onCourt = value),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) {
                final columns = constraints.maxWidth >= 680 ? 2 : 1;
                final rows = (constraints.maxHeight / 60).floor().clamp(1, 6);
                final rowHeight =
                    ((constraints.maxHeight - 8 - (rows - 1) * 4) / rows)
                        .clamp(54.0, 100.0)
                        .toDouble();
                return Scrollbar(
                  controller: scroll,
                  thumbVisibility: true,
                  child: GridView.builder(
                    controller: scroll,
                    findChildIndexCallback: (key) {
                      final index = players.indexWhere(
                        (p) => ValueKey(p.id) == key,
                      );
                      return index < 0 ? null : index;
                    },
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: rowHeight,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: players.length,
                    itemBuilder: (_, index) {
                      final player = players[index];
                      return PlayerFoulTile(
                        key: ValueKey(player.id),
                        game: game,
                        team: widget.team,
                        player: player,
                        type: type,
                        highlight: lastEditedId == null
                            ? player == widget.initial
                            : player.id == lastEditedId,
                        onPlus: game.isExcluded(player.id) || game.finished
                            ? null
                            : () => _edit(player, true),
                        onMinus:
                            game.finished ||
                                !game
                                    .playerFouls(player.id)
                                    .any((f) => f.type == type)
                            ? null
                            : () => _edit(player, false),
                      );
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
