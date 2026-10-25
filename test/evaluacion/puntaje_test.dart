import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/modelos.dart';

import 'motor_test.dart' show banco, muestra;

void avanzar(MotorEvaluacion m) {
  if (m.sesion.avisoPuntajeId != null) {
    m.resolverAvisoPuntaje(finalizar: false);
  }
  m.siguiente();
  m.reanudar();
}

void main() {
  test('aprobación una vez, cierre en siete y deshacer restaura decisión', () {
    final m = muestra(1)..iniciar();
    for (var i = 0; i < 7; i++) {
      avanzar(m);
      m.responder(m.sesion.actual!.indiceCorrecto(banco));
    }
    expect(m.sesion.avisoPuntajeId, 'S0');
    final pregunta = m.sesion.actualId;
    m.siguiente();
    expect(m.sesion.actualId, pregunta);
    m.resolverAvisoPuntaje(finalizar: true);
    expect(m.sesion.terminoAlumno('S0'), isTrue);
    final recuperada = SesionTrivia.fromJson(
      jsonDecode(jsonEncode(m.sesion.toJson())),
      banco,
    );
    expect(recuperada.finalizados, {'S0'});
    m.deshacer();
    expect(m.sesion.finalizados, isEmpty);
    expect(m.sesion.resultado('S0').puntos, 6);
    expect(m.sesion.aprobacionConsultada, isEmpty);
    m.reanudar();
    m.responder(m.sesion.actual!.indiceCorrecto(banco));
    expect(m.sesion.avisoPuntajeId, 'S0');
    m.resolverAvisoPuntaje(finalizar: true);
    m.siguiente();
    expect(m.sesion.finalizada, isTrue);
    expect(m.sesion.cierreAnticipado, isFalse);
    expect(m.sesion.resultado('S0').presentadas, 7);
    m.sesion.validar(banco);
  });

  test(
    'robo cruza de seis a ocho, de nueve a diez suma uno y sale de candidatos',
    () {
      final m = muestra(4)..iniciar();
      const objetivo = 'S0';
      var avisoOcho = false;
      var eventosDiez = 0;
      for (
        var paso = 0;
        paso < 40 && !m.sesion.terminoAlumno(objetivo);
        paso++
      ) {
        avanzar(m);
        final r = m.sesion.actual!;
        final correcta = r.indiceCorrecto(banco);
        final puntos = m.sesion.resultado(objetivo).puntos;
        if (r.titularId == objetivo) {
          // Seis puntos de robos y luego un robo para aprobar con ocho.
          if (puntos < 8) {
            m.sinRespuesta();
            m.cerrarPregunta();
          } else {
            m.responder(correcta); // ocho a nueve
          }
        } else {
          m.sinRespuesta();
          if (puntos == 8) {
            m.cerrarPregunta();
            continue;
          }
          m.iniciarRobo(objetivo);
          m.responder(correcta);
          if (puntos == 6) {
            expect(m.sesion.resultado(objetivo).puntos, 8);
            expect(m.sesion.avisoPuntajeId, objetivo);
            avisoOcho = true;
          }
          if (puntos == 9) {
            expect(r.robos.last.puntos, 1);
            expect(m.sesion.puntosOtorgados(r.robos.last), 1);
            eventosDiez++;
          }
        }
        if (m.sesion.resultado(objetivo).puntos == 9) {
          expect(m.sesion.avisoPuntajeId, isNull);
        }
        m.sesion.validar(banco);
      }
      expect(avisoOcho, isTrue);
      expect(eventosDiez, 1);
      expect(m.sesion.resultado(objetivo).puntos, 10);
      expect(m.sesion.avisoPuntajeId, objetivo);
      final restaurada = SesionTrivia.fromJson(
        jsonDecode(jsonEncode(m.sesion.toJson())),
        banco,
      );
      expect(restaurada.avisoPuntajeId, objetivo);
      expect(restaurada.resultado(objetivo).puntos, 10);
      m.deshacer();
      expect(m.sesion.resultado(objetivo).puntos, 9);
      expect(m.sesion.terminoAlumno(objetivo), isFalse);
      m.responder(m.sesion.actual!.indiceCorrecto(banco));
      m.resolverAvisoPuntaje(finalizar: false);
      for (var i = 0; i < 3; i++) {
        avanzar(m);
        expect(m.sesion.actual!.titularId, isNot(objetivo));
        m.sinRespuesta();
        expect(m.sesion.habilitadosRobo.any((a) => a.id == objetivo), isFalse);
        m.cerrarPregunta();
      }
    },
  );
}
