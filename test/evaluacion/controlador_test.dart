import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/controlador.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/modelos.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/repositorio.dart';

import 'motor_test.dart' show muestra, banco;

class _Reloj extends Stopwatch {
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

void main() {
  test('la respuesta que llega tras el plazo vence aunque no haya habido un pulso de UI', () async {
    final dir = await Directory.systemTemp.createTemp('trivia_reloj_');
    final reloj = _Reloj();
    final c = ControladorEvaluacion(
      muestra(2),
      RepositorioEvaluacion(dir),
      reloj: reloj,
      temporizador: false,
    );
    c.accion((m) => m.iniciar());
    c.accion((m) => m.siguiente());
    c.accion((m) => m.reanudar());
    final r = c.sesion.actual!;
    reloj.ms = 61000;
    c.accion((m) => m.responder(r.indiceCorrecto(banco)));
    expect(c.sesion.fase, FaseEvaluacion.esperaRobo);
    expect(r.propio!.estado, EstadoIntento.agotado);
    expect(r.propio!.correcto, isFalse);
    expect(c.sesion.resultado(r.titularId).puntos, 0);
    c.dispose();
    await c.guardadoPendiente;
    expect(
      (await c.repositorio.cargar(banco)).sesion!.actual!.propio!.estado,
      EstadoIntento.agotado,
    );
    await dir.delete(recursive: true);
  });
}
