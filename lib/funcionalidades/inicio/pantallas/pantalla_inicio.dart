import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../tema/iconos_trivia_antiguedad.dart';
import '../../../compartido/movimiento/movimiento.dart';
import '../../../compartido/sonidos/respuesta_interfaz.dart';
import '../../ajustes/controladores/controlador_experiencia.dart';
import '../../bienvenida/pantallas/pantalla_tutorial.dart';
import '../../bienvenida/pantallas/pantalla_experimentos.dart';

import '../../../compartido/componentes/boton_principal.dart';
import '../../../compartido/componentes/fondo_conversacion.dart';
import '../../../compartido/componentes/entrada_inicio.dart';
import '../../../compartido/componentes/hojas_conversacion.dart';
import '../../../tema/tema_trivia_antiguedad.dart';
import '../../partida/controladores/controlador_partida.dart';
import '../../partida/modelos/catalogo_preguntas.dart';
import '../../partida/modelos/datos_juego.dart';
import '../../partida/pantallas/pantalla_partida.dart';

class PantallaInicio extends ConsumerStatefulWidget {
  const PantallaInicio({super.key});
  @override
  ConsumerState<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends ConsumerState<PantallaInicio> {
  bool _abriendo = false;

  Future<void> _abrir(
    BuildContext context,
    WidgetRef ref, {
    bool nueva = false,
    bool consignas = false,
    bool retomar = false,
  }) async {
    if (_abriendo) return;
    _abriendo = true;
    try {
      final continuar =
          retomar ||
          (!nueva &&
              !consignas &&
              ref.read(partidaProvider).value?.coincideSeleccion == true);
      if (!retomar) {
        await ref
            .read(partidaProvider.notifier)
            .empezar(nueva: nueva, consignas: consignas);
      }
      if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
      ref
          .read(respuestaInterfazProvider)
          .emitir(
            consignas
                ? EfectoInterfaz.abrirConsignas
                : continuar
                ? EfectoInterfaz.retomarRonda
                : nueva
                ? EfectoInterfaz.otraRonda
                : EfectoInterfaz.iniciarRonda,
          );
      await Navigator.of(context)
          .push<void>(rutaSuave(context, const PantallaPartida()));
    } finally {
      _abriendo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(experienciaProvider, (anterior, siguiente) {
      final aviso = siguiente.value?.aviso;
      if (aviso == null || aviso == anterior?.value?.aviso) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(aviso)));
        ref.read(experienciaProvider.notifier).cerrarAviso();
      });
    });
    ref.listen(partidaProvider, (anterior, siguiente) {
      final aviso = siguiente.value?.aviso;
      if (aviso == null || aviso == anterior?.value?.aviso) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(aviso),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: () {
                ref
                    .read(respuestaInterfazProvider)
                    .emitir(EfectoInterfaz.reintentar);
                unawaited(
                  ref.read(partidaProvider.notifier).reintentarGuardado(),
                );
              },
            ),
          ),
        );
      });
    });
    final datos = ref.watch(partidaProvider);
    return FondoConversacion(
      ayuda: () => mostrarReglas(context),
      child: datos.when(
        loading: () => const RevelarInicio(
          fin: .60,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => RevelarInicio(
          inicio: .10,
          fin: .80,
          child: CuerpoDesplazable(
            child: Column(
              children: [
                const SizedBox(height: 60),
                const Text(
                  'No pudimos preparar la charla.',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const Text('Probemos de nuevo. Tus cartas están en la app.'),
                const SizedBox(height: 28),
                BotonPrincipal(
                  texto: 'Reintentar',
                  efecto: EfectoInterfaz.reintentar,
                  onPressed: () => ref.invalidate(partidaProvider),
                ),
              ],
            ),
          ),
        ),
        data: (datos) => _contenido(context, ref, datos),
      ),
    );
  }

  Widget _contenido(BuildContext context, WidgetRef ref, DatosJuego datos) {
    final controlador = ref.read(partidaProvider.notifier);
    return CuerpoDesplazable(
      arriba: 35,
      child: ColumnaInicio(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UN RATO PARA CONOCERSE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: TemaTriviaAntiguedad.tenue,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Hay mucho\npor contar.',
            style: TextStyle(
              fontSize: 51,
              height: 1.03,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.8,
              color: TemaTriviaAntiguedad.tinta,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'De a dos o en grupo.\nUna carta y que la charla haga lo suyo.',
            style: TextStyle(
              color: TemaTriviaAntiguedad.tenue,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          const Row(
            children: [
              Expanded(
                child: Text(
                  '¿Por dónde arrancamos?',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '3 niveles',
                style: TextStyle(
                  fontSize: 12,
                  color: TemaTriviaAntiguedad.tenue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final nivel in nivelesConversacion)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _Nivel(
                nivel: nivel,
                seleccionado: datos.ajustes.nivel == nivel.id,
                onTap: () =>
                    unawaited(controlador.seleccionar(nivel: nivel.id)),
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 20,
            children: [
              const Text(
                'La ronda',
                style: TextStyle(
                  fontSize: 13,
                  color: TemaTriviaAntiguedad.tenue,
                ),
              ),
              Wrap(
                spacing: 4,
                children: [
                  for (final cantidad in [12, 25])
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ChoiceChip(
                        key: ValueKey('ronda-$cantidad'),
                        label: Text('$cantidad cartas'),
                        selected: datos.ajustes.cantidad == cantidad,
                        showCheckmark: false,
                        selectedColor: TemaTriviaAntiguedad.salvia,
                        backgroundColor: Colors.transparent,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          color: TemaTriviaAntiguedad.tinta,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) {
                          ref
                              .read(respuestaInterfazProvider)
                              .emitir(sonidoRonda(cantidad));
                          unawaited(
                            controlador.seleccionar(cantidad: cantidad),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 19),
          BotonPrincipal(
            key: const ValueKey('empezar'),
            texto: datos.coincideSeleccion
                ? 'Seguir charlando'
                : 'Dale, arranquemos',
            tamano: 23,
            textoBlanco: true,
            feedbackExterno: true,
            onPressed: () => _abrir(context, ref),
          ),
          if (datos.puedeRetomar)
            Center(
              child: TextButton(
                key: const ValueKey('retomar'),
                onPressed: () => datos.coincideSeleccion
                    ? _abrir(context, ref, nueva: true)
                    : _abrir(context, ref, retomar: true),
                child: Text(
                  datos.coincideSeleccion
                      ? 'Empezar otra ronda'
                      : 'Retomar la ronda guardada',
                ),
              ),
            ),
          const SizedBox(height: 17),
          const Center(
            child: Text(
              'Sin apuro. Siempre podés pasar.',
              style: TextStyle(fontSize: 12, color: TemaTriviaAntiguedad.tenue),
            ),
          ),
          const SizedBox(height: 23),
          Center(
            child: TextButton(
              key: const ValueKey('consignas'),
              onPressed: () => _abrir(context, ref, consignas: true),
              child: const Column(
                children: [
                  Text(
                    '¿Probamos algo distinto?',
                    style: TextStyle(
                      color: TemaTriviaAntiguedad.tinta,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '15 dinámicas',
                    style: TextStyle(
                      fontSize: 11,
                      color: TemaTriviaAntiguedad.tenue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              key: const ValueKey('ver-tutorial'),
              icon: const Icon(IconosTriviaAntiguedad.question, size: 18),
              label: const Text('Ver tutorial', style: TextStyle(fontSize: 12)),
              onPressed: () {
                unawaited(mostrarTutorial(context));
              },
            ),
          ),
          if (kDebugMode)
            Center(
              child: TextButton(
                key: const ValueKey('experimentos'),
                onPressed: () {
                  ref
                      .read(respuestaInterfazProvider)
                      .emitir(EfectoInterfaz.abrirLaboratorio);
                  Navigator.push<void>(
                    context,
                    rutaSuave(context, const PantallaExperimentos()),
                  );
                },
                child: const Text(
                  'Probar el mazo · Experimentos',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Nivel extends ConsumerWidget {
  const _Nivel({
    required this.nivel,
    required this.seleccionado,
    required this.onTap,
  });
  final NivelConversacion nivel;
  final bool seleccionado;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    selected: seleccionado,
    button: true,
    child: ToqueConRebote(
      child: AnimatedContainer(
        duration: duracionMovimiento(context, 240),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: seleccionado
              ? TemaTriviaAntiguedad.salvia
              : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('nivel-${nivel.id}'),
            borderRadius: BorderRadius.circular(17),
            onTap: () {
              ref.read(respuestaInterfazProvider).emitir(sonidoNivel(nivel.id));
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Text(
                    '0${nivel.id}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: TemaTriviaAntiguedad.tenue,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nivel.nombre,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          nivel.descripcion,
                          style: const TextStyle(
                            fontSize: 12,
                            color: TemaTriviaAntiguedad.tenue,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
