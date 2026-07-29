# 003 - Localização em Segundo Plano

## Objetivo
Testar se é possível continuar recebendo atualizações de localização com o
app minimizado (background) e com o app totalmente encerrado (killed),
que é o cenário mais crítico para o registro automático de presença do
Missão Renovo.

## Pacotes utilizados
- `geolocator: ^13.0.0` (stream de posição)
- `flutter_background_geolocation` (alternativa paga/mais robusta, testar free trial)
- `flutter_foreground_task` (para manter um Foreground Service ativo)

## Cenários a testar
1. App aberto, tela ligada (foreground) — baseline
2. App minimizado, tela ligada (background leve)
3. App minimizado, tela desligada (background com Doze/App Standby)
4. App encerrado manualmente pelo usuário (swipe da recents)
5. App encerrado pelo sistema (memória baixa)
6. Aparelho reiniciado (boot) sem o usuário abrir o app de novo

## Código utilizado

```dart
import 'package:geolocator/geolocator.dart';

StreamSubscription<Position>? _streamAssinatura;

void iniciarMonitoramentoContinuo() {
  const configuracao = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // metros mínimos para disparar novo evento
  );

  _streamAssinatura = Geolocator.getPositionStream(
    locationSettings: configuracao,
  ).listen((Position posicao) {
    // Aqui entraria o envio para o Firestore / log local do teste
    print('Nova posição: ${posicao.latitude}, ${posicao.longitude}');
  });
}

void pararMonitoramento() {
  _streamAssinatura?.cancel();
}