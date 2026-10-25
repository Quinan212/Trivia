import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../tema/iconos_trivia_antiguedad.dart';

import '../../tema/tema_trivia_antiguedad.dart';
import '../movimiento/movimiento.dart';
import 'boton_sonido.dart';
import 'desplazamiento_con_fundido.dart';
import 'entrada_inicio.dart';

class FondoConversacion extends StatelessWidget {
  const FondoConversacion({
    super.key,
    required this.child,
    this.volver,
    this.ayuda,
    this.sonido = true,
    this.pieSeparado = false,
    this.fondoSereno = false,
  });
  final Widget child;
  final VoidCallback? volver;
  final VoidCallback? ayuda;
  final bool sonido;
  final bool pieSeparado;
  final bool fondoSereno;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
    child: Scaffold(
      backgroundColor: EntradaInicio.of(context) == null
          ? null
          : Colors.transparent,
      body: Stack(
        children: [
          if (EntradaInicio.of(context) == null)
            Positioned.fill(
              bottom: pieSeparado || fondoSereno
                  ? -MediaQuery.sizeOf(context).height * .28
                  : 0,
              child: ExcludeSemantics(
                child: ColorFiltered(
                  colorFilter: TemaTriviaAntiguedad.filtroFondo,
                  child: Image.asset(
                    'assets/imagenes/optimizadas/conversation-background-v2.webp',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    RevelarInicio(
                      fin: .47,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Row(
                            children: [
                              if (volver != null)
                                IconButton(
                                  tooltip: 'Elegir nivel',
                                  onPressed: volver,
                                  icon: const Icon(
                                    IconosTriviaAntiguedad.arrowLeft,
                                    size: 28,
                                  ),
                                )
                              else
                                const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Trivia de la antiguedad',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: TemaTriviaAntiguedad.tinta,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              if (sonido)
                                Opacity(
                                  opacity:
                                      EntradaInicio.of(context)
                                              ?.ocultarSonido ==
                                          true
                                      ? 0
                                      : 1,
                                  child: const BotonSonido(),
                                ),
                              if (ayuda != null)
                                RevelarInicio(
                                  inicio: .35,
                                  fin: .65,
                                  child: IconButton(
                                    tooltip: 'Cómo jugar',
                                    onPressed: ayuda,
                                    icon: const Icon(
                                      IconosTriviaAntiguedad.question,
                                      size: 25,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: child),
                    if (pieSeparado)
                      SizedBox(
                        height: 54,
                        width: double.infinity,
                        child: ExcludeSemantics(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 30),
                              child: ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                  TemaTriviaAntiguedad.tinta,
                                  BlendMode.srcIn,
                                ),
                                child: Image.asset(
                                  'assets/imagenes/optimizadas/marcas-naranjas.webp',
                                  key: const ValueKey('adorno-pie'),
                                  width: 42,
                                  height: 40,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class CuerpoDesplazable extends StatefulWidget {
  const CuerpoDesplazable({
    super.key,
    required this.child,
    this.arriba = 28,
    this.minHeight = false,
    this.contenido,
  });
  final Widget child;
  final double arriba;
  final bool minHeight;
  final Object? contenido;
  @override
  State<CuerpoDesplazable> createState() => _CuerpoDesplazableState();
}

class _CuerpoDesplazableState extends State<CuerpoDesplazable> {
  final _scroll = ScrollController();
  @override
  void didUpdateWidget(CuerpoDesplazable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.contenido != oldWidget.contenido) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients && _scroll.offset > 0) {
          if (MediaQuery.disableAnimationsOf(context)) {
            _scroll.jumpTo(0);
          } else {
            _scroll.animateTo(
              0,
              duration: duracionMovimiento(context, 180),
              curve: Curves.easeOutCubic,
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => DesplazamientoConFundido(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(26, widget.arriba, 26, 26),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: widget.minHeight
              ? (constraints.maxHeight - widget.arriba - 26).clamp(
                  0,
                  double.infinity,
                )
              : 0,
        ),
        child: widget.child,
      ),
    ),
  );
}
