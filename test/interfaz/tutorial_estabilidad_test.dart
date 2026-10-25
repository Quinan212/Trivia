import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/componentes/mazo_preguntas.dart';
import 'package:trivia_antiguedad/tema/iconos_trivia_antiguedad.dart';

import '../apoyo/base_pruebas.dart';
import '../apoyo/montar_interfaz.dart';

class _Sonidos implements RespuestaInterfaz {
  final efectos = <EfectoInterfaz>[];
  @override
  void emitir(EfectoInterfaz efecto) => efectos.add(efecto);
  @override
  void silenciar() {}
}

void main() {
  testWidgets(
    'cada selección tiene sonido propio y los niveles no tienen flechas',
    (tester) async {
      final sonido = _Sonidos();
      await montar(tester, AlmacenMemoria(), respuesta: sonido);
      sonido.efectos.clear();
      for (final clave in [
        'nivel-1',
        'nivel-2',
        'nivel-3',
        'ronda-12',
        'ronda-25',
      ]) {
        await tocar(tester, clave);
        if (clave.startsWith('nivel')) {
          expect(
            find.descendant(
              of: find.byKey(ValueKey(clave)),
              matching: find.byIcon(IconosTriviaAntiguedad.arrowRight),
            ),
            findsNothing,
          );
        }
      }
      expect(sonido.efectos, [
        EfectoInterfaz.nivelSuave,
        EfectoInterfaz.nivelMedio,
        EfectoInterfaz.nivelProfundo,
        EfectoInterfaz.rondaCorta,
        EfectoInterfaz.rondaLarga,
      ]);
      expect(sonido.efectos.toSet().length, 5);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('empezar')),
          matching: find.byIcon(IconosTriviaAntiguedad.arrowRight),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tutorial conserva medidas desde el primer frame y durante gestos, resultados y giros',
    (tester) async {
      await montar(tester, AlmacenMemoria(), animaciones: true);
      tester.view.physicalSize = const Size(411, 914);
      await tester.pumpAndSettle();
      await tocar(tester, 'empezar');
      final anchoGiro = tester
          .getSize(find.byKey(const ValueKey('una-mas')))
          .width;
      final altoControles = tester.getSize(find.byType(ControlesCarta)).height;
      await tester.tap(find.byTooltip('Elegir nivel'));
      await tester.pumpAndSettle();
      await tocar(tester, 'ver-tutorial');
      final guia = find.byKey(const ValueKey('tutorial-burbuja'));
      var rectGuia = tester.getRect(guia);
      await tester.tap(find.byKey(const ValueKey('tutorial-siguiente')));
      await tester.pumpAndSettle();
      rectGuia = tester.getRect(guia);
      final rectMazo = tester.getRect(find.byType(MazoPreguntas));
      final rectControles = tester.getRect(find.byType(ControlesCarta));
      Color? colorAvance() => tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('otra-carta')),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;
      final colorInicial = colorAvance();

      void comprobar() {
        expect(tester.getRect(guia), rectGuia);
        expect(tester.getRect(find.byType(MazoPreguntas)), rectMazo);
        expect(tester.getRect(find.byType(ControlesCarta)), rectControles);
        expect(
          tester.getSize(find.byKey(const ValueKey('una-mas'))).width,
          anchoGiro,
        );
        expect(rectControles.height, altoControles);
        expect(
          colorAvance(),
          colorInicial,
          reason: 'No apagar y encender los controles durante cada acción.',
        );
        final accion = find.text('4 de 6').evaluate().isNotEmpty
            ? 'una-mas'
            : find.text('5 de 6').evaluate().isNotEmpty
            ? 'pasar'
            : 'otra-carta';
        expect(
          tester.getRect(find.byKey(ValueKey(accion))).bottom,
          lessThan(rectGuia.top),
        );
        expect(tester.takeException(), isNull);
      }

      Future<void> cuadros(int cantidad) async {
        for (var i = 0; i < cantidad; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          comprobar();
        }
      }

      await cuadros(
        4,
      ); // Incluye la segunda pasada donde antes se corregía altura.
      await tocar(tester, 'tutorial-siguiente');
      rectGuia = tester.getRect(guia);
      comprobar();
      final carta = find.byKey(const ValueKey('tarjeta-visible'));
      final dedo = await tester.startGesture(tester.getRect(carta).center);
      await dedo.moveBy(const Offset(-55, 0));
      await cuadros(4);
      await dedo.up();
      await cuadros(45);
      expect(find.text('1 de 3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('otra-carta')));
      await cuadros(
        30,
      ); // Resultado, salida y asentamiento en el mismo espacio.
      expect(find.text('2 de 3'), findsOneWidget);
      expect(find.text('3 de 6'), findsOneWidget);
      await tocar(tester, 'tutorial-siguiente');
      rectGuia = tester.getRect(guia);
      comprobar();
      await tester.tap(find.byKey(const ValueKey('una-mas')));
      await cuadros(24);
      expect(find.byKey(const ValueKey('repregunta')), findsOneWidget);
      await cuadros(24);
      await tocar(tester, 'tutorial-siguiente');
      rectGuia = tester.getRect(guia);
      comprobar();
      await tester.tap(find.byKey(const ValueKey('pasar')));
      await cuadros(30);
      expect(find.text('5 de 6'), findsOneWidget);
      await tocar(tester, 'tutorial-siguiente');
      expect(
        tester.getRect(guia).bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
      expect(find.byKey(const ValueKey('cierre-ejemplo')), findsOneWidget);
      expect(find.byKey(const ValueKey('destacadas')), findsNothing);
      expect(find.byKey(const ValueKey('duracion-activa')), findsNothing);
      expect(find.text('A SU RITMO'), findsNothing);
    },
  );
}
