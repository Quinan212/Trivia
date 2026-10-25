import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../apoyo/base_pruebas.dart';
import '../apoyo/montar_interfaz.dart';

void main() {
  testWidgets('Ayuda abre la política local y vuelve sin alterar la partida', (
    tester,
  ) async {
    final texto = await tester.runAsync(
      () => rootBundle.loadString('assets/contenido/politica-privacidad.txt'),
    );
    expect(texto, File('docs/politica-privacidad.md').readAsStringSync());
    final almacen = AlmacenMemoria();
    await montar(tester, almacen);
    final antes = Map<String, String>.from(almacen.datos);
    await tester.tap(find.byTooltip('Cómo jugar'));
    await tester.pumpAndSettle();
    final acceso = find.byKey(const ValueKey('privacidad-desde-ayuda'));
    await tester.ensureVisible(acceso);
    await tester.tap(acceso);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
      () => rootBundle.loadString('assets/contenido/politica-privacidad.txt'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Podés consultar esta política sin conexión.'),
      findsOneWidget,
    );
    expect(find.text('Información guardada en el dispositivo'), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);
    await tester.ensureVisible(find.text('Volver'));
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Así se juega'), findsOneWidget);
    expect(almacen.datos, antes);
    expect(tester.takeException(), isNull);
  });
}
