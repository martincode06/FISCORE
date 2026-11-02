import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'app_widgets.dart';

void registerAudioCredit() => LicenseRegistry.addLicense(() async* {
  yield const LicenseEntryWithLineBreaks(
    ['Audio · Official NBA Horn SFX'],
    'Clip seleccionado por el usuario: Official NBA Horn SFX.\n'
    'Referencia: Rambie · https://www.youtube.com/watch?v=PEqSvldPSbI\n'
    'Archivo: TempoReverbBandwidth31836 · Voicemod Tuna\n'
    'https://tuna.voicemod.net/sound/ae648e10-2fae-4331-a8bc-e626a902f29f\n\n'
    'Adaptación: conversión a mono, ajuste de nivel y recorte de silencio al final. '
    'La señal de posesión usa un fragmento corto del mismo clip. '
    'El título es el publicado por el usuario de la plataforma; no acredita afiliación a la NBA.',
  );
});

class CreditsPanel extends StatefulWidget {
  const CreditsPanel({super.key, required this.version});
  final String? version;
  @override
  State<CreditsPanel> createState() => _CreditsPanelState();
}

class _CreditsPanelState extends State<CreditsPanel> {
  bool copied = false;

  Future<void> _copyEmail() async {
    await Clipboard.setData(
      const ClipboardData(text: 'ma.garciavi@unsm.edu.pe'),
    );
    if (mounted) setState(() => copied = true);
  }

  void _showQr() => showDialog<void>(
    context: context,
    builder: (ctx) => MatchPanel(
      title: 'Donaciones con Yape',
      subtitle: 'Pellizca para ampliar el QR',
      maxWidth: 720,
      maxHeight: 1000,
      child: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image.asset(
            'assets/yape-donaciones.png',
            fit: BoxFit.contain,
            semanticLabel: 'QR de Yape de Martin Alonso Garcia Villy',
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final brand = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: amber.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.sports_basketball, color: amber, size: 38),
        ),
        const SizedBox(height: 12),
        const Text(
          'FISCORE',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tu partido, bajo control.',
          style: TextStyle(color: amber, fontSize: 14),
        ),
        const SizedBox(height: 10),
        const Text(
          'Marcador, reloj y faltas para tus partidos.\nPensado para la cancha y sin conexión.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Text(
          widget.version == null ? 'Android' : 'Versión ${widget.version}',
          style: const TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
    final author = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF29364B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CREADO POR',
            style: TextStyle(color: muted, fontSize: 11, letterSpacing: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'Martin Villy',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            'Consultas y contrataciones',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          const SelectableText(
            'ma.garciavi@unsm.edu.pe',
            style: TextStyle(
              color: amber,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('copy-contact'),
            onPressed: _copyEmail,
            icon: Icon(copied ? Icons.check : Icons.copy_outlined, size: 18),
            label: Text(
              copied ? 'Correo copiado' : 'Copiar correo',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Donaciones con Yape',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('donation-qr'),
            onPressed: _showQr,
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Ampliar QR de Yape'),
          ),
          const SizedBox(height: 8),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: InkWell(
                key: const ValueKey('donation-qr-image'),
                onTap: _showQr,
                child: AspectRatio(
                  aspectRatio: 1131 / 1599,
                  child: Image.asset(
                    'assets/yape-donaciones.png',
                    semanticLabel: 'Donar con Yape. Toca para ampliar el QR.',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return MatchPanel(
      title: 'Créditos y contacto',
      maxWidth: 840,
      maxHeight: 760,
      actions: Row(
        children: [
          const Expanded(
            child: Text(
              'Tu apoyo voluntario ayuda a mejorar FISCORE. ¡Gracias!',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'FISCORE',
              applicationVersion: widget.version,
              applicationLegalese: 'Creado por Martin Villy',
            ),
            child: const Text('Licencias', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (_, constraints) => PanelScroll(
          child: constraints.maxWidth >= 600
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: brand),
                    const SizedBox(width: 24),
                    Expanded(child: author),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [brand, const SizedBox(height: 16), author],
                ),
        ),
      ),
    );
  }
}
