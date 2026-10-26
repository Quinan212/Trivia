import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/acceso_tableta.dart';
import 'package:trivia_antiguedad/tema/tema_trivia_antiguedad.dart';

void main() {
  for (final caso in [
    (const Size(393, 852), 1.0),
    (const Size(852, 393), 1.0),
    (const Size(599, 1200), 1.0),
    (const Size(1080, 2400), 3.0),
    (const Size(600, 960), 1.0),
    (const Size(800, 1280), 1.0),
    (const Size(1280, 800), 1.0),
  ]) {
    testWidgets(
      'el bloqueo desactivado permite entrar en ${caso.$1} a densidad ${caso.$2}',
      (tester) async {
        tester.view.physicalSize = caso.$1;
        tester.view.devicePixelRatio = caso.$2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var montada = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: TemaTriviaAntiguedad.claro,
            home: AccesoTableta(
              child: Builder(
                builder: (_) {
                  montada = true;
                  return const Scaffold(body: Text('Evaluación habilitada'));
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(montada, isTrue);
        expect(find.text('Evaluación habilitada'), findsOneWidget);
        expect(find.byType(PantallaSoloTabletas), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
