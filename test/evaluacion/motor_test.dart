import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/modelos.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/repositorio.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/controlador.dart';

final banco = BancoTrivia.desdeTexto(
  File('assets/contenido/trivia-unidad-iv.json').readAsStringSync(),
);
MotorEvaluacion muestra(int n, {int semilla = 1}) => MotorEvaluacion(
  banco,
  SesionTrivia(
    id: 'IV_PRUEBA_$semilla',
    fecha: DateTime.utc(2026, 10, 21, 15),
    huellaBanco: banco.huella,
    alumnos: List.generate(
      n,
      (i) => AlumnoTrivia(
        id: 'S$i',
        apellido: 'SIMULACIÓN $i',
        nombre: 'Estudiante de prueba',
      ),
    ),
  ),
  random: Random(semilla),
);
void main() {
  test('dos robos fallidos cierran y deshacer permite corregir el segundo', () {
    final m = muestra(5)
      ..iniciar()
      ..siguiente()
      ..reanudar();
    final r = m.sesion.actual!;
    final correcta = r.indiceCorrecto(banco);
    m.responder((correcta + 1) % 4);
    m.iniciarRobo(m.sesion.habilitadosRobo.first.id);
    expect(() => m.responder((correcta + 1) % 4), throwsStateError);
    expect(r.robos, isEmpty);
    m.responder((correcta + 2) % 4);
    m.iniciarRobo(m.sesion.habilitadosRobo.first.id);
    m.responder((correcta + 3) % 4);
    expect(r.robosRealizados, 2);
    expect(r.estado, EstadoPregunta.cerrada);
    expect(m.sesion.fase, FaseEvaluacion.revision);
    expect(m.sesion.habilitadosRobo, isEmpty);
    m.iniciarRobo('S4');
    expect(r.robos.length, 2);
    m.sesion.validar(banco);
    m.deshacer();
    expect(m.sesion.fase, FaseEvaluacion.robo);
    expect(m.sesion.actual!.robosRealizados, 1);
    m.responder(correcta);
    expect(m.sesion.actual!.robos.last.correcto, isTrue);
    expect(m.sesion.actual!.robosRealizados, 2);
  });

  test(
    'sin candidatos cierra después del intento inicial o del único robo',
    () {
      for (final cantidad in [1, 2]) {
        final m = muestra(cantidad)
          ..iniciar()
          ..siguiente()
          ..reanudar();
        final r = m.sesion.actual!;
        m.responder((r.indiceCorrecto(banco) + 1) % 4);
        if (cantidad == 2) {
          expect(m.sesion.fase, FaseEvaluacion.esperaRobo);
          m.iniciarRobo(m.sesion.habilitadosRobo.single.id);
          m.responder((r.indiceCorrecto(banco) + 2) % 4);
        }
        expect(m.sesion.fase, FaseEvaluacion.revision);
        expect(r.estado, EstadoPregunta.cerrada);
        expect(m.sesion.habilitadosRobo, isEmpty);
        m.sesion.validar(banco);
        // Recupera un v1 anterior que había quedado esperando sin candidatos.
        r.estado = EstadoPregunta.robo;
        m.sesion.fase = FaseEvaluacion.esperaRobo;
        final recuperada = SesionTrivia.fromJson(
          m.sesion.toJson(),
          banco,
          recuperar: true,
        );
        expect(recuperada.fase, FaseEvaluacion.revision);
        expect(recuperada.actual!.estado, EstadoPregunta.cerrada);
        expect(recuperada.actual!.robos.length, cantidad - 1);
        recuperada.validar(banco);
        m.deshacer();
        expect(
          m.sesion.fase,
          cantidad == 1 ? FaseEvaluacion.titular : FaseEvaluacion.robo,
        );
        m.sesion.validar(banco);
      }
    },
  );

  test(
    'quitar al último candidato durante espera de robo cierra la pregunta',
    () {
      final m = muestra(2)
        ..iniciar()
        ..siguiente()
        ..reanudar()
        ..sinRespuesta();
      m.asistencia(m.sesion.habilitadosRobo.single.id, false);
      expect(m.sesion.fase, FaseEvaluacion.revision);
      expect(m.sesion.actual!.estado, EstadoPregunta.cerrada);
      expect(m.sesion.actual!.robos, isEmpty);
      m.sesion.validar(banco);
    },
  );

  test('un v1 histórico con tres robos se conserva al recuperar', () {
    final m = muestra(5)
      ..iniciar()
      ..siguiente()
      ..reanudar()
      ..sinRespuesta();
    final r = m.sesion.actual!;
    final alumnos = m.sesion.habilitadosRobo.take(3).toList();
    for (final a in alumnos) {
      r.robos.add(
        IntentoTrivia(
          alumnoId: a.id,
          opcion: null,
          estado: EstadoIntento.sinRespuesta,
          correcto: false,
          tiempoMs: 0,
          fecha: DateTime.utc(2026, 10, 23),
        ),
      );
    }
    final s = SesionTrivia.fromJson(
      jsonDecode(jsonEncode(m.sesion.toJson())) as Map<String, dynamic>,
      banco,
      recuperar: true,
    );
    expect(s.actual!.robos.length, 3);
    expect(s.fase, FaseEvaluacion.revision);
    expect(s.habilitadosRobo, isEmpty);
    s.validar(banco);
  });

  test('la lectura no consume tiempo y el robo responde sin otro reloj', () {
    final m = muestra(2)
      ..iniciar()
      ..siguiente();
    final r = m.sesion.actual!;
    expect(m.sesion.tiempoSinIniciar, isTrue);
    m.transcurrir(90000);
    m.responder(r.indiceCorrecto(banco));
    expect(m.sesion.restanteMs, 60000);
    expect(r.propio, isNull);
    m.reanudar();
    m.transcurrir(5000);
    m.sinRespuesta();
    expect(r.propio!.tiempoMs, 5000);
    m.iniciarRobo(m.sesion.habilitadosRobo.first.id);
    expect(m.sesion.tiempoSinIniciar, isFalse);
    expect(m.sesion.aceptaRespuesta, isTrue);
    expect(m.sesion.restanteMs, 55000);
    m.transcurrir(90000);
    expect(m.sesion.restanteMs, 55000);
    expect(r.robos, isEmpty);
    m.responder(r.indiceCorrecto(banco));
    expect(r.robos.single.correcto, isTrue);
    expect(r.robos.single.tiempoMs, 0);
    m.sesion.validar(banco);
  });
  test(
    'robo tras agotar el plazo inicial permite responder, deshacer y recuperar',
    () {
      final m = muestra(3)
        ..iniciar()
        ..siguiente()
        ..reanudar()
        ..transcurrir(60000);
      final id = m.sesion.habilitadosRobo.first.id;
      m.iniciarRobo(id);
      expect(m.sesion.restanteMs, 0);
      expect(m.sesion.cronometrada, isFalse);
      m.transcurrir(999999);
      m.responder(m.sesion.actual!.indiceCorrecto(banco));
      expect(m.sesion.resultado(id).puntos, 2);
      m.deshacer();
      expect(m.sesion.aceptaRespuesta, isTrue);
      final respaldo =
          jsonDecode(jsonEncode(m.sesion.toJson())) as Map<String, dynamic>;
      respaldo['pausada'] = true;
      respaldo['restanteMs'] = 60000;
      final recuperada = SesionTrivia.fromJson(
        respaldo,
        banco,
        recuperar: true,
      );
      expect(recuperada.aceptaRespuesta, isTrue);
      expect(recuperada.pausada, isFalse);
      expect(recuperada.cronometrada, isFalse);
      final restaurado = MotorEvaluacion(banco, recuperada);
      restaurado.responder(recuperada.actual!.indiceCorrecto(banco));
      expect(restaurado.sesion.resultado(id).puntos, 2);
    },
  );
  test('ausencia y cierre de un robo sin reloj dejan un registro válido', () {
    final m = muestra(3)
      ..iniciar()
      ..siguiente()
      ..reanudar()
      ..sinRespuesta();
    final alumno = m.sesion.habilitadosRobo.first.id;
    m.iniciarRobo(alumno);
    m.asistencia(alumno, false);
    expect(m.sesion.fase, FaseEvaluacion.esperaRobo);
    expect(m.sesion.actual!.robos.single.estado, EstadoIntento.cancelado);
    m.sesion.validar(banco);
    m.asistencia(alumno, true);
    m.iniciarRobo(alumno);
    m.cerrarPregunta();
    expect(m.sesion.fase, FaseEvaluacion.revision);
    expect(m.sesion.actual!.robos.last.estado, EstadoIntento.sinRespuesta);
    m.sesion.validar(banco);
  });
  test('400 repartos exclusivos conservan los 200 IDs, las cuotas y las alternativas', () {
    final posiciones = <int>{};
    for (final n in [1, 7, 13, 20]) {
      for (var seed = 0; seed < 100; seed++) {
        final m = muestra(n, semilla: seed)..iniciar();
        final s = m.sesion;
        s.validar(banco);
        final packs = [...s.paquetes.values, ...s.reservas];
        expect(packs.length, 20);
        expect(packs.expand((p) => p).toSet().length, 200);
        for (final pack in packs) {
          final temas = pack.map((id) => banco.porId[id]!.tema).toList();
          expect(pack.length, 10);
          expect(temas.where((t) => t == 'Roma').length, 2);
          for (final t in [
            'Grecia',
            'China',
            'India',
            'Mesopotamia',
            'Egipto',
          ]) {
            expect(temas.contains(t), isTrue);
          }
          expect(temas.toSet().length, inInclusiveRange(7, 8));
        }
        posiciones.addAll(
          s.registros.values.map((r) => r.indiceCorrecto(banco)),
        );
      }
    }
    expect(posiciones, {0, 1, 2, 3});
  });
  test(
    'los turnos se equilibran y finalizan tras diez preguntas por presente',
    () {
      for (final n in [1, 2, 7, 13, 20]) {
        final m = muestra(n)..iniciar();
        final cuenta = {for (final a in m.sesion.alumnos) a.id: 0};
        for (var i = 0; i < n * 10; i++) {
          m.siguiente();
          m.reanudar();
          final r = m.sesion.actual!;
          cuenta[r.titularId] = cuenta[r.titularId]! + 1;
          expect(
            cuenta.values.reduce(max) - cuenta.values.reduce(min),
            lessThanOrEqualTo(1),
          );
          m.responder(r.indiceCorrecto(banco));
          m.sesion.validar(banco);
          if (m.sesion.avisoPuntajeId != null)
            m.resolverAvisoPuntaje(finalizar: false);
        }
        m.siguiente();
        m.reanudar();
        expect(m.sesion.finalizada, isTrue);
        expect(m.sesion.cierreAnticipado, isFalse);
        for (final a in m.sesion.alumnos) {
          expect(m.sesion.resultado(a.id).puntos, 10);
        }
      }
    },
  );
  test('propias, robos, intentos únicos y tope de nota', () {
    final m = muestra(3)
      ..iniciar()
      ..siguiente()
      ..reanudar();
    var s = m.sesion;
    final r = s.actual!;
    final correcta = r.indiceCorrecto(banco);
    m.responder((correcta + 1) % 4);
    expect(s.fase, FaseEvaluacion.esperaRobo);
    expect(s.resultado(r.titularId).puntos, 0);
    final otro = s.habilitadosRobo.first.id;
    m.iniciarRobo(otro);
    m.reanudar();
    expect(() => m.responder((correcta + 1) % 4), throwsStateError);
    m.responder((correcta + 2) % 4);
    expect(s.habilitadosRobo.any((a) => a.id == otro), isFalse);
    expect(() => m.iniciarRobo(otro), throwsStateError);
    final ganador = s.habilitadosRobo.first.id;
    m.iniciarRobo(ganador);
    m.reanudar();
    m.responder(correcta);
    m.responder(correcta);
    expect(s.resultado(ganador).puntos, 2);
    expect(r.robos.length, 2);
    s.validar(banco);
    while (!m.sesion.finalizada) {
      if (m.sesion.avisoPuntajeId != null)
        m.resolverAvisoPuntaje(finalizar: false);
      m.siguiente();
      m.reanudar();
      if (m.sesion.finalizada) break;
      final r = m.sesion.actual!;
      if (r.titularId == ganador) {
        m.responder(r.indiceCorrecto(banco));
      } else {
        m.sinRespuesta();
        if (m.sesion.habilitadosRobo.any((a) => a.id == ganador)) {
          m.iniciarRobo(ganador);
          m.responder(r.indiceCorrecto(banco));
        } else {
          m.cerrarPregunta();
        }
      }
    }
    final res = m.sesion.resultado(ganador);
    expect(res.puntos, 10);
    expect(res.nota, 10);
    expect(res.aprobado, isTrue);
  });
  test(
    'el tiempo inicial respeta la pausa y no se aplica de nuevo al robo',
    () {
      final m = muestra(2)
        ..iniciar()
        ..siguiente()
        ..reanudar();
      final r = m.sesion.actual!;
      m.transcurrir(10000);
      m.pausar();
      m.transcurrir(30000);
      expect(m.sesion.restanteMs, 50000);
      m.reanudar();
      m.transcurrir(5000);
      m.sinRespuesta();
      expect(r.propio!.tiempoMs, 15000);
      m.iniciarRobo(m.sesion.habilitadosRobo.first.id);
      m.reanudar();
      m.transcurrir(60001);
      m.responder(r.indiceCorrecto(banco));
      expect(r.robos.single.estado, EstadoIntento.respondido);
      expect(r.robos.single.correcto, isTrue);
      expect(r.robos.single.tiempoMs, 0);
      m.sesion.validar(banco);
    },
  );
  test('asistencia ajena conserva pausa; ausencia del actor suspende y es reversible', () {
    final m = muestra(3)
      ..iniciar()
      ..siguiente()
      ..reanudar();
    final r = m.sesion.actual!;
    final otro = m.sesion.alumnos.firstWhere((a) => a.id != r.titularId).id;
    m.pausar();
    m.asistencia(otro, false);
    expect(m.sesion.pausada, isTrue);
    m.asistencia(otro, true);
    m.asistencia(r.titularId, false);
    expect(m.sesion.fase, FaseEvaluacion.entreTurnos);
    expect(r.estado, EstadoPregunta.pendiente);
    m.sesion.validar(banco);
    m.asistencia(r.titularId, true);
    expect(m.sesion.paquetes[r.titularId], contains(r.preguntaId));
    m.siguiente();
    m.reanudar();
    m.sinRespuesta();
    final ladron = m.sesion.habilitadosRobo.first.id;
    m.iniciarRobo(ladron);
    m.reanudar();
    m.transcurrir(2000);
    m.asistencia(ladron, false);
    expect(m.sesion.fase, FaseEvaluacion.esperaRobo);
    expect(m.sesion.actual!.robos.single.estado, EstadoIntento.cancelado);
    m.asistencia(ladron, true);
    expect(m.sesion.habilitadosRobo.any((a) => a.id == ladron), isTrue);
    m.sesion.validar(banco);
  });
  test(
    'respaldo conserva el orden y todos los intentos y se recupera pausado',
    () {
      final m = muestra(13)
        ..iniciar()
        ..siguiente()
        ..reanudar()
        ..transcurrir(1234);
      final j =
          jsonDecode(jsonEncode(m.sesion.toJson())) as Map<String, dynamic>;
      final s = SesionTrivia.fromJson(j, banco, recuperar: true);
      expect(s.pausada, isTrue);
      expect(s.restanteMs, 58766);
      expect(s.actual!.orden, m.sesion.actual!.orden);
      expect(s.reservas.length, 7);
      j['banco'] = 'otra-edicion';
      expect(() => SesionTrivia.fromJson(j, banco), throwsFormatException);
    },
  );
  test('rechaza opciones, aciertos y asignaciones adulteradas', () {
    for (final mutacion in [0, 1, 2, 3]) {
      final m = muestra(2)
        ..iniciar()
        ..siguiente()
        ..reanudar();
      m.responder(m.sesion.actual!.indiceCorrecto(banco));
      final j =
          jsonDecode(jsonEncode(m.sesion.toJson())) as Map<String, dynamic>;
      final r = (j['preguntas'] as Map).values.firstWhere(
        (v) => v['propio'] != null,
      );
      if (mutacion == 0) {
        r['ordenOpciones'] = [0, 0, 2, 3];
      }
      if (mutacion == 1) {
        r['propio']['correcto'] = false;
      }
      if (mutacion == 2) {
        (j['paquetes'] as Map).values.first[0] = 'NO-EXISTE';
      }
      if (mutacion == 3) {
        j['version'] = 3;
      }
      expect(() => SesionTrivia.fromJson(j, banco), throwsFormatException);
    }
  });
  test(
    'cierre anticipado identifica no presentadas y ausentes sin inventar notas',
    () {
      final m = muestra(3);
      m.asistencia('S2', false);
      m.iniciar();
      m.siguiente();
      m.reanudar();
      m.transcurrir(1234);
      m.finalizar();
      final s = m.sesion;
      s.validar(banco);
      expect(s.cierreAnticipado, isTrue);
      expect(
        s.registros.values
            .where((r) => r.propio!.estado == EstadoIntento.noPresentada)
            .length,
        29,
      );
      expect(csvResultados(s), contains('"AUSENTE"'));
      expect(csvResultados(s), contains('"Finalizada"'));
      expect(s.resultado('S2').presentadas, 0);
    },
  );
  test(
    'deshacer revierte puntos y exige reanudar sin duplicar la respuesta',
    () {
      final m = muestra(2)
        ..iniciar()
        ..siguiente()
        ..reanudar();
      final id = m.sesion.actual!.titularId;
      m.transcurrir(3000);
      m.responder(m.sesion.actual!.indiceCorrecto(banco));
      expect(m.sesion.resultado(id).puntos, 1);
      m.deshacer();
      expect(m.sesion.resultado(id).puntos, 0);
      expect(m.sesion.pausada, isTrue);
      m.responder(m.sesion.actual!.indiceCorrecto(banco));
      expect(m.sesion.resultado(id).puntos, 0);
      m.reanudar();
      m.responder(m.sesion.actual!.indiceCorrecto(banco));
      expect(m.sesion.resultado(id).puntos, 1);
    },
  );
  test('guardado atómico, historial, recuperación e importación con banco validado', () async {
    final d = await Directory.systemTemp.createTemp('trivia_repo_');
    addTearDown(() => d.delete(recursive: true));
    final repo = RepositorioEvaluacion(d);
    final m = muestra(2)
      ..iniciar()
      ..siguiente()
      ..reanudar();
    await repo.guardar(jsonEncode(m.sesion.toJson()));
    m.transcurrir(5000);
    await repo.guardar(jsonEncode(m.sesion.toJson()));
    expect((await repo.cargar(banco)).sesion!.restanteMs, 55000);
    expect((await repo.historial(banco)).length, 1);
    await File('${d.path}/actual.json').writeAsString('{dañado');
    final recuperada = await repo.cargar(banco);
    expect(recuperada.sesion!.restanteMs, 60000);
    expect(recuperada.aviso, isNotNull);
    expect(recuperada.sesion!.pausada, isTrue);
    final c = ControladorEvaluacion(
      MotorEvaluacion(banco, recuperada.sesion!),
      repo,
      temporizador: false,
    );
    c.accion((m) => m.reanudar());
    c.accion((m) => m.responder(m.sesion.actual!.indiceCorrecto(banco)));
    await c.guardadoPendiente;
    expect((await repo.cargar(banco)).sesion!.fase, FaseEvaluacion.revision);
    c.dispose();
    await c.guardadoPendiente;
  });
}
