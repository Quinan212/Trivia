import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tema/paleta_evaluacion.dart';

class RelojEvaluacion extends StatelessWidget {
  const RelojEvaluacion({
    super.key,
    required this.restanteMs,
    required this.sinIniciar,
    required this.pausado,
    this.salida = 0,
    this.compacto = false,
    this.soloSegundos = false,
  });

  final int restanteMs;
  final bool sinIniciar, pausado;
  final double salida;
  final bool compacto;
  final bool soloSegundos;

  @override
  Widget build(BuildContext context) {
    final segundos = (restanteMs / 1000).ceil();
    final escala = MediaQuery.textScalerOf(context).scale(1);
    final detenido = pausado && !sinIniciar;
    final p = PaletaEvaluacion.of(context);
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 440);
    return Semantics(
      liveRegion: true,
      label: sinIniciar
          ? 'Tiempo sin iniciar'
          : detenido
          ? 'Tiempo pausado. Quedan $segundos segundos'
          : 'Tiempo restante: $segundos segundos',
      child: SizedBox.square(
        key: const ValueKey('superficie-reloj-evaluacion'),
        dimension: compacto ? 64 : 144 * escala,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: detenido ? 1 : 0),
                duration: duracion,
                curve: Curves.easeInOutCubic,
                builder: (context, pausa, _) => CustomPaint(
                  painter: _TrazoReloj(
                    paleta: p,
                    transcurrido: (1 - restanteMs / 60000).clamp(.001, 1),
                    salida: salida,
                    pausa: pausa,
                  ),
                ),
              ),
            ),
            Transform.scale(
              scale: 1 - salida,
              child: Opacity(
                opacity: 1 - salida,
                child: AnimatedSwitcher(
                  duration: duracion,
                  switchInCurve: const Interval(
                    .45,
                    1,
                    curve: Curves.easeOutCubic,
                  ),
                  switchOutCurve: const Interval(
                    .6,
                    1,
                    curve: Curves.easeInCubic,
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: .6,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: SizedBox.expand(
                    key: ValueKey(
                      detenido ? 'cara-reloj-pausa' : 'cara-reloj-tiempo',
                    ),
                    child: Center(
                      child: detenido
                          ? ExcludeSemantics(
                              child: Icon(
                                Icons.pause_rounded,
                                key: const ValueKey('icono-reloj-pausado'),
                                size: compacto ? 30 : 54,
                                color: p.naranjaTexto,
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  soloSegundos
                                      ? '$segundos'
                                      : '${(segundos ~/ 60).toString().padLeft(2, '0')}:${(segundos % 60).toString().padLeft(2, '0')}',
                                  key: const ValueKey('reloj-evaluacion'),
                                  maxLines: 1,
                                  softWrap: false,
                                  textScaler: compacto
                                      ? const TextScaler.linear(1)
                                      : null,
                                  style: TextStyle(
                                    fontSize: compacto ? 18 : 30,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                    color: p.naranjaTexto,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                if (!compacto) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    sinIniciar ? 'Sin iniciar' : 'Respuesta',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: p.tenue,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrazoReloj extends CustomPainter {
  const _TrazoReloj({
    required this.transcurrido,
    required this.salida,
    required this.paleta,
    this.pausa = 0,
  });
  final PaletaEvaluacion paleta;
  final double transcurrido, salida, pausa;

  @override
  void paint(Canvas canvas, Size size) {
    if (salida >= 1) return;
    final grosor = size.width < 80 ? 2.5 : 5.0;
    final rect = (Offset.zero & size).deflate(grosor / 2);
    final inicio = -math.pi / 2 + math.pi * 2 * salida;
    final arco = math.pi * 2 * (1 - salida);
    final alfa = 1 - const Interval(.9, 1).transform(salida);
    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      inicio,
      arco,
      false,
      trazo
        ..color = Color.lerp(
          paleta.salvia,
          paleta.borde,
          pausa,
        )!.withValues(alpha: alfa),
    );
    canvas.drawArc(
      rect,
      inicio,
      arco * transcurrido * (1 - pausa),
      false,
      trazo..color = paleta.naranjaTexto.withValues(alpha: alfa),
    );
  }

  @override
  bool shouldRepaint(_TrazoReloj oldDelegate) =>
      transcurrido != oldDelegate.transcurrido ||
      salida != oldDelegate.salida ||
      pausa != oldDelegate.pausa ||
      paleta != oldDelegate.paleta;
}
