import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:trivia_antiguedad/funcionalidades/evaluacion/modelos.dart';

void main() {
  final banco = BancoTrivia.desdeTexto(
    File('assets/contenido/trivia-unidad-iv.json').readAsStringSync(),
  );
  final motor = MotorEvaluacion(
    banco,
    SesionTrivia(
      id: 'IV_SIMULACION_ALUMNO',
      fecha: DateTime.utc(2026, 10, 21, 15),
      huellaBanco: banco.huella,
      alumnos: [
        AlumnoTrivia(
          id: 'ALUMNO_QA',
          apellido: 'SIMULACIÓN',
          nombre: 'Alumno de prueba',
        ),
      ],
    ),
    random: Random(20261021),
  )..iniciar();
  final dir = Directory('qa/evaluacion/simulacion-alumno')
    ..createSync(recursive: true);
  final json = const JsonEncoder.withIndent('  ');
  File('${dir.path}/sesion-inicial.json')
      .writeAsStringSync(json.convert(motor.sesion.toJson()));
  final preguntas = [
    for (final id in motor.sesion.paquetes['ALUMNO_QA']!)
      {
        'id_interno': id,
        'tema': banco.porId[id]!.tema,
        'pregunta': banco.porId[id]!.texto,
        'opciones_visibles': [
          for (final indice in motor.sesion.registros[id]!.orden)
            banco.porId[id]!.opciones[indice],
        ],
      },
  ];
  // La lectura previa del alumno no contiene claves ni explicaciones.
  File('${dir.path}/preguntas-sin-claves.json')
      .writeAsStringSync(json.convert(preguntas));
  stdout.writeln(json.convert(preguntas));
}
