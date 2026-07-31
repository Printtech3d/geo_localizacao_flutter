import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const String _chaveConfig = 'config_agendamento';
const String _chaveResultados = 'resultados_agendamento';

const List<String> _nomesDias = ['', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

// ---------------------------------------------------------------------
// MODELOS
// ---------------------------------------------------------------------

class HorarioVerificacao {
  final String id;
  final int hora;
  final int minuto;
  final Set<int> dias; // 1=segunda ... 7=domingo (DateTime.weekday)
  final String rotulo;

  HorarioVerificacao({
    required this.id,
    required this.hora,
    required this.minuto,
    required this.dias,
    required this.rotulo,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hora': hora,
        'minuto': minuto,
        'dias': dias.toList(),
        'rotulo': rotulo,
      };

  factory HorarioVerificacao.fromJson(Map<String, dynamic> json) =>
      HorarioVerificacao(
        id: json['id'],
        hora: json['hora'],
        minuto: json['minuto'],
        dias: Set<int>.from(json['dias']),
        rotulo: json['rotulo'] ?? '',
      );

  String get horaFormatada =>
      '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';
}

class ConfiguracaoLocal {
  final double? latitude;
  final double? longitude;
  final double raioMetros;

  ConfiguracaoLocal({this.latitude, this.longitude, this.raioMetros = 100});

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'raioMetros': raioMetros,
      };

  factory ConfiguracaoLocal.fromJson(Map<String, dynamic> json) =>
      ConfiguracaoLocal(
        latitude: json['latitude'],
        longitude: json['longitude'],
        raioMetros: (json['raioMetros'] ?? 100).toDouble(),
      );
}

class ConfigCompleta {
  final ConfiguracaoLocal local;
  final List<HorarioVerificacao> horarios;

  ConfigCompleta({required this.local, required this.horarios});

  Map<String, dynamic> toJson() => {
        'local': local.toJson(),
        'horarios': horarios.map((h) => h.toJson()).toList(),
      };

  factory ConfigCompleta.fromJson(Map<String, dynamic> json) =>
      ConfigCompleta(
        local: ConfiguracaoLocal.fromJson(json['local']),
        horarios: (json['horarios'] as List)
            .map((h) => HorarioVerificacao.fromJson(h))
            .toList(),
      );

  factory ConfigCompleta.vazia() =>
      ConfigCompleta(local: ConfiguracaoLocal(), horarios: []);
}

Future<ConfigCompleta> _carregarConfig() async {
  final prefs = await SharedPreferences.getInstance();
  final texto = prefs.getString(_chaveConfig);
  if (texto == null) return ConfigCompleta.vazia();
  return ConfigCompleta.fromJson(jsonDecode(texto));
}

Future<void> _salvarConfig(ConfigCompleta config) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_chaveConfig, jsonEncode(config.toJson()));
}

// ---------------------------------------------------------------------
// BACKGROUND — roda em isolate separado, sempre lê a config do disco
// ---------------------------------------------------------------------

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final config = await _carregarConfig();
    final horario = config.horarios.where((h) => h.id == task).toList();
    if (horario.isEmpty) return Future.value(true);

    final item = horario.first;
    final dentroDoRaio = await _verificarSeEstaNoLocal(config.local);

    final prefs = await SharedPreferences.getInstance();
    final listaAtual = prefs.getStringList(_chaveResultados) ?? [];
    listaAtual.insert(
      0,
      jsonEncode({
        'id': item.id,
        'rotulo': item.rotulo,
        'horaFormatada': item.horaFormatada,
        'dentroDoRaio': dentroDoRaio,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
    if (listaAtual.length > 100) listaAtual.removeLast();
    await prefs.setStringList(_chaveResultados, listaAtual);

    debugPrint(
      '[VERIFICACAO] ${item.rotulo} (${item.horaFormatada}) — '
      'dentro: $dentroDoRaio',
    );

    await _agendarOcorrencia(item);
    return Future.value(true);
  });
}

Future<bool> _verificarSeEstaNoLocal(ConfiguracaoLocal local) async {
  if (local.latitude == null || local.longitude == null) return false;
  try {
    final servicoAtivo = await Geolocator.isLocationServiceEnabled();
    if (!servicoAtivo) return false;

    final permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      return false;
    }

    final posicao = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final distancia = Geolocator.distanceBetween(
      local.latitude!,
      local.longitude!,
      posicao.latitude,
      posicao.longitude,
    );

    return distancia <= local.raioMetros;
  } catch (e) {
    debugPrint('[VERIFICACAO] Erro ao obter localização: $e');
    return false;
  }
}

// Calcula a próxima ocorrência entre os dias marcados e agenda uma
// tarefa única (one-off). Quando ela roda, se reagenda sozinha.
Future<void> _agendarOcorrencia(HorarioVerificacao item) async {
  if (item.dias.isEmpty) return;

  final agora = DateTime.now();
  var candidata =
      DateTime(agora.year, agora.month, agora.day, item.hora, item.minuto);

  for (var i = 0; i < 8; i++) {
    if (item.dias.contains(candidata.weekday) && candidata.isAfter(agora)) {
      break;
    }
    candidata = candidata.add(const Duration(days: 1));
  }

  final atraso = candidata.difference(agora);

  await Workmanager().registerOneOffTask(
    item.id,
    item.id,
    initialDelay: atraso,
    constraints: Constraints(networkType: NetworkType.notRequired),
  );

  debugPrint(
    '[VERIFICACAO] ${item.rotulo} agendado para $candidata '
    '(em ${atraso.inHours}h${atraso.inMinutes % 60}min)',
  );
}

// ---------------------------------------------------------------------
// TELA
// ---------------------------------------------------------------------

class TesteAgendamentoScreen extends StatefulWidget {
  const TesteAgendamentoScreen({super.key});

  @override
  State<TesteAgendamentoScreen> createState() =>
      _TesteAgendamentoScreenState();
}

class _TesteAgendamentoScreenState extends State<TesteAgendamentoScreen> {
  final _controladorLat = TextEditingController();
  final _controladorLng = TextEditingController();
  final _controladorRaio = TextEditingController(text: '100');

  ConfigCompleta _config = ConfigCompleta.vazia();
  List<Map<String, dynamic>> _resultados = [];
  bool _carregando = false;
  bool _workManagerPronto = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    await Workmanager().initialize(callbackDispatcher);
    _workManagerPronto = true;
    await _carregarTudo();
  }

  Future<void> _carregarTudo() async {
    final config = await _carregarConfig();
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_chaveResultados) ?? [];
    setState(() {
      _config = config;
      _controladorLat.text = config.local.latitude?.toString() ?? '';
      _controladorLng.text = config.local.longitude?.toString() ?? '';
      _controladorRaio.text = config.local.raioMetros.toStringAsFixed(0);
      _resultados =
          lista.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _usarLocalizacaoAtual() async {
    setState(() => _carregando = true);
    try {
      final posicao = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _controladorLat.text = posicao.latitude.toString();
        _controladorLng.text = posicao.longitude.toString();
      });
    } catch (e) {
      _mostrarSnack('Erro ao obter localização: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _salvarLocal() async {
    final lat = double.tryParse(_controladorLat.text.replaceAll(',', '.'));
    final lng = double.tryParse(_controladorLng.text.replaceAll(',', '.'));
    final raio = double.tryParse(_controladorRaio.text) ?? 100;

    if (lat == null || lng == null) {
      _mostrarSnack('Preencha latitude e longitude corretamente.');
      return;
    }

    final novaConfig = ConfigCompleta(
      local: ConfiguracaoLocal(latitude: lat, longitude: lng, raioMetros: raio),
      horarios: _config.horarios,
    );
    await _salvarConfig(novaConfig);
    setState(() => _config = novaConfig);
    _mostrarSnack('Local salvo.');
  }

  Future<void> _adicionarHorario() async {
    final resultado = await showDialog<HorarioVerificacao>(
      context: context,
      builder: (_) => const _DialogNovoHorario(),
    );
    if (resultado == null) return;

    final novaLista = [..._config.horarios, resultado];
    final novaConfig = ConfigCompleta(local: _config.local, horarios: novaLista);
    await _salvarConfig(novaConfig);
    setState(() => _config = novaConfig);

    if (_workManagerPronto) {
      await _agendarOcorrencia(resultado);
    }
    _mostrarSnack('Horário adicionado e agendado.');
  }

  Future<void> _removerHorario(HorarioVerificacao item) async {
    await Workmanager().cancelByUniqueName(item.id);
    final novaLista = _config.horarios.where((h) => h.id != item.id).toList();
    final novaConfig = ConfigCompleta(local: _config.local, horarios: novaLista);
    await _salvarConfig(novaConfig);
    setState(() => _config = novaConfig);
  }

  Future<void> _limparResultados() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveResultados);
    setState(() => _resultados = []);
  }

  void _mostrarSnack(String mensagem) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final localConfigurado =
        _config.local.latitude != null && _config.local.longitude != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('011 - Verificação por Horário'),
        actions: [
          IconButton(
            onPressed: _carregarTudo,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // CARD DO LOCAL
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Local a comparar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controladorLat,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true, signed: true),
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controladorLng,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true, signed: true),
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controladorRaio,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Raio (metros)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _carregando ? null : _usarLocalizacaoAtual,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('Usar minha localização'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _salvarLocal,
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('Salvar local'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // CARD DOS HORÁRIOS
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Horários de verificação',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: localConfigurado ? _adicionarHorario : null,
                        icon: const Icon(Icons.add_alarm, size: 18),
                        label: const Text('Adicionar'),
                      ),
                    ],
                  ),
                  if (!localConfigurado)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Salve um local primeiro para poder adicionar horários.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  if (_config.horarios.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Nenhum horário configurado ainda.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._config.horarios.map((h) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.alarm),
                          title: Text(
                            h.rotulo.isEmpty ? h.horaFormatada : h.rotulo,
                          ),
                          subtitle: Text(
                            '${h.horaFormatada} — '
                            '${h.dias.map((d) => _nomesDias[d]).join(", ")}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removerHorario(h),
                          ),
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // HISTÓRICO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Histórico (${_resultados.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _resultados.isEmpty ? null : _limparResultados,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Limpar'),
              ),
            ],
          ),
          if (_resultados.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Nenhuma verificação executada ainda. Elas rodam sozinhas '
                'nos horários configurados, mesmo com o app fechado.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._resultados.map((r) {
              final dentro = r['dentroDoRaio'] == true;
              final rotulo = (r['rotulo'] as String?)?.isNotEmpty == true
                  ? r['rotulo']
                  : r['horaFormatada'];
              return ListTile(
                dense: true,
                leading: Icon(
                  dentro ? Icons.check_circle : Icons.cancel,
                  color: dentro ? Colors.green : Colors.red,
                ),
                title: Text('$rotulo (${r['horaFormatada']})'),
                subtitle: Text('${r['timestamp']}'),
              );
            }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controladorLat.dispose();
    _controladorLng.dispose();
    _controladorRaio.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------
// DIÁLOGO DE NOVO HORÁRIO (estilo "despertador")
// ---------------------------------------------------------------------

class _DialogNovoHorario extends StatefulWidget {
  const _DialogNovoHorario();

  @override
  State<_DialogNovoHorario> createState() => _DialogNovoHorarioState();
}

class _DialogNovoHorarioState extends State<_DialogNovoHorario> {
  TimeOfDay _horaSelecionada = TimeOfDay.now();
  final Set<int> _diasSelecionados = {};
  final _controladorRotulo = TextEditingController();

  @override
  void dispose() {
    _controladorRotulo.dispose();
    super.dispose();
  }

  Future<void> _escolherHora() async {
    final resultado = await showTimePicker(
      context: context,
      initialTime: _horaSelecionada,
    );
    if (resultado != null) setState(() => _horaSelecionada = resultado);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo horário de verificação'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controladorRotulo,
              decoration: const InputDecoration(
                labelText: 'Nome (opcional)',
                hintText: 'Ex: Culto - entrada',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _escolherHora,
              icon: const Icon(Icons.access_time),
              label: Text(_horaSelecionada.format(context)),
            ),
            const SizedBox(height: 16),
            const Text(