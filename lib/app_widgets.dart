import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Uses the actual available window height. Header and actions stay visible.
class MatchPanel extends StatelessWidget {
  const MatchPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.maxWidth = 960,
    this.maxHeight = 560,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? actions;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) => MediaQuery.removeViewInsets(
    context: context,
    removeBottom: true,
    child: Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 22),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF29364B)),
            Expanded(child: child),
            if (actions != null)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF29364B))),
                ),
                child: actions,
              ),
          ],
        ),
      ),
    ),
  );
}

class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.id,
  });
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final String id;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF29364B)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        ),
        IconButton(
          key: ValueKey('$id-minus'),
          tooltip: 'Disminuir $label',
          onPressed: onMinus,
          color: amber,
          icon: const Icon(Icons.remove_circle_outline),
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
        ),
        SizedBox(
          width: 48,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              key: ValueKey('$id-value'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        IconButton(
          key: ValueKey('$id-plus'),
          tooltip: 'Aumentar $label',
          onPressed: onPlus,
          color: amber,
          icon: const Icon(Icons.add_circle_outline),
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
        ),
      ],
    ),
  );
}

class PanelScroll extends StatefulWidget {
  const PanelScroll({super.key, required this.child});
  final Widget child;
  @override
  State<PanelScroll> createState() => _PanelScrollState();
}

class _PanelScrollState extends State<PanelScroll> {
  final controller = ScrollController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: controller,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.all(12),
      child: widget.child,
    ),
  );
}

class NameDialog extends StatefulWidget {
  const NameDialog({
    super.key,
    required this.title,
    required this.value,
    required this.maxLength,
  });
  final String title;
  final String value;
  final int maxLength;
  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  late final controller = TextEditingController(text: widget.value)
    ..selection = TextSelection.collapsed(offset: widget.value.length);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, controller.text.trim());

  @override
  Widget build(BuildContext context) => Dialog(
    alignment: Alignment.topCenter,
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    backgroundColor: surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 180),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (_, constraints) {
            final tiny = constraints.maxHeight < 92;
            final compact = constraints.maxHeight < 140;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!tiny)
                  SizedBox(
                    height: compact ? 36 : 44,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          key: const ValueKey('save-name'),
                          onPressed: _save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(64, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text(
                            'Guardar',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!tiny) const SizedBox(height: 6),
                TextField(
                  key: const ValueKey('name-input'),
                  controller: controller,
                  autofocus: true,
                  maxLength: widget.maxLength,
                  maxLines: 1,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  scrollPadding: EdgeInsets.zero,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    hintText: 'Nombre',
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
