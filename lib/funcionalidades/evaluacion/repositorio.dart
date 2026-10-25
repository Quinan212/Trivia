import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'modelos.dart';

class CargaEvaluacion {
  const CargaEvaluacion(this.sesion, this.aviso, {this.banco});
  final SesionTrivia? sesion;
  final String? aviso;
  final BancoTrivia? banco;
}

class RepositorioEvaluacion {
  RepositorioEvaluacion(this.directorio);
  final Directory directorio;
  String? _ultimoValido;
  Future<void> _colaInformes = Future.value();
  final List<File> _danados = [];
  static Future<RepositorioEvaluacion> abrir() async => RepositorioEvaluacion(
    Directory(
      '${(await getApplicationDocumentsDirectory()).path}/trivia_evaluaciones',
    ),
  );
  File get _actual => File('${directorio.path}/actual.json');
  File get _respaldo => File('${directorio.path}/respaldo.json');
  Future<CargaEvaluacion> cargar(
    BancoTrivia banco, {
    bool resolverBanco = false,
  }) async {
    var habiaRegistro = false;
    for (final f in [_actual, _respaldo]) {
      if (!await f.exists()) continue;
      habiaRegistro = true;
      try {
        final raw = await f.readAsString();
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final actualBanco = resolverBanco && j['bancoPersonalizado'] != null
            ? BancoTrivia.importar(j['bancoPersonalizado'] as String)
            : banco;
        final s = SesionTrivia.fromJson(j, actualBanco, recuperar: true);
        _ultimoValido = raw;
        return CargaEvaluacion(
          s,
          f.path == _respaldo.path
              ? 'Se recuperó la copia de respaldo de la evaluación.'
              : null,
          banco: actualBanco,
        );
      } on Object {
        _danados.add(f);
      }
    }
    return CargaEvaluacion(
      null,
      habiaRegistro
          ? 'No se pudo recuperar la última evaluación. Los archivos anteriores se conservaron.'
          : null,
    );
  }

  Future<void> guardar(String raw) async {
    await directorio.create(recursive: true);
    if (_danados.isNotEmpty) {
      final recuperacion = Directory('${directorio.path}/recuperacion');
      await recuperacion.create(recursive: true);
      for (final archivo in _danados) {
        if (await archivo.exists()) {
          await archivo.copy(
            '${recuperacion.path}/${DateTime.now().microsecondsSinceEpoch}_${archivo.uri.pathSegments.last}',
          );
        }
      }
      _danados.clear();
    }
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final id = j['id'] as String;
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Identificador de sesión inválido.');
    }
    final temporal = File('${directorio.path}/actual.tmp');
    await temporal.writeAsString(raw, flush: true);
    if (_ultimoValido != null) {
      final copia = File('${directorio.path}/respaldo.tmp');
      await copia.writeAsString(_ultimoValido!, flush: true);
      await copia.rename(_respaldo.path);
    }
    final sesiones = Directory('${directorio.path}/sesiones');
    await sesiones.create(recursive: true);
    final historicoTemporal = File('${sesiones.path}/$id.tmp');
    await historicoTemporal.writeAsString(raw, flush: true);
    await historicoTemporal.rename('${sesiones.path}/$id.json');
    // Banco y sesión se confirman juntos después de conservar el historial.
    await temporal.rename(_actual.path);
    _ultimoValido = raw;
  }

  Future<List<SesionTrivia>> historial(BancoTrivia banco) async {
    final carpeta = Directory('${directorio.path}/sesiones');
    if (!await carpeta.exists()) return [];
    final sesiones = <SesionTrivia>[];
    await for (final f in carpeta.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        sesiones.add(
          SesionTrivia.fromJson(
            jsonDecode(await f.readAsString()) as Map<String, dynamic>,
            banco,
            recuperar: true,
          ),
        );
      } on Object {
        /* Un archivo dañado no oculta las otras sesiones. */
      }
    }
    sesiones.sort((a, b) => b.fecha.compareTo(a.fecha));
    return sesiones;
  }

  Future<File> guardarInforme(String nombre, List<int> bytes) {
    final operacion = _colaInformes.then(
      (_) => _escribirInforme(nombre, bytes),
    );
    _colaInformes = operacion.then<void>(
      (_) {},
      onError: (Object e, StackTrace s) {},
    );
    return operacion;
  }

  Future<File> _escribirInforme(String nombre, List<int> bytes) async {
    if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(nombre)) {
      throw ArgumentError('Nombre de archivo inválido.');
    }
    final carpeta = Directory('${directorio.path}/informes');
    await carpeta.create(recursive: true);
    final temporal = File('${carpeta.path}/$nombre.tmp');
    await temporal.writeAsBytes(bytes, flush: true);
    return temporal.rename('${carpeta.path}/$nombre');
  }
}

Future<({BancoTrivia banco, List<AlumnoTrivia> alumnos})>
cargarContenidoTrivia() async {
  final raw = await rootBundle.loadString(
    'assets/contenido/trivia-unidad-iv.json',
  );
  final nomina = jsonDecode(
    await rootBundle.loadString('assets/contenido/nomina-inicial.json'),
  ) as List;
  return (
    banco: BancoTrivia.desdeTexto(raw),
    alumnos: nomina
        .map((j) => AlumnoTrivia.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList(),
  );
}
