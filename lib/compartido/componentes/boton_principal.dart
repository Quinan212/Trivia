import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tema/iconos_trivia_antiguedad.dart';

import '../../tema/paleta_evaluacion.dart';
import '../movimiento/movimiento.dart';
import '../sonidos/respuesta_interfaz.dart';

class BotonPrincipal extends ConsumerWidget {
  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.tamano = 25,
    this.efecto,
    this.feedbackExterno = false,
    this.destacado = false,
    this.textoBlanco = false,
  });
  final String texto;
  final VoidCallback? onPressed;
  final double tamano;
  final EfectoInterfaz? efecto;
  final bool feedbackExterno;
  final bool destacado;
  final bool textoBlanco;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ToqueConRebote(
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          enableFeedback: !feedbackExterno && efecto == null,
          backgroundColor: PaletaEvaluacion.of(context).naranja,
          foregroundColor: PaletaEvaluacion.of(context).sobreNaranja,
          minimumSize: const Size(0, 65),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(23),
            side: BorderSide(
              color: destacado
                  ? PaletaEvaluacion.of(context).tinta
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        onPressed: onPressed == null
            ? null
            : () {
                if (!feedbackExterno && efecto != null) {
                  ref.read(respuestaInterfazProvider).emitir(efecto!);
                }
                onPressed!();
              },
        child: Row(
          children: [
            const SizedBox(width: 26),
            Expanded(
              child: Text(
                texto,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: tamano,
                  height: 1.2,
                  letterSpacing: -0.5,
                  fontWeight: textoBlanco ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(IconosTriviaAntiguedad.arrowRight, size: 28),
          ],
        ),
      ),
    ),
  );
}

class EtiquetaNivel extends StatelessWidget {
  const EtiquetaNivel(this.texto, {super.key});
  final String texto;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: PaletaEvaluacion.of(context).salvia,
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      texto.toUpperCase(),
      style: TextStyle(
        color: PaletaEvaluacion.of(context).tinta,
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    ),
  );
}
