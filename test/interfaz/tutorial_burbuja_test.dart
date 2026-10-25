import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/componentes/mazo_preguntas.dart';

import '../apoyo/base_pruebas.dart';
import '../apoyo/montar_interfaz.dart';

Finder _clave(String key) => find.byKey(ValueKey(key));
Rect _burbuja(WidgetTester tester) =>
    tester.getRect(_clave('tutorial-burbuja'));

Future<void> _abrir(WidgetTester tester) async {
  await montar(tester, AlmacenMemoria(), animaciones: true);
  tester.view.physicalSize = const Size(411, 914);
  await tester.pumpAndSettle();
  await tocar(tester, 'ver-tutorial');
}

void main() {
  testWidgets(
    'burbuja baja y vuelve a subir junto al objetivo sin mover el mazo',
    (tester) async {
      await _abrir(tester);
      final niveles = _burbuja(tester);
      expect(
        niveles.top,
        greaterThan(tester.getRect(_clave('tutorial-nivel-3')).bottom),
      );
      await tester.tap(_clave('tutorial-siguiente'));
      await tester.pump();
      await tester.pump();
      final mazo = tester.getRect(find.byType(MazoPreguntas));
      await tester.pump(const Duration(milliseconds: 210));
      final intermedia = _burbuja(tester);
      expect(intermedia.top, greaterThan(niveles.top));
      expect(_clave('otra-carta').hitTestable(), findsNothing);
      await tester.pumpAndSettle();
      final cartas = _burbuja(tester);
      expect(cartas.top, greaterThan(intermedia.top));
      expect(tester.getRect(find.byType(MazoPreguntas)), mazo);
      expect(cartas.overlaps(tester.getRect(_clave('otra-carta'))), isFalse);
      expect(
        cartas.overlaps(tester.getRect(find.byType(MazoPreguntas))),
        isFalse,
      );
      await tocar(tester, 'tutorial-atras');
      expect(_burbuja(tester), niveles);
      await tocar(tester, 'tutorial-omitir');
    },
  );

  testWidgets('se acerca a Una más, Pasar y el resumen sin cubrir el control', (
    tester,
  ) async {
    await _abrir(tester);
    for (var i = 0; i < 3; i++) {
      await tocar(tester, 'tutorial-siguiente');
    }
    final izquierda = _burbuja(tester);
    expect(izquierda.overlaps(tester.getRect(_clave('una-mas'))), isFalse);
    await tocar(tester, 'tutorial-siguiente');
    final derecha = _burbuja(tester);
    expect(derecha.center.dx, greaterThan(izquierda.center.dx));
    expect(derecha.overlaps(tester.getRect(_clave('pasar'))), isFalse);
    await tocar(tester, 'tutorial-siguiente');
    final resumen = _burbuja(tester);
    expect(resumen.top, lessThan(derecha.top));
    expect(resumen.bottom, lessThanOrEqualTo(914));
    await tocar(tester, 'tutorial-siguiente');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'el desplazamiento de la burbuja se pausa y continúa en primer plano',
    (tester) async {
      await _abrir(tester);
      await tester.tap(_clave('tutorial-siguiente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 170));
      final posicion = _burbuja(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 3));
      expect(_burbuja(tester), posicion);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_burbuja(tester).top, greaterThan(posicion.top));
      expect(_clave('otra-carta').hitTestable(), findsOneWidget);
      await tocar(tester, 'tutorial-omitir');
      expect(tester.takeException(), isNull);
    },
  );
}
