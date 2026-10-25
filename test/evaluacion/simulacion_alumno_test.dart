import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/compartido/componentes/entrada_inicio.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/acta_pdf.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/controlador.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/modelos.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/pantalla.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/repositorio.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/controladores/controlador_partida.dart';
import 'package:trivia_antiguedad/tema/tema_trivia_antiguedad.dart';

import '../apoyo/base_pruebas.dart';
import 'motor_test.dart' show banco;

class _RelojAlumno extends Stopwatch {
  int ms = 0;
  bool encendido = false;
  @override
  bool get isRunning => encendido;
  @override
  int get elapsedMilliseconds => ms;
  @override
  void start() => encendido = true;
  @override
  void stop() => encendido = false;
  @override
  void reset() => ms = 0;
}

class _RepositorioSimulado extends RepositorioEvaluacion {
  _RepositorioSimulado(super.directorio);
  String? ultimaSesion;
  final informes = <String, List<int>>{};
  @override
  Future<void> guardar(String raw) async => ultimaSesion = raw;
  @override
  Future<File> guardarInforme(String nombre, List<int> bytes) async {
    informes[nombre] = List.of(bytes);
    return File('${directorio.path}/$nombre');
  }
}

void main() {
  testWidgets('simulación completa de un alumno en Unidad IV', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory('qa/evaluacion/simulacion-alumno')
      ..createSync(recursive: true);
    final recursos = await tester.runAsync(() async {
      final loader = FontLoader('Outfit');
      for (final peso in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
      ]) {
        loader.addFont(rootBundle.load('assets/fuentes/Outfit-$peso.ttf'));
      }
      await loader.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader(
        'PhosphorBold',
      )..addFont(rootBundle.load('assets/fuentes/Phosphor-Bold.ttf'))).load();
      return RecursosActa.cargar();
    });
    final capturaKey = GlobalKey();
    final escalaTexto = ValueNotifier(1.0);
    final movimiento = ValueNotifier(false);
    addTearDown(escalaTexto.dispose);
    addTearDown(movimiento.dispose);
    Future<void> capturar(String nombre, {bool estabilizar = true}) async {
      if (estabilizar) await tester.pumpAndSettle();
      final objeto =
          capturaKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final imagen = await objeto.toImage();
        final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/$nombre.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        imagen.dispose();
      });
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: capturaKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: TemaTriviaAntiguedad.claro,
          home: const Scaffold(
            body: Center(child: SizedBox(width: 400, child: MarcaEvaluacion())),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(MarcaEvaluacion));
      await precacheImage(
        const AssetImage('assets/documentos/escudo-pscs.jpg'),
        ctx,
      );
      if (ctx.mounted) {
        await precacheImage(
          const AssetImage('assets/imagenes/optimizadas/marcas-naranjas.webp'),
          ctx,
        );
      }
    });
    await capturar('01-portada-unidad-iv');
    expect(find.text('Unidad'), findsOneWidget);
    expect(find.text('IV'), findsOneWidget);
    expect(find.text('Historia'), findsNothing);
    expect(find.text('Antigua'), findsNothing);

    final inicial = SesionTrivia.fromJson(
      jsonDecode(File('${dir.path}/sesion-inicial.json').readAsStringSync())
          as Map<String, dynamic>,
      banco,
    );
    final reloj = _RelojAlumno();
    final repo = _RepositorioSimulado(dir);
    final c = ControladorEvaluacion(
      MotorEvaluacion(banco, inicial, random: Random(20261021)),
      repo,
      temporizador: false,
      reloj: reloj,
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: capturaKey,
        child: ProviderScope(
          overrides: [
            almacenProvider.overrideWithValue(AlmacenMemoria()),
            respuestaInterfazProvider.overrideWithValue(
              const RespuestaSilenciosa(),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: TemaTriviaAntiguedad.claro,
            builder: (ctx, child) => AnimatedBuilder(
              animation: Listenable.merge([escalaTexto, movimiento]),
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(
                  disableAnimations: !movimiento.value,
                  textScaler: TextScaler.linear(escalaTexto.value),
                ),
                child: child!,
              ),
              child: child,
            ),
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  const FondoApertura(progreso: 1),
                  PantallaEvaluacion(controlador: c),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tocar(Finder finder) async {
      expect(finder, findsOneWidget);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    // Selecciones fijadas tras leer los enunciados SIN consultar las claves.
    // Catilina se responde mal deliberadamente y China agota el tiempo:
    // así se comprueban los tres resultados posibles de una pregunta propia.
    const selecciones = {
      'GRE-11': 1,
      'ROM-30': 1,
      'IND-29': 1,
      'MES-04': 3,
      'PER-01': 2,
      'EGI-15': 2,
      'CHI-20': null,
      'MES-17': 1,
      'ROM-35': 0,
      'GRE-06': 0,
    };
    final recorrido = <Map<String, Object?>>[];
    await tocar(find.byKey(const ValueKey('sortear-turno')));
    for (var turno = 0; turno < 10; turno++) {
      final r = c.sesion.actual!;
      final p = banco.porId[r.preguntaId]!;
      expect(
        find.byKey(const ValueKey('barra-control-evaluacion')),
        findsOneWidget,
      );
      expect(find.textContaining('Respuesta correcta:'), findsNothing);
      expect(c.sesion.tiempoSinIniciar, isTrue);
      reloj.ms = 90000;
      c.pulso();
      expect(c.sesion.restanteMs, 60000);
      expect(r.propio, isNull);
      if (turno == 0) {
        await capturar('02-lectura-sin-tiempo');
        for (final caso in [
          (const Size(800, 1280), 1.6, 'vertical'),
          (const Size(1280, 800), 2.0, 'texto-grande'),
          (const Size(1024, 600), 2.0, 'ventana-baja'),
        ]) {
          tester.view.physicalSize = caso.$1;
          escalaTexto.value = caso.$2;
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(c.sesion.restanteMs, 60000);
          await capturar('02-lectura-${caso.$3}');
        }
        tester.view.physicalSize = const Size(1280, 800);
        escalaTexto.value = 1;
        await tester.pumpAndSettle();
      }
      await tocar(find.byKey(const ValueKey('control-tiempo')));
      expect(c.sesion.pausada, isFalse);
      if (turno == 0) {
        await capturar('02-pregunta');
        reloj.ms = 12000;
        c.pulso();
        await tocar(find.byTooltip('Pausar tiempo'));
        final restante = c.sesion.restanteMs;
        reloj.ms = 45000;
        c.pulso();
        expect(c.sesion.restanteMs, restante);
        expect(c.sesion.pausada, isTrue);
        await tocar(find.byTooltip('Reanudar tiempo'));
        expect(c.sesion.pausada, isFalse);
      }
      final opcion = selecciones[r.preguntaId];
      reloj.ms = opcion == null ? 60000 : 14000 + turno * 1000;
      if (opcion == null) {
        c.pulso();
        await tester.pumpAndSettle();
        expect(r.propio!.estado, EstadoIntento.agotado);
      } else {
        await tocar(find.byKey(ValueKey('responder-$opcion')));
      }
      if (c.sesion.fase == FaseEvaluacion.esperaRobo) {
        expect(find.textContaining('Respuesta correcta:'), findsNothing);
        await tocar(find.byKey(const ValueKey('cerrar-pregunta')));
      }
      expect(c.sesion.fase, FaseEvaluacion.revision);
      expect(find.byKey(const ValueKey('ver-explicacion')), findsOneWidget);
      final intento = r.propio!;
      recorrido.add({
        'turno': turno + 1,
        'tema': p.tema,
        'pregunta': p.texto,
        'seleccion': opcion == null ? null : 'ABCD'[opcion],
        'respuesta': opcion == null ? null : p.opciones[r.orden[opcion]],
        'estado': intento.estado.name,
        'correcta': intento.correcto,
        'tiempo_activo_ms': intento.tiempoMs,
        'puntos_acumulados': c.sesion.resultado('ALUMNO_QA').puntos,
      });
      if (!intento.correcto) {
        await capturar('03-${opcion == null ? 'tiempo' : 'error'}');
      }
      if (turno == 0) {
        movimiento.value = true;
        await tester.pump();
        final siguiente = find.byKey(const ValueKey('siguiente-turno'));
        await tester.ensureVisible(siguiente);
        await tester.tap(siguiente);
        await tester.pump();
        await capturar('05-transicion-inicio', estabilizar: false);
        await tester.pump(const Duration(milliseconds: 110));
        await capturar('05-transicion-salida', estabilizar: false);
        await tester.pump(const Duration(milliseconds: 110));
        await capturar('05-transicion-asentamiento', estabilizar: false);
        await tester.pumpAndSettle();
        await capturar('05-transicion-final');
        movimiento.value = false;
        await tester.pumpAndSettle();
      } else {
        await tocar(find.byKey(const ValueKey('siguiente-turno')));
      }
    }
    expect(c.sesion.finalizada, isTrue);
    expect(c.sesion.cierreAnticipado, isFalse);
    final resultado = c.sesion.resultado('ALUMNO_QA');
    expect(resultado.presentadas, 10);
    expect(resultado.propias, 8);
    expect(resultado.robos, 0);
    expect(resultado.nota, 8);
    expect(resultado.aprobado, isTrue);
    expect(find.text('Evaluación finalizada'), findsOneWidget);
    await tocar(find.byKey(const ValueKey('seccion-2')));
    expect(find.text('8/10'), findsOneWidget);
    expect(find.text('APROBADO'), findsOneWidget);
    await c.guardadoPendiente;
    expect(repo.ultimaSesion, isNotNull);
    final recuperada = SesionTrivia.fromJson(
      jsonDecode(repo.ultimaSesion!) as Map<String, dynamic>,
      banco,
      recuperar: true,
    );
    expect(recuperada.resultado('ALUMNO_QA').nota, 8);
    await tester.runAsync(() async {
      final pdf = await GeneradorActa(recursos!)
          .crear(c.sesion, banco, alumnoId: 'ALUMNO_QA');
      File('${dir.path}/informe-alumno-simulado.pdf').writeAsBytesSync(pdf);
      const json = JsonEncoder.withIndent('  ');
      File('${dir.path}/sesion-final.json')
          .writeAsStringSync(json.convert(c.sesion.toJson()));
      File('${dir.path}/recorrido.json').writeAsStringSync(
        json.convert({
          'datos_simulados': true,
          'tiempos_virtuales': true,
          'preguntas': recorrido,
          'resultado': {'propias': 8, 'errores': 1, 'agotadas': 1, 'nota': 8},
          'lectura_sin_consumir_tiempo': true,
          'inicio_manual_en_cada_pregunta': true,
          'pausa_conserva_tiempo': true,
          'recuperacion_conserva_nota': true,
        }),
      );
    });
    await capturar('04-resultados');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
