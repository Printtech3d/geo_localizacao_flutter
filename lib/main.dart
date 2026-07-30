import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'telas/teste_permissoes_screen.dart';
import 'telas/teste_background_screen.dart';

void main() {
  runApp(const GeoLocalizacaoApp());
}

class GeoLocalizacaoApp extends StatelessWidget {
  const GeoLocalizacaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo Localização - Testes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const MenuTestesScreen(),
    );
  }
}

class MenuTestesScreen extends StatelessWidget {
  const MenuTestesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geo Localização - Testes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _itemMenu(
            context,
            titulo: '001 - Localização Básica',
            subtitulo: 'Leitura única de localização em primeiro plano',
            icone: Icons.location_on,
            destino: const TesteLocalizacaoScreen(),
          ),
          _itemMenu(
            context,
            titulo: '002 - Permissões',
            subtitulo: 'Fluxo completo: enquanto em uso vs sempre',
            icone: Icons.lock_open,
            destino: const TestePermissoesScreen(),
          ),
          _itemMenu(
            context,
            titulo: '003 - Segundo Plano',
            subtitulo: 'Monitoramento contínuo: minimizado vs encerrado',
            icone: Icons.blur_on,
            destino: const TesteBackgroundScreen(),
          ),
        ],
      ),
    );
  }

  Widget _itemMenu(
    BuildContext context, {
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required Widget destino,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icone),
        title: Text(titulo),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => destino),
          );
        },
      ),
    );
  }
}

class TesteLocalizacaoScreen extends StatefulWidget {
  const TesteLocalizacaoScreen({super.key});

  @override
  State<TesteLocalizacaoScreen> createState() =>
      _TesteLocalizacaoScreenState();
}

class _TesteLocalizacaoScreenState extends State<TesteLocalizacaoScreen> {
  Position? _posicao;
  String? _mensagemErro;
  bool _carregando = false;

  Future<void> _obterLocalizacaoAtual() async {
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final servicoAtivo = await Geolocator.isLocationServiceEnabled();
      if (!servicoAtivo) {
        setState(() {
          _mensagemErro = 'Serviço de localização desativado no aparelho.';
          _carregando = false;
        });
        return;
      }

      LocationPermission permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
        if (permissao == LocationPermission.denied) {
          setState(() {
            _mensagemErro = 'Permissão de localização negada.';
            _carregando = false;
          });
          return;
        }
      }

      if (permissao == LocationPermission.deniedForever) {
        setState(() {
          _mensagemErro =
              'Permissão negada permanentemente. Abra as configurações do app.';
          _carregando = false;
        });
        return;
      }

      final posicao = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _posicao = posicao;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _mensagemErro = 'Erro ao obter localização: $e';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('001 - Localização Básica'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            if (_carregando) const CircularProgressIndicator(),
            if (!_carregando && _posicao != null) _buildCardResultado(),
            if (!_carregando && _mensagemErro != null) _buildCardErro(),
            if (!_carregando && _posicao == null && _mensagemErro == null)
              const Text(
                'Nenhuma leitura ainda.\nToque no botão abaixo para testar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _carregando ? null : _obterLocalizacaoAtual,
              icon: const Icon(Icons.my_location),
              label: const Text('Obter localização atual'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardResultado() {
    return Card(
      elevation: 0,
      color: Colors.blue.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _linhaInfo('Latitude', '${_posicao!.latitude}'),
            _linhaInfo('Longitude', '${_posicao!.longitude}'),
            _linhaInfo(
              'Precisão',
              '${_posicao!.accuracy.toStringAsFixed(1)} m',
            ),
            _linhaInfo('Horário', '${_posicao!.timestamp}'),
          ],
        ),
      ),
    );
  }

  Widget _buildCardErro() {
    return Card(
      elevation: 0,
      color: Colors.red.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _mensagemErro!,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _linhaInfo(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(rotulo, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(valor),
        ],
      ),
    );
  }
}