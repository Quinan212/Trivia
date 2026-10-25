import '../../compartido/sonidos/respuesta_interfaz.dart';
import 'modelos.dart';

/// Copia inmutable de los cambios relevantes; un pulso del reloj no es un evento.
class EstadoSonoroEvaluacion {
  EstadoSonoroEvaluacion(SesionTrivia s)
    : sesion = s.id,
      fase = s.fase,
      pregunta = s.actualId,
      ladron = s.ladronId,
      pausada = s.pausada,
      aviso = s.avisoPuntajeId,
      intento = s.actual?.robos.lastOrNull ?? s.actual?.propio,
      evento = s.eventos.isEmpty
          ? ''
          : '${s.eventos.last['fecha']} ${s.eventos.last['accion']}',
      accion = s.eventos.lastOrNull?['accion'] ?? '',
      alumnos = Object.hashAll(
        s.alumnos.map((a) => (a.id, a.completo, a.presente)),
      ),
      notaAviso = s.avisoPuntajeId == null
          ? 0
          : s.resultado(s.avisoPuntajeId!).puntos;

  final String sesion, evento, accion;
  final String? pregunta, ladron, aviso;
  final FaseEvaluacion fase;
  final bool pausada;
  final IntentoTrivia? intento;
  final int alumnos, notaAviso;

  EfectoInterfaz? cambioDesde(EstadoSonoroEvaluacion anterior) {
    if ((
          sesion,
          fase,
          pregunta,
          ladron,
          pausada,
          aviso,
          intento,
          evento,
          alumnos,
        ) ==
        (
          anterior.sesion,
          anterior.fase,
          anterior.pregunta,
          anterior.ladron,
          anterior.pausada,
          anterior.aviso,
          anterior.intento,
          anterior.evento,
          anterior.alumnos,
        )) {
      return null;
    }
    if (sesion != anterior.sesion) return EfectoInterfaz.evaluacionToque;
    if (accion == 'Se deshizo la última acción.' && evento != anterior.evento) {
      return EfectoInterfaz.evaluacionDeshacer;
    }
    if (fase == FaseEvaluacion.finalizada && anterior.fase != fase) {
      return EfectoInterfaz.evaluacionFinal;
    }
    if (anterior.fase == FaseEvaluacion.preparacion && fase != anterior.fase) {
      return EfectoInterfaz.evaluacionInicio;
    }
    if (pregunta != anterior.pregunta && pregunta != null) {
      return EfectoInterfaz.evaluacionPasar;
    }
    final nuevo = intento;
    if (nuevo != null &&
        !identical(nuevo, anterior.intento) &&
        pregunta == anterior.pregunta &&
        nuevo.estado != EstadoIntento.cancelado &&
        nuevo.estado != EstadoIntento.noPresentada) {
      if (nuevo.correcto) {
        if (aviso != null && notaAviso >= 10) {
          return EfectoInterfaz.evaluacionDiez;
        }
        if (aviso != null && notaAviso >= 7) {
          return EfectoInterfaz.evaluacionAprobado;
        }
        return EfectoInterfaz.evaluacionCorrecta;
      }
      return switch (nuevo.estado) {
        EstadoIntento.agotado => EfectoInterfaz.evaluacionAgotado,
        EstadoIntento.sinRespuesta => EfectoInterfaz.evaluacionSinRespuesta,
        _ => EfectoInterfaz.evaluacionIncorrecta,
      };
    }
    if (fase == FaseEvaluacion.robo && anterior.fase != fase) {
      return EfectoInterfaz.evaluacionRobo;
    }
    if (fase == FaseEvaluacion.revision && anterior.fase != fase) {
      return EfectoInterfaz.evaluacionCerrar;
    }
    if (fase == FaseEvaluacion.titular &&
        anterior.fase == fase &&
        pausada != anterior.pausada) {
      return pausada
          ? EfectoInterfaz.evaluacionPausa
          : EfectoInterfaz.evaluacionTiempo;
    }
    return EfectoInterfaz.evaluacionToque;
  }
}
