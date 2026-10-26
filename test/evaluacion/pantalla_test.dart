import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:trivia_antiguedad/compartido/componentes/entrada_inicio.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/controlador.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/configuracion.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/marca_pscs.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/modelos.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/pantalla.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/repositorio.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/contorno_respuesta.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/controladores/controlador_partida.dart';
import 'package:trivia_antiguedad/tema/tema_trivia_antiguedad.dart';
import 'package:trivia_antiguedad/tema/paleta_evaluacion.dart';
import 'package:trivia_antiguedad/tema/tema_evaluacion.dart';

import '../apoyo/base_pruebas.dart';
import 'motor_test.dart' show muestra, banco;
import 'estudiantes_json_test.dart' show ejemploEstudiantes;
import 'banco_personalizado_test.dart' show ejemploBanco;

class _RepoMemoria extends RepositorioEvaluacion {
  _RepoMemoria() : super(Directory.systemTemp);
  @override
  Future<void> guardar(String raw) async {}
}

final class _ArchivoBanco extends PlatformFile {
  _ArchivoBanco(this.raw);
  final String raw;
  @override
  String get name => 'banco.json';
  @override
  Stream<Uint8List> readAsByteStream() async* {
    yield Uint8List.fromList(utf8.encode(raw));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SelectorBanco extends FilePickerPlatform {
  String? raw;
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => raw == null ? null : _ArchivoBanco(raw!);
}

final _lienzo = GlobalKey();

class _AudioEvaluacion implements RespuestaInterfaz {
  final efectos = <EfectoInterfaz>[];
  @override
  void emitir(EfectoInterfaz efecto) => efectos.add(efecto);
  @override
  void silenciar() {}
}

bool _fuentesCargadas = false;
Future<void> _montar(
  WidgetTester tester,
  ControladorEvaluacion c, {
  bool reducido = true,
  Size size = const Size(1280, 800),
  double escala = 1,
  RespuestaInterfaz? audio,
  ThemeData? tema,
  bool fondo = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (!_fuentesCargadas) {
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
    _fuentesCargadas = true;
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        almacenProvider.overrideWithValue(AlmacenMemoria()),
        respuestaInterfazProvider.overrideWithValue(
          audio ?? const RespuestaSilenciosa(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: tema ?? TemaTriviaAntiguedad.claro,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reducido,
            textScaler: TextScaler.linear(escala),
          ),
          child: RepaintBoundary(
            key: _lienzo,
            child: ColoredBox(
              color: TemaTriviaAntiguedad.fondo,
              child: Stack(
                fit: StackFit.expand,
                children: [if (fondo) const FondoApertura(progreso: 1), child!],
              ),
            ),
          ),
        ),
        home: PantallaEvaluacion(controlador: c),
      ),
    ),
  );
  await _pasar(tester, 1000);
}

Future<void> _pasar(WidgetTester tester, int ms) async {
  await tester.pump();
  for (var i = 0; i < ms; i += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _cerrar(WidgetTester tester, ControladorEvaluacion c) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  c.dispose();
  await tester.pump();
  await c.guardadoPendiente;
}

Future<void> _captura(WidgetTester tester, String nombre) async {
  if (!const bool.fromEnvironment('CAPTURAR_BARRAS')) return;
  await tester.runAsync(() async {
    final imagen =
        await (_lienzo.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('qa/evaluacion/barras-flutter-1.1.42')
      ..createSync(recursive: true);
    await File('${dir.path}/$nombre.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    imagen.dispose();
  });
}

Finder _boton(String clave) => find.byKey(ValueKey(clave));

void main() {
  testWidgets(
    'adaptaciones de secciones conservan controles, tabla y filtros en tableta',
    (tester) async {
      final datos = (await tester.runAsync(cargarContenidoTrivia))!;
      final s = SesionTrivia(
        id: 'IV_PRUEBA_ADAPTACIONES',
        fecha: DateTime.utc(2026, 10, 24),
        huellaBanco: datos.banco.huella,
        alumnos: datos.alumnos,
      );
      s.configuracion = ConfiguracionEvaluacion.fromJson(
        s.configuracion.toJson()..['color'] = 'azul',
      );
      final motor = MotorEvaluacion(datos.banco, s)..iniciar();
      for (var i = 0; i < 3; i++) {
        motor.siguiente();
        motor.reanudar();
        motor.responder(s.actual!.indiceCorrecto(datos.banco));
      }
      final c = ControladorEvaluacion(
        motor,
        _RepoMemoria(),
        temporizador: false,
        alumnosIniciales: s.alumnos.map((a) => a.id).toSet(),
      );
      await _montar(
        tester,
        c,
        fondo: true,
        tema: temaEvaluacion(const PaletaEvaluacion(ColorEvaluacion.azul)),
      );
      Future<void> captura(String nombre) async {
        for (var intento = 0; intento < 20; intento++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pumpAndSettle();
          final marca = find.descendant(
            of: find.byType(MarcaPscs),
            matching: find.byType(RawImage),
          );
          if (marca.evaluate().isNotEmpty &&
              tester.widget<RawImage>(marca.first).image != null) {
            break;
          }
        }
        await tester.runAsync(() async {
          final image =
              await (_lienzo.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final dir = Directory('qa/evaluacion/adaptaciones-1.1.78')
            ..createSync(recursive: true);
          await File('${dir.path}/$nombre.png')
              .writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }

      for (final size in [const Size(1280, 800), const Size(800, 1280)]) {
        tester.view.physicalSize = size;
        final orientacion = size.width > size.height
            ? 'horizontal'
            : 'vertical';
        for (final vista in [0, 2, 3]) {
          await tester.tap(_boton('seccion-$vista'));
          await _pasar(tester, 1600);
          final tools = _boton('herramientas-seccion');
          expect(tester.getSize(tools), const Size(76, 228));
          expect(
            tester
                .getRect(tools)
                .overlaps(tester.getRect(_boton('panel-secciones'))),
            isFalse,
          );
          final area = tester.getRect(_boton('area-seccion'));
          expect(
            tester.getRect(_boton('panel-secciones')).left - area.right,
            closeTo(size.width > size.height ? 72 : 24, .1),
          );
          expect(area.top, closeTo(0, .01));
          expect(area.bottom, closeTo(size.height, .01));
          if (vista == 2) {
            expect(find.text('Resultados'), findsOneWidget);
            expect(
              tester.widget<IconButton>(_boton('todos-informes-pdf')).onPressed,
              isNotNull,
            );
            expect(find.text('Informe parcial'), findsNothing);
            expect(find.text('Resultados individuales'), findsNothing);
            expect(
              find.byTooltip('PDF de ${s.alumnos.first.completo}'),
              findsOneWidget,
            );
          }
          if (vista == 3) {
            expect(
              tester.widget<IconButton>(_boton('cargar-banco-json')).onPressed,
              isNotNull,
            );
          }
          await captura('$orientacion-$vista');
        }
        await tester.tap(_boton('seccion-2'));
        await _pasar(tester, 1300);
        await tester.ensureVisible(
          find.byTooltip('PDF de ${s.alumnos.last.completo}'),
        );
        await _pasar(tester, 300);
        expect(
          find.byTooltip('PDF de ${s.alumnos.last.completo}').hitTestable(),
          findsOneWidget,
        );
        await captura('$orientacion-resultados-final');
      }
      await _cerrar(tester, c);
    },
  );

  testWidgets(
    'lista agrupada conserva asistencia y acceso a todos los estudiantes',
    (tester) async {
      final datos = (await tester.runAsync(cargarContenidoTrivia))!;
      await tester.runAsync(() async {
        await (FontLoader(
          'PhosphorBold',
        )..addFont(rootBundle.load('assets/fuentes/Phosphor-Bold.ttf'))).load();
      });
      final sesion = SesionTrivia(
        id: 'IV_PRUEBA_DISENO_ESTUDIANTES',
        fecha: DateTime.utc(2026, 10, 24),
        huellaBanco: datos.banco.huella,
        alumnos: datos.alumnos,
      );
      sesion.configuracion = ConfiguracionEvaluacion.fromJson(
        sesion.configuracion.toJson()
          ..['color'] = 'azul'
          ..['comision'] = '3B · 2026',
      );
      for (var i = 0; i < sesion.alumnos.length; i++) {
        sesion.alumnos[i].presente = i == 3;
      }
      final motor = MotorEvaluacion(datos.banco, sesion)..iniciar();
      final c = ControladorEvaluacion(
        motor,
        _RepoMemoria(),
        temporizador: false,
        alumnosIniciales: datos.alumnos.map((a) => a.id).toSet(),
      );
      await _montar(
        tester,
        c,
        tema: temaEvaluacion(const PaletaEvaluacion(ColorEvaluacion.azul)),
      );
      await tester.tap(_boton('seccion-0'));
      await _pasar(tester, 1200);
      expect(find.text('13 estudiantes · 1 presente'), findsOneWidget);
      expect(find.byType(Chip), findsNothing);
      expect(
        _boton('nueva-evaluacion-estudiantes').hitTestable(),
        findsOneWidget,
      );
      Future<void> captura(String nombre) async {
        if (!const bool.fromEnvironment('CAPTURAR_BARRAS')) return;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pumpAndSettle();
        final zona = tester.getRect(_boton('area-seccion'));
        await tester.runAsync(() async {
          final imagen =
              await (_lienzo.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('qa/evaluacion/estudiantes-agrupados')
            ..createSync(recursive: true);
          await File('${dir.path}/$nombre.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          await File('${dir.path}/$nombre-zona.json').writeAsString(
            jsonEncode([zona.left, zona.top, zona.right, zona.bottom]),
          );
          imagen.dispose();
        });
      }

      await captura('horizontal');
      final nombre = sesion.alumno('S01').completo;
      await tester.tap(_boton('asistencia-S01'));
      await _pasar(tester, 300);
      expect(sesion.alumno('S01').presente, isTrue);
      expect(sesion.alumno('S01').completo, nombre);
      expect(find.text('13 estudiantes · 2 presentes'), findsOneWidget);
      await tester.tap(_boton('asistencia-S01'));
      await _pasar(tester, 300);
      final ultimo = _boton('asistencia-${sesion.alumnos.last.id}');
      await tester.ensureVisible(ultimo);
      await _pasar(tester, 300);
      expect(ultimo.hitTestable(), findsOneWidget);
      expect(sesion.alumnos.where((a) => a.presente).length, 1);
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const PageStorageKey('nomina-evaluacion')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scroll.position.jumpTo(0);
      tester.view.physicalSize = const Size(800, 1280);
      await _pasar(tester, 1000);
      await captura('vertical');
      await tester.ensureVisible(ultimo);
      await _pasar(tester, 300);
      expect(ultimo.hitTestable(), findsOneWidget);
      await tester.ensureVisible(_boton('nueva-evaluacion-estudiantes'));
      await _pasar(tester, 300);
      expect(
        _boton('nueva-evaluacion-estudiantes').hitTestable(),
        findsOneWidget,
      );
      await _montar(
        tester,
        c,
        size: const Size(800, 1280),
        escala: 2,
        tema: temaEvaluacion(const PaletaEvaluacion(ColorEvaluacion.azul)),
      );
      await tester.ensureVisible(ultimo);
      await _pasar(tester, 300);
      expect(ultimo.hitTestable(), findsOneWidget);
      await _cerrar(tester, c);
    },
  );

  testWidgets(
    'carga JSON, permite cancelar, actualiza temas y bloquea cambios durante la evaluación',
    (tester) async {
      final anterior = FilePickerPlatform.instance;
      final selector = _SelectorBanco();
      FilePickerPlatform.instance = selector;
      addTearDown(() => FilePickerPlatform.instance = anterior);
      final c = ControladorEvaluacion(
        muestra(2),
        _RepoMemoria(),
        temporizador: false,
      );
      await _montar(tester, c);
      await tester.tap(_boton('seccion-3'));
      await _pasar(tester, 1200);
      final id = c.sesion.id;
      await tester.tap(_boton('cargar-banco-json'));
      await _pasar(tester, 400);
      expect(c.sesion.id, id);
      selector.raw = jsonEncode(ejemploBanco(23));
      await tester.tap(_boton('cargar-banco-json'));
      await _pasar(tester, 400);
      expect(find.text('Cargar banco'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Cargar'));
      await _pasar(tester, 600);
      expect(c.banco.personalizado, isTrue);
      expect(find.textContaining('Banco de prueba'), findsOneWidget);
      final temas = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(temas.items!.map((i) => i.value), [
        'Todos',
        'tema:Tema nuevo',
        'tema:Otro tema',
        'tema:Todos',
      ]);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await _pasar(tester, 300);
      await tester.tap(find.text('Tema nuevo').last);
      await _pasar(tester, 400);
      expect(find.textContaining('8 preguntas · Tema nuevo'), findsOneWidget);
      await _captura(tester, 'banco-personalizado');
      await tester.tap(_boton('seccion-0'));
      await _pasar(tester, 1000);
      expect(find.textContaining('23 preguntas · 3 temas'), findsOneWidget);
      await tester.tap(_boton('seccion-3'));
      await _pasar(tester, 1000);
      c.accion((m) => m.iniciar());
      await _pasar(tester, 300);
      expect(
        tester.widget<IconButton>(_boton('cargar-banco-json')).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<IconButton>(_boton('guardar-plantilla-json')).onPressed,
        isNotNull,
      );
      final idActivo = c.sesion.id;
      await tester.tap(_boton('cargar-banco-json'));
      await _pasar(tester, 300);
      expect(
        find.textContaining('La evaluación actual quedará guardada.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Volver'));
      await _pasar(tester, 300);
      expect(c.sesion.id, idActivo);
      expect(c.sesion.iniciada, isTrue);
      await tester.tap(_boton('cargar-banco-json'));
      await _pasar(tester, 300);
      await tester.tap(find.text('Crear evaluación'));
      await _pasar(tester, 500);
      expect(c.sesion.id, isNot(idActivo));
      expect(c.sesion.iniciada, isFalse);
      await _cerrar(tester, c);
    },
  );
  testWidgets(
    'la evaluación conecta sus señales sin repetirlas por reconstrucción',
    (tester) async {
      final audio = _AudioEvaluacion();
      final c = ControladorEvaluacion(
        muestra(3)..iniciar(),
        _RepoMemoria(),
        temporizador: false,
      );
      await _montar(tester, c, audio: audio);
      expect(audio.efectos, isEmpty);
      c.accion((m) => m.siguiente());
      await _pasar(tester, 200);
      c.accion((m) => m.reanudar());
      final correcta = c.sesion.actual!.indiceCorrecto(banco);
      c.accion((m) => m.responder((correcta + 1) % 4));
      c.accion((m) => m.iniciarRobo(m.sesion.habilitadosRobo.first.id));
      c.accion((m) => m.responder(correcta));
      await _pasar(tester, 500);
      c.reintentar();
      await _pasar(tester, 300);
      expect(audio.efectos, [
        EfectoInterfaz.evaluacionPasar,
        EfectoInterfaz.evaluacionTiempo,
        EfectoInterfaz.evaluacionIncorrecta,
        EfectoInterfaz.evaluacionRobo,
        EfectoInterfaz.evaluacionCorrecta,
      ]);
      c.accion((m) => m.deshacer());
      expect(audio.efectos.last, EfectoInterfaz.evaluacionDeshacer);
      await _cerrar(tester, c);
    },
  );
  testWidgets(
    'avisos de puntaje redondeados: aprobación vertical y diez horizontal',
    (tester) async {
      for (final puntos in [7, 10]) {
        final m = muestra(1)..iniciar();
        for (var i = 0; i < puntos; i++) {
          if (m.sesion.avisoPuntajeId != null) {
            m.resolverAvisoPuntaje(finalizar: false);
          }
          m.siguiente();
          m.reanudar();
          m.responder(m.sesion.actual!.indiceCorrecto(banco));
        }
        final c = ControladorEvaluacion(m, _RepoMemoria(), temporizador: false);
        await _montar(
          tester,
          c,
          size: puntos == 7 ? const Size(800, 1280) : const Size(1280, 800),
        );
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.textContaining('El alumno SIMULACIÓN 0, Estudiante de prueba'),
          findsOneWidget,
        );
        expect(find.text('Continuar'), findsOneWidget);
        expect(
          find.text('Finalizar'),
          puntos == 7 ? findsOneWidget : findsNothing,
        );
        final dialogo = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect(
          (dialogo.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(28),
        );
        await _captura(tester, 'aviso-puntaje-$puntos');
        await tester.tap(find.text(puntos == 7 ? 'Finalizar' : 'Continuar'));
        await _pasar(tester, 400);
        expect(c.sesion.avisoPuntajeId, isNull);
        expect(c.sesion.terminoAlumno('S0'), isTrue);
        await _cerrar(tester, c);
      }
    },
  );

  testWidgets(
    'vertical de menor altura conserva tamaños y controles visibles',
    (tester) async {
      final c = ControladorEvaluacion(
        muestra(3)
          ..iniciar()
          ..siguiente(),
        _RepoMemoria(),
        temporizador: false,
      );
      await _montar(tester, c, size: const Size(600, 960), escala: 1.5);
      final barra = _boton('barra-control-evaluacion');
      expect(tester.getSize(barra).width, 76);
      final herramientas = _boton('herramientas-seccion');
      expect(tester.getSize(herramientas).width, 76);
      expect(
        tester.getRect(herramientas).overlaps(tester.getRect(barra)),
        isFalse,
      );
      expect(
        tester.getSize(_boton('configuracion-evaluacion')),
        const Size(52, 52),
      );
      expect(tester.getSize(_boton('panel-secciones')), const Size(76, 284));
      await tester.tap(_boton('control-tiempo'));
      await _pasar(tester, 1200);
      for (var i = 0; i < 4; i++) {
        final boton = _boton('responder-$i');
        expect(boton.hitTestable(), findsOneWidget);
        expect(tester.getRect(barra).contains(tester.getCenter(boton)), isTrue);
      }
      expect(_boton('no-contesta').hitTestable(), findsOneWidget);
      await _captura(tester, 'vertical-600-texto-ampliado');
      await _cerrar(tester, c);
    },
  );

  testWidgets('vertical aprobado: dos círculos, cápsulas de 76 y dos robos', (
    tester,
  ) async {
    final c = ControladorEvaluacion(
      muestra(5)..iniciar(),
      _RepoMemoria(),
      temporizador: false,
    );
    await _montar(tester, c, reducido: false, size: const Size(800, 1280));
    await tester.tap(_boton('sortear-turno'));
    await _pasar(tester, 1280);
    final nav = _boton('panel-secciones');
    final barra = _boton('barra-control-evaluacion');
    final circuloNav = tester.getRect(nav);
    final circuloControl = tester.getRect(barra);
    expect(circuloNav.size, const Size(76, 76));
    expect(circuloControl.size, const Size(76, 76));
    expect(circuloNav.top - circuloControl.bottom, closeTo(24, .1));
    expect(circuloNav.left, circuloControl.left);
    await _captura(tester, 'vertical-circulos-acoplados');
    await _pasar(tester, 1120);
    expect(tester.getSize(nav), const Size(76, 304));
    expect(tester.getSize(barra), const Size(76, 548));
    final marco = tester.getRect(_boton('superficie-pregunta'));
    final datos = tester.getRect(_boton('datos-turno-vertical'));
    expect(datos.bottom, lessThan(marco.top));
    expect(marco.right + 24, closeTo(tester.getRect(barra).left, .1));
    final posicionBarra = tester.getRect(barra);
    await _captura(tester, 'vertical-lectura');
    await tester.tap(_boton('control-tiempo'));
    await _pasar(tester, 1200);
    for (var i = 0; i < 4; i++) {
      expect(_boton('responder-$i').hitTestable(), findsOneWidget);
    }
    await _captura(tester, 'vertical-respuestas');
    final correcta = c.sesion.actual!.indiceCorrecto(banco);
    await tester.tap(_boton('responder-${(correcta + 1) % 4}'));
    await _pasar(tester, 4000);
    expect(find.text('Incorrecto'), findsNothing);
    for (var intento = 0; intento < 2; intento++) {
      expect(tester.getRect(barra), posicionBarra);
      expect(
        tester.getRect(_boton('superficie-pregunta')).top,
        closeTo(marco.top, .01),
      );
      expect(
        tester.getRect(_boton('superficie-pregunta')).height,
        closeTo(marco.height, .01),
      );
      await tester.tap(_boton('seleccion-robo'));
      await _pasar(tester, 300);
      final menu = tester.getRect(_boton('menu-estudiantes-robo'));
      expect(
        menu.bottom,
        lessThan(tester.getRect(_boton('seleccion-robo')).top),
      );
      await _captura(tester, 'vertical-menu-$intento');
      await tester.tap(find.text(c.sesion.habilitadosRobo.first.completo).last);
      await _pasar(tester, 700);
      await tester.tap(_boton('iniciar-robo'));
      await _pasar(tester, 1200);
      for (final usada in c.sesion.actual!.opcionesUsadas) {
        expect(
          tester.widget<IconButton>(_boton('responder-$usada')).onPressed,
          isNull,
        );
      }
      await _captura(tester, 'vertical-robo-$intento');
      await tester.tap(_boton('responder-${(correcta + intento + 2) % 4}'));
      await _pasar(tester, 4000);
    }
    expect(c.sesion.fase, FaseEvaluacion.revision);
    expect(_boton('ver-explicacion').hitTestable(), findsOneWidget);
    expect(_boton('siguiente-turno').hitTestable(), findsOneWidget);
    await tester.tap(_boton('ver-explicacion'));
    await _pasar(tester, 1000);
    expect(
      tester.getRect(_boton('superficie-pregunta')).top,
      closeTo(marco.top, .01),
    );
    expect(
      tester.getRect(_boton('superficie-pregunta')).height,
      closeTo(marco.height, .01),
    );
    await _captura(tester, 'vertical-explicacion');
    await tester.tap(_boton('seccion-0'));
    await _pasar(tester, 3000);
    expect(tester.getSize(nav), const Size(76, 304));
    expect(barra, findsNothing);
    await tester.tap(_boton('seccion-1'));
    await _pasar(tester, 3000);
    expect(tester.getRect(barra), posicionBarra);
    expect(
      tester.getRect(_boton('superficie-pregunta')).top,
      closeTo(marco.top, .01),
    );
    expect(
      tester.getRect(_boton('superficie-pregunta')).height,
      closeTo(marco.height, .01),
    );
    // Rotar la tableta recompone la versión horizontal ya existente.
    tester.view.physicalSize = const Size(1280, 800);
    await _pasar(tester, 1200);
    expect(tester.getSize(nav), const Size(244, 76));
    expect(tester.getSize(barra).height, 76);
    expect(_boton('datos-turno-vertical'), findsNothing);
    expect(c.sesion.actual!.robosRealizados, 2);
    await _cerrar(tester, c);
  });

  testWidgets('los nombres se muestran como texto y la asistencia funciona', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final datos = (await tester.runAsync(cargarContenidoTrivia))!;
    final c = ControladorEvaluacion(
      MotorEvaluacion(
        datos.banco,
        SesionTrivia(
          id: 'IV_PRUEBA_NOMBRES',
          fecha: DateTime.utc(2026, 10, 23),
          huellaBanco: datos.banco.huella,
          alumnos: datos.alumnos,
        ),
      ),
      _RepoMemoria(),
      temporizador: false,
      alumnosIniciales: datos.alumnos.map((a) => a.id).toSet(),
    );
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
          home: PantallaEvaluacion(controlador: c),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fila = find.byKey(const ValueKey('fila-S01'));
    expect(
      find.descendant(of: fila, matching: find.byType(TextField)),
      findsNothing,
    );
    expect(find.text('Azol, Mateo'), findsOneWidget);
    final nombre = c.sesion.alumno('S01').completo;
    await tester.tap(find.descendant(of: fila, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(c.sesion.alumno('S01').presente, isFalse);
    expect(c.sesion.alumno('S01').completo, nombre);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump();
    await c.guardadoPendiente;
  });

  testWidgets(
    'la tarjeta se compacta y las dos barras acoplan; navegación completa y rebote',
    (tester) async {
      final c = ControladorEvaluacion(
        muestra(5)..iniciar(),
        _RepoMemoria(),
        temporizador: false,
      );
      await _montar(tester, c, reducido: false);
      final nav = _boton('panel-secciones');
      expect(tester.getSize(nav), const Size(76, 304));
      await _captura(tester, '01-sorteo');
      await tester.tap(_boton('sortear-turno'));
      await tester.pump();
      final control = _boton('barra-control-evaluacion');
      final inicial = tester.getRect(control);
      expect(inicial.size, const Size(460, 330));
      await _pasar(tester, 250);
      final medio = tester.getRect(control);
      expect(medio.width, lessThan(inicial.width));
      expect(medio.center.dx, closeTo(inicial.center.dx, .1));
      await _captura(tester, '02-compactacion');
      await _pasar(tester, 240);
      expect(tester.getSize(control).width, closeTo(76, .1));
      expect(tester.getSize(control).height, closeTo(76, .1));
      await _captura(tester, '03-circulos');
      await _pasar(tester, 1100);
      await _captura(tester, '04-recorrido');
      await _pasar(tester, 1100);
      await _captura(tester, '05-apertura');
      await _pasar(tester, 700);
      expect(tester.getSize(nav), const Size(244, 76));
      expect(tester.getSize(control).height, 76);
      expect(
        tester.getRect(control).right + 12,
        closeTo(tester.getRect(nav).left, .1),
      );
      final pregunta = tester.getRect(_boton('superficie-pregunta'));
      final barra = tester.getRect(control);
      expect(barra.top, greaterThan(pregunta.bottom));
      await _captura(tester, '06-lectura');
      final posicionNav = tester.getRect(nav);
      await tester.tap(_boton('seccion-1'));
      await _pasar(tester, 150);
      expect(tester.getRect(nav).left, isNot(closeTo(posicionNav.left, .1)));
      expect(tester.getRect(_boton('superficie-pregunta')), pregunta);
      expect(tester.getRect(control), barra);
      await _pasar(tester, 500);
      for (final destino in [0, 2, 3]) {
        await tester.tap(_boton('seccion-$destino'));
        if (destino == 0) {
          await _pasar(tester, 650);
          expect(
            tester
                .widget<Opacity>(_boton('transicion-titulo-evaluacion'))
                .opacity,
            0,
          );
          expect(_boton('navegacion-unificada'), findsOneWidget);
          await _captura(tester, 'navegacion-circulo-unificado');
          await _pasar(tester, 450);
          await _captura(tester, 'navegacion-ultimos-200ms');
          await _pasar(tester, 700);
        } else {
          await _pasar(tester, 2800);
        }
        expect(tester.getSize(nav), const Size(76, 304));
        expect(_boton('navegacion-unificada'), findsNothing);
        expect(
          tester.getRect(nav).left -
              tester.getRect(_boton('area-seccion')).right,
          closeTo(72, .1),
        );
        expect(_boton('barra-control-evaluacion'), findsNothing);
        expect(_boton('superficie-pregunta'), findsNothing);
        await _captura(tester, 'pantalla-$destino');
        await tester.tap(_boton('seccion-1'));
        await _pasar(tester, 2800);
        expect(
          tester
              .widget<Opacity>(_boton('transicion-titulo-evaluacion'))
              .opacity,
          1,
        );
        expect(tester.getSize(nav), const Size(244, 76));
        expect(tester.getRect(_boton('superficie-pregunta')), pregunta);
        expect(c.sesion.pausada, isTrue);
      }
      await _cerrar(tester, c);
    },
  );

  testWidgets(
    'botonera responde, dos robos, explicación, siguiente turno y deshacer',
    (tester) async {
      final c = ControladorEvaluacion(
        muestra(5)
          ..iniciar()
          ..siguiente(),
        _RepoMemoria(),
        temporizador: false,
      );
      await _montar(tester, c, reducido: false);
      final r = c.sesion.actual!;
      final correcta = r.indiceCorrecto(banco);
      final marco = tester.getRect(_boton('superficie-pregunta'));
      final ancho = tester.getSize(_boton('barra-control-evaluacion')).width;
      await tester.tap(_boton('trivia-opcion-$correcta'));
      await tester.pumpAndSettle();
      expect(r.propio, isNull);
      expect(_boton('responder-0'), findsNothing);
      expect(_boton('icono-reloj-pausado'), findsNothing);
      await tester.tap(_boton('control-tiempo'));
      await tester.pumpAndSettle();
      final posicionReloj = tester.getRect(_boton('reloj-evaluacion'));
      final superficieReloj = tester.getRect(
        _boton('superficie-reloj-evaluacion'),
      );
      expect(_boton('icono-reloj-pausado'), findsNothing);
      await tester.tap(find.byTooltip('Pausar tiempo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      await _captura(tester, 'pausa-1.1.80-01-salida');
      await tester.pump(const Duration(milliseconds: 180));
      await _captura(tester, 'pausa-1.1.80-02-entrada');
      await tester.pumpAndSettle();
      await _captura(tester, 'pausa-1.1.80-03-pausado');
      final tiempoRestante = c.sesion.restanteMs;
      await tester.pump(const Duration(seconds: 2));
      expect(_boton('icono-reloj-pausado'), findsOneWidget);
      expect(_boton('reloj-evaluacion'), findsNothing);
      expect(
        tester.getRect(_boton('superficie-reloj-evaluacion')),
        superficieReloj,
      );
      expect(c.sesion.restanteMs, tiempoRestante);
      await tester.tap(find.byTooltip('Reanudar tiempo'));
      await tester.pumpAndSettle();
      expect(_boton('icono-reloj-pausado'), findsNothing);
      expect(tester.getRect(_boton('reloj-evaluacion')), posicionReloj);
      await _captura(tester, 'pausa-1.1.80-04-reanudado');
      await _montar(tester, c);
      for (var i = 0; i < 4; i++) {
        expect(_boton('responder-$i').hitTestable(), findsOneWidget);
      }
      expect(
        tester.getSize(_boton('barra-control-evaluacion')).width,
        closeTo(ancho, .01),
      );
      await _captura(tester, '07-respuestas');
      await tester.tap(_boton('responder-${(correcta + 1) % 4}'));
      await tester.pumpAndSettle();
      expect(c.sesion.fase, FaseEvaluacion.esperaRobo);
      expect(
        tester.getSize(_boton('barra-control-evaluacion')).width,
        closeTo(ancho, .01),
      );
      expect(tester.getRect(_boton('superficie-pregunta')), marco);
      final seleccionada = tester.widget<ContornoRespuesta>(
        _boton('tarjeta-opcion-${(correcta + 1) % 4}'),
      );
      expect(seleccionada.color, TemaTriviaAntiguedad.naranja);
      expect(_boton('ver-explicacion').hitTestable(), findsNothing);
      for (var intento = 0; intento < 2; intento++) {
        final estudiante = c.sesion.habilitadosRobo.first;
        final selector = _boton('seleccion-robo');
        final posicion = tester.getRect(selector);
        await tester.tap(selector);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byType(PopupMenuItem<String>).first).top,
          lessThan(posicion.top),
        );
        await _captura(tester, '08-selector-$intento');
        await tester.tap(find.text(estudiante.completo).last);
        await tester.pumpAndSettle();
        expect(tester.getSize(_boton('iniciar-robo')), const Size(52, 52));
        await tester.tap(_boton('iniciar-robo'));
        await tester.pumpAndSettle();
        expect(c.sesion.fase, FaseEvaluacion.robo);
        for (final usada in r.opcionesUsadas) {
          expect(
            tester.widget<IconButton>(_boton('responder-$usada')).onPressed,
            isNull,
          );
        }
        expect(_boton('responder-$correcta').hitTestable(), findsOneWidget);
        await _captura(tester, '09-robo-$intento');
        await tester.tap(_boton('responder-${(correcta + intento + 2) % 4}'));
        await tester.pumpAndSettle();
      }
      expect(c.sesion.fase, FaseEvaluacion.revision);
      expect(r.robosRealizados, 2);
      expect(_boton('iniciar-robo'), findsNothing);
      await _captura(tester, '10-cierre');
      await tester.tap(_boton('deshacer-evaluacion'));
      await tester.pumpAndSettle();
      expect(c.sesion.fase, FaseEvaluacion.robo);
      await tester.tap(_boton('responder-$correcta'));
      await tester.pumpAndSettle();
      expect(c.sesion.actual!.robos.last.correcto, isTrue);
      expect(find.text('Correcto'), findsOneWidget);
      await _captura(tester, '11-correcto');
      await tester.tap(_boton('ver-explicacion'));
      await tester.pumpAndSettle();
      expect(find.text('Explicación del banco').hitTestable(), findsOneWidget);
      expect(tester.getRect(_boton('superficie-pregunta')), marco);
      await _captura(tester, '12-explicacion');
      await tester.tap(_boton('ver-explicacion'));
      await tester.pumpAndSettle();
      await tester.tap(_boton('siguiente-turno'));
      await tester.pumpAndSettle();
      expect(c.sesion.actualId, isNot(r.preguntaId));
      expect(c.sesion.tiempoSinIniciar, isTrue);
      expect(_boton('responder-0'), findsNothing);
      await tester.tap(_boton('control-tiempo'));
      await tester.pumpAndSettle();
      expect(_boton('responder-0').hitTestable(), findsOneWidget);
      await _captura(tester, '13-segundo-turno');
      await _cerrar(tester, c);
    },
  );

  testWidgets(
    'resultado y robo se suceden en el mismo marco sin cambiar ancho',
    (tester) async {
      final c = ControladorEvaluacion(
        muestra(5)
          ..iniciar()
          ..siguiente(),
        _RepoMemoria(),
        temporizador: false,
      );
      await _montar(tester, c, reducido: false);
      final ancho = tester.getSize(_boton('barra-control-evaluacion')).width;
      await tester.tap(_boton('control-tiempo'));
      await _pasar(tester, 1200);
      expect(
        tester.getSize(_boton('barra-control-evaluacion')).width,
        closeTo(ancho, .01),
      );
      final r = c.sesion.actual!;
      await tester.tap(
        _boton('responder-${(r.indiceCorrecto(banco) + 1) % 4}'),
      );
      await _pasar(tester, 450);
      await _captura(tester, 'respuesta-marcada');
      expect(
        tester.getSize(_boton('barra-control-evaluacion')).width,
        closeTo(ancho, .01),
      );
      await _pasar(tester, 1450);
      expect(_boton('ver-explicacion'), findsNothing);
      expect(c.sesion.fase, FaseEvaluacion.esperaRobo);
      final resultado = tester.getRect(_boton('resultado-respuesta'));
      await tester.tapAt(Offset(resultado.right + 30, resultado.center.dy));
      await _pasar(tester, 100);
      expect(c.sesion.fase, FaseEvaluacion.esperaRobo);
      expect(find.text('Explicación del banco'), findsNothing);
      expect(_boton('seleccion-robo').hitTestable(), findsNothing);
      await _captura(tester, 'resultado-antes-robo');
      await _pasar(tester, 2000);
      expect(_boton('ver-explicacion'), findsNothing);
      expect(_boton('seleccion-robo').hitTestable(), findsOneWidget);
      expect(
        tester.getSize(_boton('barra-control-evaluacion')).width,
        closeTo(ancho, .01),
      );
      await _captura(tester, 'robo-solo-tres-botones');
      await tester.tap(_boton('iniciar-robo'));
      await _pasar(tester, 500);
      expect(find.byType(PopupMenuItem<String>), findsWidgets);
      expect(c.sesion.fase, FaseEvaluacion.esperaRobo);
      for (var robo = 0; robo < 2; robo++) {
        if (robo > 0) {
          await tester.tap(_boton('seleccion-robo'));
          await _pasar(tester, 400);
        }
        final estudiante = c.sesion.habilitadosRobo.first;
        await tester.tap(find.text(estudiante.completo).last);
        await _pasar(tester, 500);
        await tester.tap(_boton('iniciar-robo'));
        await _pasar(tester, 1200);
        final anteriores = r.opcionesUsadas.toList();
        final elegida = List.generate(4, (i) => i).firstWhere(
          (i) => i != r.indiceCorrecto(banco) && !anteriores.contains(i),
        );
        await tester.tap(_boton('responder-$elegida'));
        await _pasar(tester, 450);
        expect(_boton('reloj-evaluacion'), findsNothing);
        expect(_boton('ver-explicacion'), findsNothing);
        for (final usada in anteriores) {
          final marca = tester.widget<Icon>(_boton('marca-opcion-$usada'));
          expect(marca.icon, Icons.cancel);
          expect(marca.color, TemaTriviaAntiguedad.deshabilitado);
          expect(
            tester.widget<IconButton>(_boton('responder-$usada')).onPressed,
            isNull,
          );
        }
        expect(
          tester.widget<Icon>(_boton('marca-opcion-$elegida')).color,
          TemaTriviaAntiguedad.naranja,
        );
        await _captura(tester, 'robo-marcas-persistentes-$robo');
        await _pasar(tester, 3500);
        expect(
          _boton('ver-explicacion').hitTestable(),
          robo == 0 ? findsNothing : findsOneWidget,
        );
      }
      await _cerrar(tester, c);
    },
  );

  for (final ultimoRobo in [false, true]) {
    testWidgets(
      'explicación espera el cierre y la transición: ${ultimoRobo ? 'último candidato' : 'correcta inicial'}',
      (tester) async {
        final m = muestra(2)
          ..iniciar()
          ..siguiente();
        if (ultimoRobo) {
          m.reanudar();
          m.sinRespuesta();
          m.iniciarRobo(m.sesion.habilitadosRobo.single.id);
        }
        final c = ControladorEvaluacion(m, _RepoMemoria(), temporizador: false);
        await _montar(tester, c, reducido: false);
        if (!ultimoRobo) {
          await tester.tap(_boton('control-tiempo'));
          await _pasar(tester, 1200);
        }
        final correcta = c.sesion.actual!.indiceCorrecto(banco);
        await tester.tap(
          _boton('responder-${ultimoRobo ? (correcta + 1) % 4 : correcta}'),
        );
        await _pasar(tester, 1400);
        expect(c.sesion.fase, FaseEvaluacion.revision);
        expect(_boton('ver-explicacion'), findsNothing);
        expect(_boton('seleccion-robo'), findsNothing);
        await _captura(tester, 'explicacion-bloqueada-$ultimoRobo');
        await _pasar(tester, 600);
        expect(_boton('ver-explicacion'), findsOneWidget);
        expect(_boton('ver-explicacion').hitTestable(), findsNothing);
        final ojo = tester.getRect(_boton('ver-explicacion'));
        await tester.tapAt(ojo.center);
        await _pasar(tester, 100);
        expect(find.text('Explicación del banco'), findsNothing);
        await _pasar(tester, 600);
        expect(_boton('ver-explicacion').hitTestable(), findsOneWidget);
        expect(_boton('siguiente-turno').hitTestable(), findsOneWidget);
        expect(_boton('iniciar-robo'), findsNothing);
        await _captura(tester, 'explicacion-habilitada-$ultimoRobo');
        await tester.tap(_boton('ver-explicacion'));
        await _pasar(tester, 1200);
        expect(
          find.text('Explicación del banco').hitTestable(),
          findsOneWidget,
        );
        await _cerrar(tester, c);
      },
    );
  }

  for (final cantidad in [2, 20]) {
    testWidgets(
      'selector de robo anclado con ${cantidad - 1} estudiantes y al redimensionar',
      (tester) async {
        final m = muestra(cantidad)
          ..iniciar()
          ..siguiente()
          ..reanudar()
          ..sinRespuesta();
        final c = ControladorEvaluacion(m, _RepoMemoria(), temporizador: false);
        await _montar(tester, c);
        await tester.tap(_boton('seleccion-robo'));
        await tester.pumpAndSettle();
        void comprobar() {
          final ancla = tester.getRect(_boton('seleccion-robo'));
          final menu = tester.getRect(_boton('menu-estudiantes-robo'));
          expect(menu.bottom, closeTo(ancla.top - 16, .1));
          expect(menu.left, closeTo(ancla.left - 36, .1));
          expect(menu.height, lessThanOrEqualTo(312));
          if (cantidad == 2) expect(menu.height, lessThan(200));
        }

        comprobar();
        await _captura(tester, 'selector-anclado-${cantidad - 1}');
        tester.view.physicalSize = const Size(1024, 600);
        await tester.pumpAndSettle();
        comprobar();
        await _captura(tester, 'selector-redimensionado-${cantidad - 1}');
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(_boton('menu-estudiantes-robo'), findsNothing);
        expect(c.sesion.fase, FaseEvaluacion.esperaRobo);
        await _cerrar(tester, c);
      },
    );
  }

  testWidgets(
    'solo el cambio de estudiante amplía la barra y desplaza la navegación con continuidad',
    (tester) async {
      final m = muestra(4)
        ..iniciar()
        ..siguiente();
      final titular = m.sesion.alumno(m.sesion.actual!.titularId);
      titular.apellido = 'Falcón';
      titular.nombre = 'María Eugenia';
      final ladron = m.sesion.habilitadosRobo.first;
      ladron.apellido = 'Olivera';
      ladron.nombre = 'Esteban Juan Daniel';
      final c = ControladorEvaluacion(m, _RepoMemoria(), temporizador: false);
      await _montar(tester, c, reducido: false);
      final barra = _boton('barra-control-evaluacion'),
          nav = _boton('panel-secciones');
      final inicial = tester.getRect(barra);
      final navInicial = tester.getRect(nav);
      await _captura(tester, 'proporciones-nombre-corto');
      await tester.tap(_boton('no-contesta'));
      await _pasar(tester, 3900);
      expect(tester.getRect(barra), inicial);
      await tester.tap(_boton('seleccion-robo'));
      await _pasar(tester, 400);
      await tester.tap(find.text(ladron.completo).last);
      await tester.pump();
      await _pasar(tester, 350);
      final medio = tester.getRect(barra);
      expect(medio.left, closeTo(inicial.left, .01));
      expect(medio.width, greaterThan(inicial.width));
      expect(medio.width, lessThan(inicial.width + 60));
      await _pasar(tester, 1000);
      expect(tester.getRect(barra).width, closeTo(inicial.width + 60, .1));
      expect(tester.getRect(nav).left, closeTo(navInicial.left + 60, .1));
      expect(find.text(ladron.completo), findsOneWidget);
      await _captura(tester, 'alumno-seleccionado-antes-robo');
      await tester.tap(_boton('iniciar-robo'));
      await _pasar(tester, 1200);
      expect(tester.getRect(barra).width, closeTo(inicial.width + 60, .1));
      final seleccion = _boton('seleccion-secciones');
      final desde = tester.getTopLeft(seleccion) - tester.getTopLeft(nav);
      await tester.tap(_boton('seccion-0'));
      await _pasar(tester, 150);
      final durante = tester.getTopLeft(seleccion) - tester.getTopLeft(nav);
      expect(durante.dx, lessThan(desde.dx));
      expect(durante.dx, greaterThan(10.7));
      await _captura(tester, 'seleccion-navegacion-en-recorrido');
      await _pasar(tester, 2700);
      expect(tester.getSize(nav), const Size(76, 304));
      await _cerrar(tester, c);
    },
  );

  testWidgets(
    'no contesta no marca alternativas y solo permite explicar tras cerrar los robos',
    (tester) async {
      final c = ControladorEvaluacion(
        muestra(3)
          ..iniciar()
          ..siguiente(),
        _RepoMemoria(),
        temporizador: false,
      );
      await _montar(tester, c);
      await tester.tap(_boton('no-contesta'));
      await tester.pumpAndSettle();
      expect(c.sesion.actual!.propio!.estado, EstadoIntento.sinRespuesta);
      expect(c.sesion.actual!.opcionesUsadas, isEmpty);
      expect(c.sesion.restanteMs, 60000);
      expect(_boton('ver-explicacion'), findsNothing);
      await tester.tap(_boton('cerrar-pregunta'));
      await tester.pumpAndSettle();
      expect(_boton('iniciar-robo'), findsNothing);
      await tester.tap(_boton('ver-explicacion'));
      await tester.pumpAndSettle();
      expect(c.sesion.fase, FaseEvaluacion.revision);
      expect(_boton('seleccion-robo'), findsNothing);
      expect(find.text('Explicación del banco').hitTestable(), findsOneWidget);
      await _cerrar(tester, c);
    },
  );

  for (final caso in [
    (const Size(1280, 800), 1.0),
    (const Size(1280, 800), 2.0),
    (const Size(1024, 600), 2.0),
  ]) {
    testWidgets(
      'texto completo, controles en una línea y scroll en ${caso.$1} escala ${caso.$2}',
      (tester) async {
        final m = muestra(20)
          ..iniciar()
          ..siguiente();
        final extensa = banco.preguntas.reduce(
          (a, b) =>
              (a.texto + a.opciones.join()).length >
                  (b.texto + b.opciones.join()).length
              ? a
              : b,
        );
        m.sesion.actual!.estado = EstadoPregunta.pendiente;
        m.sesion.actualId = extensa.id;
        m.sesion.actual!.estado = EstadoPregunta.activa;
        final c = ControladorEvaluacion(m, _RepoMemoria(), temporizador: false);
        await _montar(tester, c, size: caso.$1, escala: caso.$2);
        for (var i = 0; i < 4; i++) {
          await tester.ensureVisible(_boton('trivia-opcion-$i'));
          await tester.pumpAndSettle();
          // Una opción con letra ampliada puede superar todo el viewport.
          // Comprobar el contenido visible y que se pueda llegar a su final,
          // en lugar de exigir que su centro esté dentro del recorte.
          final ventana = tester.getRect(_boton('scroll-opciones-evaluacion'));
          expect(
            tester.getRect(_boton('trivia-opcion-$i')).overlaps(ventana),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        }
        final scroll = tester.state<ScrollableState>(
          find.descendant(
            of: _boton('scroll-opciones-evaluacion'),
            matching: find.byType(Scrollable),
          ),
        );
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(_boton('trivia-opcion-3')).bottom,
          lessThanOrEqualTo(
            tester.getRect(_boton('scroll-opciones-evaluacion')).bottom,
          ),
        );
        await tester.ensureVisible(_boton('control-tiempo'));
        await tester.pumpAndSettle();
        await tester.tap(_boton('control-tiempo'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(_boton('responder-3'));
        await tester.pumpAndSettle();
        expect(_boton('responder-3').hitTestable(), findsOneWidget);
        expect(tester.getSize(_boton('barra-control-evaluacion')).height, 76);
        await _captura(tester, 'escala-${caso.$1.width.toInt()}-${caso.$2}');
        await _cerrar(tester, c);
      },
    );
  }
  testWidgets(
    'estudiantes JSON: cancelar, cargar y conservar nombres al cambiar de pantalla',
    (tester) async {
      final anterior = FilePickerPlatform.instance;
      final selector = _SelectorBanco();
      FilePickerPlatform.instance = selector;
      addTearDown(() => FilePickerPlatform.instance = anterior);
      final c = ControladorEvaluacion(
        muestra(2),
        _RepoMemoria(),
        temporizador: false,
      );
      await _montar(tester, c);
      final id = c.sesion.id;
      await tester.tap(_boton('cargar-estudiantes-json'));
      await _pasar(tester, 400);
      expect(c.sesion.id, id);
      selector.raw = ejemploEstudiantes(3);
      await tester.tap(_boton('cargar-estudiantes-json'));
      await _pasar(tester, 400);
      await tester.tap(find.widgetWithText(TextButton, 'Volver'));
      await _pasar(tester, 400);
      expect(c.sesion.id, id);
      await tester.tap(_boton('cargar-estudiantes-json'));
      await _pasar(tester, 400);
      await tester.tap(find.widgetWithText(FilledButton, 'Cargar'));
      await _pasar(tester, 600);
      expect(c.sesion.alumnos.length, 3);
      expect(find.text('Apellido 0, Nombre 0'), findsOneWidget);
      expect(
        find.textContaining('3 estudiantes · 2 presentes'),
        findsOneWidget,
      );
      await tester.tap(_boton('seccion-2'));
      await _pasar(tester, 1000);
      await tester.tap(_boton('seccion-0'));
      await _pasar(tester, 1000);
      expect(find.text('Apellido 0, Nombre 0'), findsOneWidget);
      await _cerrar(tester, c);
    },
  );

  testWidgets(
    'añade estudiantes desde el botón más y cancelar conserva la lista',
    (tester) async {
      final c = ControladorEvaluacion(
        muestra(2),
        _RepoMemoria(),
        temporizador: false,
      );
      await _montar(tester, c);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(_boton('abrir-nuevo-estudiante'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo estudiante'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_boton('guardar-estudiante')).onPressed,
        isNull,
      );
      expect(_boton('eliminar-estudiante'), findsNothing);
      await tester.enterText(_boton('editar-estudiante-apellido'), 'Quintero');
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(_boton('guardar-estudiante')).onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(c.sesion.alumnos.length, 2);
      await tester.tap(_boton('abrir-nuevo-estudiante'));
      await tester.pumpAndSettle();
      await tester.enterText(_boton('editar-estudiante-apellido'), 'Quintero');
      await tester.enterText(_boton('editar-estudiante-nombre'), 'Elena');
      await tester.pumpAndSettle();
      await tester.tap(_boton('guardar-estudiante'));
      await tester.pumpAndSettle();
      expect(c.sesion.alumnos.length, 3);
      final nuevo = c.sesion.alumnos.singleWhere(
        (a) => a.apellido == 'Quintero',
      );
      expect(nuevo.nombre, 'Elena');
      expect(nuevo.presente, isTrue);
      expect(_boton('dialogo-estudiante'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.pump();
      await c.guardadoPendiente;
    },
  );

  testWidgets(
    'pulsación prolongada edita y elimina estudiantes sin cambiar asistencia',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final c = ControladorEvaluacion(
        muestra(2),
        _RepoMemoria(),
        temporizador: false,
      );
      await _montar(tester, c);
      final primero = c.sesion.alumnos.first;
      await tester.longPress(_boton('fila-${primero.id}'));
      await tester.pumpAndSettle();
      expect(_boton('dialogo-estudiante'), findsOneWidget);
      await tester.enterText(
        _boton('editar-estudiante-nombre'),
        'María Eugenia',
      );
      await tester.pumpAndSettle();
      await tester.tap(_boton('guardar-estudiante'));
      await tester.pumpAndSettle();
      expect(c.sesion.alumnos.first.nombre, 'María Eugenia');
      expect(c.sesion.alumnos.first.presente, primero.presente);
      await tester.longPress(_boton('fila-${primero.id}'));
      await tester.pumpAndSettle();
      await tester.tap(_boton('eliminar-estudiante'));
      await tester.pumpAndSettle();
      expect(c.sesion.alumnos.length, 1);
      expect(c.sesion.alumnos.any((a) => a.id == primero.id), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.pump();
      await c.guardadoPendiente;
    },
  );
}
