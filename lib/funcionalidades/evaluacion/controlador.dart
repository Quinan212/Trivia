import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'modelos.dart';
import 'repositorio.dart';
import 'configuracion.dart';
import 'estudiantes_json.dart';

class ControladorEvaluacion extends ChangeNotifier {
  ControladorEvaluacion(
    this.motor,
    this.repositorio, {
    this.aviso,
    Set<String> alumnosIniciales = const {},
    bool temporizador = true,
    Stopwatch? reloj,
  }) : alumnosIniciales = Set.unmodifiable(alumnosIniciales),
       _reloj = reloj ?? Stopwatch() {
    if (temporizador) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => pulso(),
      );
    }
  }
  static Future<ControladorEvaluacion> abrir() async {
    final datos = await cargarContenidoTrivia();
    final repo = await RepositorioEvaluacion.abrir();
    final carga = await repo.cargar(datos.banco, resolverBanco: true);
    final banco = carga.banco ?? datos.banco;
    final s =
        carga.sesion ??
        SesionTrivia(
          id: 'IV_${DateTime.now().microsecondsSinceEpoch}',
          fecha: DateTime.now().toUtc(),
          huellaBanco: banco.huella,
          alumnos: datos.alumnos,
        );
    return ControladorEvaluacion(
      MotorEvaluacion(banco, s),
      repo,
      aviso: carga.aviso,
      alumnosIniciales: datos.alumnos.map((a) => a.id).toSet(),
    );
  }

  MotorEvaluacion motor;
  final RepositorioEvaluacion repositorio;
  final Set<String> alumnosIniciales;
  String? aviso;
  Timer? _timer;
  final Stopwatch _reloj;
  int _lectura = 0, _ultimoRespaldo = 0;
  Future<void> _cola = Future.value();
  bool _cerrado = false;
  bool _cambiandoBanco = false;
  bool get puedeCambiarBanco =>
      !_cerrado && !_cambiandoBanco && (!sesion.iniciada || sesion.finalizada);
  bool get puedeSeleccionarBanco => !_cerrado && !_cambiandoBanco;
  BancoTrivia get banco => motor.banco;
  SesionTrivia get sesion => motor.sesion;
  Future<void> get guardadoPendiente => _cola;
  bool _sincronizar() {
    final fase = sesion.fase;
    if (_reloj.isRunning) {
      final actual = _reloj.elapsedMilliseconds;
      motor.transcurrir(actual - _lectura);
      _lectura = actual;
    }
    return fase != sesion.fase;
  }

  void _reiniciarReloj() {
    _reloj
      ..stop()
      ..reset();
    _lectura = 0;
    _ultimoRespaldo = 0;
    if (sesion.cronometrada && !sesion.pausada) _reloj.start();
  }

  void pulso() {
    if (_cerrado || !sesion.cronometrada || sesion.pausada) return;
    final cambio = _sincronizar();
    if (cambio || _lectura - _ultimoRespaldo >= 5000) {
      _guardar();
      _ultimoRespaldo = _lectura;
    }
    if (!sesion.cronometrada) _reiniciarReloj();
    notifyListeners();
  }

  void accion(void Function(MotorEvaluacion) operar) {
    if (_cambiandoBanco) {
      throw StateError('Esperá a que termine de cargarse el banco.');
    }
    _sincronizar();
    try {
      operar(motor);
    } finally {
      // Incluso una acción rechazada debe conservar un vencimiento recién detectado.
      _reiniciarReloj();
      _guardar();
      notifyListeners();
    }
  }

  void _guardar() {
    // Capturar ahora evita que una escritura pendiente observe un estado futuro.
    final raw = jsonEncode(sesion.toJson());
    _cola = _cola.then((_) async {
      try {
        await repositorio.guardar(raw);
      } on Object {
        aviso = 'La evaluación sigue abierta, pero no se pudo guardar. Descargá un respaldo y reintentá el guardado.';
        if (!_cerrado) notifyListeners();
      }
    });
  }

  void pausar() {
    if (!sesion.cronometrada || sesion.pausada) return;
    accion((m) => m.pausar());
  }

  void reintentar() {
    aviso = null;
    _guardar();
    notifyListeners();
  }

  void restaurar(SesionTrivia nueva) {
    if (_cambiandoBanco) {
      throw StateError('Esperá a que termine de cargarse el banco.');
    }
    nueva.validar(banco);
    if (nueva.cronometrada) nueva.pausada = true;
    motor = MotorEvaluacion(banco, nueva);
    _reiniciarReloj();
    _guardar();
    notifyListeners();
  }

  void importar(String raw) => restaurar(
    SesionTrivia.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
      banco,
      recuperar: true,
    ),
  );
  void nuevaSesion() {
    if (_cambiandoBanco) {
      throw StateError('Esperá a que termine de cargarse el banco.');
    }
    _sincronizar();
    _guardar();
    final alumnos = sesion.alumnos
        .map(
          (a) => AlumnoTrivia(
            id: a.id,
            apellido: a.apellido,
            nombre: a.nombre,
            presente: true,
          ),
        )
        .toList();
    final nueva = SesionTrivia(
      id: 'IV_${DateTime.now().microsecondsSinceEpoch}',
      fecha: DateTime.now().toUtc(),
      huellaBanco: banco.huella,
      alumnos: alumnos,
      configuracion: sesion.configuracion,
    );
    motor = MotorEvaluacion(banco, nueva);
    _reiniciarReloj();
    _guardar();
    notifyListeners();
  }

  Future<void> cambiarBanco(
    BancoTrivia nuevo, {
    bool crearNuevaEvaluacion = false,
  }) async {
    if (!puedeSeleccionarBanco ||
        (!puedeCambiarBanco && !crearNuevaEvaluacion)) {
      throw StateError(
        'Creá una nueva evaluación antes de cambiar el banco de preguntas.',
      );
    }
    if (nuevo.preguntas.length < sesion.alumnos.length * 10) {
      throw StateError(
        'Se necesitan al menos ${sesion.alumnos.length * 10} preguntas para los ${sesion.alumnos.length} estudiantes registrados.',
      );
    }
    if (crearNuevaEvaluacion) {
      pausar();
    }
    final anterior = jsonEncode(sesion.toJson());
    final conservarAnterior = sesion.iniciada && !sesion.finalizada;
    _cambiandoBanco = true;
    notifyListeners();
    try {
      final nueva = SesionTrivia(
        id: 'IV_${DateTime.now().microsecondsSinceEpoch}',
        fecha: DateTime.now().toUtc(),
        huellaBanco: nuevo.huella,
        bancoPersonalizado: nuevo.personalizado ? nuevo.raw : null,
        configuracion: sesion.configuracion,
        alumnos: [
          for (final a in sesion.alumnos)
            AlumnoTrivia(
              id: a.id,
              apellido: a.apellido,
              nombre: a.nombre,
              presente: a.presente,
            ),
        ],
      );
      nueva.validar(nuevo);
      final operacion = _cola.then((_) async {
        if (conservarAnterior) await repositorio.guardar(anterior);
        await repositorio.guardar(jsonEncode(nueva.toJson()));
      });
      _cola = operacion.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
      await operacion;
      if (_cerrado) return;
      motor = MotorEvaluacion(nuevo, nueva);
      aviso = null;
      _reiniciarReloj();
    } finally {
      _cambiandoBanco = false;
      if (!_cerrado) notifyListeners();
    }
  }

  Future<void> cambiarEstudiantes(
    List<AlumnoTrivia> alumnos, {
    bool crearNuevaEvaluacion = false,
  }) async {
    if (!puedeSeleccionarBanco || (sesion.iniciada && !crearNuevaEvaluacion)) {
      throw StateError(
        'Creá una nueva evaluación antes de reemplazar los estudiantes.',
      );
    }
    final copia = EstudiantesJson.importar(
      jsonEncode(alumnos.map((a) => a.toJson()).toList()),
    );
    if (banco.preguntas.length < copia.length * 10) {
      throw StateError(
        'Se necesitan al menos ${copia.length * 10} preguntas para los ${copia.length} estudiantes registrados.',
      );
    }
    final nueva = SesionTrivia(
      id: 'IV_${DateTime.now().microsecondsSinceEpoch}',
      fecha: DateTime.now().toUtc(),
      huellaBanco: banco.huella,
      bancoPersonalizado: banco.personalizado ? banco.raw : null,
      configuracion: sesion.configuracion,
      alumnos: copia,
    );
    nueva.validar(banco);
    pausar();
    final anterior = jsonEncode(sesion.toJson());
    final conservarAnterior = sesion.iniciada;
    _cambiandoBanco = true;
    notifyListeners();
    try {
      final operacion = _cola.then((_) async {
        if (conservarAnterior) await repositorio.guardar(anterior);
        await repositorio.guardar(jsonEncode(nueva.toJson()));
      });
      _cola = operacion.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
      await operacion;
      if (_cerrado) return;
      motor = MotorEvaluacion(banco, nueva);
      aviso = null;
      _reiniciarReloj();
    } finally {
      _cambiandoBanco = false;
      if (!_cerrado) notifyListeners();
    }
  }

  Future<void> configurar(ConfiguracionEvaluacion nueva) async {
    if (_cerrado || _cambiandoBanco) {
      throw StateError('Esperá a que termine la operación actual.');
    }
    nueva = ConfiguracionEvaluacion.fromJson(nueva.toJson());
    pausar();
    _cambiandoBanco = true;
    notifyListeners();
    try {
      final json = sesion.toJson()..['configuracion'] = nueva.toJson();
      final operacion = _cola.then(
        (_) => repositorio.guardar(jsonEncode(json)),
      );
      _cola = operacion.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
      await operacion;
      sesion.configuracion = nueva;
    } finally {
      _cambiandoBanco = false;
      if (!_cerrado) notifyListeners();
    }
  }

  @override
  void dispose() {
    _sincronizar();
    motor.pausar();
    _guardar();
    _cerrado = true;
    _timer?.cancel();
    _reloj.stop();
    super.dispose();
  }
}

String csvResultados(SesionTrivia s) {
  String celda(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
  final filas = <List<Object?>>[
    [
      'Apellido',
      'Nombre',
      'Asistencia',
      'Respuestas correctas',
      'Robos correctos',
      'Puntos',
      'Nota sobre 10',
      'Resultado',
      'Evaluación',
    ],
    for (final a in s.alumnos)
      [
        a.apellido,
        a.nombre,
        a.presente ? 'Presente' : 'Ausente',
        s.resultado(a.id).propias,
        s.resultado(a.id).robos,
        s.resultado(a.id).puntos,
        a.presente ? s.resultado(a.id).nota : '',
        !a.presente
            ? 'AUSENTE'
            : !s.finalizada
            ? 'EN CURSO'
            : s.resultado(a.id).aprobado
            ? 'APROBADO'
            : 'NO APROBADO',
        s.finalizada ? 'Finalizada' : 'Parcial',
      ],
  ];
  return '\uFEFF${filas.map((f) => f.map(celda).join(';')).join('\r\n')}';
}
