import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/compartido/componentes/entrada_inicio.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/datos/repositorio_experiencia.dart';

import '../apoyo/base_pruebas.dart';
import '../apoyo/montar_interfaz.dart';

class _Audio implements RespuestaInterfaz {
  final efectos = <EfectoInterfaz>[];
  int silencios = 0;
  @override
  void emitir(EfectoInterfaz efecto) => efectos.add(efecto);
  @override
  void silenciar() => silencios++;
}

void main() {
  const boton = ValueKey('comenzar-bienvenida');
  const cortina = ValueKey('cortina-inicial');

  double entrada(WidgetTester tester) => tester
      .widget<EntradaInicio>(
        find.byKey(const ValueKey('entrada-pantalla-inicial')),
      )
      .progreso;

  testWidgets(
    'retira el logo, centra Comenzar y revela el menú en cascada tras 150 ms',
    (tester) async {
      await montar(
        tester,
        AlmacenMemoria(),
        animaciones: true,
        completarEntrada: false,
      );
      await tester.pumpAndSettle();
      final centro = tester.getRect(find.byKey(cortina)).center;
      final botonAntes = tester.getCenter(find.byKey(boton));
      await tester.tap(find.byKey(boton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 550));
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('identidad-bienvenida')))
            .opacity,
        0,
      );
      expect(
        (tester.getCenter(find.byKey(boton)) - botonAntes).distance,
        lessThan(.01),
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.getCenter(find.byKey(boton)).dx, closeTo(centro.dx, .01));
      expect(tester.getCenter(find.byKey(boton)).dy, closeTo(centro.dy, .01));
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('retiro-comenzar')))
            .opacity,
        closeTo(1, .001),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('retiro-comenzar')))
            .opacity,
        closeTo(0, .001),
      );
      expect(entrada(tester), 0);
      await tester.pump(const Duration(milliseconds: 149));
      expect(entrada(tester), 0);
      expect(find.byKey(cortina), findsOneWidget);
      expect(find.byKey(const ValueKey('empezar')).hitTestable(), findsNothing);
      await tester.pump(const Duration(milliseconds: 451));
      expect(entrada(tester), inExclusiveRange(.35, .65));
      final sonido = tester.getCenter(
        find.byTooltip('Silenciar sonidos').hitTestable(),
      );
      final ayuda = tester.getCenter(find.byTooltip('Cómo jugar'));
      expect((sonido - ayuda).distance, greaterThan(46));
      expect(find.byKey(cortina), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 451));
      expect(entrada(tester), 1);
      expect(find.byKey(cortina), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('empezar')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('empezar')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'silenciar sigue disponible durante la revelación junto al encabezado',
    (tester) async {
      final audio = _Audio();
      final almacen = AlmacenMemoria();
      await montar(
        tester,
        almacen,
        animaciones: true,
        respuesta: audio,
        completarEntrada: false,
      );
      await tester.pumpAndSettle();
      audio.efectos.clear();
      await tester.tap(find.byKey(boton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2300));
      expect(find.byKey(cortina), findsOneWidget);
      expect(find.byTooltip('Silenciar sonidos').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Silenciar sonidos').hitTestable());
      await tester.pumpAndSettle();
      expect(audio.silencios, greaterThan(0));
      expect(audio.efectos, [
        EfectoInterfaz.comenzar,
        EfectoInterfaz.entradaInicio,
      ]);
      expect((await RepositorioExperiencia(almacen).cargar()).sonidos, isFalse);
    },
  );

  testWidgets(
    'segundo plano suspende también la pausa de salida sin repetir sonido',
    (tester) async {
      final audio = _Audio();
      await montar(
        tester,
        AlmacenMemoria(),
        animaciones: true,
        respuesta: audio,
        completarEntrada: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(boton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1750));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect(entrada(tester), 0);
      expect(find.byKey(cortina), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 99));
      expect(entrada(tester), 0);
      await tester.pumpAndSettle();
      expect(find.byKey(cortina), findsNothing);
      expect(audio.efectos, [
        EfectoInterfaz.bienvenida,
        EfectoInterfaz.comenzar,
        EfectoInterfaz.entradaInicio,
      ]);
    },
  );

  testWidgets(
    'movimiento reducido omite el traslado pero conserva la pausa de salida',
    (tester) async {
      await montar(tester, AlmacenMemoria(), completarEntrada: false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(boton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1699));
      expect(find.byKey(cortina), findsOneWidget);
      expect(entrada(tester), 0);
      await tester.pump(const Duration(milliseconds: 2));
      expect(find.byKey(cortina), findsNothing);
      expect(entrada(tester), 1);
    },
  );

  testWidgets('espera dos segundos, anima Comenzar y exige un toque único', (
    tester,
  ) async {
    final audio = _Audio();
    await montar(
      tester,
      AlmacenMemoria(),
      animaciones: true,
      respuesta: audio,
      completarEntrada: false,
    );
    expect(find.byKey(boton).hitTestable(), findsNothing);
    expect(find.byKey(const ValueKey('empezar')).hitTestable(), findsNothing);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byKey(boton).hitTestable(), findsNothing);
    expect(audio.efectos, isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
    expect(audio.efectos, [EfectoInterfaz.bienvenida]);
    final fundido = find
        .ancestor(of: find.byKey(boton), matching: find.byType(FadeTransition))
        .first;
    expect(tester.widget<FadeTransition>(fundido).opacity.value, 0);
    await tester.pump(const Duration(milliseconds: 275));
    expect(
      tester.widget<FadeTransition>(fundido).opacity.value,
      greaterThan(0),
    );
    expect(tester.widget<FadeTransition>(fundido).opacity.value, lessThan(1));
    await tester.pump(const Duration(milliseconds: 275));
    expect(tester.widget<FadeTransition>(fundido).opacity.value, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(find.byKey(cortina), findsOneWidget);
    final centro = tester.getCenter(find.byKey(boton));
    await tester.tapAt(centro);
    await tester.tapAt(centro);
    await tester.pump();
    expect(find.byKey(boton).hitTestable(), findsNothing);
    await tester.pumpAndSettle();
    expect(audio.efectos, [
      EfectoInterfaz.bienvenida,
      EfectoInterfaz.comenzar,
      EfectoInterfaz.entradaInicio,
    ]);
    expect(find.byKey(cortina), findsNothing);
    expect(find.text('Hay mucho\npor contar.'), findsOneWidget);
    expect(vibracionDelEfecto(EfectoInterfaz.comenzar), isFalse);
    expect(vibracionDelEfecto(EfectoInterfaz.entradaInicio), isFalse);
  });

  testWidgets('movimiento reducido conserva la espera y el silencio de ajustes', (
    tester,
  ) async {
    final audio = _Audio();
    final almacen = AlmacenMemoria()
      ..datos[RepositorioExperiencia.clave] =
          '{"version":2,"tutorialVisto":true,"sonidos":false,"vibracion":true}';
    await montar(tester, almacen, respuesta: audio, completarEntrada: false);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byKey(boton).hitTestable(), findsNothing);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(boton).hitTestable(), findsOneWidget);
    await tocar(tester, 'comenzar-bienvenida');
    expect(audio.efectos, isEmpty);
    expect(find.byKey(cortina), findsNothing);
    expect((await RepositorioExperiencia(almacen).cargar()).sonidos, isFalse);
  });

  testWidgets(
    'segundo plano pausa la espera y no repite la bienvenida al volver',
    (tester) async {
      final audio = _Audio();
      await montar(
        tester,
        AlmacenMemoria(),
        animaciones: true,
        respuesta: audio,
        completarEntrada: false,
      );
      await tester.pump(const Duration(milliseconds: 800));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect(find.byKey(boton).hitTestable(), findsNothing);
      expect(audio.efectos, isEmpty);
      expect(audio.silencios, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1199));
      expect(audio.efectos, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(audio.efectos, [EfectoInterfaz.bienvenida]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(audio.efectos, [EfectoInterfaz.bienvenida]);
      await tocar(tester, 'comenzar-bienvenida');
    },
  );

  testWidgets(
    'silenciar en la portada detiene el audio y entrar no añade sonido',
    (tester) async {
      final audio = _Audio();
      await montar(
        tester,
        AlmacenMemoria(),
        respuesta: audio,
        completarEntrada: false,
      );
      await tester.pump(const Duration(milliseconds: 2001));
      await tester.pump();
      expect(audio.efectos, [EfectoInterfaz.bienvenida]);
      await tester.tap(find.byTooltip('Silenciar sonidos').hitTestable());
      await tester.pumpAndSettle();
      expect(audio.silencios, 1);
      await tocar(tester, 'comenzar-bienvenida');
      expect(audio.efectos, [EfectoInterfaz.bienvenida]);
    },
  );

  testWidgets(
    'primera visita conserva la guía con una sola confirmación de entrada',
    (tester) async {
      final audio = _Audio();
      await montar(
        tester,
        AlmacenMemoria(),
        primeraVez: true,
        respuesta: audio,
      );
      expect(find.text('1 de 6'), findsOneWidget);
      expect(audio.efectos, [
        EfectoInterfaz.bienvenida,
        EfectoInterfaz.comenzar,
        EfectoInterfaz.entradaInicio,
      ]);
      await tocar(tester, 'tutorial-omitir');
    },
  );

  testWidgets('la llegada suena una vez, justo al empezar a subir el menú', (
    tester,
  ) async {
    final audio = _Audio();
    await montar(
      tester,
      AlmacenMemoria(),
      animaciones: true,
      respuesta: audio,
      completarEntrada: false,
    );
    await tester.pumpAndSettle();
    audio.efectos.clear();
    await tester.tap(find.byKey(boton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1849));
    expect(audio.efectos, [EfectoInterfaz.comenzar]);
    expect(entrada(tester), 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(audio.efectos, [
      EfectoInterfaz.comenzar,
      EfectoInterfaz.entradaInicio,
    ]);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 5));
    expect(audio.efectos, [
      EfectoInterfaz.comenzar,
      EfectoInterfaz.entradaInicio,
    ]);
  });

  testWidgets(
    'silenciar durante la salida cancela también la llegada pendiente',
    (tester) async {
      final audio = _Audio();
      await montar(
        tester,
        AlmacenMemoria(),
        animaciones: true,
        respuesta: audio,
        completarEntrada: false,
      );
      await tester.pumpAndSettle();
      audio.efectos.clear();
      await tester.tap(find.byKey(boton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.tap(find.byTooltip('Silenciar sonidos').hitTestable());
      await tester.pumpAndSettle();
      expect(audio.silencios, greaterThan(0));
      expect(audio.efectos, [EfectoInterfaz.comenzar]);
      await tester.tap(find.byTooltip('Activar sonidos').hitTestable());
      await tester.pumpAndSettle();
      expect(audio.efectos, [
        EfectoInterfaz.comenzar,
        EfectoInterfaz.activarSonido,
      ]);
      await tester.pump(const Duration(seconds: 5));
      expect(audio.efectos, [
        EfectoInterfaz.comenzar,
        EfectoInterfaz.activarSonido,
      ]);
    },
  );

  testWidgets(
    'movimiento reducido sonoriza la llegada al terminar el ascenso sonoro',
    (tester) async {
      final audio = _Audio();
      await montar(
        tester,
        AlmacenMemoria(),
        respuesta: audio,
        completarEntrada: false,
      );
      await tester.pumpAndSettle();
      audio.efectos.clear();
      await tester.tap(find.byKey(boton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1699));
      expect(audio.efectos, [EfectoInterfaz.comenzar]);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(audio.efectos, [
        EfectoInterfaz.comenzar,
        EfectoInterfaz.entradaInicio,
      ]);
      expect(find.byKey(cortina), findsNothing);
    },
  );

  testWidgets('el motivo de aparición termina antes de aceptar Comenzar', (
    tester,
  ) async {
    final audio = _Audio();
    await montar(
      tester,
      AlmacenMemoria(),
      animaciones: true,
      respuesta: audio,
      completarEntrada: false,
    );
    await tester.pump(const Duration(milliseconds: 2002));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(audio.efectos, [EfectoInterfaz.bienvenida]);
    expect(find.byKey(boton).hitTestable(), findsNothing);
    await tester.tapAt(tester.getCenter(find.byKey(boton)));
    await tester.pump(const Duration(milliseconds: 249));
    expect(audio.efectos, [EfectoInterfaz.bienvenida]);
    await tester.pump(const Duration(milliseconds: 2));
    expect(find.byKey(boton).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(boton));
    await tester.pump();
    expect(audio.efectos, [EfectoInterfaz.bienvenida, EfectoInterfaz.comenzar]);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'la portada permite Comenzar con texto grande y tamaños diversos',
    (tester) async {
      await montar(tester, AlmacenMemoria(), completarEntrada: false);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      for (final size in [
        const Size(320, 640),
        const Size(411, 914),
        const Size(600, 1100),
      ]) {
        for (final escala in [1.0, 1.6, 2.0]) {
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = escala;
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(boton));
          expect(find.byKey(boton).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tocar(tester, 'comenzar-bienvenida');
    },
  );
}
