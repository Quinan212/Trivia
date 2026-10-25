import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivia_antiguedad/compartido/movimiento/coordinador_carta.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/componentes/mazo_preguntas.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/controladores/controlador_partida.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/datos/repositorio_partida.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/datos/repositorio_experiencia.dart';

import '../apoyo/base_pruebas.dart';
import '../apoyo/montar_interfaz.dart';
import '../apoyo/reloj_prueba.dart';

class RegistroRespuesta implements RespuestaInterfaz {
  final efectos = <EfectoInterfaz>[];
  @override
  void emitir(EfectoInterfaz efecto) => efectos.add(efecto);
  @override
  void silenciar() {}
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MazoPreguntas)));
CoordinadorCarta _motor(WidgetTester tester) =>
    tester.widget<MazoPreguntas>(find.byType(MazoPreguntas)).coordinador;
Finder get _tarjeta => find.byKey(const ValueKey('tarjeta-visible'));

void main() {
  testWidgets(
    'cuatro colores opacos, misma cara al girar y próximo color visible en el mazo',
    (tester) async {
      await montar(tester, AlmacenMemoria(), animaciones: true);
      await tocar(tester, 'empezar');
      Color color(Finder superficie) =>
          (tester.widget<DecoratedBox>(superficie).decoration as BoxDecoration)
              .color!;
      final colores = <Color>{};
      for (var i = 0; i < 4; i++) {
        final actual = color(_tarjeta);
        expect(actual.a, 1);
        colores.add(actual);
        if (_motor(tester).hayRepregunta) {
          await tocar(tester, 'una-mas');
          expect(color(_tarjeta), actual);
          await tocar(tester, 'una-mas');
          expect(color(_tarjeta), actual);
        }
        final siguiente = color(find.byKey(const ValueKey('mazo-detras-1')));
        await tocar(tester, 'otra-carta');
        expect(color(_tarjeta), siguiente);
      }
      expect(colores.length, 4);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'mazo, acciones y adornos ocupan zonas separadas en las nueve configuraciones',
    (tester) async {
      await montar(tester, AlmacenMemoria());
      await tocar(tester, 'empezar');
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
          await tester.ensureVisible(find.byKey(const ValueKey('pasar')));
          await tester.pumpAndSettle();
          final pie = tester.getRect(find.byKey(const ValueKey('adorno-pie')));
          final pasar = tester.getRect(find.byKey(const ValueKey('pasar')));
          final avanzar = tester.getRect(
            find.byKey(const ValueKey('otra-carta')),
          );
          expect(pasar.bottom, lessThan(pie.top));
          expect(avanzar.bottom, lessThan(pie.top));
          expect(pasar.overlaps(avanzar), isFalse);
          expect(tester.getRect(_tarjeta).height, inInclusiveRange(180, 480));
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'tutorial completo conserva objetivo y navegación sin superposición en nueve configuraciones',
    (tester) async {
      await montar(tester, AlmacenMemoria());
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
          await tocar(tester, 'ver-tutorial');
          for (var paso = 0; paso < 6; paso++) {
            final burbuja = tester.getRect(
              find.byKey(const ValueKey('tutorial-burbuja')),
            );
            expect(
              find.byKey(const ValueKey('tutorial-siguiente')).hitTestable(),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('tutorial-omitir')).hitTestable(),
              findsOneWidget,
            );
            if (paso == 1 || paso == 2) {
              expect(tester.getRect(_tarjeta).overlaps(burbuja), isFalse);
            }
            if (paso == 3 || paso == 4) {
              final accion = find.text(paso == 3 ? 'Una más' : 'Esta la paso');
              await tester.ensureVisible(accion);
              await tester.pumpAndSettle();
              expect(accion.hitTestable(), findsOneWidget);
              expect(tester.getRect(accion).overlaps(burbuja), isFalse);
              await tester.tap(accion);
              await tester.pumpAndSettle();
              expect(find.text('${paso + 1} de 6'), findsOneWidget);
            }
            await tocar(tester, 'tutorial-siguiente');
            expect(
              tester.takeException(),
              isNull,
              reason: 'Pantalla $tamano, escala $escala, paso ${paso + 1}',
            );
          }
        }
      }
    },
  );
  testWidgets(
    'lectura vertical y cambios larga/corta mantienen altura y reinician solo la carta nueva',
    (tester) async {
      await montar(tester, AlmacenMemoria(), animaciones: true);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tocar(tester, 'experimentos');
      final altura = tester.getRect(_tarjeta).height;
      await tester.dragFrom(
        tester.getRect(_tarjeta).center,
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      final desplazable = find.descendant(
        of: _tarjeta,
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(desplazable).position.pixels,
        greaterThan(0),
      );
      await tocar(tester, 'otra-carta');
      expect(tester.state<ScrollableState>(desplazable).position.pixels, 0);
      expect(tester.getRect(_tarjeta).height, altura);
      await tester.ensureVisible(_tarjeta);
      await tester.pumpAndSettle();
      await tester.dragFrom(
        tester.getRect(_tarjeta).center,
        const Offset(0, -190),
      );
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(desplazable).position.pixels,
        greaterThan(0),
      );
      await tocar(tester, 'otra-carta');
      expect(tester.state<ScrollableState>(desplazable).position.pixels, 0);
      expect(tester.getRect(_tarjeta).height, altura);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'navegar durante salida retoma el índice confirmado; fallo de guardado no traba el mazo',
    (tester) async {
      final almacen = AlmacenMemoria();
      await montar(tester, almacen, animaciones: true);
      await tocar(tester, 'empezar');
      await tester.tap(find.byKey(const ValueKey('otra-carta')));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.byTooltip('Elegir nivel'));
      await tester.pumpAndSettle();
      await tocar(tester, 'empezar');
      expect(find.text('2 de 12'), findsOneWidget);
      almacen.fallar = true;
      await tocar(tester, 'otra-carta');
      expect(find.text('3 de 12'), findsOneWidget);
      expect(_motor(tester).fase, FaseCarta.reposo);
      expect(
        find.text(
          'La ronda sigue abierta, pero no pudimos guardar los cambios.',
        ),
        findsOneWidget,
      );
      almacen.fallar = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      final partida = (await RepositorioPartida(almacen).cargar(catalogoReal()))
          .partida!;
      expect(partida.indice, 2);
      expect(tester.takeException(), isNull);
    },
  );
  test('distancia y velocidad confirman solamente hacia la izquierda', () {
    expect(CoordinadorCarta.confirmaArrastre(-112, 0, 400), isTrue);
    expect(CoordinadorCarta.confirmaArrastre(-111, -899, 400), isFalse);
    expect(CoordinadorCarta.confirmaArrastre(-48, -901, 400), isTrue);
    expect(CoordinadorCarta.confirmaArrastre(-47, -2000, 400), isFalse);
    expect(CoordinadorCarta.confirmaArrastre(200, 1800, 400), isFalse);
  });

  testWidgets(
    'arrastre corto, derecho, diagonal vertical y cancelado conservan la carta',
    (tester) async {
      final almacen = AlmacenMemoria();
      final registro = RegistroRespuesta();
      await montar(tester, almacen, animaciones: true, respuesta: registro);
      await tocar(tester, 'empezar');
      registro.efectos.clear();
      final rect = tester.getRect(_tarjeta);
      for (final desplazamiento in [
        const Offset(-35, 0),
        const Offset(120, 0),
        const Offset(-12, -90),
      ]) {
        await tester.timedDragFrom(
          rect.center,
          desplazamiento,
          const Duration(milliseconds: 400),
        );
        await tester.pumpAndSettle();
        expect(
          _container(tester).read(partidaProvider).requireValue.partida!.indice,
          0,
        );
        expect(_motor(tester).desplazamiento, 0);
      }
      final dedo = await tester.startGesture(rect.center);
      await dedo.moveBy(const Offset(-80, 0));
      await tester.pump();
      await dedo.cancel();
      await tester.pumpAndSettle();
      expect(find.text('1 de 12'), findsOneWidget);
      expect(registro.efectos, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'botón durante gesto y doble toque producen un avance y un efecto',
    (tester) async {
      final registro = RegistroRespuesta();
      await montar(
        tester,
        AlmacenMemoria(),
        animaciones: true,
        respuesta: registro,
      );
      await tocar(tester, 'empezar');
      registro.efectos.clear();
      final motor = _motor(tester);
      motor.comenzarArrastre();
      motor.arrastrar(-160);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('otra-carta')));
      await tester.pump();
      motor.soltar(-1200);
      await tester.tap(
        find.byKey(const ValueKey('otra-carta')),
        warnIfMissed: false,
      );
      expect(
        _container(tester).read(partidaProvider).requireValue.partida!.indice,
        1,
      );
      await tester.pumpAndSettle();
      expect(registro.efectos, [EfectoInterfaz.carta]);
      expect(find.text('2 de 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('un segundo dedo cancela sin avanzar ni emitir feedback', (
    tester,
  ) async {
    final registro = RegistroRespuesta();
    await montar(
      tester,
      AlmacenMemoria(),
      animaciones: true,
      respuesta: registro,
    );
    await tocar(tester, 'empezar');
    registro.efectos.clear();
    final centro = tester.getRect(_tarjeta).center;
    final uno = await tester.startGesture(centro, pointer: 1);
    await uno.moveBy(const Offset(-50, 0));
    await tester.pump();
    final dos = await tester.startGesture(
      centro + const Offset(20, 30),
      pointer: 2,
    );
    await uno.moveBy(const Offset(-150, 0));
    await dos.up();
    await uno.up();
    await tester.pumpAndSettle();
    expect(find.text('1 de 12'), findsOneWidget);
    expect(registro.efectos, isEmpty);
  });

  testWidgets(
    'avance real por velocidad y arrastre largo, desde reverso y sin cartas ficticias',
    (tester) async {
      await montar(tester, AlmacenMemoria(), animaciones: true);
      await tocar(tester, 'experimentos');
      expect(find.byKey(const ValueKey('mazo-detras-2')), findsOneWidget);
      await tester.flingFrom(
        tester.getRect(_tarjeta).center,
        const Offset(-72, 0),
        1500,
      );
      await tester.pumpAndSettle();
      expect(find.text('2 de 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('mazo-detras-2')), findsNothing);
      await tocar(tester, 'una-mas');
      expect(find.byKey(const ValueKey('repregunta')), findsOneWidget);
      await tester.dragFrom(
        tester.getRect(_tarjeta).center,
        const Offset(-190, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 de 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('repregunta')), findsNothing);
      expect(find.byKey(const ValueKey('mazo-detras-1')), findsNothing);
      expect(find.text('Cómo jugar'), findsOneWidget);
      await tocar(tester, 'otra-carta');
      expect(_tarjeta, findsNothing);
      expect(find.byKey(const ValueKey('fin-ronda')), findsOneWidget);
    },
  );

  testWidgets(
    'Atrás vuelve al frente; solo la cara actual llega al lector de pantalla',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await montar(tester, AlmacenMemoria(), animaciones: true);
      await tocar(tester, 'empezar');
      final pregunta = tester
          .widget<Text>(find.byKey(const ValueKey('pregunta')))
          .data!;
      await tocar(tester, 'una-mas');
      expect(find.byKey(const ValueKey('pregunta')), findsNothing);
      final nodo = tester.getSemantics(find.byType(MazoPreguntas));
      expect(nodo.toStringDeep(), contains('reverso'));
      expect(nodo.toStringDeep(), isNot(contains(pregunta)));
      expect(nodo.toStringDeep(), contains('Otra carta'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pregunta')), findsOneWidget);
      expect(find.text('1 de 12'), findsOneWidget);
      expect(find.byType(MazoPreguntas), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'salida pausa el reloj, segundo plano conserva el avance confirmado y el guardado',
    (tester) async {
      final reloj = RelojPrueba();
      final almacen = AlmacenMemoria();
      await montar(tester, almacen, animaciones: true, reloj: reloj);
      await tocar(tester, 'empezar');
      reloj.pasar(3000);
      await tester.tap(find.byKey(const ValueKey('otra-carta')));
      await tester.pump();
      expect(reloj.activo, isFalse);
      reloj.pasar(4000);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      reloj.pasar(600000);
      expect(_motor(tester).fase, FaseCarta.reposo);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      reloj.pasar(2000);
      await tocar(tester, 'pasar');
      final partida = (await RepositorioPartida(almacen).cargar(catalogoReal()))
          .partida!;
      expect(partida.indice, 2);
      expect(partida.pasadas, 1);
      expect(partida.tiemposMs[partida.cartas[0]], 3000);
      expect(partida.tiemposMs[partida.cartas[1]], 2000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tutorial reacciona a acciones reales y conserva los datos guardados',
    (tester) async {
      final almacen = AlmacenMemoria();
      await montar(tester, almacen, animaciones: true);
      await tocar(tester, 'empezar');
      await tocar(tester, 'pasar');
      await tester.tap(find.byTooltip('Elegir nivel'));
      await tester.pumpAndSettle();
      final guardado = Map.of(almacen.datos);
      await tocar(tester, 'ver-tutorial');
      await tocar(tester, 'tutorial-nivel-3');
      expect(find.text('1 de 6'), findsOneWidget);
      await tocar(tester, 'tutorial-siguiente');
      await tocar(tester, 'otra-carta');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('3 de 6'), findsOneWidget);
      await tester.dragFrom(
        tester.getRect(_tarjeta).center,
        const Offset(-160, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 de 6'), findsOneWidget);
      expect(find.text('3 de 3'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('4 de 6'), findsOneWidget);
      await tester.ensureVisible(find.text('Una más'));
      await tester.tap(find.text('Una más'));
      await tester.pumpAndSettle();
      expect(find.text('4 de 6'), findsOneWidget);
      expect(find.byKey(const ValueKey('repregunta')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Esta la paso'));
      await tester.tap(find.text('Esta la paso'));
      await tester.pumpAndSettle();
      expect(find.text('5 de 6'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('6 de 6'), findsOneWidget);
      expect(find.byKey(const ValueKey('cierre-ejemplo')), findsOneWidget);
      await tocar(tester, 'tutorial-siguiente');
      expect(
        almacen.datos[RepositorioPartida.clave],
        guardado[RepositorioPartida.clave],
      );
      expect(
        almacen.datos['trivia_antiguedad_ajustes_v1'],
        guardado['trivia_antiguedad_ajustes_v1'],
      );
      expect(
        (await RepositorioExperiencia(almacen).cargar()).tutorialVisto,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'movimiento reducido conserva gesto, frente/reverso y mazo visible',
    (tester) async {
      await montar(tester, AlmacenMemoria());
      await tocar(tester, 'empezar');
      expect(_motor(tester).reducido, isTrue);
      expect(_tarjeta, findsOneWidget);
      await tocar(tester, 'una-mas');
      expect(find.byKey(const ValueKey('repregunta')), findsOneWidget);
      await tester.dragFrom(
        tester.getRect(_tarjeta).center,
        const Offset(-160, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 de 12'), findsOneWidget);
      expect(find.byKey(const ValueKey('pregunta')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
