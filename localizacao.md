# 001 - Localização Básica

## Objetivo
Obter a localização atual do dispositivo (uma única leitura), em primeiro plano,
usando o pacote `geolocator`. Servir como base antes de avançar para atualização
contínua, background e geofence.

## Pacotes utilizados
- `geolocator: ^13.0.0` (ajustar para a versão mais recente ao implementar)

## Código utilizado

```dart
import 'package:geolocator/geolocator.dart';

Future<Position?> obterLocalizacaoAtual() async {
  bool servicoAtivo = await Geolocator.isLocationServiceEnabled();
  if (!servicoAtivo) {
    // GPS/localização desativado no aparelho
    return null;
  }

  LocationPermission permissao = await Geolocator.checkPermission();
  if (permissao == LocationPermission.denied) {
    permissao = await Geolocator.requestPermission();
    if (permissao == LocationPermission.denied) {
      return null;
    }
  }

  if (permissao == LocationPermission.deniedForever) {
    // Usuário negou permanentemente, precisa abrir configurações
    return null;
  }

  Position posicao = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
  return posicao;
}