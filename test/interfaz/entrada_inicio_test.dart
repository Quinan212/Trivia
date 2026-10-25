import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/componentes/entrada_inicio.dart';

const captura = ValueKey('captura-revelacion');

int diferenciaDeColor(List<int> a, List<int> b) =>
    List.generate(3, (i) => (a[i] - b[i]).abs()).reduce((a, b) => a + b);

Future<List<int>> pixel(WidgetTester tester, int x, int y) async {
  final caja = tester.renderObject<RenderRepaintBoundary>(find.byKey(captura));
  return (await tester.runAsync(() async {
    final imagen = await caja.toImage(pixelRatio: 1);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.rawRgba);
    final inicio = (y * imagen.width + x) * 4;
    final color = [for (var i = 0; i < 3; i++) bytes!.getUint8(inicio + i)];
    imagen.dispose();
    return color;
  }))!;
}

void main() {
  testWidgets(
    'la portada está limpia y las esquinas se dibujan una sola vez sobre la misma textura',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> montar(double progreso) async {
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: captura,
              child: FondoApertura(progreso: progreso),
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/imagenes/optimizadas/conversation-background-v2.webp'),
            tester.element(find.byType(FondoApertura)),
          ),
        );
        await tester.pumpAndSettle();
      }

      await montar(0);
      final textura = tester.element(
        find.byKey(const ValueKey('textura-apertura')),
      );
      final centro = await pixel(tester, 190, 430);
      final arriba = await pixel(tester, 320, 50);
      final abajo = await pixel(tester, 20, 825);
      final marca = await pixel(tester, 73, 840);
      await montar(.20);
      expect(
        tester.element(find.byKey(const ValueKey('textura-apertura'))),
        same(textura),
      );
      expect(await pixel(tester, 190, 430), centro);
      expect(await pixel(tester, 20, 825), abajo);
      await montar(1);
      expect(await pixel(tester, 190, 430), centro);
      // El contraste se mide en RGB: los tonos rojos pueden compartir R.
      expect(
        diferenciaDeColor(await pixel(tester, 320, 50), arriba),
        greaterThan(30),
      );
      expect(
        diferenciaDeColor(await pixel(tester, 20, 825), abajo),
        greaterThan(30),
      );
      expect(diferenciaDeColor(await pixel(tester, 73, 840), marca), greaterThan(100));
    },
  );

  testWidgets(
    'la cascada muestra primero arriba y conserva las posiciones de los controles',
    (tester) async {
      Future<void> montar(double progreso) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EntradaInicio(
              progreso: progreso,
              enCurso: progreso < 1,
              child: RepaintBoundary(
                key: captura,
                child: ColoredBox(
                  color: Colors.white,
                  child: ColumnaInicio(
                    children: const [
                      ColoredBox(
                        key: ValueKey('arriba'),
                        color: Colors.red,
                        child: SizedBox(width: 100, height: 100),
                      ),
                      SizedBox(height: 50),
                      ColoredBox(
                        key: ValueKey('abajo'),
                        color: Colors.blue,
                        child: SizedBox(width: 100, height: 100),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await montar(.5);
      final posicion = tester
          .getTopLeft(find.byKey(const ValueKey('abajo')))
          .dy;
      final x = tester
          .getCenter(find.byKey(const ValueKey('arriba')))
          .dx
          .toInt();
      expect(await pixel(tester, x, 30), [244, 67, 54]);
      expect(await pixel(tester, x, 190), [255, 255, 255]);
      await montar(1);
      expect(await pixel(tester, x, 190), [33, 150, 243]);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('abajo'))).dy,
        posicion + 14,
      );
    },
  );
}
