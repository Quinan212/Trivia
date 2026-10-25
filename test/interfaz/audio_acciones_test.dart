import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/controladores/controlador_experiencia.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/datos/repositorio_experiencia.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/controladores/controlador_partida.dart';

import '../apoyo/base_pruebas.dart';
import '../apoyo/montar_interfaz.dart';

class _Registro implements RespuestaInterfaz {
  final efectos = <EfectoInterfaz>[];
  int silencios = 0;
  @override
  void emitir(EfectoInterfaz efecto) => efectos.add(efecto);
  @override
  void silenciar() => silencios++;
}

Future<void> _volver(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'reintentar guardado tiene feedback neutral y recupera la escritura',
    (tester) async {
      final audio = _Registro();
      final almacen = AlmacenMemoria();
      await montar(tester, almacen, respuesta: audio);
      almacen.fallar = true;
      await tocar(tester, 'empezar');
      await _volver(tester);
      audio.efectos.clear();
      almacen.fallar = false;
      await tester.tap(find.widgetWithText(SnackBarAction, 'Reintentar'));
      await tester.pumpAndSettle();
      expect(audio.efectos, [EfectoInterfaz.reintentar]);
      expect(almacen.escrituras, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );
  test('43 archivos únicos PCM16 mono 44100 Hz, cuatro variantes solo para tarjetas', () {
    final archivos = Directory('assets/sonidos')
        .listSync()
        .whereType<File>()
        .toList();
    expect(archivos.length, 43);
    expect(
      EfectoInterfaz.values.take(EfectoInterfaz.evaluacionToque.index).length,
      31,
    );
    var bytes = 0;
    final contenido = <String>{};
    for (final efecto in EfectoInterfaz.values.take(
      EfectoInterfaz.evaluacionToque.index,
    )) {
      for (var variante = 0; variante < cantidadVariantes(efecto); variante++) {
        final data = File('assets/${archivoSonido(efecto, variante)}')
            .readAsBytesSync();
        final cabecera = ByteData.sublistView(data);
        expect(ascii.decode(data.sublist(0, 4)), 'RIFF');
        expect(ascii.decode(data.sublist(8, 12)), 'WAVE');
        expect(cabecera.getUint16(20, Endian.little), 1);
        expect(cabecera.getUint16(22, Endian.little), 1);
        expect(cabecera.getUint32(24, Endian.little), 44100);
        expect(cabecera.getUint16(34, Endian.little), 16);
        contenido.add(base64Encode(data));
        bytes += data.length;
      }
    }
    expect(contenido.length, 43);
    expect(bytes, lessThan(2000000));
    expect(File('assets/sonidos/toque.wav').existsSync(), isFalse);
    expect(File('assets/sonidos/seleccion.wav').existsSync(), isFalse);
  });

  testWidgets(
    'inicio, continuación, reinicio, consignas y laboratorio tienen una señal propia',
    (tester) async {
      final audio = _Registro();
      await montar(tester, AlmacenMemoria(), respuesta: audio);
      audio.efectos.clear();
      await tocar(tester, 'empezar');
      await _volver(tester);
      await tocar(tester, 'empezar');
      await _volver(tester);
      await tocar(tester, 'retomar');
      await _volver(tester);
      await tocar(tester, 'consignas');
      await _volver(tester);
      await tocar(tester, 'experimentos');
      await _volver(tester);
      expect(audio.efectos, [
        EfectoInterfaz.iniciarRonda,
        EfectoInterfaz.volverInicio,
        EfectoInterfaz.retomarRonda,
        EfectoInterfaz.volverInicio,
        EfectoInterfaz.otraRonda,
        EfectoInterfaz.volverInicio,
        EfectoInterfaz.abrirConsignas,
        EfectoInterfaz.volverInicio,
        EfectoInterfaz.abrirLaboratorio,
        EfectoInterfaz.volverInicio,
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'carta y sus dos caras conservan el mapa en partida y laboratorio',
    (tester) async {
      final audio = _Registro();
      await montar(tester, AlmacenMemoria(), respuesta: audio);
      audio.efectos.clear();
      for (final entrada in ['empezar', 'experimentos']) {
        await tocar(tester, entrada);
        audio.efectos.clear();
        await tocar(tester, 'una-mas');
        await _volver(tester); // Atrás vuelve al frente en la partida.
        if (entrada == 'experimentos') {
          // El laboratorio conserva su navegación de salida al inicio.
          expect(audio.efectos, [
            EfectoInterfaz.giro,
            EfectoInterfaz.volverInicio,
          ]);
          await tocar(tester, entrada);
          audio.efectos.clear();
          await tocar(tester, 'una-mas');
          await tocar(tester, 'una-mas');
        } else {
          expect(audio.efectos, [
            EfectoInterfaz.giro,
            EfectoInterfaz.volverCarta,
          ]);
        }
        await tocar(tester, 'otra-carta');
        await tocar(tester, 'pasar');
        expect(audio.efectos, [
          EfectoInterfaz.giro,
          EfectoInterfaz.volverCarta,
          EfectoInterfaz.carta,
          EfectoInterfaz.pasar,
        ]);
        await _volver(tester);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ayuda cierra igual por botón, gesto y Atrás; entrada al tutorial sin doble señal',
    (tester) async {
      final audio = _Registro();
      await montar(tester, AlmacenMemoria(), respuesta: audio);
      audio.efectos.clear();
      for (var forma = 0; forma < 3; forma++) {
        await tester.tap(find.byTooltip('Cómo jugar'));
        await tester.pumpAndSettle();
        if (forma == 0) {
          await tester.tap(find.byTooltip('Cerrar'));
        } else if (forma == 1) {
          await tester.flingFrom(
            tester.getTopLeft(find.byType(BottomSheet)) + const Offset(190, 15),
            const Offset(0, 700),
            1800,
          );
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
      }
      expect(
        audio.efectos,
        List.generate(
          3,
          (_) => [EfectoInterfaz.abrirAyuda, EfectoInterfaz.cerrarAyuda],
        ).expand((x) => x).toList(),
      );
      audio.efectos.clear();
      await tester.tap(find.byTooltip('Cómo jugar'));
      await tester.pumpAndSettle();
      await tocar(tester, 'tutorial-desde-ayuda');
      await tocar(tester, 'tutorial-omitir');
      expect(audio.efectos, [
        EfectoInterfaz.abrirAyuda,
        EfectoInterfaz.abrirTutorial,
        EfectoInterfaz.tutorialOmitir,
      ]);
    },
  );

  testWidgets(
    'tutorial distingue avance, retroceso, salida y completar; controles bloqueados silenciosos',
    (tester) async {
      final audio = _Registro();
      await montar(tester, AlmacenMemoria(), respuesta: audio);
      audio.efectos.clear();
      await tocar(tester, 'ver-tutorial');
      await tester.tap(find.byKey(const ValueKey('tutorial-atras')));
      await tester.pumpAndSettle();
      expect(audio.efectos, [EfectoInterfaz.abrirTutorial]);
      await tocar(tester, 'tutorial-siguiente');
      await tocar(tester, 'tutorial-atras');
      for (var i = 0; i < 6; i++) {
        await tocar(tester, 'tutorial-siguiente');
      }
      expect(audio.efectos, [
        EfectoInterfaz.abrirTutorial,
        EfectoInterfaz.tutorialSiguiente,
        EfectoInterfaz.tutorialAnterior,
        ...List.filled(5, EfectoInterfaz.tutorialSiguiente),
        EfectoInterfaz.tutorialCompletar,
      ]);
    },
  );

  testWidgets(
    'ajustes independientes, silenciar inmediato y ninguna vibración nueva',
    (tester) async {
      final audio = _Registro();
      final almacen = AlmacenMemoria()
        ..datos[RepositorioExperiencia.clave] =
            '{"version":2,"tutorialVisto":true,"sonidos":true,"vibracion":false}';
      await montar(tester, almacen, respuesta: audio);
      await tester.tap(find.byTooltip('Cómo jugar'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BottomSheet)),
      );
      audio.efectos.clear();
      await tocar(tester, 'ajuste-sonido');
      expect(audio.silencios, 1);
      expect(audio.efectos, isEmpty);
      expect(container.read(experienciaProvider).value!.sonidos, isFalse);
      await tocar(tester, 'ajuste-sonido');
      await tocar(tester, 'ajuste-vibracion');
      await tocar(tester, 'ajuste-vibracion');
      expect(audio.efectos, [
        EfectoInterfaz.activarSonido,
        EfectoInterfaz.activarVibracion,
        EfectoInterfaz.desactivarVibracion,
      ]);
      for (final efecto in [
        EfectoInterfaz.abrirAyuda,
        EfectoInterfaz.cerrarAyuda,
        EfectoInterfaz.activarSonido,
        EfectoInterfaz.activarVibracion,
        EfectoInterfaz.desactivarVibracion,
        EfectoInterfaz.reintentar,
      ]) {
        expect(vibracionDelEfecto(efecto), isFalse);
      }
    },
  );

  testWidgets('doble inicio y doble otra ronda aceptan una sola acción', (
    tester,
  ) async {
    final audio = _Registro();
    await montar(tester, AlmacenMemoria(), respuesta: audio);
    audio.efectos.clear();
    await tester.ensureVisible(find.byKey(const ValueKey('empezar')));
    final punto = tester.getCenter(find.byKey(const ValueKey('empezar')));
    await tester.tapAt(punto);
    await tester.tapAt(punto);
    await tester.pumpAndSettle();
    expect(audio.efectos, [EfectoInterfaz.iniciarRonda]);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('otra-carta'))),
    );
    for (var i = 0; i < 12; i++) {
      await tocar(tester, 'otra-carta');
    }
    expect(container.read(partidaProvider).value!.partida!.terminada, isTrue);
    await tester.ensureVisible(find.text('Otra ronda'));
    audio.efectos.clear();
    await tester.tap(find.text('Otra ronda'));
    await tester.tap(find.text('Otra ronda'));
    await tester.pumpAndSettle();
    expect(audio.efectos, [EfectoInterfaz.otraRonda]);
    expect(container.read(partidaProvider).value!.partida!.indice, 0);
  });
}
