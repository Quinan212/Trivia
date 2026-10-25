import 'package:flutter/material.dart';

/// Mantiene el fundido del juego original también en páginas con slivers.
class FundidoBordeScroll extends StatelessWidget {
  const FundidoBordeScroll({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: child,
    builder: (context, child) => ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (limites) {
        final posicion = controller.hasClients ? controller.position : null;
        final arriba = (posicion?.extentBefore ?? 0)
            .clamp(0.0, 36.0)
            .clamp(0.0, limites.height / 2);
        final abajo = (posicion?.extentAfter ?? 0)
            .clamp(0.0, 36.0)
            .clamp(0.0, limites.height / 2);
        if (limites.height == 0) {
          return const LinearGradient(colors: [Colors.white, Colors.white])
              .createShader(limites);
        }
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            arriba > 0 ? Colors.transparent : Colors.white,
            arriba > 0 ? const Color(0x66FFFFFF) : Colors.white,
            Colors.white,
            Colors.white,
            abajo > 0 ? const Color(0x66FFFFFF) : Colors.white,
            abajo > 0 ? Colors.transparent : Colors.white,
          ],
          stops: [
            0,
            arriba * .4 / limites.height,
            arriba / limites.height,
            1 - abajo / limites.height,
            1 - abajo * .4 / limites.height,
            1,
          ],
        ).createShader(limites);
      },
      child: child,
    ),
  );
}

/// Suaviza el contenido que cruza el borde bajo el encabezado fijo.
/// La máscara sigue solamente este scroll, no las lecturas anidadas.
class DesplazamientoConFundido extends StatefulWidget {
  const DesplazamientoConFundido({
    super.key,
    required this.child,
    this.controller,
    this.padding,
  });

  final Widget child;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  @override
  State<DesplazamientoConFundido> createState() =>
      _DesplazamientoConFundidoState();
}

class _DesplazamientoConFundidoState extends State<DesplazamientoConFundido> {
  late ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = widget.controller ?? ScrollController();
  }

  @override
  void didUpdateWidget(DesplazamientoConFundido oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null) _scroll.dispose();
      _scroll = widget.controller ?? ScrollController();
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scroll,
    child: SingleChildScrollView(
      controller: _scroll,
      padding: widget.padding,
      child: widget.child,
    ),
    builder: (context, child) => ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (limites) {
        final profundidad = _scroll.hasClients
            ? _scroll.offset.clamp(0.0, 36.0)
            : 0.0;
        if (profundidad == 0 || limites.height == 0) {
          return const LinearGradient(colors: [Colors.white, Colors.white])
              .createShader(limites);
        }
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0x66FFFFFF), Colors.white],
          stops: [0, .4, 1],
        ).createShader(
          Rect.fromLTWH(limites.left, limites.top, limites.width, profundidad),
        );
      },
      child: child,
    ),
  );
}
