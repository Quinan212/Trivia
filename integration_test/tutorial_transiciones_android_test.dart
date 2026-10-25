import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trivia_antiguedad/app.dart';
import 'package:trivia_antiguedad/compartido/componentes/entrada_inicio.dart';
import 'package:trivia_antiguedad/compartido/movimiento/movimiento.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/controladores/controlador_experiencia.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/datos/repositorio_experiencia.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/controladores/controlador_partida.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/datos/repositorio_partida.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/dominio/reloj_carta.dart';

import '../test/apoyo/base_pruebas.dart';

class _AudioAndroid extends RespuestaSonora {
  _AudioAndroid(super.habilitado, super.vibracion);
  final efectos = <EfectoInterfaz>[];
  @override
  void emitir(EfectoInterfaz efecto) {
    efectos.add(efecto);
    super.emitir(efecto);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  ProviderContainer? contenedor;
  late _AudioAndroid audio;
  setUpAll(() async {
    audio = _AudioAndroid(
      () => contenedor?.read(experienciaProvider).value?.sonidos ?? false,
      () => false,
    );
    await audio.preparar();
  });
  setUp(() {
    audio.silenciar();
    audio.efectos.clear();
  });
  tearDownAll(() => audio.cerrar());
  Finder clave(String valor) => find.byKey(ValueKey(valor));
  Future<void> tocar(WidgetTester tester, String valor) async {
    await tester.ensureVisible(clave(valor));
    await tester.tap(clave(valor));
    await tester.pumpAndSettle();
  }

  Future<void> captura(WidgetTester tester, String nombre) async {
    debugPrint('QA-CAPTURA:$nombre');
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> montar(
    WidgetTester tester,
    AlmacenMemoria almacen, {
    bool movimiento = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          almacenProvider.overrideWithValue(almacen),
          respuestaInterfazProvider.overrideWithValue(audio),
          permitirMovimientoProvider.overrideWithValue(movimiento),
          intervaloRespaldoProvider.overrideWithValue(null),
        ],
        child: const TriviaAntiguedadApp(modoConversacion: true),
      ),
    );
    contenedor = ProviderScope.containerOf(
      tester.element(find.byType(TriviaAntiguedadApp)),
    );
    var listo = false;
    for (var i = 0; i < 200 && !listo; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final boton = clave('comenzar-bienvenida');
      listo =
          boton.hitTestable().evaluate().isNotEmpty &&
          find
              .ancestor(of: boton, matching: find.byType(IgnorePointer))
              .evaluate()
              .every((e) => !(e.widget as IgnorePointer).ignoring);
    }
    expect(listo, isTrue);
    await tocar(tester, 'comenzar-bienvenida');
    await tester.pumpAndSettle();
  }

  Future<void> esperarPaso(WidgetTester tester, int paso) async {
    for (var i = 0; i < 60 && find.text('$paso de 6').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('$paso de 6'), findsOneWidget);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'tutorial Android: fondo compartido, práctica, tres salidas y audio único',
    (tester) async {
      final almacen = AlmacenMemoria()
        ..datos[RepositorioExperiencia.clave] =
            '{"version":2,"tutorialVisto":true,"sonidos":true,"vibracion":false}';
      await montar(tester, almacen);
      final partidaAnterior = almacen.datos[RepositorioPartida.clave];
      await captura(tester, '01-menu-antes-del-tutorial');
      audio.efectos.clear();
      await tocar(tester, 'ver-tutorial');
      expect(find.byType(FondoApertura), findsOneWidget);
      expect(
        tester.widget<EntradaInicio>(clave('entrada-tutorial')).progreso,
        1,
      );
      expect(clave('tutorial-siguiente').hitTestable(), findsOneWidget);
      expect(audio.efectos, [EfectoInterfaz.abrirTutorial]);
      await captura(tester, '02-tutorial-entrada-completa');
      final guiaNiveles = tester.getRect(clave('tutorial-burbuja'));
      await tocar(tester, 'tutorial-nivel-2');
      await tocar(tester, 'tutorial-siguiente');
      expect(
        tester.getRect(clave('tutorial-burbuja')).top,
        greaterThan(guiaNiveles.top),
      );
      expect(
        tester
            .getRect(clave('tutorial-burbuja'))
            .overlaps(tester.getRect(clave('otra-carta'))),
        isFalse,
      );
      await captura(tester, '02b-burbuja-otra-carta');
      await tocar(tester, 'otra-carta');
      await esperarPaso(tester, 3);
      expect(
        audio.efectos
            .where((e) => e == EfectoInterfaz.tutorialSiguiente)
            .length,
        1,
      );
      final carta = clave('tarjeta-visible');
      final dedo = await tester.startGesture(tester.getRect(carta).center);
      await dedo.moveBy(const Offset(-24, 0));
      await tester.pump();
      await dedo.moveBy(const Offset(-170, 0));
      await tester.pump();
      await dedo.up();
      await esperarPaso(tester, 4);
      final guiaIzquierda = tester.getRect(clave('tutorial-burbuja'));
      await captura(tester, '02c-burbuja-una-mas');
      await tocar(tester, 'una-mas');
      await esperarPaso(tester, 5);
      final guiaDerecha = tester.getRect(clave('tutorial-burbuja'));
      expect(guiaDerecha.center.dx, greaterThan(guiaIzquierda.center.dx));
      expect(clave('repregunta'), findsOneWidget);
      await captura(tester, '03-tutorial-repregunta');
      await tocar(tester, 'pasar');
      await esperarPaso(tester, 6);
      expect(
        tester.getRect(clave('tutorial-burbuja')).top,
        lessThan(guiaDerecha.top),
      );
      await captura(tester, '04-tutorial-cierre');
      await tocar(tester, 'tutorial-siguiente');
      expect(find.text('Hay mucho\npor contar.'), findsOneWidget);
      expect(
        audio.efectos
            .where((e) => e == EfectoInterfaz.tutorialCompletar)
            .length,
        1,
      );
      await captura(tester, '05-menu-tras-completar');
      await tocar(tester, 'ver-tutorial');
      await tocar(tester, 'tutorial-omitir');
      await tocar(tester, 'ver-tutorial');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        audio.efectos.where((e) => e == EfectoInterfaz.tutorialOmitir).length,
        2,
      );
      expect(
        audio.efectos.where((e) => e == EfectoInterfaz.abrirTutorial).length,
        3,
      );
      expect(almacen.datos[RepositorioPartida.clave], partidaAnterior);
      await tester.pump(const Duration(seconds: 1));
      debugPrint('QA-AUDIO-REPOSO');
      await tester.pump(const Duration(seconds: 1));
      debugPrint(
        'QA-TUTORIAL:completar,omitir,atras;audio-unico;partida-conservada',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'primera visita y movimiento reducido no repiten la señal de entrada',
    (tester) async {
      final almacen = AlmacenMemoria();
      await montar(tester, almacen, movimiento: false);
      expect(find.text('1 de 6'), findsOneWidget);
      expect(audio.efectos, [
        EfectoInterfaz.bienvenida,
        EfectoInterfaz.comenzar,
        EfectoInterfaz.entradaInicio,
      ]);
      for (var i = 0; i < 6; i++) {
        await tocar(tester, 'tutorial-siguiente');
      }
      expect(
        (await RepositorioExperiencia(almacen).cargar()).tutorialVisto,
        isTrue,
      );
      expect(find.text('Hay mucho\npor contar.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugPrint(
        'QA-TUTORIAL:primera-visita;movimiento-reducido;sin-duplicado',
      );
    },
  );
}
