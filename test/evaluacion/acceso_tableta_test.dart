import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/app.dart';
import 'package:trivia_antiguedad/funcionalidades/bienvenida/componentes/puerta_bienvenida.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/acceso_tableta.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/pantalla.dart';
import 'package:trivia_antiguedad/tema/tema_trivia_antiguedad.dart';

void main() {
  for (final caso in [
    (const Size(393, 852), 1.0),
    (const Size(852, 393), 1.0),
    (const Size(599, 1200), 1.0),
    (const Size(1080, 2400), 3.0),
  ]) {
    testWidgets('el móvil ${caso.$1} a densidad ${caso.$2} no monta el juego', (
      tester,
    ) async {
      tester.view.physicalSize = caso.$1;
      tester.view.devicePixelRatio = caso.$2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final captura = GlobalKey();
      if (caso.$1 == const Size(393, 852)) {
        await tester.runAsync(() async {
          final fuente = FontLoader('Outfit');
          for (final peso in ['Regular', 'Bold']) {
            fuente.addFont(rootBundle.load('assets/fuentes/Outfit-$peso.ttf'));
          }
          await fuente.load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: captura,
          child: const ProviderScope(child: TriviaAntiguedadApp()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PantallaSoloTabletas), findsOneWidget);
      expect(find.text('Ups, esta app es para tabletas'), findsOneWidget);
      expect(find.byType(PuertaBienvenida), findsNothing);
      expect(find.byType(PantallaEvaluacion), findsNothing);
      expect(find.text('Comenzar'), findsNothing);
      expect(tester.takeException(), isNull);
      if (caso.$1 == const Size(393, 852)) {
        await tester.runAsync(() async {
          final render =
              captura.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final imagen = await render.toImage();
          final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
          final carpeta = Directory('qa/evaluacion/solo-tabletas')
            ..createSync(recursive: true);
          File('${carpeta.path}/telefono-bloqueado.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          imagen.dispose();
        });
      }
    });
  }

  for (final tamano in [
    const Size(600, 960),
    const Size(800, 1280),
    const Size(1280, 800),
  ]) {
    testWidgets('la tableta $tamano permite entrar', (tester) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var montada = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: TemaTriviaAntiguedad.claro,
          home: AccesoTableta(
            child: Builder(
              builder: (_) {
                montada = true;
                return const Scaffold(body: Text('Evaluación habilitada'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(montada, isTrue);
      expect(find.text('Evaluación habilitada'), findsOneWidget);
      expect(find.byType(PantallaSoloTabletas), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
