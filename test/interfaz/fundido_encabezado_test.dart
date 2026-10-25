import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/componentes/desplazamiento_con_fundido.dart';
import 'package:trivia_antiguedad/compartido/componentes/fondo_conversacion.dart';

import '../apoyo/base_pruebas.dart';
import '../apoyo/montar_interfaz.dart';

const _captura = ValueKey('captura-fundido');

Future<List<int>> _opacidades(WidgetTester tester, List<int> filas) async {
  final caja = tester.renderObject<RenderRepaintBoundary>(find.byKey(_captura));
  return (await tester.runAsync(() async {
    final imagen = await caja.toImage(pixelRatio: 1);
    final datos = (await imagen.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final valores = [
      for (final y in filas)
        datos.getUint8((y * imagen.width + imagen.width ~/ 2) * 4 + 3),
    ];
    imagen.dispose();
    return valores;
  }))!;
}

Widget _pantalla(Widget child) => MaterialApp(
  home: FondoConversacion(
    sonido: false,
    child: RepaintBoundary(key: _captura, child: child),
  ),
);

void main() {
  testWidgets('el borde desvanece al subir y recupera opacidad al volver', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _pantalla(
        DesplazamientoConFundido(
          controller: scroll,
          child: const ColoredBox(
            color: Colors.blue,
            child: SizedBox(height: 2000, width: double.infinity),
          ),
        ),
      ),
    );
    final encabezado = tester.getRect(find.text('Trivia de la antiguedad'));
    expect(await _opacidades(tester, [0, 18, 35, 40]), [255, 255, 255, 255]);
    scroll.jumpTo(36);
    await tester.pump();
    final completo = await _opacidades(tester, [0, 18, 35, 40]);
    expect(completo[0], lessThan(10));
    expect(completo[1], inInclusiveRange(100, 200));
    expect(completo[2], greaterThan(245));
    expect(completo[3], 255);
    scroll.jumpTo(9);
    await tester.pump();
    final retorno = await _opacidades(tester, [4, 10, 18]);
    expect(retorno[0], inInclusiveRange(80, 220));
    expect(retorno.skip(1), everyElement(255));
    scroll.jumpTo(0);
    await tester.pump();
    expect(await _opacidades(tester, [0, 18, 40]), [255, 255, 255]);
    expect(tester.getRect(find.text('Trivia de la antiguedad')), encabezado);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cambiar contenido reinicia lectura y fundido sin reemplazar scroll',
    (tester) async {
      Widget contenido(int numero) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: CuerpoDesplazable(
          arriba: 0,
          contenido: numero,
          child: const ColoredBox(
            color: Colors.blue,
            child: SizedBox(height: 2000, width: double.infinity),
          ),
        ),
      );
      await tester.pumpWidget(_pantalla(contenido(1)));
      final posicion = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      posicion.jumpTo(120);
      await tester.pump();
      expect((await _opacidades(tester, [0])).single, lessThan(10));
      await tester.pumpWidget(_pantalla(contenido(2)));
      await tester.pump();
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position,
        same(posicion),
      );
      expect(posicion.pixels, 0);
      expect((await _opacidades(tester, [0])).single, 255);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leer dentro de una carta no activa el fundido del encabezado', (
    tester,
  ) async {
    final exterior = ScrollController();
    final interior = ScrollController();
    addTearDown(exterior.dispose);
    addTearDown(interior.dispose);
    await tester.pumpWidget(
      _pantalla(
        DesplazamientoConFundido(
          controller: exterior,
          child: SizedBox(
            height: 180,
            child: SingleChildScrollView(
              controller: interior,
              child: const ColoredBox(
                color: Colors.blue,
                child: SizedBox(height: 1000, width: double.infinity),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    expect(interior.offset, greaterThan(0));
    expect(exterior.offset, 0);
    expect((await _opacidades(tester, [0])).single, 255);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'leer la guía no desplaza práctica ni bloquea navegación accesible',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await montar(tester, AlmacenMemoria());
      await tocar(tester, 'ver-tutorial');
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tocar(tester, 'tutorial-siguiente');
      }
      final guia = find.byKey(const ValueKey('tutorial-burbuja'));
      final rectGuia = tester.getRect(guia);
      final encabezado = tester.getRect(find.text('Trivia de la antiguedad'));
      final exterior = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(DesplazamientoConFundido),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      final inicio = exterior.pixels;
      final lectura = find
          .descendant(of: guia, matching: find.byType(Scrollable))
          .first;
      await tester.drag(lectura, const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(lectura).position.pixels,
        greaterThan(0),
      );
      expect(exterior.pixels, inicio);
      expect(tester.getRect(guia), rectGuia);
      expect(tester.getRect(find.text('Trivia de la antiguedad')), encabezado);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('tutorial-siguiente')))
            .toStringDeep(),
        contains('Siguiente'),
      );
      await tocar(tester, 'tutorial-siguiente');
      expect(find.text('5 de 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
