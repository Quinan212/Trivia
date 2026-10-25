import 'package:flutter/material.dart';

import '../../../compartido/componentes/boton_principal.dart';
import '../../../tema/tema_trivia_antiguedad.dart';
import '../modelos/estado_partida.dart';
import '../modelos/catalogo_preguntas.dart';
import '../../../compartido/movimiento/movimiento.dart';

class ResumenRonda extends StatelessWidget {
  const ResumenRonda({
    super.key,
    required this.partida,
    required this.catalogo,
    required this.otraRonda,
    required this.elegirNivel,
    this.mostrarAcciones = true,
    this.compacto = false,
  });
  final EstadoPartida partida;
  final CatalogoPreguntas catalogo;
  final VoidCallback otraRonda;
  final VoidCallback elegirNivel;
  final bool mostrarAcciones;
  final bool compacto;
  @override
  Widget build(BuildContext context) => compacto
      ? Container(
          key: const ValueKey('cierre-ejemplo'),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: TemaTriviaAntiguedad.hoja,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: TemaTriviaAntiguedad.borde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CIERRE · EJEMPLO',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1,
                  color: TemaTriviaAntiguedad.tenue,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Qué linda charla.',
                style: TextStyle(
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, limites) {
                  // Android escala de forma distinta fuentes grandes y chicas.
                  // Medir la etiqueta de 13 dp, no escalar un ancho hipotético.
                  final etiqueta = TextPainter(
                    text: TextSpan(
                      text: 'Compartidas',
                      style: DefaultTextStyle.of(context).style
                          .copyWith(fontSize: 13),
                    ),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout();
                  final apilar = limites.maxWidth / 2 < etiqueta.width + 12;
                  etiqueta.dispose();
                  return apilar
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Conteo('Compartidas', partida.compartidas),
                            const SizedBox(height: 12),
                            _Conteo('Pasadas', partida.pasadas),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _Conteo(
                                'Compartidas',
                                partida.compartidas,
                              ),
                            ),
                            Expanded(
                              child: _Conteo('Pasadas', partida.pasadas),
                            ),
                          ],
                        );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'La conversación puede seguir.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: TemaTriviaAntiguedad.tenue,
                ),
              ),
            ],
          ),
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EtiquetaNivel('A su ritmo'),
            const SizedBox(height: 45),
            const CelebracionBreve(
              child: AparicionBreve(
                child: Text(
                  'Qué linda\ncharla.',
                  key: ValueKey('fin-ronda'),
                  style: TextStyle(
                    fontSize: 63,
                    height: 1.02,
                    letterSpacing: -2,
                    fontWeight: FontWeight.w800,
                    color: TemaTriviaAntiguedad.tinta,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Las cartas se terminaron.\nLa conversación puede seguir.',
              style: TextStyle(
                fontSize: 17,
                color: TemaTriviaAntiguedad.tenue,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            const Divider(color: TemaTriviaAntiguedad.borde),
            const SizedBox(height: 14),
            AparicionBreve(
              demora: 60,
              child: Row(
                children: [
                  Expanded(child: _Conteo('Compartidas', partida.compartidas)),
                  Expanded(child: _Conteo('Pasadas', partida.pasadas)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Divider(color: TemaTriviaAntiguedad.borde),
            const SizedBox(height: 18),
            AparicionBreve(
              demora: 120,
              child: Wrap(
                spacing: 28,
                runSpacing: 14,
                children: [
                  _DatoTiempo(
                    'Tiempo activo',
                    _duracion(partida.duracionActivaMs),
                    clave: 'duracion-activa',
                  ),
                  _DatoTiempo(
                    'Promedio por carta',
                    _duracion(partida.promedioCompletadaMs),
                    clave: 'promedio-carta',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tiempo con las cartas abiertas, sin pausas ni transiciones.',
              style: TextStyle(
                fontSize: 12,
                color: TemaTriviaAntiguedad.tenue,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            if (partida.nivel != 0) ...[
              const Text(
                'Donde más se quedaron',
                key: ValueKey('destacadas'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Las cartas donde más tiempo se quedaron.',
                style: TextStyle(
                  fontSize: 13,
                  color: TemaTriviaAntiguedad.tenue,
                ),
              ),
              const SizedBox(height: 16),
              if (partida.masConversadas.isEmpty)
                const Text(
                  'En una próxima ronda, las charlas más largas van a aparecer acá.',
                  style: TextStyle(
                    fontSize: 14,
                    color: TemaTriviaAntiguedad.tenue,
                    height: 1.4,
                  ),
                ),
              for (final (posicion, carta) in partida.masConversadas.indexed)
                AparicionBreve(
                  demora: 180 + posicion * 60,
                  child: Container(
                    key: ValueKey('destacada-${carta.key}'),
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: TemaTriviaAntiguedad.hoja.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '0${posicion + 1}',
                              style: const TextStyle(
                                color: TemaTriviaAntiguedad.naranjaTexto,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _duracion(carta.value),
                              style: const TextStyle(
                                color: TemaTriviaAntiguedad.tenue,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Text(
                          partida.textosCompartidos[carta.key] ??
                              catalogo.porId[carta.key]!.texto,
                          style: const TextStyle(
                            fontSize: 19,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'El tiempo es una pista. Ustedes saben qué charla dejó más.',
                style: TextStyle(
                  fontSize: 12,
                  color: TemaTriviaAntiguedad.tenue,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 30),
            ],
            const Text(
              '¿Con qué te quedás de este rato?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 28),
            if (mostrarAcciones)
              BotonPrincipal(texto: 'Otra ronda', onPressed: otraRonda),
            const SizedBox(height: 12),
            if (mostrarAcciones)
              Center(
                child: TextButton(
                  onPressed: elegirNivel,
                  child: const Text('Elegir otro nivel'),
                ),
              ),
            const SizedBox(height: 17),
            const Center(
              child: Text(
                'Gracias por compartir.',
                style: TextStyle(
                  fontSize: 12,
                  color: TemaTriviaAntiguedad.tenue,
                ),
              ),
            ),
          ],
        );
}

String _duracion(int milisegundos) {
  final segundos = milisegundos ~/ 1000;
  final minutos = segundos ~/ 60;
  if (minutos == 0) return '$segundos s';
  if (segundos % 60 == 0) return '$minutos min';
  return '$minutos min ${segundos % 60} s';
}

class _Conteo extends StatelessWidget {
  const _Conteo(this.nombre, this.cantidad);
  final String nombre;
  final int cantidad;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        nombre,
        style: const TextStyle(fontSize: 13, color: TemaTriviaAntiguedad.tenue),
      ),
      Text(
        cantidad.toString(),
        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _DatoTiempo extends StatelessWidget {
  const _DatoTiempo(this.nombre, this.valor, {required this.clave});
  final String nombre, valor, clave;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        nombre,
        style: const TextStyle(fontSize: 13, color: TemaTriviaAntiguedad.tenue),
      ),
      const SizedBox(height: 4),
      Text(
        valor,
        key: ValueKey(clave),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
    ],
  );
}
