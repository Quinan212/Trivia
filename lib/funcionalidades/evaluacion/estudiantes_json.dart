import 'dart:convert';

import 'modelos.dart';

class EstudiantesJson {
  static const maxBytes = 256 * 1024;

  static String limpiar(String valor) =>
      valor.trim().replaceAll(RegExp(r'\s+'), ' ');

  static List<AlumnoTrivia> importar(String raw) {
    if (utf8.encode(raw).length > maxBytes) {
      throw const FormatException(
        'El archivo de estudiantes no puede superar 256 KB.',
      );
    }
    final contenido = jsonDecode(raw);
    final List<dynamic> filas;
    if (contenido is List) {
      filas = contenido;
    } else if (contenido is Map &&
        contenido['formato'] == 'estudiantes-trivia' &&
        contenido['version'] == 1 &&
        contenido['estudiantes'] is List) {
      filas = contenido['estudiantes'] as List;
    } else {
      throw const FormatException('Usá la plantilla JSON de estudiantes.');
    }
    if (filas.isEmpty || filas.length > 20) {
      throw const FormatException(
        'La lista debe contener entre 1 y 20 estudiantes.',
      );
    }
    final reservados = <String>{};
    for (final fila in filas) {
      if (fila is! Map) throw const FormatException('Estudiante inválido.');
      if (fila.containsKey('id')) {
        final id = fila['id'];
        if (id is! String ||
            !RegExp(r'^[a-zA-Z0-9_-]{1,24}$').hasMatch(id) ||
            !reservados.add(id)) {
          throw const FormatException(
            'Los identificadores de estudiantes deben ser válidos y distintos.',
          );
        }
      }
    }
    var siguiente = 1;
    return [
      for (final fila in filas)
        (() {
          String campo(String clave) {
            final valor = fila[clave];
            if (valor is! String ||
                limpiar(valor).isEmpty ||
                limpiar(valor).length > 120) {
              throw const FormatException(
                'Cada estudiante necesita apellido y nombre de hasta 120 caracteres.',
              );
            }
            return limpiar(valor);
          }

          final apellido = campo('apellido'), nombre = campo('nombre');
          if (fila.containsKey('presente') && fila['presente'] is! bool) {
            throw const FormatException('La asistencia debe ser true o false.');
          }
          var id = fila['id'] as String?;
          if (id == null) {
            do {
              id = 'E${(siguiente++).toString().padLeft(3, '0')}';
            } while (!reservados.add(id));
          }
          return AlumnoTrivia(
            id: id,
            apellido: apellido,
            nombre: nombre,
            presente: fila['presente'] as bool? ?? true,
          );
        })(),
    ];
  }

  static String plantilla(Iterable<AlumnoTrivia> alumnos) =>
      const JsonEncoder.withIndent('  ').convert({
        'formato': 'estudiantes-trivia',
        'version': 1,
        'estudiantes': [
          for (final a in alumnos)
            {
              'apellido': a.apellido,
              'nombre': a.nombre,
              'presente': a.presente,
            },
        ],
      });
}
