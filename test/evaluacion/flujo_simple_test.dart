import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/controlador.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/pantalla.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/repositorio.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/controladores/controlador_partida.dart';
import 'package:trivia_antiguedad/tema/tema_trivia_antiguedad.dart';

import '../apoyo/base_pruebas.dart';
import 'motor_test.dart' show muestra, banco;

class _RepositorioMemoria extends RepositorioEvaluacion {
  _RepositorioMemoria() : super(Directory.systemTemp);
  int informes = 0;
  @override
  Future<void> guardar(String raw) async {}
  @override
  Future<File> guardarInforme(String nombre, List<int> bytes) async {
    informes++;
    return File('${Directory.systemTemp.path}/$nombre');
  }
}

void main() {
  testWidgets('informes individuales y nueva evaluación desde ambos accesos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const capturar = bool.fromEnvironment('CAPTURAR_PANTALLAS');
    if (capturar) {
      await tester.runAsync(() async {
        final fuente = FontLoader('Outfit');
        for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
          fuente.addFont(rootBundle.load('assets/fuentes/Outfit-$peso.ttf'));
        }
        await fuente.load();
        await (FontLoader(
          'PhosphorBold',
        )..addFont(rootBundle.load('assets/fuentes/Phosphor-Bold.ttf'))).load();
        await (FontLoader('MaterialIcons')..addFont(
              File(
                'C:/Users/alan/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      });
    }
    final motor = muestra(2)
      ..iniciar()
      ..siguiente()
      ..reanudar();
    final titular = motor.sesion.actual!.titularId;
    motor.responder(motor.sesion.actual!.indiceCorrecto(banco));
    motor.siguiente();
    final repositorio = _RepositorioMemoria();
    final c = ControladorEvaluacion(motor, repositorio, temporizador: false);
    final nombres = c.sesion.alumnos.map((a) => a.completo).toList();
    final idInicial = c.sesion.id;
    final lienzo = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          almacenProvider.overrideWithValue(AlmacenMemoria()),
          respuestaInterfazProvider.overrideWithValue(
            const RespuestaSilenciosa(),
          ),
        ],
        child: MaterialApp(
          theme: TemaTriviaAntiguedad.claro,
          builder: (_, child) => RepaintBoundary(
            key: lienzo,
            child: ColoredBox(color: TemaTriviaAntiguedad.fondo, child: child!),
          ),
          home: PantallaEvaluacion(controlador: c),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> captura(String nombre) async {
      if (!capturar) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final imagen =
            await (lienzo.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
        final carpeta = Directory('qa/evaluacion/pantallas-1.1.34')
          ..createSync(recursive: true);
        await File('${carpeta.path}/$nombre.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        imagen.dispose();
      });
    }

    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await captura('evaluacion');
    await tester.tap(find.byKey(const ValueKey('seccion-0')));
    await tester.pumpAndSettle();
    final nuevaEstudiantes = find.byKey(
      const ValueKey('nueva-evaluacion-estudiantes'),
    );
    expect(nuevaEstudiantes.hitTestable(), findsOneWidget);
    await captura('estudiantes');
    await tester.tap(nuevaEstudiantes);
    await tester.pumpAndSettle();
    await captura('confirmacion');
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(c.sesion.id, idInicial);
    expect(c.sesion.resultado(titular).puntos, 1);
    await tester.tap(nuevaEstudiantes);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear evaluación'));
    await tester.pumpAndSettle();
    expect(c.sesion.iniciada, isFalse);
    expect(c.sesion.id, isNot(idInicial));
    expect(c.sesion.resultado(titular).puntos, 0);
    expect(c.sesion.alumnos.map((a) => a.completo), nombres);
    c.accion((m) {
      m.iniciar();
      m.finalizar();
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('seccion-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('nueva-evaluacion-finalizada')).hitTestable(),
      findsOneWidget,
    );
    expect(repositorio.informes, 0);
    await captura('finalizada');
    await tester.tap(find.text('Ver resultados'));
    await tester.pumpAndSettle();
    for (final a in c.sesion.alumnos) {
      expect(find.byTooltip('PDF de ${a.completo}'), findsOneWidget);
    }
    expect(find.textContaining('informe general'), findsNothing);
    expect(find.text('Informe general'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await captura('resultados');
    await tester.tap(find.byKey(const ValueKey('seccion-3')));
    await tester.pumpAndSettle();
    await captura('banco');
    await tester.tap(find.byKey(const ValueKey('seccion-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nueva-evaluacion-finalizada')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear evaluación'));
    await tester.pumpAndSettle();
    expect(c.sesion.iniciada, isFalse);
    expect(c.sesion.finalizada, isFalse);
    expect(c.sesion.alumnos.map((a) => a.completo), nombres);
    expect(repositorio.informes, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump();
    await c.guardadoPendiente;
  });
}
