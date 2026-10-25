import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/acta_pdf.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/modelos.dart';

import 'motor_test.dart' show muestra, banco;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('actas A4 con portada, 13 estudiantes e informe individual; estrés de 200 preguntas y 19 robos', () async {
    final carpeta = Directory('qa/evaluacion/pdf')..createSync(recursive: true);
    final recursos = await RecursosActa.cargar();
    final generador = GeneradorActa(recursos);
    final m = muestra(13, semilla: 37);
    m.asistencia('S12', false);
    m.iniciar();
    while (!m.sesion.finalizada) {
      if (m.sesion.avisoPuntajeId != null)
        m.resolverAvisoPuntaje(finalizar: false);
      m.siguiente();
      m.reanudar();
      if (m.sesion.finalizada) break;
      final r = m.sesion.actual!;
      m.transcurrir(12500);
      if (m.sesion.resultado(r.titularId).presentadas % 3 == 0) {
        m.sinRespuesta();
        final candidatos = m.sesion.habilitadosRobo
          ..sort(
            (a, b) => m.sesion
                .resultado(a.id)
                .robos
                .compareTo(m.sesion.resultado(b.id).robos),
          );
        if (candidatos.isEmpty) {
          m.cerrarPregunta();
          continue;
        }
        final ladron = candidatos.first.id;
        m.iniciarRobo(ladron);
        m.reanudar();
        m.transcurrir(5300);
        final cantidad = m.sesion.registros.values
            .where((r) => r.propio != null)
            .length;
        m.responder(
          cantidad.isEven
              ? r.indiceCorrecto(banco)
              : (r.indiceCorrecto(banco) + 1) % 4,
        );
        if (m.sesion.fase == FaseEvaluacion.esperaRobo) m.cerrarPregunta();
      } else {
        m.responder(r.indiceCorrecto(banco));
      }
    }
    final j = m.sesion.toJson();
    j['id'] = 'IV_SIMULACION_13';
    final s = SesionTrivia.fromJson(j, banco);
    final general = await generador.crear(s, banco);
    expect(general.length, greaterThan(30000));
    await File('${carpeta.path}/muestra-acta-general.pdf')
        .writeAsBytes(general);
    await File('${carpeta.path}/muestra-informe-individual.pdf')
        .writeAsBytes(await generador.crear(s, banco, alumnoId: 'S0'));
    final stress = muestra(20, semilla: 81);
    for (final a in stress.sesion.alumnos) {
      a.apellido =
          'SIMULACIÓN ${a.id} Apellido compuesto extraordinariamente extenso para verificar todos los saltos y márgenes de la planilla';
      a.nombre = 'Nombre compuesto de estudiante de prueba con caracteres á é í ó ú ü ñ y una extensión deliberadamente grande para el acta';
    }
    for (final a in stress.sesion.alumnos) {
      a.apellido = a.apellido.padRight(120).substring(0, 120);
      a.nombre = a.nombre.padRight(120).substring(0, 120);
    }
    stress.iniciar();
    stress.siguiente();
    stress.reanudar();
    final r = stress.sesion.actual!;
    stress.sinRespuesta();
    // Caso histórico v1: el exportador conserva los 19 registros anteriores
    // al límite actual, sin simular nuevos intentos prohibidos por el motor.
    for (final a in stress.sesion.alumnos.where((a) => a.id != r.titularId)) {
      r.robos.add(
        IntentoTrivia(
          alumnoId: a.id,
          opcion: (r.indiceCorrecto(banco) + 1) % 4,
          estado: EstadoIntento.respondido,
          correcto: false,
          tiempoMs: 59200,
          fecha: DateTime.utc(2026, 10, 23),
        ),
      );
    }
    stress.cerrarPregunta();
    stress.finalizar();
    final jj = stress.sesion.toJson();
    jj['id'] = 'IV_SIMULACION_ESTRES';
    final ss = SesionTrivia.fromJson(jj, banco);
    await File('${carpeta.path}/prueba-estres-200.pdf')
        .writeAsBytes(await generador.crear(ss, banco));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
