import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class TestePermissoesScreen extends StatefulWidget {
  const TestePermissoesScreen({super.key});

  @override
  State<TestePermissoesScreen> createState() => _TestePermissoesScreenState();
}

class _TestePermissoesScreenState extends State<TestePermissoesScreen> {
  LocationPermission? _permissaoAtual;
  PermissionStatus? _statusBackground;
  bool _carregando = false;
  String? _log;

  @override
  void initState() {
    super.initState();
    _atualizarStatus();
  }

  Future<void> _atualizarStatus() async {
    final permissao = await Geolocator.checkPermission();
    final statusBg = await Permission.locationAlways.status;
    setState(() {
      _permissaoAtual = permissao;
      _statusBackground = statusBg;
    });
  }

  Future<void> _solicitarPermissaoCompleta() async {
    setState(() {
      _carregando = true;
      _log = null;
    });

    LocationPermission permissao = await Geolocator.checkPermission();

    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }

    if (permissao == LocationPermission.deniedForever) {
      setState(() {
        _log = 'Permissão negada para sempre. Abrindo configurações...';
        _carregando = false;
      });
      await Geolocator.openAppSettings();
      await _atualizarStatus();
      return;
    }

    if (permissao == LocationPermission.whileInUse ||
        permissao == LocationPermission.always) {
      final status = await Permission.locationAlways.request();
      setState(() {
        _log = status.isGranted
            ? 'Permissão "sempre" concedida com sucesso.'
            : 'Permissão "sempre" NÃO concedida (status: $status). '
                'No Android 11+, isso costuma exigir ir manualmente em '
                'Configurações > Apps > Permissões.';
      });
    }

    await _atualizarStatus();
    setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('002 - Permissões')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardStatus(),
            const SizedBox(height: 24),
            if (_carregando) const Center(child: CircularProgressIndicator()),
            if (_log != null)
              Card(
                elevation: 0,
                color: Colors.blueGrey.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_log!),
                ),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _carregando ? null : _solicitarPermissaoCompleta,
              icon: const Icon(Icons.lock_open),
              label: const Text('Solicitar permissão "sempre"'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _atualizarStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar status'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardStatus() {
    return Card(
      elevation: 0,
      color: Colors.blue.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enquanto em uso / sempre: ${_permissaoAtual?.name ?? "-"}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Permissão "sempre" (background): ${_statusBackground ?? "-"}'),
          ],
        ),
      ),
    );
  }
}