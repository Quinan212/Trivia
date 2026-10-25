import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/modelos.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/controlador.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/repositorio.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/acta_pdf.dart';

import 'motor_test.dart' show banco, muestra;

Map<String, dynamic> ejemploBanco(int n) => {
  'formato': 'banco-trivia',
  'version': 1,
  'nombre': 'Banco de prueba',
  'preguntas': [
    for (var i = 0; i < n; i++)
      {
        'id': 'P$i',
        'tema': ['Tema nuevo', 'Otro tema', 'Todos'][i % 3],
        'subtema': 'Contenido ${i % 7}',
        'tipo': 'General',
        'pregunta': 'Enunciado de prueba $i',
        'opciones': [
          'Opción A de $i',
          'Opción B de $i',
          'Opción C de $i',
          'Opción D de $i',
        ],
        'correcta': 'ABCD'[i % 4],
        'explicacion': 'Explicación de prueba $i',
      },
  ],
};
BancoTrivia personalizado(int n) =>
    BancoTrivia.importar(jsonEncode(ejemploBanco(n)));

class _RepositorioFallido extends RepositorioEvaluacion {
  _RepositorioFallido() : super(Directory.systemTemp);
  @override
  Future<void> guardar(String raw) async =>
      throw const FileSystemException('Error de prueba');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'el informe individual admite el banco personalizado y sus temas',
    () async {
      final b = personalizado(23);
      final s = SesionTrivia(
        id: 'IV_SIMULACION_BANCO',
        fecha: DateTime.utc(2026, 10, 23),
        huellaBanco: b.huella,
        alumnos: muestra(2).sesion.alumnos,
      );
      final m = MotorEvaluacion(b, s)
        ..iniciar()
        ..siguiente()
        ..reanudar();
      final id = s.actual!.titularId;
      m.responder(s.actual!.indiceCorrecto(b));
      m.finalizar();
      final bytes = await GeneradorActa(await RecursosActa.cargar())
          .crear(s, b, alumnoId: id);
      final dir = Directory('qa/evaluacion/pdf/banco-personalizado')
        ..createSync(recursive: true);
      await File('${dir.path}/informe-prueba.pdf').writeAsBytes(bytes);
      expect(bytes.length, greaterThan(10000));
    },
  );
  test(
    'la plantilla mantiene literalmente las 200 preguntas y claves originales',
    () {
      final copia = BancoTrivia.importar(banco.plantillaJson());
      expect(copia.personalizado, isTrue);
      expect(copia.preguntas.length, 200);
      for (var i = 0; i < 200; i++) {
        final original = banco.preguntas[i], nueva = copia.preguntas[i];
        expect(
          (
            nueva.id,
            nueva.tema,
            nueva.subtema,
            nueva.tipo,
            nueva.texto,
            nueva.correcta,
            nueva.explicacion,
          ),
          (
            original.id,
            original.tema,
            original.subtema,
            original.tipo,
            original.texto,
            original.correcta,
            original.explicacion,
          ),
        );
        expect(nueva.opciones, original.opciones);
      }
      expect(BancoTrivia.importar(banco.raw).preguntas.length, 200);
    },
  );

  test('rechaza JSON y preguntas inválidas sin aceptar claves ambiguas', () {
    for (final mutacion in [
      'pocas',
      'id',
      'texto',
      'opciones',
      'letra',
      'tema',
      'explicacion',
      'formato',
      'version',
    ]) {
      final j = ejemploBanco(20);
      final preguntas = j['preguntas'] as List;
      switch (mutacion) {
        case 'pocas':
          preguntas.removeRange(5, preguntas.length);
        case 'id':
          preguntas[1]['id'] = preguntas[0]['id'];
        case 'texto':
          preguntas[1]['pregunta'] = preguntas[0]['pregunta'];
        case 'opciones':
          preguntas[0]['opciones'] = ['A', 'A', 'C', 'D'];
        case 'letra':
          preguntas[0]['correcta'] = 1;
        case 'tema':
          preguntas[0]['tema'] = ' ';
        case 'explicacion':
          preguntas[0].remove('explicacion');
        case 'formato':
          j['formato'] = 'otro';
        case 'version':
          j['version'] = 2;
      }
      expect(
        () => BancoTrivia.importar(jsonEncode(j)),
        throwsFormatException,
        reason: mutacion,
      );
    }
    expect(() => BancoTrivia.importar('{incompleto'), throwsFormatException);
    expect(
      () => BancoTrivia.importar(' ' * (2 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
    expect(personalizado(20).temas, ['Tema nuevo', 'Otro tema', 'Todos']);
  });

  test('repartos variables: exclusividad, reservas completas y sobrantes', () {
    for (final n in [10, 23, 37, 130, 213, 2000]) {
      final b = personalizado(n);
      // La sesión de prueba se crea con la huella de este banco.
      final s = SesionTrivia(
        id: 'IV_CUSTOM_$n',
        fecha: DateTime.utc(2026, 10, 23),
        huellaBanco: b.huella,
        alumnos: muestra(min(20, n ~/ 10)).sesion.alumnos,
      );
      final motor = MotorEvaluacion(b, s, random: Random(n))..iniciar();
      final todos = [
        ...s.paquetes.values.expand((p) => p),
        ...s.reservas.expand((p) => p),
      ];
      expect(todos.length, n);
      expect(todos.toSet().length, n);
      expect(s.paquetes.values.every((p) => p.length == 10), isTrue);
      s.validar(b);
      motor.siguiente();
      motor.reanudar();
      motor.responder(s.actual!.indiceCorrecto(b));
      final restaurada = SesionTrivia.fromJson(
        jsonDecode(jsonEncode(s.toJson())),
        b,
        recuperar: true,
      );
      expect(restaurada.actual!.propio!.correcto, isTrue);
      motor.deshacer();
      expect(motor.sesion.bancoPersonalizado, b.raw);
      expect(motor.sesion.actual!.propio, isNull);
    }
  });

  test(
    'no inicia cuando no alcanza para cada estudiante, incluso ausentes',
    () {
      final b = personalizado(23);
      final s = SesionTrivia(
        id: 'IV_INSUFICIENTE',
        fecha: DateTime.utc(2026),
        huellaBanco: b.huella,
        alumnos: muestra(3).sesion.alumnos,
      );
      s.alumnos.last.presente = false;
      final m = MotorEvaluacion(b, s);
      expect(m.iniciar, throwsStateError);
      expect(s.paquetes, isEmpty);
    },
  );

  test('banco y evaluación se recuperan juntos; bloqueo activo y regreso al predeterminado', () async {
    final d = await Directory.systemTemp.createTemp('trivia_bancos_');
    final repo = RepositorioEvaluacion(d);
    final inicial = muestra(2);
    inicial.asistencia('S1', false);
    final c = ControladorEvaluacion(inicial, repo, temporizador: false);
    try {
      await repo.guardar(jsonEncode(c.sesion.toJson()));
      final originalId = c.sesion.id;
      final b = personalizado(23);
      await c.cambiarBanco(b);
      expect(c.sesion.alumno('S1').presente, isFalse);
      expect(
        await File('${d.path}/sesiones/$originalId.json').exists(),
        isTrue,
      );
      c.accion((m) => m.iniciar());
      c.accion((m) => m.siguiente());
      c.accion((m) => m.reanudar());
      c.accion((m) => m.responder(m.sesion.actual!.indiceCorrecto(b)));
      await c.guardadoPendiente;
      await expectLater(c.cambiarBanco(banco), throwsStateError);
      final rec = await RepositorioEvaluacion(d)
          .cargar(banco, resolverBanco: true);
      expect(rec.banco!.huella, b.huella);
      expect(rec.sesion!.actual!.propio!.correcto, isTrue);
      expect(rec.sesion!.bancoPersonalizado, b.raw);
      await File('${d.path}/actual.json').writeAsString('{roto');
      final respaldo = await RepositorioEvaluacion(d)
          .cargar(banco, resolverBanco: true);
      expect(respaldo.banco!.huella, b.huella);
      expect(respaldo.sesion, isNotNull);
      c.nuevaSesion();
      await c.cambiarBanco(banco);
      final defecto = await RepositorioEvaluacion(d)
          .cargar(banco, resolverBanco: true);
      expect(defecto.banco!.personalizado, isFalse);
      expect(defecto.sesion!.bancoPersonalizado, isNull);
    } finally {
      c.dispose();
      await c.guardadoPendiente;
      await d.delete(recursive: true);
    }
  });

  test(
    'un fallo de escritura no cambia el banco ni la sesión en memoria',
    () async {
      final c = ControladorEvaluacion(
        muestra(2),
        _RepositorioFallido(),
        temporizador: false,
      );
      final id = c.sesion.id;
      await expectLater(
        c.cambiarBanco(personalizado(23)),
        throwsA(isA<FileSystemException>()),
      );
      expect(c.banco.huella, banco.huella);
      expect(c.sesion.id, id);
      expect(c.puedeCambiarBanco, isTrue);
      c.dispose();
      await c.guardadoPendiente;
    },
  );
  test('reemplazo confirmado guarda la sesión activa y crea otra sin mezclar respuestas', () async {
    final d = await Directory.systemTemp.createTemp('trivia_reemplazo_');
    final repo = RepositorioEvaluacion(d);
    final motor = muestra(2)
      ..iniciar()
      ..siguiente()
      ..reanudar();
    motor.responder(motor.sesion.actual!.indiceCorrecto(banco));
    final c = ControladorEvaluacion(motor, repo, temporizador: false);
    final id = c.sesion.id;
    final actor = c.sesion.actual!.titularId;
    try {
      expect(c.puedeSeleccionarBanco, isTrue);
      await expectLater(c.cambiarBanco(personalizado(23)), throwsStateError);
      expect(c.sesion.id, id);
      await c.cambiarBanco(personalizado(23), crearNuevaEvaluacion: true);
      final anterior = SesionTrivia.fromJson(
        jsonDecode(await File('${d.path}/sesiones/$id.json').readAsString()),
        banco,
      );
      expect(anterior.resultado(actor).puntos, 1);
      expect(c.sesion.id, isNot(id));
      expect(c.sesion.iniciada, isFalse);
      expect(c.sesion.registros, isEmpty);
      expect(c.banco.preguntas.length, 23);
      expect(
        (await RepositorioEvaluacion(
          d,
        ).cargar(banco, resolverBanco: true)).banco!.huella,
        c.banco.huella,
      );
    } finally {
      c.dispose();
      await c.guardadoPendiente;
      await d.delete(recursive: true);
    }
  });

  test(
    'reemplazo confirmado fallido conserva la sesión activa y su puntaje',
    () async {
      final motor = muestra(2)
        ..iniciar()
        ..siguiente()
        ..reanudar();
      motor.responder(motor.sesion.actual!.indiceCorrecto(banco));
      final c = ControladorEvaluacion(
        motor,
        _RepositorioFallido(),
        temporizador: false,
      );
      final id = c.sesion.id;
      final actor = c.sesion.actual!.titularId;
      await expectLater(
        c.cambiarBanco(personalizado(23), crearNuevaEvaluacion: true),
        throwsA(isA<FileSystemException>()),
      );
      expect(c.sesion.id, id);
      expect(c.sesion.resultado(actor).puntos, 1);
      expect(c.banco.huella, banco.huella);
      c.dispose();
      await c.guardadoPendiente;
    },
  );
}
