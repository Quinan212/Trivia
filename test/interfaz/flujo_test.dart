import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/datos/repositorio_partida.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/dominio/armador_rondas.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/modelos/estado_partida.dart';

import '../apoyo/base_pruebas.dart';
import '../apoyo/montar_interfaz.dart';

void main() {
  testWidgets('inicio, repregunta, pasar, volver, retomar y resumen', (
    tester,
  ) async {
    await montar(tester, AlmacenMemoria());
    expect(find.text('Hay mucho\npor contar.'), findsOneWidget);
    await tocar(tester, 'empezar');
    expect(find.text('1 de 12'), findsOneWidget);
    await tocar(tester, 'una-mas');
    expect(find.byKey(const ValueKey('repregunta')), findsOneWidget);
    await tester.tap(find.text('Volver a la carta'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 12'), findsOneWidget);
    await tocar(tester, 'pasar');
    expect(find.text('2 de 12'), findsOneWidget);
    await tester.tap(find.byTooltip('Elegir nivel'));
    await tester.pumpAndSettle();
    expect(find.text('Seguir charlando'), findsOneWidget);
    await tocar(tester, 'empezar');
    expect(find.text('2 de 12'), findsOneWidget);
    for (var i = 0; i < 11; i++) {
      await tocar(tester, 'otra-carta');
    }
    expect(find.byKey(const ValueKey('fin-ronda')), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('dos toques al empezar abren una sola pantalla', (tester) async {
    await montar(
      tester,
      AlmacenMemoria()..demora = const Duration(milliseconds: 30),
    );
    final boton = find.byKey(const ValueKey('empezar'));
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(find.text('1 de 12'), findsOneWidget);
    await tester.tap(find.byTooltip('Elegir nivel'));
    await tester.pumpAndSettle();
    expect(find.text('Hay mucho\npor contar.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consignas completas y ayuda disponibles', (tester) async {
    await montar(tester, AlmacenMemoria());
    await tester.tap(find.byTooltip('Cómo jugar'));
    await tester.pumpAndSettle();
    expect(find.text('Así se juega'), findsOneWidget);
    await tester.ensureVisible(find.text('Dale, entendido'));
    await tester.tap(find.text('Dale, entendido'));
    await tester.pumpAndSettle();
    await tocar(tester, 'consignas');
    expect(find.text('1 de 15'), findsOneWidget);
    for (var i = 0; i < 15; i++) {
      await tocar(tester, 'otra-carta');
    }
    expect(find.byKey(const ValueKey('fin-ronda')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('pantalla chica con texto grande conserva acceso a controles', (
    tester,
  ) async {
    await montar(tester, AlmacenMemoria());
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tocar(tester, 'empezar');
    await tocar(tester, 'pasar');
    expect(find.text('2 de 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('B09 mantiene los adornos fuera del texto en distintos tamaños', (
    tester,
  ) async {
    final catalogo = catalogoReal();
    final almacen = AlmacenMemoria();
    final base = ArmadorRondas.crear(
      catalogo,
      nivel: 2,
      cantidad: 12,
      ronda: 1,
    );
    // Esta prueba comprueba el layout de B09, independientemente del orden
    // que use el catálogo ampliado para las rondas nuevas.
    final partida = EstadoPartida.fromJson({
      ...base.toJson(),
      'cartas': [
        'B09',
        ...catalogo
            .deNivel(2)
            .where((carta) => carta.id != 'B09')
            .take(11)
            .map((carta) => carta.id),
      ],
    }, catalogo);
    expect(partida.cartaActual, 'B09');
    await RepositorioPartida(almacen).guardar(partida, catalogo);
    await montar(tester, almacen);
    await tocar(tester, 'empezar');
    expect(find.text(catalogo.porId['B09']!.texto), findsOneWidget);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final tamano in [
      const Size(320, 640),
      const Size(411, 914),
      const Size(600, 1100),
    ]) {
      tester.view.physicalSize = tamano;
      for (final escala in [1.0, 1.6, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = escala;
        await tester.pumpAndSettle();
        final adorno = tester.getRect(
          find.byKey(const ValueKey('adorno-pregunta')),
        );
        final pregunta = tester.getRect(find.byKey(const ValueKey('pregunta')));
        expect(adorno.bottom, lessThan(pregunta.top));
        expect(adorno.overlaps(pregunta), isFalse);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
