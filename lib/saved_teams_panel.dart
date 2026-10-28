import 'dart:convert';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'game.dart';
import 'saved_teams.dart';

class SavedTeamsPanel extends StatefulWidget {
  const SavedTeamsPanel({
    super.key,
    required this.currentTeams,
    required this.read,
    required this.store,
    required this.use,
  });
  final List<Team> currentTeams;
  final Future<String?> Function() read;
  final Future<void> Function(String) store;
  final Future<bool> Function(SavedTeam, int) use;
  @override
  State<SavedTeamsPanel> createState() => _SavedTeamsPanelState();
}

class _SavedTeamsPanelState extends State<SavedTeamsPanel> {
  SavedTeams? library;
  bool loading = true;
  bool busy = false;
  String? status;
  String? error;
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final stored = await widget.read();
      final loaded = stored == null
          ? SavedTeams()
          : SavedTeams.fromJson(jsonDecode(stored));
      if (mounted) setState(() => library = loaded);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'No se pudieron leer tus equipos. Pulsa Reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save(int slot) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameDialog(
        title: 'Guardar equipo como',
        value: widget.currentTeams[slot].name,
        maxLength: 22,
      ),
    );
    if (!mounted || name == null || name.isEmpty) return;
    SavedTeam team;
    try {
      team = SavedTeam.capture(widget.currentTeams[slot], name: name);
    } catch (_) {
      setState(
        () => error = 'Revisa los nombres y los dorsales antes de guardar.',
      );
      return;
    }
    if (library!.contains(team.id)) {
      final update = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text(
            'Actualizar ${team.name}',
            style: const TextStyle(fontSize: 18),
          ),
          content: const Text(
            'Se reemplazará la plantilla guardada por los jugadores y dorsales actuales.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Actualizar'),
            ),
          ],
        ),
      );
      if (!mounted || update != true) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final next = library!.withTeam(team);
    try {
      await widget.store(jsonEncode(next.toJson()));
      if (mounted) {
        setState(() {
          library = next;
          status = '${team.name}: plantilla guardada';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'No se pudo guardar el equipo. Vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _use(SavedTeam team, int slot) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final accepted = await widget.use(team, slot);
      if (mounted && accepted) {
        Navigator.pop(context);
        return;
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'No se pudo cargar el equipo. Vuelve a intentarlo.',
        );
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => MatchPanel(
    title: 'Mis equipos',
    subtitle:
        'Guarda nombres y dorsales. Carga plantillas sin puntos ni faltas.',
    maxWidth: 900,
    maxHeight: 520,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          child: Row(
            children: [
              for (var slot = 0; slot < 2; slot++) ...[
                if (slot == 1) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: ValueKey('save-team-$slot'),
                    onPressed: loading || busy || library == null
                        ? null
                        : () => _save(slot),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 19),
                    label: Text(
                      'Guardar ${widget.currentTeams[slot].name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (error != null || status != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              error ?? status!,
              maxLines: 2,
              style: TextStyle(
                fontSize: 12,
                color: error == null
                    ? const Color(0xFF67DDB2)
                    : Colors.redAccent,
              ),
            ),
          ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : library == null
              ? Center(
                  child: TextButton.icon(
                    onPressed: _read,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                )
              : library!.teams.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Guarda los equipos de este partido para volver a usarlos.\nSe conservan jugadores y dorsales, sin puntos ni faltas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ),
                )
              : Scrollbar(
                  controller: scroll,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: library!.teams.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final team = library!.teams[index];
                      return Material(
                        key: ValueKey('saved-team-${team.id}'),
                        color: background,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF29364B)),
                        ),
                        child: Column(
                          children: [
                            ExpansionTile(
                              key: PageStorageKey(team.id),
                              title: Text(
                                team.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${team.players.length} jugadores · Toca para ver la plantilla',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                12,
                                0,
                                12,
                                8,
                              ),
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: team.players
                                      .map(
                                        (p) => Chip(
                                          label: Text(
                                            '#${p.number}${p.name.isEmpty ? '' : ' · ${p.name}'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: Row(
                                children: [
                                  for (var slot = 0; slot < 2; slot++) ...[
                                    if (slot == 1) const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.tonal(
                                        key: ValueKey(
                                          'use-team-${team.id}-$slot',
                                        ),
                                        onPressed: busy
                                            ? null
                                            : () => _use(team, slot),
                                        child: Text(
                                          slot == 0
                                              ? 'Usar como local'
                                              : 'Usar como visitante',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  );
}
