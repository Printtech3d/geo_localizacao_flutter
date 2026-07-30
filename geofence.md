# 004 - Geofence

## Objetivo
Testar a criação e o disparo de eventos de geofence (ENTER, EXIT, DWELL) para
detectar automaticamente quando um membro chega e permanece na igreja,
incluindo o comportamento com o app minimizado e encerrado.

## Pacotes utilizados
- `native_geofence` (usa APIs nativas do Android/iOS, não depende de stream Dart ativo)
- `geofence_service` (alternativa 100% Dart, mais fácil mas menos robusta em background)

## Conceitos
- **ENTER** — disparado quando o dispositivo entra no raio da geofence
- **EXIT** — disparado quando o dispositivo sai do raio
- **DWELL** — disparado quando o dispositivo permanece dentro do raio por um
  tempo mínimo definido (ex: 5 minutos) — é o evento usado para confirmar
  presença real, e não só uma passagem rápida

## Código utilizado

```dart
import 'package:native_geofence/native_geofence.dart';

Future<void> criarGeofenceIgreja() async {
  await NativeGeofenceManager.instance.initialize();

  final geofence = Geofence(
    id: 'igreja_principal',
    location: Location(latitude: -23.55052, longitude: -46.63330),
    radiusMeters: 100,
    triggers: {
      GeofenceEvent.enter,
      GeofenceEvent.exit,
      GeofenceEvent.dwell,
    },
    androidSettings: AndroidGeofenceSettings(
      initialTriggers: {GeofenceEvent.enter},
      loiteringDelay: const Duration(minutes: 5), // tempo para considerar DWELL
      notificationResponsiveness: const Duration(minutes: 1),
    ),
  );

  await NativeGeofenceManager.instance.createGeofence(
    geofence,
    geofenceCallback, // função top-level, roda em background isolate
  );
}

// Precisa ser uma função top-level (fora de classe) para funcionar em background
@pragma('vm:entry-point')
void geofenceCallback(GeofenceCallbackParams params) {
  for (final evento in params.event) {
    print('Geofence ${params.geofences.first.id}: evento $evento');
    // Aqui entraria a gravação no Firestore
  }
}