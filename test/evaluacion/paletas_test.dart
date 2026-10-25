import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/almacenamiento/proveedores_almacenamiento.dart';
import 'package:trivia_antiguedad/compartido/componentes/entrada_inicio.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/configuracion.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/controlador.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/pantalla.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/repositorio.dart';
import 'package:trivia_antiguedad/tema/paleta_evaluacion.dart';
import 'package:trivia_antiguedad/tema/tema_evaluacion.dart';

import '../apoyo/base_pruebas.dart';
import 'motor_test.dart' show muestra;

class _Repo extends RepositorioEvaluacion {
  _Repo() : super(Directory.systemTemp);
  @override
  Future<void> guardar(String raw) async {}
}

void main() {
  testWidgets(
    'las cinco paletas preservan exactamente el papel y la textura de la pantalla real',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final f = FontLoader('Outfit');
        for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
          f.addFont(rootBundle.load('assets/fuentes/Outfit-$peso.ttf'));
        }
        await f.load();
        final iconos = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await iconos.load();
      });
      final roja = const PaletaEvaluacion(ColorEvaluacion.rojo);
      const muestras = {
        ColorEvaluacion.rojo: 0xFFB2190E,
        ColorEvaluacion.verde: 0xFF118E0B,
        ColorEvaluacion.azul: 0xFF0973BA,
        ColorEvaluacion.amarillo: 0xFFFFCC00,
        ColorEvaluacion.naranja: 0xFFC44E0F,
      };
      List<int>? papelRojo;
      final carpeta = Directory('qa/evaluacion/paletas')
        ..createSync(recursive: true);
      for (final tipo in ColorEvaluacion.values) {
        final p = PaletaEvaluacion(tipo);
        expect(p.naranja, Color(muestras[tipo]!));
        expect(p.fondo, roja.fondo);
        expect(p.hoja, roja.hoja);
        expect(p.tinta, roja.tinta);
        expect(p.tenue, roja.tenue);
        expect(p.filtroFondo, roja.filtroFondo);
        final switchTema = temaEvaluacion(p).switchTheme;
        expect(
          switchTema.thumbColor!.resolve({WidgetState.selected}),
          Colors.white,
        );
        expect(switchTema.thumbColor!.resolve({}), Colors.white);
        if (tipo == ColorEvaluacion.verde || tipo == ColorEvaluacion.amarillo) {
          expect(
            p.sobreNaranja,
            tipo == ColorEvaluacion.amarillo ? Colors.black : Colors.white,
          );
        }
        if (tipo != ColorEvaluacion.amarillo) {
          for (final par in [
            (p.salviaClara, roja.salviaClara),
            (p.salviaMedia, roja.salviaMedia),
            (p.salviaOscura, roja.salviaOscura),
            (p.borde, roja.borde),
          ]) {
            expect(
              (par.$1.computeLuminance() - par.$2.computeLuminance()).abs(),
              lessThan(.004),
            );
          }
        }
        if (tipo == ColorEvaluacion.amarillo) {
          expect(HSVColor.fromColor(p.salviaClara).saturation, greaterThan(.2));
          expect(HSVColor.fromColor(p.salviaMedia).saturation, greaterThan(.4));
          expect(
            HSVColor.fromColor(p.salviaOscura).saturation,
            greaterThan(.7),
          );
        }
        final c = ControladorEvaluacion(
          muestra(13),
          _Repo(),
          temporizador: false,
        );
        c.sesion.configuracion = ConfiguracionEvaluacion(color: tipo);
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
              debugShowCheckedModeBanner: false,
              theme: temaEvaluacion(p),
              home: RepaintBoundary(
                key: lienzo,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const FondoApertura(progreso: 1),
                    PantallaEvaluacion(controlador: c),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(
              'assets/imagenes/optimizadas/conversation-background-v2.webp',
            ),
            lienzo.currentContext!,
          ),
        );
        await tester.pump();
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(tester.takeException(), isNull);
        final iniciar = tester.widget<FilledButton>(
          find.byKey(const ValueKey('iniciar-evaluacion')),
        );
        expect(iniciar.style!.foregroundColor!.resolve({}), p.sobreNaranja);
        expect(
          tester.widget<Text>(find.text('10')).style!.color,
          p.naranjaTexto,
        );
        expect(
          tester.widget<Text>(find.text('LA EVALUACIÓN')).style!.color,
          p.naranjaTexto,
        );
        await tester.runAsync(() async {
          final imagen =
              await (lienzo.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final raw = (await imagen.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final papel = <int>[
            for (var y = 80; y < 100; y++)
              for (var x = 10; x < 30; x++)
                for (var canal = 0; canal < 4; canal++)
                  raw.getUint8((y * 1280 + x) * 4 + canal),
          ];
          papelRojo ??= papel;
          expect(papel, papelRojo, reason: tipo.name);
          final bytes = (await imagen.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File('${carpeta.path}/${tipo.name}.png')
              .writeAsBytes(bytes.buffer.asUint8List());
          imagen.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        await tester.pump();
        await c.guardadoPendiente;
      }
    },
  );
}
