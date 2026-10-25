import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/datos/repositorio_experiencia.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/datos/repositorio_partida.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/dominio/armador_rondas.dart';

import '../apoyo/base_pruebas.dart';
import '../apoyo/montar_interfaz.dart';
import '../apoyo/reloj_prueba.dart';

void main() {
  testWidgets(
    'tutorial automático una sola vez y repetición preserva la ronda',
    (tester) async {
      final almacen = AlmacenMemoria();
      final catalogo = catalogoReal();
      final partida = ArmadorRondas.crear(
        catalogo,
        nivel: 2,
        cantidad: 12,
      ).avanzar(milisegundos: 12000);
      await RepositorioPartida(almacen).guardar(partida, catalogo);
      await montar(tester, almacen, primeraVez: true);
      expect(find.text('1 de 6'), findsOneWidget);
      for (var paso = 0; paso < 6; paso++) {
        await tocar(tester, 'tutorial-siguiente');
      }
      expect(find.text('Hay mucho\npor contar.'), findsOneWidget);
      expect(
        (await RepositorioExperiencia(almacen).cargar()).tutorialVisto,
        isTrue,
      );
      await tocar(tester, 'ver-tutorial');
      expect(find.text('1 de 6'), findsOneWidget);
      await tocar(tester, 'tutorial-omitir');
      final guardada = (await RepositorioPartida(almacen).cargar(catalogo))
          .partida!;
      expect(guardada.toJson(), partida.toJson());
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await montar(tester, almacen, primeraVez: true);
      expect(find.byKey(const ValueKey('tutorial-contador')), findsNothing);
      expect(find.text('Hay mucho\npor contar.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('guía con letra grande conserva siguiente, omitir y pasos', (
    tester,
  ) async {
    await montar(tester, AlmacenMemoria());
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tocar(tester, 'ver-tutorial');
    for (var paso = 0; paso < 6; paso++) {
      expect(find.text('${paso + 1} de 6'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tutorial-omitir')).hitTestable(),
        findsOneWidget,
      );
      await tocar(tester, 'tutorial-siguiente');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('silencio persiste y puede activarse de nuevo', (tester) async {
    final almacen = AlmacenMemoria();
    await montar(tester, almacen);
    await tester.tap(find.byTooltip('Silenciar sonidos'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Activar sonidos'), findsOneWidget);
    expect((await RepositorioExperiencia(almacen).cargar()).sonidos, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await montar(tester, almacen);
    expect(find.byTooltip('Activar sonidos'), findsOneWidget);
    await tester.tap(find.byTooltip('Activar sonidos'));
    await tester.pumpAndSettle();
    expect((await RepositorioExperiencia(almacen).cargar()).sonidos, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android en segundo plano y el menú no suman tiempo de carta', (
    tester,
  ) async {
    final almacen = AlmacenMemoria();
    final reloj = RelojPrueba();
    await montar(tester, almacen, reloj: reloj);
    await tocar(tester, 'empezar');
    reloj.pasar(3000);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    reloj.pasar(600000);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    reloj.pasar(2000);
    await tocar(tester, 'otra-carta');
    await tester.tap(find.byTooltip('Elegir nivel'));
    await tester.pumpAndSettle();
    expect(reloj.activo, isFalse);
    reloj.pasar(400000);
    final partida = (await RepositorioPartida(almacen).cargar(catalogoReal()))
        .partida!;
    expect(partida.tiemposMs[partida.cartas.first], 5000);
    expect(partida.indice, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('movimiento real cambia cartas y conserva la cabecera', (
    tester,
  ) async {
    await montar(tester, AlmacenMemoria(), animaciones: true);
    await tester.ensureVisible(find.byKey(const ValueKey('empezar')));
    await tester.tap(find.byKey(const ValueKey('empezar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    final cabecera = tester.getRect(find.text('Trivia de la antiguedad'));
    await tester.ensureVisible(find.byKey(const ValueKey('otra-carta')));
    await tester.tap(find.byKey(const ValueKey('otra-carta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.text('2 de 12'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.getRect(find.text('Trivia de la antiguedad')), cabecera);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
