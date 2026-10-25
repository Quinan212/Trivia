import '../modelos/catalogo_preguntas.dart';
import '../modelos/estado_partida.dart';
import '../modelos/pregunta.dart';

abstract final class ArmadorRondas {
  static EstadoPartida crear(
    CatalogoPreguntas catalogo, {
    required int nivel,
    required int cantidad,
    int ronda = 0,
    DateTime? inicio,
  }) {
    if (nivel < 0 || nivel > 3 || ronda < 0) {
      throw ArgumentError('Nivel o ronda inválidos.');
    }
    final disponibles = catalogo.deNivel(nivel);
    if (nivel != 0 && cantidad != 12 && cantidad != 25) {
      throw ArgumentError('La ronda debe tener 12 o 25 cartas.');
    }
    if (cantidad < 1 || cantidad > disponibles.length) {
      throw ArgumentError('No hay suficientes cartas.');
    }
    final grupos = <String, List<Pregunta>>{};
    for (final carta in disponibles) {
      grupos.putIfAbsent(carta.tema, () => []).add(carta);
    }
    final temas = grupos.values.toList();
    final ordenTemas = temas.length == 5
        ? [1, 2, 3, 0, 4]
        : List.generate(temas.length, (indice) => indice);
    final orden = <String>[];
    var vuelta = 0;
    while (orden.length < disponibles.length) {
      for (final indice in ordenTemas) {
        final grupo = temas[indice];
        if (vuelta < grupo.length) {
          orden.add(grupo[vuelta].id);
        }
      }
      vuelta++;
    }
    // Continuar por la biblioteca completa permite ampliar el catálogo sin
    // dejar siempre las mismas cartas al comienzo de cada ronda.
    final desplazamiento = (ronda * cantidad) % orden.length;
    return EstadoPartida(
      nivel: nivel,
      cartas: List.generate(
        cantidad,
        (indice) => orden[(desplazamiento + indice) % orden.length],
      ),
      versionContenido: catalogo.version,
      ronda: ronda,
      inicio: inicio ?? DateTime.now(),
    );
  }
}
