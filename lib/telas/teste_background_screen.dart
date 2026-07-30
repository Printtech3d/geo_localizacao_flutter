import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class TesteBackgroundScreen extends StatefulWidget {
  const TesteBackgroundScreen({super.key});

  @override
  State<TesteBackgroundScreen> createState() => _TesteBackgroundScreenState();
}

class _TesteBackgroundScreenState extends State<TesteBackgroundScreen> {
  StreamSubscription<Position>? _streamAssinatura;
  final List<Position> _historico = [];
  bool _monitorando = false;
  String? _mensagemErro;

  @override
  void dispose() {
    _streamAssinatura?.cancel();
    super.dispose();
  }

  Future<void> _iniciarMonitoramento() async {
    setState(() => _mensagemErro = null);

    final servicoAtivo = await Geolocator.isLocationServiceEnabled();
    if (!servicoAtivo) {
      setState(() => _mensagemErro = 'Serviço de localização desativado.');
      return;
    }

    LocationPermission permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      setState(() => _mensagemErro = 'Permissão de localização necessária.');
      return;
    }

    const configuracao = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _streamAssinatura = Geolocator.getPositionStream(
      locationSettings: configuracao,
    ).listen((posicao) {
      setState(() {
        _historico.insert(0, posicao);
        if (_historico.length > 20) _historico.removeLast();
      });
    });

    setState(() => _monitorando = true);
  }

  void _pararMonitoramento() {
    _streamAssinatura?.cancel();
    setState(() => _monitorando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('003 - Segundo Plano')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: _monitorando
                ? Colors.green.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _monitorando
                      ? '🟢 Monitorando (${_historico.length} leituras)'
                      : '⚪ Parado',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Roteiro de teste:\n'
                  '1. Inicie o monitoramento\n'
                  '2. Minimize o app (não feche) e ande um pouco — volte e '
                  'veja se as leituras continuaram\n'
                  '3. Fache o app pela tela de apps recentes (swipe) e '
                  'ande de novo — volte e veja se parou (sem Foreground '
                  'Service, o esperado é que pare)\n'
                  '4. Anote o resultado em docs/003-background.md',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (_mensagemErro != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _mensagemErro!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: _historico.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhuma leitura ainda.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _historico.length,
                    itemBuilder: (context, index) {
                      final posicao = _historico[index];
                      return ListTile(
                        dense: true,
                        leading: Text('${_historico.length - index}'),
                        title: Text(
                          '${posicao.latitude.toStringAsFixed(6)}, '
                          '${posicao.longitude.toStringAsFixed(6)}',
                        ),
                        subtitle: Text('${posicao.timestamp}'),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed:
                  _monitorando ? _pararMonitoramento : _iniciarMonitoramento,
              icon: Icon(_monitorando ? Icons.stop : Icons.play_arrow),
              label: Text(
                _monitorando ? 'Parar monitoramento' : 'Iniciar monitoramento',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _monitorando ? Colors.red : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}