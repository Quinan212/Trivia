import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/controlador.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/estudiantes_json.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/repositorio.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/modelos.dart';

import 'motor_test.dart' show muestra, banco;
import 'banco_personalizado_test.dart' show personalizado;

String ejemploEstudiantes(int n) => jsonEncode({
  'formato': 'estudiantes-trivia',
  'version': 1,
  'estudiantes': [
    for (var i = 0; i < n; i++)
      {'apellido': 'Apellido $i', 'nombre': 'Nombre $i', 'presente': i.isEven},
  ],
});

class _RepoFallido extends RepositorioEvaluacion {
  _RepoFallido() : super(Directory.systemTemp);
  @override
  Future<void> guardar(String raw) async =>
      throw const FileSystemException('Fallo simulado');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('plantilla, orden, asistencia, homónimos e IDs opcionales', () {
    final lista = EstudiantesJson.importar(ejemploEstudiantes(20));
    expect(lista.length, 20);
    expect(lista.map((a) => a.id).toSet().length, 20);
    final copia = EstudiantesJson.importar(EstudiantesJson.plantilla(lista));
    expect(
      copia.map((a) => (a.apellido, a.nombre, a.presente)),
      lista.map((a) => (a.apellido, a.nombre, a.presente)),
    );
    final homonimos = EstudiantesJson.importar(
      jsonEncode([
        {'apellido': '  Pérez  ', 'nombre': ' María  Eugenia '},
        {'id': 'E001', 'apellido': 'Pérez', 'nombre': 'María Eugenia'},
      ]),
    );
    expect(homonimos.first.nombre, 'María Eugenia');
    expect(homonimos.first.presente, isTrue);
    expect(homonimos.first.id, isNot(homonimos.last.id));
  });

  test('rechaza formatos, filas, tipos, IDs y tamaños inválidos', () {
    final validos = jsonDecode(ejemploEstudiantes(2)) as Map<String, dynamic>;
    for (final raw in [
      'no json',
      '{}',
      ejemploEstudiantes(0),
      ejemploEstudiantes(21),
      jsonEncode({...validos, 'version': 2}),
      jsonEncode({...validos, 'formato': 'banco-trivia'}),
      jsonEncode([
        {'apellido': 'A', 'nombre': 123},
      ]),
      jsonEncode([
        {'apellido': ' ', 'nombre': 'B'},
      ]),
      jsonEncode([
        {'apellido': 'A', 'nombre': 'B', 'presente': 'sí'},
      ]),
      jsonEncode([
        {'id': '../ruta', 'apellido': 'A', 'nombre': 'B'},
      ]),
      jsonEncode([
        for (var i = 0; i < 2; i++) {'id': 'X', 'apellido': 'A', 'nombre': 'B'},
      ]),
      jsonEncode([
        {'apellido': 'A' * 121, 'nombre': 'B'},
      ]),
      ' ' * (EstudiantesJson.maxBytes + 1),
    ]) {
      expect(() => EstudiantesJson.importar(raw), throwsFormatException);
    }
  });

  test('carga guarda y recupera lista, banco y configuración juntos', () async {
    final dir = await Directory.systemTemp.createTemp('estudiantes-trivia-');
    addTearDown(() => dir.delete(recursive: true));
    final c = ControladorEvaluacion(
      muestra(2),
      RepositorioEvaluacion(dir),
      temporizador: false,
    );
    final cfg = c.sesion.configuracion.toJson();
    await c.cambiarEstudiantes(EstudiantesJson.importar(ejemploEstudiantes(3)));
    final recuperada = await c.repositorio.cargar(banco, resolverBanco: true);
    expect(
      recuperada.sesion!.alumnos.map((a) => a.toJson()),
      c.sesion.alumnos.map((a) => a.toJson()),
    );
    expect(recuperada.sesion!.configuracion.toJson(), cfg);
    expect(recuperada.sesion!.iniciada, isFalse);
    c.nuevaSesion();
    expect(c.sesion.alumnos.length, 3);
    c.dispose();
    await c.guardadoPendiente;
  });

  test('evaluación en curso exige confirmación y conserva historial', () async {
    final dir = await Directory.systemTemp.createTemp('estudiantes-historial-');
    addTearDown(() => dir.delete(recursive: true));
    final m = muestra(2)
      ..iniciar()
      ..siguiente()
      ..reanudar();
    m.responder(m.sesion.actual!.indiceCorrecto(banco));
    final c = ControladorEvaluacion(
      m,
      RepositorioEvaluacion(dir),
      temporizador: false,
    );
    final anterior = c.sesion.id;
    final lista = EstudiantesJson.importar(ejemploEstudiantes(3));
    await expectLater(c.cambiarEstudiantes(lista), throwsStateError);
    expect(c.sesion.id, anterior);
    await c.cambiarEstudiantes(lista, crearNuevaEvaluacion: true);
    expect(c.sesion.id, isNot(anterior));
    expect(c.sesion.alumnos.length, 3);
    expect(c.sesion.iniciada, isFalse);
    final historia = await c.repositorio.historial(banco);
    expect(
      historia.any(
        (s) =>
            s.id == anterior &&
            s.registros.values.any((r) => r.propio?.correcto == true),
      ),
      isTrue,
    );
    c.dispose();
    await c.guardadoPendiente;
  });

  test(
    'banco insuficiente y fallo de escritura conservan la lista anterior',
    () async {
      final m = muestra(2);
      final c = ControladorEvaluacion(m, _RepoFallido(), temporizador: false);
      final raw = jsonEncode(c.sesion.toJson());
      await expectLater(
        c.cambiarEstudiantes(EstudiantesJson.importar(ejemploEstudiantes(3))),
        throwsA(isA<FileSystemException>()),
      );
      expect(jsonEncode(c.sesion.toJson()), raw);
      expect(c.puedeSeleccionarBanco, isTrue);
      c.dispose();
      await c.guardadoPendiente;
      final b = personalizado(20);
      final s = SesionTrivia(
        id: 'IV_CAPACIDAD',
        fecha: DateTime.utc(2026),
        huellaBanco: b.huella,
        alumnos: muestra(2).sesion.alumnos,
      );
      final corto = ControladorEvaluacion(
        MotorEvaluacion(b, s),
        _RepoFallido(),
        temporizador: false,
      );
      await expectLater(
        corto.cambiarEstudiantes(
          EstudiantesJson.importar(ejemploEstudiantes(3)),
        ),
        throwsStateError,
      );
      expect(corto.sesion.alumnos.length, 2);
      expect(corto.sesion.id, 'IV_CAPACIDAD');
      corto.dispose();
      await corto.guardadoPendiente;
    },
  );

  test(
    'corregir nombre conserva puntos y deshacer; borrar solo antes de iniciar',
    () {
      final m = muestra(2)
        ..iniciar()
        ..siguiente()
        ..reanudar();
      final id = m.sesion.actual!.titularId;
      m.responder(m.sesion.actual!.indiceCorrecto(banco));
      final puntos = m.sesion.resultado(id).puntos;
      m.editarAlumno(id, 'Pérez', 'María Eugenia');
      expect(m.sesion.resultado(id).puntos, puntos);
      expect(() => m.eliminarAlumno(id), throwsStateError);
      m.deshacer();
      expect(m.sesion.alumno(id).completo, 'Pérez, María Eugenia');
      final preparacion = muestra(2);
      preparacion.eliminarAlumno(preparacion.sesion.alumnos.first.id);
      expect(preparacion.sesion.alumnos.length, 1);
      expect(
        () => preparacion.eliminarAlumno(preparacion.sesion.alumnos.first.id),
        throwsStateError,
      );
    },
  );
}
