import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _idGeofenceTeste = 'geofence_teste_001';
const String _chaveEventosSalvos = 'eventos_geofence';

// Precisa ser top-level (fora de classe) para funcionar em background,
// mesmo com o app encerrado. Roda em um isolate separado do app principal.
@pragma('vm:entry-point')
Future<void> geofenceCallback(GeofenceCallbackParams params) async {
  debugPrint(
    '[GEOFENCE] ${DateTime.now()} — id: ${params.geofences.first.id} — '
    'evento: ${params.event}',
  );

  // Salva em disco (shared_preferences) para a tela conseguir ler depois,
  // mesmo que o evento tenha disparado com o app fechado. Não dá para
  // atualizar a UI diretamente daqui, pois é um isolate separado.
  try {
    final prefs = await SharedPreferences.getInstance();
    final listaAtual = prefs.getStringList(_chaveEventosSalvos) ?? [];

    final novoEvento = jsonEncode({
      'evento': params.event.toString(),
      'geofenceId': params.geofences.first.id,
      'timestamp': DateTime.now().toIso8601String(),
    });

    listaAtual.insert(0, novoEvento);
    if (listaAtual.length > 50) listaAtual.removeLast();

    await prefs.setStringList(_chaveEventosSalvos, listaAtual);
  } catch (e) {
    debugPrint('[GEOFENCE] Erro ao salvar evento: $e');
  }
}

class TesteGeofenceScreen extends StatefulWidget {
  const TesteGeofenceScreen({super.key});

  @override
  State<TesteGeofenceScreen> createState() => _TesteGeofenceScreenState();
}

class _TesteGeofenceScreenState extends State<TesteGeofenceScreen>
    with WidgetsBindingObserver {
  final _controladorRaio = TextEditingController(text: '100');
  Position? _posicaoAtual;
  bool _geofenceAtiva = false;
  bool _carregando = false;
  String? _mensagem;
  List<Map<String, dynamic>> _eventos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _carregarEventosSalvos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controladorRaio.dispose();
    super.dispose();
  }

  // Sempre que o app volta ao primeiro plano, recarrega a lista — assim
  // eventos disparados enquanto o app estava minimizado/fechado aparecem
  // automaticamente sem precisar apertar em nada.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _carregarEventosSalvos();
    }
  }

  Future<void> _carregarEventosSalvos() async {
    final prefs = await SharedPreferences.getInstance();
    final listaSalva = prefs.getStringList(_chaveEventosSalvos) ?? [];
    setState(() {
      _eventos = listaSalva
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();
    });
  }

  Future<void> _limparEventos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveEventosSalvos);
    setState(() => _eventos = []);
  }

  Future<void> _obterLocalizacaoAtual() async {
    setState(() => _carregando = true);
    try {
      final posicao = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _posicaoAtual = posicao;
        _mensagem = 'Localização atual capturada. Use-a como centro da '
            'geofence, ou ande até o local desejado antes de criar.';
      });
    } catch (e) {
      setState(() => _mensagem = 'Erro ao obter localização: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _criarGeofence() async {
    if (_posicaoAtual == null) {
      setState(() {
        _mensagem = 'Capture a localização atual primeiro (será o centro '
            'da geofence).';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _mensagem = null;
    });

    try {
      await NativeGeofenceManager.instance.initialize();

      final raio = double.tryParse(_controladorRaio.text) ?? 100;

      final geofence = Geofence(
        id: _idGeofenceTeste,
        location: Location(
          latitude: _posicaoAtual!.latitude,
          longitude: _posicaoAtual!.longitude,
        ),
        radiusMeters: raio,
        triggers: {
          GeofenceEvent.enter,
          GeofenceEvent.exit,
          GeofenceEvent.dwell,
        },
        iosSettings: const IosGeofenceSettings(
          initialTrigger: true,
        ),
        androidSettings: AndroidGeofenceSettings(
          initialTriggers: {GeofenceEvent.enter},
          loiteringDelay: const Duration(minutes: 1),
          notificationResponsiveness: const Duration(seconds: 30),
        ),
      );

      await NativeGeofenceManager.instance.createGeofence(
        geofence,
        geofenceCallback,
      );

      setState(() {
        _geofenceAtiva = true;
        _mensagem = 'Geofence criada! Centro: '
            '${_posicaoAtual!.latitude.toStringAsFixed(6)}, '
            '${_posicaoAtual!.longitude.toStringAsFixed(6)} — '
            'raio ${raio.toStringAsFixed(0)}m.\n\n'
            'Agora afaste-se do local (mais que o raio) e volte, ou '
            'feche o app e ande. Pode desconectar o USB — os eventos '
            'ficam salvos e aparecem na lista abaixo quando você reabrir '
            'o app.';
      });
    } catch (e) {
      setState(() => _mensagem = 'Erro ao criar geofence: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _removerGeofence() async {
    setState(() => _carregando = true);
    try {
      await NativeGeofenceManager.instance.removeGeofenceById(
        _idGeofenceTeste,
      );
      setState(() {
        _geofenceAtiva = false;
        _mensagem = 'Geofence removida.';
      });
    } catch (e) {
      setState(() => _mensagem = 'Erro ao remover geofence: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('004 - Geofence'),
        actions: [
          IconButton(
            onPressed: _carregarEventosSalvos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar lista de eventos',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 0,
                  color: Colors.blueGrey.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _geofenceAtiva
                              ? '🟢 Geofence ativa'
                              : '⚪ Nenhuma geofence ativa',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_posicaoAtual != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Centro: '
                            '${_posicaoAtual!.latitude.toStringAsFixed(6)}, '
                            '${_posicaoAtual!.longitude.toStringAsFixed(6)}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controladorRaio,
                  keyboardType: TextInputType.number,
                  enabled: !_geofenceAtiva,
                  decoration: const InputDecoration(
                    labelText: 'Raio da geofence (metros)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_carregando)
                  const Center(child: CircularProgressIndicator()),
                if (_mensagem != null)
                  Card(
                    elevation: 0,
                    color: Colors.blue.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_mensagem!),
                    ),
                  ),
                const SizedBox(height: 16),
                if (!_geofenceAtiva) ...[
                  OutlinedButton.icon(
                    onPressed: _carregando ? null : _obterLocalizacaoAtual,
                    icon: const Icon(Icons.my_location),
                    label: const Text('1. Capturar localização atual'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _carregando ? null : _criarGeofence,
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('2. Criar geofence aqui'),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: _carregando ? null : _removerGeofence,
                    icon: const Icon(Icons.location_off),
                    label: const Text('Remover geofence'),
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.red),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Eventos registrados (${_eventos.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _eventos.isEmpty ? null : _limparEventos,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Limpar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _eventos.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhum evento ainda. Depois de criar a geofence, '
                        'entre/saia da área e volte no app (ou toque em '
                        'atualizar) para ver os eventos aqui.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _eventos.length,
                    itemBuilder: (context, index) {
                      final evento = _eventos[index];
                      final tipoEvento =
                          evento['evento'].toString().toUpperCase();
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          tipoEvento.contains('ENTER')
                              ? Icons.login
                              : tipoEvento.contains('EXIT')
                                  ? Icons.logout
                                  : Icons.timer,
                          color: tipoEvento.contains('ENTER')
                              ? Colors.green
                              : tipoEvento.contains('EXIT')
                                  ? Colors.red
                                  : Colors.orange,
                        ),
                        title: Text(tipoEvento),
                        subtitle: Text('${evento['timestamp']}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}