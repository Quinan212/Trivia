import 'catalogo_preguntas.dart';

class EstadoPartida {
  EstadoPartida({
    required this.nivel,
    required List<String> cartas,
    required this.versionContenido,
    required this.ronda,
    required this.inicio,
    this.indice = 0,
    this.pasadas = 0,
    Map<String, int> tiemposMs = const {},
    Set<String> cartasPasadas = const {},
    Map<String, String> textosCompartidos = const {},
  }) : cartas = List.unmodifiable(cartas),
       tiemposMs = Map.unmodifiable(tiemposMs),
       cartasPasadas = Set.unmodifiable(cartasPasadas),
       textosCompartidos = Map.unmodifiable(textosCompartidos);
  final int nivel;
  final List<String> cartas;
  final String versionContenido;
  final int ronda;
  final DateTime inicio;
  final int indice;
  final int pasadas;
  final Map<String, int> tiemposMs;
  final Set<String> cartasPasadas;
  final Map<String, String> textosCompartidos;
  bool get terminada => indice == cartas.length;
  int get compartidas => indice - pasadas;
  String? get cartaActual => terminada ? null : cartas[indice];
  int get duracionActivaMs =>
      cartas.take(indice).fold(0, (total, id) => total + (tiemposMs[id] ?? 0));
  int get promedioCompletadaMs =>
      indice == 0 ? 0 : (duracionActivaMs / indice).round();
  EstadoPartida registrarTiempo(int milisegundos) {
    if (terminada || milisegundos <= 0) return this;
    return _copiar(
      tiemposMs: {
        ...tiemposMs,
        cartaActual!: (tiemposMs[cartaActual] ?? 0) + milisegundos,
      },
    );
  }

  EstadoPartida _copiar({
    int? indice,
    int? pasadas,
    Map<String, int>? tiemposMs,
    Set<String>? cartasPasadas,
    Map<String, String>? textosCompartidos,
  }) => EstadoPartida(
    nivel: nivel,
    cartas: cartas,
    versionContenido: versionContenido,
    ronda: ronda,
    inicio: inicio,
    indice: indice ?? this.indice,
    pasadas: pasadas ?? this.pasadas,
    tiemposMs: tiemposMs ?? this.tiemposMs,
    cartasPasadas: cartasPasadas ?? this.cartasPasadas,
    textosCompartidos: textosCompartidos ?? this.textosCompartidos,
  );

  EstadoPartida avanzar({
    bool pasar = false,
    int milisegundos = 0,
    String? textoCompartido,
  }) {
    if (terminada) return this;
    final conTiempo = registrarTiempo(milisegundos);
    return conTiempo._copiar(
      indice: indice + 1,
      pasadas: pasadas + (pasar ? 1 : 0),
      cartasPasadas: pasar ? {...cartasPasadas, cartaActual!} : cartasPasadas,
      textosCompartidos: textoCompartido == null
          ? textosCompartidos
          : {...textosCompartidos, cartaActual!: textoCompartido},
    );
  }

  List<MapEntry<String, int>> get masConversadas {
    final terminadas = cartas.take(indice).toSet();
    final ordenadas =
        tiemposMs.entries
            .where(
              (carta) =>
                  terminadas.contains(carta.key) &&
                  !cartasPasadas.contains(carta.key) &&
                  carta.value >= 1000,
            )
            .toList()
          ..sort((a, b) {
            final tiempo = b.value.compareTo(a.value);
            return tiempo != 0
                ? tiempo
                : cartas.indexOf(a.key).compareTo(cartas.indexOf(b.key));
          });
    return List.unmodifiable(ordenadas.take(3));
  }

  Map<String, dynamic> toJson() => {
    'version': 2,
    'nivel': nivel,
    'cartas': cartas,
    'contenido': versionContenido,
    'ronda': ronda,
    'inicio': inicio.toUtc().toIso8601String(),
    'indice': indice,
    'pasadas': pasadas,
    'tiemposMs': tiemposMs,
    'cartasPasadas': cartasPasadas.toList(),
    'textosCompartidos': textosCompartidos,
  };
  factory EstadoPartida.fromJson(
    Map<String, dynamic> json,
    CatalogoPreguntas catalogo,
  ) {
    if (json['version'] != 1 && json['version'] != 2) {
      throw const FormatException('Versión de sesión incompatible.');
    }
    final versionGuardada = json['contenido'] as String;
    final anteriores = catalogo.textosAnteriores[versionGuardada];
    if (versionGuardada != catalogo.version && anteriores == null) {
      throw const FormatException('Edición de contenido incompatible.');
    }
    final cartas = (json['cartas'] as List).cast<String>();
    if (anteriores != null && cartas.any((id) => !anteriores.containsKey(id))) {
      throw const FormatException(
        'La ronda contiene cartas ajenas a su edición.',
      );
    }
    final indice = json['indice'] as int;
    if (indice < 0 || indice > cartas.length) {
      throw const FormatException('Posición de sesión inválida.');
    }
    final textos = json['textosCompartidos'] == null
        ? <String, String>{}
        : Map<String, String>.from(json['textosCompartidos'] as Map);
    if (anteriores != null) {
      for (final id in cartas.take(indice)) {
        if (anteriores[id] case final String texto) {
          textos.putIfAbsent(id, () => texto);
        }
      }
    }
    final partida = EstadoPartida(
      nivel: json['nivel'] as int,
      cartas: cartas,
      versionContenido: catalogo.version,
      ronda: json['ronda'] as int,
      inicio: DateTime.parse(json['inicio'] as String),
      indice: indice,
      pasadas: json['pasadas'] as int,
      tiemposMs: json['version'] == 2
          ? (json['tiemposMs'] as Map).cast<String, int>()
          : const {},
      cartasPasadas: json['version'] == 2
          ? (json['cartasPasadas'] as List).cast<String>().toSet()
          : const {},
      textosCompartidos: textos,
    );
    final cantidadValida = partida.nivel == 0
        ? partida.cartas.length == catalogo.deNivel(0).length
        : [12, 25].contains(partida.cartas.length);
    if (!cantidadValida ||
        partida.versionContenido != catalogo.version ||
        partida.nivel < 0 ||
        partida.nivel > 3 ||
        partida.ronda < 0 ||
        partida.indice < 0 ||
        partida.indice > partida.cartas.length ||
        partida.pasadas < 0 ||
        partida.pasadas > partida.indice ||
        partida.cartas.toSet().length != partida.cartas.length ||
        partida.cartas.any(
          (id) => catalogo.porId[id]?.nivel != partida.nivel,
        ) ||
        partida.tiemposMs.entries.any(
          (entrada) =>
              entrada.value < 0 ||
              !partida.cartas
                  .take(partida.indice + (partida.terminada ? 0 : 1))
                  .contains(entrada.key),
        ) ||
        partida.cartasPasadas.length > partida.pasadas ||
        partida.cartasPasadas.any(
          (id) => !partida.cartas.take(partida.indice).contains(id),
        ) ||
        partida.textosCompartidos.entries.any(
          (entrada) =>
              entrada.value.trim().isEmpty ||
              !partida.cartas.take(partida.indice).contains(entrada.key),
        )) {
      throw const FormatException('Sesión inválida para este catálogo.');
    }
    return partida;
  }
}
