import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/movimiento/coordinador_carta.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/bienvenida/componentes/foco_tutorial.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/componentes/mazo_preguntas.dart';

import '../apoyo/base_pruebas.dart';
import '../apoyo/montar_interfaz.dart';

class _Feedback implements RespuestaInterfaz {
  final efectos = <EfectoInterfaz>[];
  @override
  void emitir(EfectoInterfaz efecto) => efectos.add(efecto);
  @override
  void silenciar() {}
}

Finder _clave(String valor) => find.byKey(ValueKey(valor));
CoordinadorCarta _motor(WidgetTester tester) =>
    tester.widget<MazoPreguntas>(find.byType(MazoPreguntas)).coordinador;

Future<void> _abrir(
  WidgetTester tester, {
  bool movimiento = true,
  RespuestaInterfaz respuesta = const RespuestaSilenciosa(),
}) async {
  await montar(
    tester,
    AlmacenMemoria(),
    animaciones: movimiento,
    respuesta: respuesta,
  );
  await tocar(tester, 'ver-tutorial');
  await tocar(tester, 'tutorial-siguiente');
}

Future<void> _continuarAutomaticamente(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'texto grande deja aire al control y permite leer la explicación y el cierre desde el inicio',
    (tester) async {
      await _abrir(tester);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tocar(tester, 'tutorial-siguiente');
      await tocar(tester, 'tutorial-siguiente');
      final zona = tester.getRect(find.byType(FocoTutorial));
      final boton = tester.getRect(_clave('una-mas'));
      expect(boton.bottom, lessThan(zona.bottom - 12));
      expect(_clave('una-mas').hitTestable(), findsOneWidget);
      final guia = tester.getRect(_clave('tutorial-burbuja'));
      final lectura = find
          .descendant(
            of: _clave('explicacion-3'),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(lectura, const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(lectura).position.pixels,
        greaterThan(0),
      );
      expect(tester.getRect(_clave('tutorial-burbuja')), guia);
      expect(_clave('tutorial-siguiente').hitTestable(), findsOneWidget);
      expect(_clave('tutorial-omitir').hitTestable(), findsOneWidget);
      await tocar(tester, 'tutorial-siguiente');
      await tocar(tester, 'tutorial-siguiente');
      final titulo = tester.getRect(find.text('Qué linda charla.'));
      expect(titulo.top, greaterThanOrEqualTo(zona.top));
      final compartidas = tester.getRect(find.text('Compartidas'));
      final pasadas = tester.getRect(find.text('Pasadas'));
      expect(compartidas.left, pasadas.left);
      expect(pasadas.top, greaterThan(compartidas.bottom));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'tres toques en página 2 confirman una sola carta y esperan el resultado',
    (tester) async {
      final feedback = _Feedback();
      await _abrir(tester, respuesta: feedback);
      feedback.efectos.clear();
      expect(_clave('una-mas').hitTestable(), findsNothing);
      expect(_clave('pasar').hitTestable(), findsNothing);
      final motor = _motor(tester);
      expect(motor.ejecutar(AccionCarta.girar), isFalse);
      expect(motor.ejecutar(AccionCarta.pasar), isFalse);
      await tester.tap(_clave('otra-carta'));
      await tester.pump();
      for (var i = 0; i < 2; i++) {
        await tester.tap(_clave('otra-carta'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 80));
      }
      await tester.pumpAndSettle();
      expect(find.text('2 de 3'), findsOneWidget);
      expect(find.text('2 de 6'), findsOneWidget);
      expect(_clave('cierre-ejemplo'), findsNothing);
      expect(feedback.efectos, [EfectoInterfaz.carta]);
      expect(motor.ejecutar(AccionCarta.avanzar), isFalse);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('2 de 6'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('3 de 6'), findsOneWidget);
      expect(find.text('2 de 3'), findsOneWidget);
      expect(feedback.efectos, [EfectoInterfaz.carta]);
      expect(_clave('otra-carta').hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'arrastre cancelado da una indicación; avance, giro y pasar enseñan y continúan',
    (tester) async {
      final feedback = _Feedback();
      await _abrir(tester, respuesta: feedback);
      await tocar(tester, 'otra-carta');
      await _continuarAutomaticamente(tester);
      feedback.efectos.clear();
      final tarjeta = _clave('tarjeta-visible');
      await tester.timedDragFrom(
        tester.getRect(tarjeta).center,
        const Offset(-45, 0),
        const Duration(milliseconds: 700),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('3 de 6'), findsOneWidget);
      expect(find.text('2 de 3'), findsOneWidget);
      expect(find.textContaining('Así vuelve'), findsOneWidget);
      expect(feedback.efectos, isEmpty);
      await tester.dragFrom(
        tester.getRect(tarjeta).center,
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 de 3'), findsOneWidget);
      expect(find.text('3 de 6'), findsOneWidget);
      await _continuarAutomaticamente(tester);
      expect(find.text('4 de 6'), findsOneWidget);
      expect(_clave('otra-carta').hitTestable(), findsNothing);
      await tocar(tester, 'una-mas');
      expect(_clave('repregunta'), findsOneWidget);
      expect(find.text('4 de 6'), findsOneWidget);
      await _continuarAutomaticamente(tester);
      expect(find.text('5 de 6'), findsOneWidget);
      expect(_clave('repregunta'), findsOneWidget);
      expect(_clave('pasar').hitTestable(), findsOneWidget);
      await tocar(tester, 'pasar');
      expect(find.text('5 de 6'), findsOneWidget);
      await _continuarAutomaticamente(tester);
      expect(find.text('6 de 6'), findsOneWidget);
      expect(_clave('cierre-ejemplo'), findsOneWidget);
      expect(_clave('destacadas'), findsNothing);
      expect(feedback.efectos, [
        EfectoInterfaz.carta,
        EfectoInterfaz.giro,
        EfectoInterfaz.pasar,
      ]);
      await tocar(tester, 'tutorial-siguiente');
    },
  );

  testWidgets('Siguiente, Atrás y Omitir cancelan la continuación pendiente', (
    tester,
  ) async {
    await _abrir(tester);
    await tocar(tester, 'otra-carta');
    await tocar(tester, 'tutorial-siguiente');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('3 de 6'), findsOneWidget);
    await tocar(tester, 'otra-carta');
    await tocar(tester, 'tutorial-atras');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('2 de 6'), findsOneWidget);
    expect(find.text('1 de 3'), findsOneWidget);
    await tocar(tester, 'otra-carta');
    await tocar(tester, 'tutorial-omitir');
    await tester.pump(const Duration(seconds: 2));
    expect(_clave('tutorial-contador'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('segundo plano detiene la espera y preserva un giro confirmado', (
    tester,
  ) async {
    await _abrir(tester);
    await tocar(tester, 'tutorial-siguiente');
    await tocar(tester, 'tutorial-siguiente');
    await tester.tap(_clave('una-mas'));
    await tester.pump(const Duration(milliseconds: 60));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('4 de 6'), findsOneWidget);
    expect(_clave('repregunta'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('4 de 6'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('5 de 6'), findsOneWidget);
    expect(_clave('repregunta'), findsOneWidget);
  });

  testWidgets(
    'el difuminado respeta esquinas y deja libre la trayectoria de la carta',
    (tester) async {
      await _abrir(tester);
      final foco = find.byKey(const ValueKey('tutorial-difuminado'));
      final origen = tester.getTopLeft(foco);
      RecorteFocoTutorial recorte() =>
          tester.widget<ClipPath>(foco).clipper! as RecorteFocoTutorial;
      final carta = tester.getRect(find.byType(MazoPreguntas)).shift(-origen);
      final boton = tester.getRect(_clave('otra-carta')).shift(-origen);
      final formas = recorte().huecos;
      expect(
        formas.any((h) => h.outerRect == carta && h.tlRadiusX == 28),
        isTrue,
      );
      expect(
        formas.any((h) => h.outerRect == boton && h.tlRadiusX == 23),
        isTrue,
      );
      final velo = recorte().getClip(tester.getSize(foco));
      expect(velo.contains(carta.center), isFalse);
      expect(velo.contains(carta.topLeft + const Offset(1, 1)), isTrue);
      expect(velo.contains(boton.center), isFalse);
      expect(velo.contains(const Offset(2, 2)), isTrue);
      final gesto = await tester.startGesture(
        tester.getRect(_clave('tarjeta-visible')).center,
      );
      await gesto.moveBy(const Offset(-24, 0));
      await tester.pump();
      await gesto.moveBy(const Offset(-70, 0));
      await tester.pump();
      final trayectoria = recorte().getClip(tester.getSize(foco));
      final tarjetaMovida = tester
          .getRect(_clave('tarjeta-visible'))
          .shift(-origen);
      expect(tarjetaMovida.left, lessThan(carta.left - 40));
      expect(trayectoria.contains(tarjetaMovida.center), isFalse);
      expect(
        trayectoria.contains(Offset(carta.right + 5, carta.center.dy)),
        isTrue,
        reason: 'El fondo sigue oscuro fuera de las superficies; no aparece un rectángulo claro extra.',
      );
      await gesto.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tocar(tester, 'tutorial-siguiente');
      await tocar(tester, 'tutorial-siguiente');
      final botonGiro = tester.getRect(_clave('una-mas')).shift(-origen);
      final superficieGiro = tester
          .getRect(
            find
                .descendant(
                  of: _clave('una-mas'),
                  matching: find.byType(Material),
                )
                .first,
          )
          .shift(-origen);
      expect(
        botonGiro,
        superficieGiro,
        reason: 'El recorte debe coincidir con el botón pintado, no con un área táctil mayor.',
      );
      expect(
        recorte().huecos.any((h) => h.outerRect == superficieGiro),
        isTrue,
      );
    },
  );
}
