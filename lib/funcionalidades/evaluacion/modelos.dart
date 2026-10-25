import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'configuracion.dart';

const temasTrivia = [
  'Roma',
  'Grecia',
  'China',
  'India',
  'Mesopotamia',
  'Egipto',
  'Persia',
  'Siria y Levante',
];

class PreguntaTrivia {
  PreguntaTrivia.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      tema = j['theme'] as String,
      subtema = j['subtheme'] as String,
      tipo = j['type'] as String,
      texto = j['text'] as String,
      opciones = List.unmodifiable((j['options'] as List).cast<String>()),
      correcta = j['answer'] as int,
      explicacion = j['explanation'] as String;
  final String id, tema, subtema, tipo, texto, explicacion;
  final List<String> opciones;
  final int correcta;
}

class BancoTrivia {
  BancoTrivia.desdeTexto(String raw)
    : this._(raw, jsonDecode(raw) as List, false, 'Unidad IV');

  factory BancoTrivia.importar(String raw) {
    if (utf8.encode(raw).length > 2 * 1024 * 1024) {
      throw const FormatException('El archivo JSON no puede superar 2 MB.');
    }
    try {
      final contenido = jsonDecode(
        raw.startsWith('\uFEFF') ? raw.substring(1) : raw,
      );
      final List lista;
      var nombre = 'Banco personalizado';
      if (contenido is List) {
        lista = contenido;
      } else if (contenido is Map &&
          contenido['formato'] == 'banco-trivia' &&
          contenido['version'] == 1 &&
          contenido['preguntas'] is List) {
        lista = contenido['preguntas'] as List;
        if (contenido['nombre'] is! String ||
            (contenido['nombre'] as String).trim().isEmpty ||
            (contenido['nombre'] as String).length > 120) {
          throw const FormatException(
            'Indicá un nombre de banco de hasta 120 caracteres.',
          );
        }
        nombre = (contenido['nombre'] as String).trim().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
      } else {
        throw const FormatException(
          'Usá la plantilla JSON del banco de preguntas.',
        );
      }
      final normalizadas = <Map<String, dynamic>>[];
      for (var i = 0; i < lista.length; i++) {
        if (lista[i] is! Map) {
          throw FormatException(
            'La pregunta ${i + 1} no tiene un formato válido.',
          );
        }
        final p = Map<String, dynamic>.from(lista[i] as Map);
        if (p.containsKey('pregunta')) {
          final letra = p['correcta'];
          if (letra is! String ||
              !RegExp(r'^[ABCD]$').hasMatch(letra.trim().toUpperCase())) {
            throw FormatException(
              'En la pregunta ${i + 1}, correcta debe ser A, B, C o D.',
            );
          }
          normalizadas.add({
            'id': p['id'],
            'theme': p['tema'],
            'subtheme': p['subtema'] ?? p['tema'],
            'type': p['tipo'] ?? 'General',
            'text': p['pregunta'],
            'options': p['opciones'],
            'answer': 'ABCD'.indexOf(letra.trim().toUpperCase()),
            'explanation': p['explicacion'],
          });
        } else {
          normalizadas.add(p);
        }
      }
      return BancoTrivia._(raw, normalizadas, true, nombre);
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException(
        'Revisá los campos de cada pregunta: tema, enunciado, cuatro opciones, respuesta y explicación.',
      );
    }
  }

  BancoTrivia._(this.raw, List lista, this.personalizado, this.nombre)
    : huella = sha256.convert(utf8.encode(raw)).toString(),
      preguntas = List.unmodifiable(
        lista.map(
          (j) => PreguntaTrivia.fromJson(Map<String, dynamic>.from(j as Map)),
        ),
      ) {
    porId = Map.unmodifiable({for (final p in preguntas) p.id: p});
    const cantidades = {
      'Roma': 40,
      'Grecia': 30,
      'China': 30,
      'India': 30,
      'Mesopotamia': 25,
      'Egipto': 20,
      'Persia': 12,
      'Siria y Levante': 13,
    };
    if ((!personalizado && preguntas.length != 200) ||
        (personalizado && (preguntas.length < 10 || preguntas.length > 2000)) ||
        porId.length != preguntas.length ||
        preguntas.map((p) => p.texto.trim()).toSet().length !=
            preguntas.length) {
      throw const FormatException(
        'El banco debe contener preguntas únicas, con IDs distintos; se admiten entre 10 y 2000 preguntas.',
      );
    }
    for (final p in preguntas) {
      if (p.id.isEmpty ||
          (personalizado && !RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(p.id)) ||
          p.tema.trim().isEmpty ||
          p.tema.length > 120 ||
          p.subtema.length > 200 ||
          p.tipo.length > 160 ||
          p.texto.trim().isEmpty ||
          p.texto.length > 12000 ||
          p.explicacion.length > 12000 ||
          p.explicacion.trim().isEmpty ||
          p.opciones.length != 4 ||
          p.opciones.toSet().length != 4 ||
          p.opciones.map((o) => o.trim()).toSet().length != 4 ||
          p.opciones.any((o) => o.trim().isEmpty || o.length > 6000) ||
          p.correcta < 0 ||
          p.correcta > 3 ||
          (!personalizado && !cantidades.containsKey(p.tema))) {
        throw FormatException('Pregunta inválida: ${p.id}.');
      }
    }
    for (final e
        in personalizado ? <MapEntry<String, int>>[] : cantidades.entries) {
      if (preguntas.where((p) => p.tema == e.key).length != e.value) {
        throw FormatException('Distribución inesperada: ${e.key}.');
      }
    }
  }
  final String huella, raw, nombre;
  final bool personalizado;
  final List<PreguntaTrivia> preguntas;
  late final Map<String, PreguntaTrivia> porId;
  List<String> get temas =>
      List.unmodifiable(preguntas.map((p) => p.tema).toSet());
  String plantillaJson() => const JsonEncoder.withIndent('  ').convert({
    'formato': 'banco-trivia',
    'version': 1,
    'nombre': personalizado ? nombre : 'Mi banco de preguntas',
    'preguntas': [
      for (final p in preguntas)
        {
          'id': p.id,
          'tema': p.tema,
          'subtema': p.subtema,
          'tipo': p.tipo,
          'pregunta': p.texto,
          'opciones': p.opciones,
          'correcta': 'ABCD'[p.correcta],
          'explicacion': p.explicacion,
        },
    ],
  });
}

class AlumnoTrivia {
  AlumnoTrivia({
    required this.id,
    required this.apellido,
    required this.nombre,
    this.presente = true,
  });
  final String id;
  String apellido, nombre;
  bool presente;
  String get completo => '$apellido, $nombre';
  Map<String, dynamic> toJson() => {
    'id': id,
    'apellido': apellido,
    'nombre': nombre,
    'presente': presente,
  };
  factory AlumnoTrivia.fromJson(Map<String, dynamic> j) => AlumnoTrivia(
    id: j['id'] as String,
    apellido: j['apellido'] as String,
    nombre: j['nombre'] as String,
    presente: j['presente'] as bool,
  );
}

enum EstadoIntento {
  respondido,
  sinRespuesta,
  agotado,
  cancelado,
  noPresentada,
}

enum EstadoPregunta { pendiente, activa, robo, cerrada }

enum FaseEvaluacion {
  preparacion,
  entreTurnos,
  titular,
  esperaRobo,
  robo,
  revision,
  finalizada,
}

class IntentoTrivia {
  const IntentoTrivia({
    required this.alumnoId,
    required this.opcion,
    required this.estado,
    required this.correcto,
    required this.tiempoMs,
    required this.fecha,
    this.puntos,
  });
  final String alumnoId;
  final int? puntos;
  final int? opcion;
  final EstadoIntento estado;
  final bool correcto;
  final int tiempoMs;
  final DateTime fecha;
  Map<String, dynamic> toJson() => {
    'alumno': alumnoId,
    'opcionMostrada': opcion,
    'estado': estado.name,
    'correcto': correcto,
    'puntos': puntos,
    'tiempoMs': tiempoMs,
    'fecha': fecha.toUtc().toIso8601String(),
  };
  factory IntentoTrivia.fromJson(Map<String, dynamic> j) => IntentoTrivia(
    alumnoId: j['alumno'] as String,
    opcion: j['opcionMostrada'] as int?,
    estado: EstadoIntento.values.byName(j['estado'] as String),
    correcto: j['correcto'] as bool,
    puntos: j['puntos'] as int?,
    tiempoMs: j['tiempoMs'] as int,
    fecha: DateTime.parse(j['fecha'] as String),
  );
}

class RegistroTrivia {
  RegistroTrivia({
    required this.preguntaId,
    required this.titularId,
    required List<int> orden,
    this.estado = EstadoPregunta.pendiente,
    this.propio,
    List<IntentoTrivia>? robos,
  }) : orden = List.unmodifiable(orden),
       robos = robos ?? [];
  final String preguntaId, titularId;
  final List<int> orden;
  EstadoPregunta estado;
  IntentoTrivia? propio;
  final List<IntentoTrivia> robos;
  int get robosRealizados =>
      robos.where((i) => i.estado != EstadoIntento.cancelado).length;
  Set<int> get opcionesUsadas => {
    if (propio?.opcion != null) propio!.opcion!,
    for (final intento in robos)
      if (intento.opcion != null && intento.estado != EstadoIntento.cancelado)
        intento.opcion!,
  };
  int indiceCorrecto(BancoTrivia b) =>
      orden.indexOf(b.porId[preguntaId]!.correcta);
  Map<String, dynamic> toJson() => {
    'pregunta': preguntaId,
    'titular': titularId,
    'ordenOpciones': orden,
    'estado': estado.name,
    'propio': propio?.toJson(),
    'robos': robos.map((a) => a.toJson()).toList(),
  };
  factory RegistroTrivia.fromJson(Map<String, dynamic> j) => RegistroTrivia(
    preguntaId: j['pregunta'] as String,
    titularId: j['titular'] as String,
    orden: (j['ordenOpciones'] as List).cast<int>(),
    estado: EstadoPregunta.values.byName(j['estado'] as String),
    propio: j['propio'] == null
        ? null
        : IntentoTrivia.fromJson(Map<String, dynamic>.from(j['propio'] as Map)),
    robos: (j['robos'] as List)
        .map((v) => IntentoTrivia.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList(),
  );
}

class ResultadoAlumno {
  ResultadoAlumno(this.alumno, this.registros, this.participaciones);
  final AlumnoTrivia alumno;
  final List<RegistroTrivia> registros;
  final List<({RegistroTrivia registro, IntentoTrivia intento})>
  participaciones;
  int get propias => registros.where((r) => r.propio?.correcto == true).length;
  int get robos => participaciones.where((r) => r.intento.correcto).length;
  int get puntos => min(
    10,
    registros.fold<int>(
          0,
          (n, r) =>
              n + (r.propio?.correcto == true ? r.propio!.puntos ?? 1 : 0),
        ) +
        participaciones.fold<int>(
          0,
          (n, r) => n + (r.intento.correcto ? r.intento.puntos ?? 2 : 0),
        ),
  );
  int get nota => min(10, puntos);
  bool get aprobado => puntos >= 7;
  int get cerradas =>
      registros.where((r) => r.estado == EstadoPregunta.cerrada).length;
  int get presentadas => registros
      .where(
        (r) =>
            r.propio != null && r.propio!.estado != EstadoIntento.noPresentada,
      )
      .length;
}

class SesionTrivia {
  SesionTrivia({
    required this.id,
    required this.fecha,
    required this.huellaBanco,
    required this.alumnos,
    this.bancoPersonalizado,
    this.configuracion = const ConfiguracionEvaluacion(),
  });
  final String id, huellaBanco;
  String? bancoPersonalizado;
  ConfiguracionEvaluacion configuracion;
  final DateTime fecha;
  final List<AlumnoTrivia> alumnos;
  Map<String, List<String>> paquetes = {};
  Map<String, RegistroTrivia> registros = {};
  List<List<String>> reservas = [];
  FaseEvaluacion fase = FaseEvaluacion.preparacion;
  String? actualId, ladronId;
  final Set<String> finalizados = {};
  final Set<String> aprobacionConsultada = {};
  String? avisoPuntajeId;
  bool terminoAlumno(String id) =>
      finalizados.contains(id) || resultado(id).puntos >= 10;

  int puntosOtorgados(IntentoTrivia intento) {
    if (!intento.correcto) return 0;
    if (intento.puntos != null) return intento.puntos!;
    // Los respaldos anteriores no guardaban el valor de cada acierto.
    final anteriores = <({IntentoTrivia intento, int valor})>[
      for (final r in registros.values) ...[
        if (r.propio?.alumnoId == intento.alumnoId && r.propio!.correcto)
          (intento: r.propio!, valor: 1),
        for (final a in r.robos)
          if (a.alumnoId == intento.alumnoId && a.correcto)
            (intento: a, valor: 2),
      ],
    ]..sort((a, b) => a.intento.fecha.compareTo(b.intento.fecha));
    var total = 0;
    for (final a in anteriores) {
      final valor = min(10 - total, a.intento.puntos ?? a.valor);
      if (identical(a.intento, intento)) return valor;
      total += valor;
    }
    return 0;
  }

  bool pausada = false, cierreAnticipado = false;
  int restanteMs = 60000;
  List<String> ultimos = [];
  List<Map<String, String>> eventos = [];
  String mensaje = '';
  bool get iniciada => fase != FaseEvaluacion.preparacion;
  bool get finalizada => fase == FaseEvaluacion.finalizada;
  bool get cronometrada => fase == FaseEvaluacion.titular;
  bool get aceptaRespuesta =>
      (cronometrada && !pausada) || fase == FaseEvaluacion.robo;
  bool get tiempoSinIniciar => cronometrada && pausada && restanteMs == 60000;
  RegistroTrivia? get actual => registros[actualId];
  AlumnoTrivia alumno(String id) => alumnos.firstWhere((a) => a.id == id);
  ResultadoAlumno resultado(String id) => ResultadoAlumno(
    alumno(id),
    registros.values.where((r) => r.titularId == id).toList(),
    [
      for (final r in registros.values)
        for (final a in r.robos)
          if (a.alumnoId == id) (registro: r, intento: a),
    ],
  );
  List<AlumnoTrivia> get habilitadosRobo {
    if ((actual?.robosRealizados ?? 0) >= 2) return [];
    return _candidatosRobo;
  }

  // La validación del formato v1 admite registros históricos anteriores al
  // límite. La disponibilidad de nuevos intentos se calcula por separado.
  List<AlumnoTrivia> get _candidatosRobo {
    final r = actual;
    if (r == null) return [];
    final intentaron = r.robos
        .where((a) => a.estado != EstadoIntento.cancelado)
        .map((a) => a.alumnoId)
        .toSet();
    return alumnos
        .where(
          (a) =>
              a.presente &&
              !terminoAlumno(a.id) &&
              a.id != r.titularId &&
              !intentaron.contains(a.id),
        )
        .toList();
  }

  Map<String, dynamic> toJson() => {
    'formato': 'trivia-antiguedad-evaluacion',
    'version': 1,
    'id': id,
    'fecha': fecha.toUtc().toIso8601String(),
    'banco': huellaBanco,
    'configuracion': configuracion.toJson(),
    if (bancoPersonalizado != null) 'bancoPersonalizado': bancoPersonalizado,
    'alumnos': alumnos.map((a) => a.toJson()).toList(),
    'paquetes': paquetes,
    'reservas': reservas,
    'preguntas': registros.map((k, v) => MapEntry(k, v.toJson())),
    'fase': fase.name,
    'actual': actualId,
    'ladron': ladronId,
    'pausada': pausada,
    'restanteMs': restanteMs,
    'ultimos': ultimos,
    'eventos': eventos,
    'mensaje': mensaje,
    'cierreAnticipado': cierreAnticipado,
    'finalizados': finalizados.toList(),
    'aprobacionConsultada': aprobacionConsultada.toList(),
    'avisoPuntaje': avisoPuntajeId,
  };
  factory SesionTrivia.fromJson(
    Map<String, dynamic> j,
    BancoTrivia banco, {
    bool recuperar = false,
  }) {
    if (j['formato'] != 'trivia-antiguedad-evaluacion' ||
        j['version'] != 1 ||
        j['banco'] != banco.huella) {
      throw const FormatException(
        'El respaldo no pertenece a esta edición de la trivia.',
      );
    }
    final s = SesionTrivia(
      id: j['id'] as String,
      fecha: DateTime.parse(j['fecha'] as String),
      huellaBanco: j['banco'] as String,
      bancoPersonalizado: banco.personalizado ? banco.raw : null,
      configuracion: j['configuracion'] == null
          ? const ConfiguracionEvaluacion()
          : ConfiguracionEvaluacion.fromJson(
              Map<String, dynamic>.from(j['configuracion'] as Map),
            ),
      alumnos: (j['alumnos'] as List)
          .map(
            (v) => AlumnoTrivia.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList(),
    );
    s.paquetes = (j['paquetes'] as Map).map(
      (k, v) => MapEntry(k as String, (v as List).cast<String>()),
    );
    s.reservas = (j['reservas'] as List)
        .map((v) => (v as List).cast<String>())
        .toList();
    s.registros = (j['preguntas'] as Map).map(
      (k, v) => MapEntry(
        k as String,
        RegistroTrivia.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
    );
    s.fase = FaseEvaluacion.values.byName(j['fase'] as String);
    s.actualId = j['actual'] as String?;
    s.ladronId = j['ladron'] as String?;
    s.pausada = j['pausada'] as bool;
    s.restanteMs = j['restanteMs'] as int;
    if (s.fase == FaseEvaluacion.robo) s.pausada = false;
    s.ultimos = (j['ultimos'] as List).cast<String>();
    s.eventos = (j['eventos'] as List)
        .map((v) => Map<String, String>.from(v as Map))
        .toList();
    s.mensaje = j['mensaje'] as String;
    s.cierreAnticipado = j['cierreAnticipado'] as bool;
    s.finalizados.addAll((j['finalizados'] as List? ?? []).cast<String>());
    s.aprobacionConsultada.addAll(
      (j['aprobacionConsultada'] as List? ?? []).cast<String>(),
    );
    s.avisoPuntajeId = j['avisoPuntaje'] as String?;
    s.validar(banco);
    if (recuperar &&
        s.fase == FaseEvaluacion.titular &&
        s.terminoAlumno(s.actual!.titularId)) {
      s.actual!.estado = EstadoPregunta.pendiente;
      s.actualId = null;
      s.fase = FaseEvaluacion.entreTurnos;
      s.pausada = false;
    }
    if (recuperar &&
        s.fase == FaseEvaluacion.robo &&
        s.terminoAlumno(s.ladronId!)) {
      s.ladronId = null;
      s.fase = FaseEvaluacion.esperaRobo;
    }
    if (recuperar &&
        (((s.actual?.robosRealizados ?? 0) >= 2 &&
                (s.fase == FaseEvaluacion.robo ||
                    s.fase == FaseEvaluacion.esperaRobo)) ||
            (s.fase == FaseEvaluacion.esperaRobo &&
                s.habilitadosRobo.isEmpty))) {
      s.actual!.estado = EstadoPregunta.cerrada;
      s.fase = FaseEvaluacion.revision;
      s.ladronId = null;
      s.pausada = false;
    }
    if (recuperar && s.cronometrada) {
      s.pausada = true;
      s.mensaje = 'Sesión recuperada. El tiempo está pausado; reanudalo cuando estén listos.';
    }
    return s;
  }
  void validar(BancoTrivia banco) {
    Never error() =>
        throw const FormatException('La sesión contiene datos inconsistentes.');
    final ids = alumnos.map((a) => a.id).toSet();
    if (!ids.containsAll(finalizados) ||
        !ids.containsAll(aprobacionConsultada) ||
        (avisoPuntajeId != null &&
            (!ids.contains(avisoPuntajeId) ||
                resultado(avisoPuntajeId!).puntos < 7))) {
      error();
    }
    if (id.isEmpty ||
        id.length > 64 ||
        huellaBanco != banco.huella ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id) ||
        alumnos.isEmpty ||
        alumnos.length > 20 ||
        ids.length != alumnos.length ||
        restanteMs < 0 ||
        restanteMs > 60000 ||
        alumnos.any(
          (a) =>
              !RegExp(r'^[a-zA-Z0-9_-]{1,24}$').hasMatch(a.id) ||
              a.apellido.trim().isEmpty ||
              a.nombre.trim().isEmpty ||
              a.apellido.length > 120 ||
              a.nombre.length > 120,
        ) ||
        eventos.length > 10000 ||
        ultimos.any((id) => !ids.contains(id))) {
      error();
    }
    if (!iniciada) {
      if (paquetes.isNotEmpty ||
          registros.isNotEmpty ||
          reservas.isNotEmpty ||
          actualId != null ||
          ladronId != null) {
        error();
      }
      return;
    }
    if (paquetes.keys.toSet().difference(ids).isNotEmpty ||
        paquetes.length != alumnos.length ||
        paquetes.values.any((p) => p.length != 10) ||
        reservas.any(
          (p) =>
              p.isEmpty ||
              p.length > 10 ||
              (!banco.personalizado && p.length != 10),
        )) {
      error();
    }
    final todos = [
      ...paquetes.values.expand((v) => v),
      ...reservas.expand((v) => v),
    ];
    if (todos.length != banco.preguntas.length ||
        todos.toSet().length != banco.preguntas.length ||
        todos.any((id) => !banco.porId.containsKey(id)) ||
        registros.length != alumnos.length * 10) {
      error();
    }
    for (final e in paquetes.entries) {
      for (final id in e.value) {
        if (registros[id]?.titularId != e.key ||
            registros[id]?.preguntaId != id) {
          error();
        }
      }
    }
    for (final r in registros.values) {
      if (!banco.porId.containsKey(r.preguntaId) ||
          !ids.contains(r.titularId) ||
          r.orden.length != 4 ||
          r.orden.toSet().length != 4 ||
          r.orden.any((i) => i < 0 || i > 3)) {
        error();
      }
      final intentados = <String>{};
      for (final a in [?r.propio, ...r.robos]) {
        if (!ids.contains(a.alumnoId) ||
            (a.puntos != null &&
                (a.puntos! < 0 ||
                    a.puntos! > (identical(a, r.propio) ? 1 : 2) ||
                    (!a.correcto && a.puntos != 0))) ||
            a.tiempoMs < 0 ||
            a.tiempoMs > 60000 ||
            (a.opcion != null && (a.opcion! < 0 || a.opcion! > 3)) ||
            (a.estado == EstadoIntento.respondido) != (a.opcion != null) ||
            a.correcto !=
                (a.estado == EstadoIntento.respondido &&
                    a.opcion == r.indiceCorrecto(banco))) {
          error();
        }
      }
      if (r.propio != null && r.propio!.alumnoId != r.titularId) error();
      if (r.propio?.estado == EstadoIntento.cancelado) error();
      if (r.propio?.estado == EstadoIntento.noPresentada &&
          (r.estado != EstadoPregunta.cerrada || r.propio!.tiempoMs != 0)) {
        error();
      }
      if (r.robos.isNotEmpty &&
          (r.propio == null ||
              r.propio!.correcto ||
              r.propio!.estado == EstadoIntento.noPresentada)) {
        error();
      }
      for (final a in r.robos) {
        if (intentados.contains(a.alumnoId)) error();
        if (a.alumnoId == r.titularId ||
            a.estado == EstadoIntento.noPresentada) {
          error();
        }
        if (a.estado != EstadoIntento.cancelado &&
            !intentados.add(a.alumnoId)) {
          error();
        }
      }
      if (r.estado == EstadoPregunta.pendiente &&
          (r.propio != null || r.robos.isNotEmpty)) {
        error();
      }
      if (r.estado == EstadoPregunta.cerrada && r.propio == null) error();
      if (r.propio?.correcto == true &&
          (r.estado != EstadoPregunta.cerrada || r.robos.isNotEmpty)) {
        error();
      }
      if (r.robos.where((a) => a.correcto).length > 1) error();
      if (r.robos.any((a) => a.correcto) &&
          (!r.robos.last.correcto || r.estado != EstadoPregunta.cerrada)) {
        error();
      }
      if (r.estado == EstadoPregunta.activa &&
          (r.preguntaId != actualId || fase != FaseEvaluacion.titular)) {
        error();
      }
      if (r.estado == EstadoPregunta.robo &&
          (r.preguntaId != actualId ||
              (fase != FaseEvaluacion.robo &&
                  fase != FaseEvaluacion.esperaRobo))) {
        error();
      }
    }
    if (actualId != null && !registros.containsKey(actualId)) error();
    if (fase == FaseEvaluacion.entreTurnos &&
        (actualId != null || ladronId != null)) {
      error();
    }
    if (fase != FaseEvaluacion.robo && ladronId != null) error();
    if (fase == FaseEvaluacion.robo &&
        !alumnos.any(
          (a) =>
              a.presente &&
              a.id == ladronId &&
              a.id != actual?.titularId &&
              !actual!.robos.any(
                (i) =>
                    i.alumnoId == a.id && i.estado != EstadoIntento.cancelado,
              ),
        )) {
      error();
    }
    if (fase == FaseEvaluacion.titular &&
        actual != null &&
        !alumno(actual!.titularId).presente) {
      error();
    }
    if (cronometrada && (actual == null || restanteMs == 0)) {
      error();
    }
    if (fase == FaseEvaluacion.titular &&
        (actual?.estado != EstadoPregunta.activa || actual?.propio != null)) {
      error();
    }
    if ((fase == FaseEvaluacion.esperaRobo || fase == FaseEvaluacion.robo) &&
        (actual?.estado != EstadoPregunta.robo || actual?.propio == null)) {
      error();
    }
    if (fase == FaseEvaluacion.revision &&
        actual?.estado != EstadoPregunta.cerrada) {
      error();
    }
    if (finalizada &&
        (actualId != null ||
            ladronId != null ||
            registros.values.any((r) => r.estado != EstadoPregunta.cerrada))) {
      error();
    }
  }
}

class MotorEvaluacion {
  MotorEvaluacion(this.banco, this.sesion, {Random? random})
    : random = random ?? Random() {
    sesion.bancoPersonalizado = banco.personalizado ? banco.raw : null;
  }
  final BancoTrivia banco;
  SesionTrivia sesion;
  final Random random;
  final List<Map<String, dynamic>> _deshacer = [];
  bool get puedeDeshacer => _deshacer.isNotEmpty;
  void _guardarPaso() {
    final copia = sesion.toJson()..remove('bancoPersonalizado');
    _deshacer.add(jsonDecode(jsonEncode(copia)) as Map<String, dynamic>);
    if (_deshacer.length > 20) _deshacer.removeAt(0);
  }

  void _evento(String texto) => sesion.eventos.add({
    'fecha': DateTime.now().toUtc().toIso8601String(),
    'accion': texto,
  });
  List<List<String>> _repartir() {
    if (banco.personalizado) return _repartirPersonalizado();
    for (var intento = 0; intento < 500; intento++) {
      final grupos = {
        for (final tema in temasTrivia)
          tema:
              banco.preguntas
                  .where((p) => p.tema == tema)
                  .map((p) => p.id)
                  .toList()
                ..shuffle(random),
      };
      final paquetes = List.generate(20, (_) => <String>[]);
      final extras = List.generate(20, (_) => <String>[]);
      void tomar(String tema, int i) =>
          paquetes[i].add(grupos[tema]!.removeLast());
      for (var i = 0; i < 20; i++) {
        tomar('Roma', i);
        tomar('Roma', i);
        for (final tema in [
          'Grecia',
          'China',
          'India',
          'Mesopotamia',
          'Egipto',
        ]) {
          tomar(tema, i);
        }
        tomar(i.isEven ? 'Persia' : 'Siria y Levante', i);
      }
      final pendientes = [
        for (final e in grupos.entries)
          for (var i = 0; i < e.value.length; i++) e.key,
      ]..shuffle(random);
      final frecuencias = {
        for (final t in temasTrivia) t: pendientes.where((v) => v == t).length,
      };
      pendientes.sort((a, b) => frecuencias[b]!.compareTo(frecuencias[a]!));
      var sirve = true;
      for (final tema in pendientes) {
        var disponibles = [
          for (var i = 0; i < 20; i++)
            if (extras[i].length < 2 && !extras[i].contains(tema)) i,
        ];
        if (disponibles.isEmpty) {
          sirve = false;
          break;
        }
        final minimo = disponibles.map((i) => extras[i].length).reduce(min);
        disponibles =
            disponibles.where((i) => extras[i].length == minimo).toList()
              ..shuffle(random);
        disponibles.sort(
          (a, b) =>
              (paquetes[a].any((id) => banco.porId[id]!.tema == tema) ? 1 : 0)
                  .compareTo(
                    paquetes[b].any((id) => banco.porId[id]!.tema == tema)
                        ? 1
                        : 0,
                  ),
        );
        final i = disponibles.first;
        extras[i].add(tema);
        tomar(tema, i);
      }
      if (sirve && paquetes.every((p) => p.length == 10)) {
        for (final p in paquetes) {
          p.shuffle(random);
        }
        return paquetes..shuffle(random);
      }
    }
    throw StateError('No se pudo construir un reparto equilibrado.');
  }

  List<List<String>> _repartirPersonalizado() {
    final cantidad = banco.preguntas.length;
    final paquetes = List.generate((cantidad / 10).ceil(), (_) => <String>[]);
    final cuotas = List.generate(
      paquetes.length,
      (i) => min(10, cantidad - i * 10),
    );
    final conteos = List.generate(paquetes.length, (_) => <String, int>{});
    final grupos = {
      for (final tema in banco.temas)
        tema: banco.preguntas.where((p) => p.tema == tema).toList()
          ..shuffle(random),
    };
    final temas = grupos.keys.toList()..shuffle(random);
    temas.sort((a, b) => grupos[b]!.length.compareTo(grupos[a]!.length));
    for (final tema in temas) {
      for (final pregunta in grupos[tema]!) {
        final destinos = [
          for (var i = 0; i < paquetes.length; i++)
            if (paquetes[i].length < cuotas[i]) i,
        ]..shuffle(random);
        destinos.sort((a, b) {
          final diversidad = (conteos[a][tema] ?? 0).compareTo(
            conteos[b][tema] ?? 0,
          );
          return diversidad != 0
              ? diversidad
              : paquetes[a].length.compareTo(paquetes[b].length);
        });
        final i = destinos.first;
        paquetes[i].add(pregunta.id);
        conteos[i][tema] = (conteos[i][tema] ?? 0) + 1;
      }
    }
    final completos = paquetes.where((p) => p.length == 10).toList()
      ..shuffle(random);
    for (final p in paquetes) {
      p.shuffle(random);
    }
    return [...completos, ...paquetes.where((p) => p.length < 10)];
  }

  void iniciar() {
    if (sesion.iniciada) return;
    if (banco.preguntas.length < sesion.alumnos.length * 10) {
      throw StateError(
        'Se necesitan ${sesion.alumnos.length * 10} preguntas para reservar diez por cada uno de los ${sesion.alumnos.length} estudiantes registrados. Este banco tiene ${banco.preguntas.length}.',
      );
    }
    if (!sesion.alumnos.any((a) => a.presente)) {
      throw StateError('Marcá al menos un estudiante presente.');
    }
    final paquetes = _repartir();
    for (var i = 0; i < sesion.alumnos.length; i++) {
      final a = sesion.alumnos[i];
      sesion.paquetes[a.id] = paquetes[i];
      for (final id in paquetes[i]) {
        sesion.registros[id] = RegistroTrivia(
          preguntaId: id,
          titularId: a.id,
          orden: [0, 1, 2, 3]..shuffle(random),
        );
      }
    }
    sesion.reservas = paquetes.skip(sesion.alumnos.length).toList();
    sesion.fase = FaseEvaluacion.entreTurnos;
    _evento(
      'Inicio de la evaluación. ${sesion.alumnos.where((a) => a.presente).length} presentes.',
    );
  }

  void siguiente() {
    if (sesion.avisoPuntajeId != null) return;
    if (sesion.fase != FaseEvaluacion.entreTurnos &&
        sesion.fase != FaseEvaluacion.revision) {
      return;
    }
    final disponibles = sesion.alumnos
        .where(
          (a) =>
              a.presente &&
              !sesion.terminoAlumno(a.id) &&
              sesion.paquetes[a.id]!.any(
                (id) =>
                    sesion.registros[id]!.estado == EstadoPregunta.pendiente,
              ),
        )
        .toList();
    if (disponibles.isEmpty) {
      finalizar();
      return;
    }
    _guardarPaso();
    int usados(AlumnoTrivia a) => sesion.paquetes[a.id]!
        .where((id) => sesion.registros[id]!.estado != EstadoPregunta.pendiente)
        .length;
    final minimo = disponibles.map(usados).reduce(min);
    var elegibles = disponibles.where((a) => usados(a) == minimo).toList();
    final recientes = sesion.ultimos.reversed.take(2).toSet();
    final sinRepetir = elegibles
        .where((a) => !recientes.contains(a.id))
        .toList();
    if (sinRepetir.isNotEmpty) elegibles = sinRepetir;
    final alumno = elegibles[random.nextInt(elegibles.length)];
    final preguntas = sesion.paquetes[alumno.id]!
        .where((id) => sesion.registros[id]!.estado == EstadoPregunta.pendiente)
        .toList();
    sesion.actualId = preguntas[random.nextInt(preguntas.length)];
    sesion.actual!.estado = EstadoPregunta.activa;
    sesion.fase = FaseEvaluacion.titular;
    sesion.pausada = true;
    sesion.restanteMs = 60000;
    sesion.ladronId = null;
    sesion.ultimos.add(alumno.id);
    if (sesion.ultimos.length > 5) sesion.ultimos.removeAt(0);
    sesion.mensaje = '';
    _evento('Turno de ${alumno.completo}. ${sesion.actualId}.');
  }

  void transcurrir(int ms) {
    if (!sesion.cronometrada || sesion.pausada || ms <= 0) return;
    sesion.restanteMs = max(0, sesion.restanteMs - ms);
    if (sesion.restanteMs == 0) _terminarIntento(null, EstadoIntento.agotado);
  }

  void pausar() {
    if (!sesion.cronometrada || sesion.pausada) return;
    sesion.pausada = true;
    _evento('Tiempo pausado.');
  }

  void reanudar() {
    if (!sesion.cronometrada || !sesion.pausada) return;
    sesion.pausada = false;
    _evento(
      sesion.restanteMs == 60000
          ? 'Comienza el tiempo de respuesta.'
          : 'Tiempo reanudado.',
    );
  }

  void responder(int opcion) {
    if (!sesion.aceptaRespuesta) return;
    if (opcion < 0 || opcion > 3) throw ArgumentError('Alternativa inválida.');
    if (sesion.fase == FaseEvaluacion.robo &&
        sesion.actual!.opcionesUsadas.contains(opcion)) {
      throw StateError('Esta alternativa ya fue elegida.');
    }
    if (sesion.cronometrada && sesion.restanteMs <= 0) {
      _terminarIntento(null, EstadoIntento.agotado);
      return;
    }
    _guardarPaso();
    _terminarIntento(opcion, EstadoIntento.respondido);
  }

  void sinRespuesta() {
    if (!sesion.aceptaRespuesta) return;
    _guardarPaso();
    _terminarIntento(null, EstadoIntento.sinRespuesta);
  }

  void _terminarIntento(int? opcion, EstadoIntento estado) {
    final r = sesion.actual!;
    final esRobo = sesion.fase == FaseEvaluacion.robo;
    final actor = esRobo ? sesion.ladronId! : r.titularId;
    final acierto =
        estado == EstadoIntento.respondido && opcion == r.indiceCorrecto(banco);
    final anteriores = sesion.resultado(actor).puntos;
    final puntos = acierto ? min(esRobo ? 2 : 1, 10 - anteriores) : 0;
    final intento = IntentoTrivia(
      alumnoId: actor,
      opcion: opcion,
      estado: estado,
      correcto: acierto,
      puntos: puntos,
      tiempoMs: esRobo ? 0 : 60000 - sesion.restanteMs,
      fecha: DateTime.now().toUtc(),
    );
    if (esRobo) {
      r.robos.add(intento);
    } else {
      r.propio = intento;
    }
    if (acierto) {
      r.estado = EstadoPregunta.cerrada;
      sesion.fase = FaseEvaluacion.revision;
      sesion.mensaje =
          '${esRobo ? 'Robo correcto' : 'Respuesta correcta'}: +$puntos ${puntos == 1 ? 'punto' : 'puntos'}.';
      final total = sesion.resultado(actor).puntos;
      if (total >= 10) {
        sesion.finalizados.add(actor);
        sesion.avisoPuntajeId = actor;
      } else if (anteriores < 7 &&
          total >= 7 &&
          !sesion.aprobacionConsultada.contains(actor)) {
        sesion.avisoPuntajeId = actor;
      }
    } else if ((esRobo && r.robosRealizados >= 2) ||
        sesion.habilitadosRobo.isEmpty) {
      r.estado = EstadoPregunta.cerrada;
      sesion.fase = FaseEvaluacion.revision;
      sesion.mensaje = 'Respuesta incorrecta.';
    } else {
      r.estado = EstadoPregunta.robo;
      sesion.fase = FaseEvaluacion.esperaRobo;
      sesion.mensaje = switch (estado) {
        EstadoIntento.agotado => 'Se agotó el tiempo. Se abre el robo.',
        EstadoIntento.sinRespuesta => 'Sin respuesta. Se abre el robo.',
        _ =>
          esRobo
              ? 'Robo incorrecto. No se descuentan puntos.'
              : 'Respuesta incorrecta. Se abre el robo.',
      };
    }
    sesion.ladronId = null;
    sesion.pausada = false;
    _evento(
      '${esRobo ? 'Robo' : 'Respuesta'} · ${sesion.alumno(actor).completo} · ${r.preguntaId} · ${estado.name} · ${acierto ? 'correcta' : 'sin puntos'}.',
    );
  }

  void iniciarRobo(String id) {
    if (sesion.avisoPuntajeId != null) return;
    if (sesion.fase != FaseEvaluacion.esperaRobo) return;
    if (sesion.actual!.robosRealizados >= 2) {
      throw StateError('Esta pregunta ya completó los intentos de robo.');
    }
    if (!sesion.habilitadosRobo.any((a) => a.id == id)) {
      throw StateError('Este estudiante no puede realizar el robo.');
    }
    _guardarPaso();
    sesion.ladronId = id;
    sesion.fase = FaseEvaluacion.robo;
    sesion.pausada = false;
    sesion.mensaje = 'Intento de robo en curso.';
    _evento('Comienza el robo de ${sesion.alumno(id).completo}.');
  }

  void cerrarPregunta() {
    if (sesion.fase != FaseEvaluacion.esperaRobo &&
        sesion.fase != FaseEvaluacion.robo) {
      return;
    }
    _guardarPaso();
    if (sesion.fase == FaseEvaluacion.robo) {
      _terminarIntento(null, EstadoIntento.sinRespuesta);
    }
    sesion.actual!.estado = EstadoPregunta.cerrada;
    sesion.fase = FaseEvaluacion.revision;
    sesion.ladronId = null;
    sesion.mensaje = 'Pregunta cerrada sin más intentos de robo.';
    _evento(sesion.mensaje);
  }

  void asistencia(String id, bool presente) {
    final a = sesion.alumno(id);
    if (a.presente == presente) return;
    a.presente = presente;
    if (!presente &&
        (sesion.cronometrada || sesion.fase == FaseEvaluacion.robo) &&
        sesion.actual != null) {
      if (sesion.fase == FaseEvaluacion.titular &&
          sesion.actual!.titularId == id) {
        sesion.actual!.estado = EstadoPregunta.pendiente;
        sesion.actualId = null;
        sesion.fase = FaseEvaluacion.entreTurnos;
        sesion.mensaje = 'Turno suspendido por corrección de asistencia.';
      } else if (sesion.fase == FaseEvaluacion.robo && sesion.ladronId == id) {
        sesion.actual!.robos.add(
          IntentoTrivia(
            alumnoId: id,
            opcion: null,
            estado: EstadoIntento.cancelado,
            correcto: false,
            tiempoMs: 0,
            fecha: DateTime.now().toUtc(),
          ),
        );
        sesion.ladronId = null;
        sesion.fase = FaseEvaluacion.esperaRobo;
        sesion.mensaje = 'Robo suspendido por corrección de asistencia.';
      }
      if (!sesion.cronometrada) sesion.pausada = false;
    }
    if (sesion.fase == FaseEvaluacion.esperaRobo &&
        sesion.habilitadosRobo.isEmpty) {
      sesion.actual!.estado = EstadoPregunta.cerrada;
      sesion.fase = FaseEvaluacion.revision;
      sesion.ladronId = null;
      sesion.pausada = false;
    }
    _evento('${a.completo}: ${presente ? 'presente' : 'ausente'}.');
    if (sesion.finalizada) {
      sesion.cierreAnticipado = sesion.alumnos
          .where((a) => a.presente && !sesion.terminoAlumno(a.id))
          .any((a) => sesion.resultado(a.id).presentadas < 10);
    }
  }

  void editarAlumno(String id, String apellido, String nombre) {
    if (apellido.trim().isEmpty ||
        nombre.trim().isEmpty ||
        apellido.length > 120 ||
        nombre.length > 120) {
      return;
    }
    final a = sesion.alumno(id);
    a.apellido = apellido.trim().replaceAll(RegExp(r'\s+'), ' ');
    a.nombre = nombre.trim().replaceAll(RegExp(r'\s+'), ' ');
    // Corregir la identidad no forma parte del deshacer de respuestas/asistencia.
    for (final paso in _deshacer) {
      for (final fila in paso['alumnos'] as List) {
        if (fila['id'] == id) {
          fila['apellido'] = a.apellido;
          fila['nombre'] = a.nombre;
        }
      }
    }
  }

  void eliminarAlumno(String id) {
    if (sesion.iniciada) {
      throw StateError('No se puede eliminar durante una evaluación.');
    }
    if (sesion.alumnos.length <= 1) {
      throw StateError('Debe quedar al menos un estudiante.');
    }
    sesion.alumno(id);
    sesion.alumnos.removeWhere((a) => a.id == id);
  }

  void agregarAlumno(String apellido, String nombre) {
    if (sesion.iniciada) return;
    if (sesion.alumnos.length >= 20) {
      throw StateError('Se pueden incluir hasta veinte estudiantes.');
    }
    if (apellido.trim().isEmpty ||
        nombre.trim().isEmpty ||
        apellido.length > 120 ||
        nombre.length > 120) {
      throw StateError('Completá apellido y nombre.');
    }
    var n = 1;
    while (sesion.alumnos.any(
      (a) => a.id == 'S${n.toString().padLeft(2, '0')}',
    )) {
      n++;
    }
    sesion.alumnos.add(
      AlumnoTrivia(
        id: 'S${n.toString().padLeft(2, '0')}',
        apellido: apellido.trim(),
        nombre: nombre.trim(),
      ),
    );
  }

  void finalizar() {
    if (sesion.avisoPuntajeId != null) return;
    if (!sesion.iniciada || sesion.finalizada) return;
    _guardarPaso();
    sesion.cierreAnticipado = sesion.alumnos
        .where((a) => a.presente && !sesion.terminoAlumno(a.id))
        .any(
          (a) => sesion.paquetes[a.id]!.any(
            (id) => sesion.registros[id]!.estado != EstadoPregunta.cerrada,
          ),
        );
    for (final r in sesion.registros.values) {
      if (r.estado == EstadoPregunta.cerrada) continue;
      if (r.propio == null) {
        final fueActual =
            sesion.actualId == r.preguntaId &&
            sesion.fase == FaseEvaluacion.titular;
        r.propio = IntentoTrivia(
          alumnoId: r.titularId,
          opcion: null,
          estado: fueActual
              ? EstadoIntento.sinRespuesta
              : EstadoIntento.noPresentada,
          correcto: false,
          tiempoMs: fueActual ? 60000 - sesion.restanteMs : 0,
          fecha: DateTime.now().toUtc(),
        );
      }
      if (sesion.fase == FaseEvaluacion.robo &&
          sesion.actualId == r.preguntaId &&
          sesion.ladronId != null) {
        r.robos.add(
          IntentoTrivia(
            alumnoId: sesion.ladronId!,
            opcion: null,
            estado: EstadoIntento.sinRespuesta,
            correcto: false,
            tiempoMs: 0,
            fecha: DateTime.now().toUtc(),
          ),
        );
      }
      r.estado = EstadoPregunta.cerrada;
    }
    sesion.fase = FaseEvaluacion.finalizada;
    sesion.actualId = null;
    sesion.ladronId = null;
    sesion.pausada = false;
    sesion.mensaje =
        'Evaluación finalizada. El registro está disponible en Resultados.';
    _evento(
      'Cierre de la evaluación${sesion.cierreAnticipado ? ' anticipado' : ''}.',
    );
  }

  void deshacer() {
    if (_deshacer.isEmpty) return;
    sesion = SesionTrivia.fromJson(
      _deshacer.removeLast()..['configuracion'] = sesion.configuracion.toJson(),
      banco,
      recuperar: true,
    );
    _evento('Se deshizo la última acción.');
    sesion.mensaje =
        'Última acción deshecha.${sesion.cronometrada ? ' El tiempo queda pausado.' : ''}';
  }

  void resolverAvisoPuntaje({required bool finalizar}) {
    final id = sesion.avisoPuntajeId;
    if (id == null) return;
    sesion.aprobacionConsultada.add(id);
    if (finalizar || sesion.resultado(id).puntos >= 10) {
      sesion.finalizados.add(id);
    }
    sesion.avisoPuntajeId = null;
  }
}

String fechaArgentina(DateTime fecha) {
  final f = fecha.toUtc().subtract(const Duration(hours: 3));
  const meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${f.day} de ${meses[f.month - 1]} de ${f.year}';
}

String etiquetaIntento(IntentoTrivia? intento) => intento == null
    ? 'Pendiente'
    : switch (intento.estado) {
        EstadoIntento.respondido =>
          intento.correcto ? 'Correcta' : 'Incorrecta',
        EstadoIntento.sinRespuesta => 'Sin respuesta',
        EstadoIntento.agotado => 'Tiempo agotado',
        EstadoIntento.cancelado => 'Intento cancelado',
        EstadoIntento.noPresentada => 'No presentada al cerrar',
      };
