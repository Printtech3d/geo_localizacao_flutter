# 002 - Permissões de Localização

## Objetivo
Mapear todos os estados possíveis de permissão de localização no Android
(negada, concedida "enquanto em uso", concedida "sempre", negada para sempre)
e definir o fluxo correto de solicitação para cada caso, já pensando no que
será necessário para o segundo plano e o geofence mais adiante.

## Pacotes utilizados
- `geolocator: ^13.0.0`
- `permission_handler: ^11.0.0` (para checar/solicitar permissão "sempre" separadamente)

## Estados de permissão
- `denied` — nunca solicitado ou negado (pode solicitar de novo)
- `deniedForever` — usuário negou e marcou "não perguntar novamente"
- `whileInUse` — concedida só enquanto o app está em uso
- `always` — concedida para uso em segundo plano também

## Código utilizado

```dart
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

Future<LocationPermission> solicitarPermissaoCompleta() async {
  LocationPermission permissao = await Geolocator.checkPermission();

  if (permissao == LocationPermission.denied) {
    permissao = await Geolocator.requestPermission();
  }

  if (permissao == LocationPermission.deniedForever) {
    // Não adianta pedir de novo, precisa direcionar para configurações
    await Geolocator.openAppSettings();
    return permissao;
  }

  // No Android 10+, a permissão "sempre" (background) precisa ser
  // solicitada separadamente, depois que "enquanto em uso" já foi concedida
  if (permissao == LocationPermission.whileInUse) {
    final status = await Permission.locationAlways.request();
    if (status.isGranted) {
      permissao = await Geolocator.checkPermission();
    }
  }

  return permissao;
}