import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'game.dart';

class PlayerEditorPanel extends StatefulWidget {
  const PlayerEditorPanel({
    super.key,
    required this.game,
    required this.team,
    required this.player,
    required this.onSave,
  });
  final Game game;
  final int team;
  final Player player;
  final Future<bool> Function() onSave;
  @override
  State<PlayerEditorPanel> createState() => _PlayerEditorPanelState();
}

class _PlayerEditorPanelState extends State<PlayerEditorPanel> {
  late String number = widget.player.number;
  late String name = widget.player.name;
  bool fresh = true;
  bool saving = false;
  String? error;

  void _digit(String value) {
    HapticFeedback.selectionClick();
    setState(() {
      error = null;
      if (value == 'back') {
        if (number.isNotEmpty) number = number.substring(0, number.length - 1);
      } else if (value == '00') {
        number = '00';
      } else {
        number = fresh || number.length >= 2 ? value : '$number$value';
        if (number.length == 2 && number.startsWith('0') && number != '00') {
          number = number.substring(1);
        }
      }
      fresh = false;
    });
  }

  Future<void> _name() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          NameDialog(title: 'Nombre del jugador', value: name, maxLength: 28),
    );
    if (result != null && mounted) setState(() => name = result);
  }

  Future<void> _save() async {
    if (number.isEmpty) {
      setState(() => error = 'Escribe un dorsal.');
      return;
    }
    if (widget.game.teams[widget.team].players.any(
      (p) => p.id != widget.player.id && p.number == number,
    )) {
      setState(() => error = 'El dorsal $number ya pertenece a otro jugador.');
      return;
    }
    setState(() => saving = true);
    widget.player.number = number;
    widget.player.name = name;
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
  Widget build(BuildContext context) => MatchPanel(
    title: 'Jugador · ${widget.game.teams[widget.team].name}',
    subtitle: 'Toca los dígitos: para 88, pulsa 8 y 8.',
    maxWidth: 760,
    maxHeight: 370,
    actions: Row(
      children: [
        Expanded(
          child: Text(
            error ?? 'Dorsales: 0, 00 y 1–99',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: error == null ? muted : Colors.redAccent,
            ),
          ),
        ),
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          key: const ValueKey('save-player'),
          onPressed: saving ? null : _save,
          child: Text(saving ? 'Guardando…' : 'Guardar'),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (_, constraints) {
        final columns = constraints.maxHeight < 220 ? 4 : 3;
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: teamColors[widget.team].withValues(alpha: .5),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'DORSAL',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Text(
                    number.isEmpty ? '—' : '#$number',
                    key: const ValueKey('jersey-value'),
                    style: TextStyle(
                      color: teamColors[widget.team],
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('edit-player-name'),
              onPressed: saving ? null : _name,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                name.isEmpty ? 'Agregar nombre' : name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        );
        final keypad = GridView(
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 48,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          physics: const NeverScrollableScrollPhysics(),
          children:
              ['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0', 'back']
                  .map(
                    (digit) => ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: FilledButton(
                        key: ValueKey('jersey-key-$digit'),
                        onPressed: saving ? null : () => _digit(digit),
                        style: FilledButton.styleFrom(
                          backgroundColor: background,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(44, 44),
                        ),
                        child: digit == 'back'
                            ? const Icon(
                                Icons.backspace_outlined,
                                semanticLabel: 'Borrar último dígito',
                                size: 22,
                              )
                            : Text(
                                digit,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  )
                  .toList(),
        );
        return PanelScroll(
          child: constraints.maxWidth >= 540
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 2, child: identity),
                    const SizedBox(width: 18),
                    Expanded(flex: 3, child: keypad),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [identity, const SizedBox(height: 12), keypad],
                ),
        );
      },
    ),
  );
}
