import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/componentes/entrada_inicio.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/configuracion.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/reloj_evaluacion.dart';
import 'package:trivia_antiguedad/tema/paleta_evaluacion.dart';
import 'package:trivia_antiguedad/tema/tema_evaluacion.dart';

void main() {
  testWidgets(
    'cancelar repinta el fondo original y el reloj tras transiciones interrumpidas',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final seleccion = ValueNotifier(ColorEvaluacion.naranja);
      addTearDown(seleccion.dispose);
      final fondo = GlobalKey();
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: seleccion,
          builder: (context, tipo, _) => MaterialApp(
            theme: temaEvaluacion(PaletaEvaluacion(tipo)),
            themeAnimationDuration: duracionCambioPaleta,
            themeAnimationCurve: curvaCambioPaleta,
            home: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  key: fondo,
                  child: const FondoApertura(progreso: 1),
                ),
                const Positioned(
                  left: 40,
                  top: 220,
                  child: RepaintBoundary(
                    child: RelojEvaluacion(
                      restanteMs: 30000,
                      sinIniciar: false,
                      pausado: true,
                      compacto: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(
            'assets/imagenes/optimizadas/conversation-background-v2.webp',
          ),
          fondo.currentContext!,
        ),
      );
      await tester.pumpAndSettle();
      Future<List<int>> pixeles() async {
        late List<int> salida;
        await tester.runAsync(() async {
          final imagen =
              await (fondo.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final datos = (await imagen.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          salida = [
            for (final punto in [
              const Offset(1100, 50),
              const Offset(150, 760),
            ])
              for (var y = punto.dy.toInt(); y < punto.dy + 8; y++)
                for (var x = punto.dx.toInt(); x < punto.dx + 8; x++)
                  for (var canal = 0; canal < 4; canal++)
                    datos.getUint8((y * 1280 + x) * 4 + canal),
          ];
          imagen.dispose();
        });
        return salida;
      }

      CustomPainter reloj() => tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(RelojEvaluacion),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
      final inicial = await pixeles();
      seleccion.value = ColorEvaluacion.amarillo;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final primerReloj = reloj();
      await tester.pump(const Duration(milliseconds: 100));
      expect(reloj().shouldRepaint(primerReloj), isTrue);
      expect(await pixeles(), isNot(inicial));
      seleccion.value = ColorEvaluacion.verde;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      seleccion.value = ColorEvaluacion.naranja;
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        await pixeles(),
        inicial,
        reason: 'Cancelar durante el cambio debe restaurar exactamente ambas esquinas.',
      );
      seleccion.value = ColorEvaluacion.azul;
      await tester.pump();
      await tester.pumpAndSettle();
      expect(await pixeles(), isNot(inicial));
      seleccion.value = ColorEvaluacion.naranja;
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        await pixeles(),
        inicial,
        reason: 'Cancelar después de completar la previsualización también restaura el fondo.',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
