import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/almacenamiento/proveedores_almacenamiento.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/configuracion.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/controlador.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/modelos.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/preferencias_evaluacion.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/repositorio.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/dialogo_configuracion.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/acta_pdf.dart';
import 'package:trivia_antiguedad/tema/paleta_evaluacion.dart';
import 'package:trivia_antiguedad/tema/tema_evaluacion.dart';

import '../apoyo/base_pruebas.dart';
import 'motor_test.dart' show muestra, banco;

class _RepoFallido extends RepositorioEvaluacion {
  _RepoFallido() : super(Directory.systemTemp);
  @override
  Future<void> guardar(String raw) async =>
      throw const FileSystemException('Fallo simulado');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nueva = ConfiguracionEvaluacion(
    materia: 'Biología',
    nombreCorto: 'Biología',
    tema: 'La célula',
    docente: 'Docente de prueba',
    ayudante: 'Ayudante de prueba',
    comision: '2B · 2026',
    color: ColorEvaluacion.azul,
  );
  test('respaldo v1, configuración propia, persistencia y deshacer', () async {
    final directorio = await Directory.systemTemp.createTemp(
      'configuracion-evaluacion-',
    );
    addTearDown(() => directorio.delete(recursive: true));
    final m = muestra(2);
    final viejo = m.sesion.toJson()..remove('configuracion');
    expect(
      SesionTrivia.fromJson(viejo, banco).configuracion.titulo,
      'Antigüedad - Unidad IV',
    );
    m.iniciar();
    m.siguiente();
    m.reanudar();
    m.responder(m.sesion.actual!.indiceCorrecto(banco));
    final c = ControladorEvaluacion(
      m,
      RepositorioEvaluacion(directorio),
      temporizador: false,
    );
    await c.configurar(nueva);
    expect(
      (await c.repositorio.cargar(banco)).sesion!.configuracion.titulo,
      nueva.titulo,
    );
    m.deshacer();
    expect(m.sesion.configuracion.toJson(), nueva.toJson());
    c.nuevaSesion();
    expect(c.sesion.configuracion.tema, 'La célula');
    c.dispose();
    await c.guardadoPendiente;
    final roto = ControladorEvaluacion(
      muestra(2),
      _RepoFallido(),
      temporizador: false,
    );
    await expectLater(
      roto.configurar(nueva),
      throwsA(isA<FileSystemException>()),
    );
    expect(roto.sesion.configuracion.titulo, 'Antigüedad - Unidad IV');
    roto.dispose();
    await roto.guardadoPendiente;
  });
  test('preferencias recuperadas y validación de configuración', () async {
    final almacen = AlmacenMemoria();
    final container = ProviderContainer(
      overrides: [almacenProvider.overrideWithValue(almacen)],
    );
    await container.read(configuracionEvaluacionProvider.future);
    await container
        .read(configuracionEvaluacionProvider.notifier)
        .guardar(nueva);
    container.dispose();
    final otro = ProviderContainer(
      overrides: [almacenProvider.overrideWithValue(almacen)],
    );
    addTearDown(otro.dispose);
    expect(
      (await otro.read(configuracionEvaluacionProvider.future)).toJson(),
      nueva.toJson(),
    );
    expect(
      ConfiguracionEvaluacion.fromJson(nueva.toJson()..remove('ayudante'))
          .ayudante,
      '',
    );
    expect(
      ConfiguracionEvaluacion.fromJson(nueva.toJson()..['ayudante'] = '  ')
          .ayudante,
      '',
    );
    expect(
      () =>
          ConfiguracionEvaluacion.fromJson(nueva.toJson()..['ayudante'] = 123),
      throwsFormatException,
    );
    expect(
      () => ConfiguracionEvaluacion.fromJson(nueva.toJson()..['tema'] = '  '),
      throwsFormatException,
    );
    expect(
      () => ConfiguracionEvaluacion.fromJson(
        nueva.toJson()..['color'] = 'violeta',
      ),
      throwsFormatException,
    );
  });
  testWidgets(
    'configuración desplazable en ambas orientaciones y cinco paletas con contraste',
    (tester) async {
      ConfiguracionEvaluacion? guardada;
      await tester.runAsync(() async {
        final fuente = FontLoader('Outfit');
        for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
          fuente.addFont(rootBundle.load('assets/fuentes/Outfit-$peso.ttf'));
        }
        await fuente.load();
      });
      for (final size in [const Size(1280, 800), const Size(800, 1280)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        final lienzo = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                RepaintBoundary(key: lienzo, child: child!),
            theme: temaEvaluacion(const PaletaEvaluacion(ColorEvaluacion.azul)),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    guardada = await editarConfiguracion(context, nueva);
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final imagen =
              await (lienzo.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final datos = (await imagen.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final carpeta = Directory('qa/evaluacion/configuracion-agrupada')
            ..createSync(recursive: true);
          await File(
            '${carpeta.path}/${size.width > size.height ? 'horizontal' : 'vertical'}.png',
          ).writeAsBytes(datos.buffer.asUint8List());
          imagen.dispose();
        });
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Guardar'),
              )
              .onPressed,
          isNull,
        );
        await tester.enterText(
          find.byKey(const ValueKey('configuracion-tema')),
          'Ecosistemas',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(find.text('Guardar').hitTestable(), findsOneWidget);
        expect(find.text('Cancelar').hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('Amarillo'));
        expect(
          (tester.getCenter(find.text('Paleta de colores')).dy -
                  tester.getCenter(find.byTooltip('Amarillo')).dy)
              .abs(),
          lessThan(1),
        );
        expect(find.byType(ChoiceChip), findsNothing);
        await tester.tap(find.byTooltip('Amarillo'));
        await tester.pump();
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(guardada!.tema, 'Ecosistemas');
        expect(guardada!.ayudante, nueva.ayudante);
        expect(guardada!.color, ColorEvaluacion.amarillo);
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pump();
      }
      for (final tipo in ColorEvaluacion.values) {
        final p = PaletaEvaluacion(tipo);
        double contraste(Color a, Color b) {
          final x = a.computeLuminance(), y = b.computeLuminance();
          return (x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05));
        }

        if (tipo == ColorEvaluacion.verde || tipo == ColorEvaluacion.amarillo) {
          expect(
            p.sobreNaranja,
            tipo == ColorEvaluacion.amarillo ? Colors.black : Colors.white,
          );
        } else {
          expect(
            contraste(p.naranja, p.sobreNaranja),
            greaterThanOrEqualTo(4.5),
            reason: tipo.name,
          );
        }
        expect(contraste(p.tinta, p.hoja), greaterThanOrEqualTo(7));
        expect(p.error, const Color(0xFFB2190E));
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
  test(
    'informes con nombres configurados y muestras de las cinco paletas',
    () async {
      final carpeta = Directory('qa/evaluacion/configuracion')
        ..createSync(recursive: true);
      final recursos = await RecursosActa.cargar();
      final m = muestra(2);
      m.iniciar();
      m.siguiente();
      m.reanudar();
      m.responder(m.sesion.actual!.indiceCorrecto(banco));
      for (final tipo in ColorEvaluacion.values) {
        m.sesion.configuracion = ConfiguracionEvaluacion.fromJson(
          nueva.toJson()..['color'] = tipo.name,
        );
        final bytes = await GeneradorActa(recursos)
            .crear(m.sesion, banco, alumnoId: m.sesion.alumnos.first.id);
        await File('${carpeta.path}/informe-${tipo.name}.pdf')
            .writeAsBytes(bytes);
      }
      m.sesion.configuracion = ConfiguracionEvaluacion(
        materia: List.filled(18, 'Materia de').join(' ').substring(0, 180),
        nombreCorto: 'Biología',
        tema: List.filled(8, 'Unidad extensa').join(' ').substring(0, 80),
        docente: List.filled(12, 'Docente de').join(' ').substring(0, 120),
        ayudante: List.filled(12, 'Ayudante de').join(' ').substring(0, 120),
        comision: 'Comisión con un nombre largo',
        color: ColorEvaluacion.verde,
      );
      await File('${carpeta.path}/informe-nombres-largos.pdf').writeAsBytes(
        await GeneradorActa(recursos)
            .crear(m.sesion, banco, alumnoId: m.sesion.alumnos.first.id),
      );
      await File('${carpeta.path}/respaldo-prueba.json')
          .writeAsString(jsonEncode(m.sesion.toJson()));
    },
  );
  test(
    'PDF completo conserva cada informe individual y su numeración',
    () async {
      final carpeta = Directory('qa/evaluacion/informes-unificados-1.1.75')
        ..createSync(recursive: true);
      final m = muestra(3);
      m.sesion.configuracion = nueva;
      m.asistencia(m.sesion.alumnos.last.id, false);
      m.iniciar();
      m.siguiente();
      m.reanudar();
      m.responder(m.sesion.actual!.indiceCorrecto(banco));
      final generador = GeneradorActa(await RecursosActa.cargar());
      var suma = 0;
      for (var i = 0; i < m.sesion.alumnos.length; i++) {
        final bytes = await generador.crear(
          m.sesion,
          banco,
          alumnoId: m.sesion.alumnos[i].id,
          alContar: (n) => suma += n,
        );
        await File('${carpeta.path}/individual-$i.pdf').writeAsBytes(bytes);
      }
      var total = 0;
      final completo = await generador.crearCompleto(
        m.sesion,
        banco,
        alContar: (n) => total = n,
      );
      expect(total, suma);
      expect(total, greaterThanOrEqualTo(6));
      await File('${carpeta.path}/completo.pdf').writeAsBytes(completo);
    },
  );
}
