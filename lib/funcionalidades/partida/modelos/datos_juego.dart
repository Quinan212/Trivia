import '../../ajustes/modelos/ajustes_juego.dart';
import 'catalogo_preguntas.dart';
import 'estado_partida.dart';

class DatosJuego {
  const DatosJuego({
    required this.catalogo,
    required this.ajustes,
    this.partida,
    this.aviso,
  });
  final CatalogoPreguntas catalogo;
  final AjustesJuego ajustes;
  final EstadoPartida? partida;
  final String? aviso;
  bool get puedeRetomar => partida != null && !partida!.terminada;
  bool get coincideSeleccion =>
      puedeRetomar &&
      partida!.nivel == ajustes.nivel &&
      partida!.cartas.length == ajustes.cantidad;
  DatosJuego copyWith({
    AjustesJuego? ajustes,
    EstadoPartida? partida,
    String? aviso,
    bool limpiarAviso = false,
  }) => DatosJuego(
    catalogo: catalogo,
    ajustes: ajustes ?? this.ajustes,
    partida: partida ?? this.partida,
    aviso: limpiarAviso ? null : aviso ?? this.aviso,
  );
}
