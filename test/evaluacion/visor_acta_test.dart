import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/visor_acta.dart';
import 'package:trivia_antiguedad/tema/tema_trivia_antiguedad.dart';

void main() {
  testWidgets('visor ajusta la página y navega desde el lateral sin franjas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final png = File('assets/imagenes/iconos-unidad-iv/evaluacion.png')
        .readAsBytesSync();
    final rasterizadas = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaTriviaAntiguedad.claro,
        home: VistaActa(
          bytes: png,
          nombre: 'muestra.pdf',
          paginas: 3,
          rasterizar: (pagina) async {
            rasterizadas.add(pagina);
            return png;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    Finder clave(String nombre) => find.byKey(ValueKey(nombre));
    IconButton boton(String nombre) => tester.widget<IconButton>(clave(nombre));

    void verificarAjuste(Size pantalla) {
      final pagina = tester.getRect(clave('pagina-pdf-0'));
      expect(pagina.top, greaterThanOrEqualTo(16));
      expect(pagina.bottom, lessThanOrEqualTo(pantalla.height - 16));
      expect(pagina.center.dx, closeTo(pantalla.width / 2, .01));
      for (final accion in [
        'volver',
        'anterior',
        'siguiente',
        'descargar',
        'compartir',
        'imprimir',
      ]) {
        final rect = tester.getRect(clave('visor-$accion'));
        expect(rect.left, greaterThan(pantalla.width - 88));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(pantalla.height));
      }
      expect(tester.takeException(), isNull);
    }

    expect(find.byType(AppBar), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar,
      isNull,
    );
    expect(find.text('1/3'), findsOneWidget);
    expect(boton('visor-anterior').onPressed, isNull);
    verificarAjuste(const Size(1280, 800));
    final transformacion = tester
        .widget<InteractiveViewer>(clave('visor-documento'))
        .transformationController!;
    transformacion.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.tap(clave('visor-siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
    expect(transformacion.value, Matrix4.identity());
    await tester.tap(clave('visor-anterior'));
    await tester.pumpAndSettle();
    expect(rasterizadas, [0, 1]);
    await tester.tap(clave('visor-siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(clave('visor-siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);
    expect(boton('visor-siguiente').onPressed, isNull);
    await tester.tap(clave('visor-anterior'));
    await tester.pumpAndSettle();
    await tester.tap(clave('visor-anterior'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(800, 1280);
    await tester.pumpAndSettle();
    verificarAjuste(const Size(800, 1280));
  });
}
