import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trivia_antiguedad/app.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/controladores/controlador_experiencia.dart';
import 'package:trivia_antiguedad/compartido/movimiento/coordinador_carta.dart';
import 'package:trivia_antiguedad/compartido/movimiento/movimiento.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/controladores/controlador_partida.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/componentes/mazo_preguntas.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/datos/repositorio_partida.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/datos/repositorio_preguntas.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/dominio/armador_rondas.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/dominio/reloj_carta.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/datos/repositorio_experiencia.dart';

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
  Future<void> tocar(WidgetTester tester, String clave) async {
    final elemento = find.byKey(ValueKey(clave));
    if (clave == 'comenzar-bienvenida') {
      // La preparación nativa puede completar después de pumpAndSettle.
      // Esperar el control habilitado, no solamente su espacio reservado.
      var listo = false;
      for (var i = 0; i < 200 && !listo; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        listo =
            elemento.hitTestable().evaluate().isNotEmpty &&
            find
                .ancestor(of: elemento, matching: find.byType(IgnorePointer))
                .evaluate()
                .every((e) => !(e.widget as IgnorePointer).ignoring);
      }
      expect(
        listo,
        isTrue,
        reason: 'Comenzar terminó de aparecer y está habilitado.',
      );
    }
    await tester.ensureVisible(elemento);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    await tester.tap(elemento);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    for (
      var i = 0;
      i < 200 &&
          find.byKey(const ValueKey('cortina-inicial')).evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('cortina-inicial')), findsNothing);
  }

  Future<void> capturar(WidgetTester tester, String nombre) async {
    await tester.pump();
    debugPrint('QA-CAPTURA:$nombre');
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> esperarPaso(WidgetTester tester, int paso) async {
    for (var i = 0; i < 60 && find.text('$paso de 6').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('$paso de 6'), findsOneWidget);
    await tester.pumpAndSettle();
  }

  testWidgets('mazo aislado, juego completo y tutorial táctil en Android', (
    tester,
  ) async {
    final almacen = AlmacenMemoria()
      ..datos[RepositorioExperiencia.clave] =
          '{"version":2,"tutorialVisto":true,"sonidos":true,"vibracion":false}';
    late ProviderContainer container;
    final audio = _AudioAndroid(
      () => container.read(experienciaProvider).value?.sonidos ?? false,
      () => container.read(experienciaProvider).value?.vibracion ?? false,
    );
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          almacenProvider.overrideWithValue(almacen),
          respuestaInterfazProvider.overrideWithValue(audio),
        ],
        child: const TriviaAntiguedadApp(modoConversacion: true),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(TriviaAntiguedadApp)),
    );
    addTearDown(audio.cerrar);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    await tocar(tester, 'comenzar-bienvenida');
    await prepararRespuesta(audio);
    // Reproduce cada exportación mediante SoundPool nativo, sin red ni mocks.
    for (final efecto in EfectoInterfaz.values) {
      for (var variante = 0; variante < cantidadVariantes(efecto); variante++) {
        audio.emitir(efecto);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1500)),
        );
      }
    }
    debugPrint('QA-AUDIO-REPOSO');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1500)),
    );
    await capturar(tester, 'audio-43-exportaciones');
    audio.efectos.clear();
    for (final clave in [
      'nivel-1',
      'nivel-2',
      'nivel-3',
      'ronda-25',
      'ronda-12',
    ]) {
      await tocar(tester, clave);
    }
    await tocar(tester, 'nivel-1');
    await capturar(tester, '00-inicio-selecciones');
    await tocar(tester, 'experimentos');
    await capturar(tester, '01-laboratorio-mazo');
    final tarjeta = find.byKey(const ValueKey('tarjeta-visible'));
    final dedo = await tester.startGesture(tester.getRect(tarjeta).center);
    await dedo.moveBy(const Offset(-74, 0));
    await tester.pump();
    await capturar(tester, '02-arrastre');
    await dedo.up();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    expect(find.text('1 de 3'), findsOneWidget);
    await tocar(tester, 'una-mas');
    await capturar(tester, '03-reverso');
    await tocar(tester, 'una-mas');
    expect(audio.efectos.last, EfectoInterfaz.volverCarta);
    await tocar(tester, 'otra-carta');
    expect(find.text('2 de 3'), findsOneWidget);
    await capturar(tester, '04-carta-larga');
    await tester.tap(find.byKey(const ValueKey('pasar')));
    await tester.pump(const Duration(milliseconds: 70));
    await capturar(tester, '05-salida-pasada');
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    expect(find.text('3 de 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('mazo-detras-1')), findsNothing);
    await capturar(tester, '06-ultima-carta');
    await tocar(tester, 'otra-carta');
    await capturar(tester, '07-cierre-ejemplo');
    await tester.ensureVisible(find.text('Elegir otro nivel'));
    await tester.tap(find.text('Elegir otro nivel'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    await tocar(tester, 'empezar');
    await capturar(tester, '08-juego-integrado');
    final cabecera = tester.getRect(find.text('Trivia de la antiguedad'));
    await tocar(tester, 'una-mas');
    await capturar(tester, '09-juego-reverso');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    expect(find.byKey(const ValueKey('pregunta')), findsOneWidget);
    await tocar(tester, 'pasar');
    final motor = tester
        .widget<MazoPreguntas>(find.byType(MazoPreguntas))
        .coordinador;
    expect(motor.fase, FaseCarta.reposo);
    expect(tester.getRect(find.text('Trivia de la antiguedad')), cabecera);
    for (var i = 1; i < 12; i++) {
      await tocar(tester, 'otra-carta');
    }
    await capturar(tester, '10-cierre-juego');
    expect(find.byKey(const ValueKey('duracion-activa')), findsOneWidget);
    await tester.tap(find.byTooltip('Elegir nivel'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    final guardado = Map.of(almacen.datos);
    await tester.tap(find.byTooltip('Cómo jugar'));
    await tester.pumpAndSettle();
    await capturar(tester, 'audio-ajustes');
    await tocar(tester, 'ajuste-sonido');
    expect(container.read(experienciaProvider).value!.sonidos, isFalse);
    await tocar(tester, 'ajuste-sonido');
    await tocar(tester, 'ajuste-vibracion');
    await tocar(tester, 'ajuste-vibracion');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tocar(tester, 'ver-tutorial');
    await capturar(tester, '11-tutorial-tono');
    await tocar(tester, 'tutorial-nivel-1');
    await tocar(tester, 'tutorial-siguiente');
    await capturar(tester, '12-tutorial-carta');
    await tocar(tester, 'otra-carta');
    await esperarPaso(tester, 3);
    expect(find.text('2 de 3'), findsOneWidget);
    final mano = await tester.startGesture(tester.getRect(tarjeta).center);
    await mano.moveBy(
      const Offset(-24, 0),
    ); // Resolver primero el reconocimiento.
    await tester.pump();
    await mano.moveBy(const Offset(-170, 0));
    await capturar(tester, '13-tutorial-arrastre');
    await mano.up();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    await esperarPaso(tester, 4);
    expect(find.text('3 de 3'), findsOneWidget);
    await capturar(tester, '14-tutorial-girar');
    await tester.ensureVisible(find.text('Una más'));
    await tester.tap(find.text('Una más'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    await esperarPaso(tester, 5);
    expect(find.byKey(const ValueKey('repregunta')), findsOneWidget);
    await capturar(tester, '15-tutorial-reverso-pasar');
    await tester.ensureVisible(find.text('Esta la paso'));
    await tester.tap(find.text('Esta la paso'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    await esperarPaso(tester, 6);
    await capturar(tester, '16-tutorial-cierre');
    expect(find.byKey(const ValueKey('cierre-ejemplo')), findsOneWidget);
    expect(find.byKey(const ValueKey('destacadas')), findsNothing);
    expect(find.byKey(const ValueKey('duracion-activa')), findsNothing);
    await tocar(tester, 'tutorial-siguiente');
    expect(
      audio.efectos,
      containsAll([
        EfectoInterfaz.abrirLaboratorio,
        EfectoInterfaz.volverCarta,
        EfectoInterfaz.iniciarRonda,
        EfectoInterfaz.volverInicio,
        EfectoInterfaz.abrirAyuda,
        EfectoInterfaz.cerrarAyuda,
        EfectoInterfaz.activarSonido,
        EfectoInterfaz.activarVibracion,
        EfectoInterfaz.desactivarVibracion,
        EfectoInterfaz.abrirTutorial,
        EfectoInterfaz.tutorialCompletar,
      ]),
    );
    debugPrint('QA-AUDIO-MAPA:${audio.efectos.map((e) => e.name).join(",")}');
    expect(
      almacen.datos[RepositorioPartida.clave],
      guardado[RepositorioPartida.clave],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('edición completa con texto grande y ronda anterior en Android', (
    tester,
  ) async {
    // Usa el asset empaquetado en Android, sin catálogo sustituto.
    final catalogo = await const RepositorioPreguntas().cargar();
    var anterior = ArmadorRondas.crear(
      catalogo,
      nivel: 2,
      cantidad: 12,
      ronda: 0,
    );
    final primera = anterior.cartaActual!;
    for (var i = 0; i < 5; i++) {
      anterior = anterior.avanzar(milisegundos: i == 0 ? 100000 : 1000);
    }
    final registroAnterior = anterior.toJson()
      ..['contenido'] = '0.2-complicidad-cotidiana'
      ..remove('textosCompartidos');
    final rawAnterior = jsonEncode(registroAnterior);
    final almacen = AlmacenMemoria()
      ..datos[RepositorioPartida.clave] = rawAnterior
      ..datos[RepositorioExperiencia.clave] =
          '{"version":2,"tutorialVisto":true,"sonidos":false,"vibracion":false}';
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          almacenProvider.overrideWithValue(almacen),
          respuestaInterfazProvider.overrideWithValue(
            const RespuestaSilenciosa(),
          ),
          permitirMovimientoProvider.overrideWithValue(false),
          intervaloRespaldoProvider.overrideWithValue(null),
        ],
        child: const TriviaAntiguedadApp(modoConversacion: true),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TriviaAntiguedadApp)),
    );
    expect(almacen.datos[RepositorioPartida.clave], rawAnterior);
    await tocar(tester, 'comenzar-bienvenida');
    expect(container.read(partidaProvider).requireValue.partida!.indice, 5);
    // Al coincidir nivel y cantidad, el botón principal continúa la ronda;
    // el secundario ofrece empezar otra.
    await tocar(tester, 'empezar');
    expect(find.text('6 de 12'), findsOneWidget);
    for (var i = 5; i < 12; i++) {
      final partida = container.read(partidaProvider).requireValue.partida!;
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('pregunta'))).data,
        catalogo.porId[partida.cartaActual]!.texto,
      );
      await tocar(tester, 'otra-carta');
    }
    // El resumen recuerda lo conversado, sin atribuirle el texto nuevo.
    final destacada = find.byKey(ValueKey('destacada-$primera'));
    await tester.ensureVisible(destacada);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: destacada,
        matching: find.text(
          catalogo.textosAnteriores['0.2-complicidad-cotidiana']![primera]!,
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Elegir nivel'));
    await tester.pumpAndSettle();

    final vistas = <String>{};
    var reversos = 0;
    for (final nivel in [1, 2, 3, 0]) {
      final idsNivel = catalogo.deNivel(nivel).map((carta) => carta.id).toSet();
      final ordenVisto = <String>[];
      final rondas = nivel == 0 ? 1 : (idsNivel.length / 25).ceil();
      for (var ronda = 0; ronda < rondas; ronda++) {
        if (nivel == 0) {
          await tocar(tester, 'consignas');
        } else {
          await tocar(tester, 'nivel-$nivel');
          await tocar(tester, 'ronda-25');
          await tocar(tester, 'empezar');
        }
        final cantidad = nivel == 0 ? idsNivel.length : 25;
        for (var i = 0; i < cantidad; i++) {
          final partida = container.read(partidaProvider).requireValue.partida!;
          final id = partida.cartaActual!;
          final carta = catalogo.porId[id]!;
          vistas.add(id);
          ordenVisto.add(id);
          expect(find.text('${i + 1} de $cantidad'), findsOneWidget);
          expect(
            tester.widget<Text>(find.byKey(const ValueKey('pregunta'))).data,
            carta.texto,
          );
          if (i == 0) {
            debugPrint('QA-CONTENIDO-NIVEL:$nivel:$id');
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(seconds: 1)),
            );
          }
          if (nivel != 0) {
            await tocar(tester, 'una-mas');
            expect(find.byKey(const ValueKey('pregunta')), findsNothing);
            expect(
              tester
                  .widget<Text>(find.byKey(const ValueKey('repregunta')))
                  .data,
              carta.repregunta,
            );
            reversos++;
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('pregunta')), findsOneWidget);
          }
          await tocar(tester, i == 1 ? 'pasar' : 'otra-carta');
          expect(tester.takeException(), isNull, reason: id);
        }
        expect(find.byKey(const ValueKey('fin-ronda')), findsOneWidget);
        final finalizada = container
            .read(partidaProvider)
            .requireValue
            .partida!;
        expect(finalizada.pasadas, 1);
        expect(finalizada.textosCompartidos.length, cantidad);
        final recargada = (await RepositorioPartida(almacen).cargar(catalogo))
            .partida!;
        expect(recargada.textosCompartidos, finalizada.textosCompartidos);
        await tester.tap(find.byTooltip('Elegir nivel'));
        await tester.pumpAndSettle();
      }
      expect(ordenVisto.take(idsNivel.length).toSet(), idsNivel);
      expect(ordenVisto.take(idsNivel.length).toSet().length, idsNivel.length);
    }
    expect(vistas.length, catalogo.cartas.length);
    expect(reversos, 150);
    debugPrint(
      'QA-CONTENIDO:${vistas.length}-cartas:150-reversos-presentados:escala-2:historial-conservado',
    );
  });
}
