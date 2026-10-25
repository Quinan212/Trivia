import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/componentes/entrada_inicio.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/bienvenida/pantallas/pantalla_tutorial.dart';

import '../apoyo/base_pruebas.dart';
import '../apoyo/montar_interfaz.dart';

class _Audio implements RespuestaInterfaz {
  final efectos = <EfectoInterfaz>[];
  @override
  void emitir(EfectoInterfaz efecto) => efectos.add(efecto);
  @override
  void silenciar() {}
}

EntradaInicio _reloj(WidgetTester tester, String key) =>
    tester.widget(find.byKey(ValueKey(key), skipOffstage: false));

void main() {
  testWidgets('salir cancela la pista pendiente durante el recorrido inverso', (
    tester,
  ) async {
    final audio = _Audio();
    await montar(tester, AlmacenMemoria(), animaciones: true, respuesta: audio);
    await tocar(tester, 'ver-tutorial');
    await tocar(tester, 'tutorial-siguiente');
    await tocar(tester, 'tutorial-siguiente');
    audio.efectos.clear();
    await tocar(tester, 'tutorial-omitir');
    await tester.pump(const Duration(seconds: 2));
    expect(audio.efectos, [EfectoInterfaz.tutorialOmitir]);
    expect(find.byType(PantallaTutorial), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'tutorial retira el menú y revela los bloques sobre un solo fondo',
    (tester) async {
      final audio = _Audio();
      await montar(
        tester,
        AlmacenMemoria(),
        animaciones: true,
        respuesta: audio,
      );
      audio.efectos.clear();
      final fondo = tester.getRect(
        find.byKey(const ValueKey('textura-apertura')),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('ver-tutorial')));
      await tester.tap(find.byKey(const ValueKey('ver-tutorial')));
      await tester.tap(
        find.byKey(const ValueKey('ver-tutorial')),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester
          .pump(); // Termina la medición inicial de la ruta fuera de escena.
      expect(_reloj(tester, 'entrada-tutorial').progreso, 0);
      await tester.pump(const Duration(milliseconds: 180));
      expect(_reloj(tester, 'entrada-pantalla-inicial').progreso, lessThan(1));
      expect(_reloj(tester, 'entrada-tutorial').progreso, 0);
      expect(
        find.byKey(const ValueKey('tutorial-siguiente')).hitTestable(),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 220));
      final p = _reloj(tester, 'entrada-tutorial').progreso;
      expect(p, inExclusiveRange(0, .45));
      expect(_reloj(tester, 'entrada-pantalla-inicial').progreso, 0);
      final tutorial = find.byType(PantallaTutorial);
      expect(
        find.ancestor(of: tutorial, matching: find.byType(FadeTransition)),
        findsNothing,
      );
      expect(
        find.ancestor(of: tutorial, matching: find.byType(SlideTransition)),
        findsNothing,
      );
      expect(find.byType(FondoApertura), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('textura-apertura'))),
        fondo,
      );
      await tester.pumpAndSettle();
      expect(audio.efectos, [EfectoInterfaz.abrirTutorial]);
      expect(
        find.byKey(const ValueKey('tutorial-siguiente')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('tutorial-omitir')));
      await tester.tap(
        find.byKey(const ValueKey('tutorial-omitir')),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        _reloj(tester, 'entrada-tutorial').progreso,
        inExclusiveRange(0, 1),
      );
      expect(_reloj(tester, 'entrada-pantalla-inicial').progreso, 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_reloj(tester, 'entrada-tutorial').progreso, 0);
      expect(
        _reloj(tester, 'entrada-pantalla-inicial').progreso,
        inExclusiveRange(0, 1),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PantallaTutorial), findsNothing);
      expect(_reloj(tester, 'entrada-pantalla-inicial').progreso, 1);
      expect(
        tester.getRect(find.byKey(const ValueKey('textura-apertura'))),
        fondo,
      );
      expect(audio.efectos, [
        EfectoInterfaz.abrirTutorial,
        EfectoInterfaz.tutorialOmitir,
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('entrada y salida del tutorial se suspenden en segundo plano', (
    tester,
  ) async {
    await montar(tester, AlmacenMemoria(), animaciones: true);
    await tester.ensureVisible(find.byKey(const ValueKey('ver-tutorial')));
    await tester.tap(find.byKey(const ValueKey('ver-tutorial')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    final entrada = _reloj(tester, 'entrada-tutorial').progreso;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 4));
    expect(_reloj(tester, 'entrada-tutorial').progreso, entrada);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final salida = _reloj(tester, 'entrada-tutorial').progreso;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 4));
    expect(_reloj(tester, 'entrada-tutorial').progreso, salida);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(PantallaTutorial), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'movimiento reducido y completar conservan el sonido de cada acción',
    (tester) async {
      final audio = _Audio();
      await montar(tester, AlmacenMemoria(), respuesta: audio);
      audio.efectos.clear();
      await tocar(tester, 'ver-tutorial');
      expect(_reloj(tester, 'entrada-tutorial').progreso, 1);
      for (var i = 0; i < 6; i++) {
        await tocar(tester, 'tutorial-siguiente');
      }
      expect(find.byType(PantallaTutorial), findsNothing);
      expect(audio.efectos, [
        EfectoInterfaz.abrirTutorial,
        ...List.filled(5, EfectoInterfaz.tutorialSiguiente),
        EfectoInterfaz.tutorialCompletar,
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}
