
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_geo_localizacao/main.dart';

void main() {
  testWidgets('Menu inicial exibe os testes disponíveis',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GeoLocalizacaoApp());

    expect(find.text('001 - Localização Básica'), findsOneWidget);
    expect(find.text('002 - Permissões'), findsOneWidget);
    expect(find.text('003 - Segundo Plano'), findsOneWidget);
    expect(find.text('004 - Geofence'), findsOneWidget);
  });
}