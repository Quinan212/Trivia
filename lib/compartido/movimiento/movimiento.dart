import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tema/tema_trivia_antiguedad.dart';

final permitirMovimientoProvider = Provider<bool>((ref) => true);

Duration duracionMovimiento(BuildContext context, int milisegundos) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milisegundos);

class EntradaSuave extends StatelessWidget {
  const EntradaSuave({super.key, required this.child, this.demora = 0});
  final Widget child;
  final int demora;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 480 + demora),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, valor, child) {
        final progreso =
            ((valor - demora / (480 + demora)) / (1 - demora / (480 + demora)))
                .clamp(0.0, 1.0);
        return Opacity(
          opacity: progreso,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - progreso)),
            child: child,
          ),
        );
      },
    );
  }
}

class ToqueConRebote extends StatefulWidget {
  const ToqueConRebote({super.key, required this.child});
  final Widget child;
  @override
  State<ToqueConRebote> createState() => _ToqueConReboteState();
}

class _ToqueConReboteState extends State<ToqueConRebote> {
  bool _presionado = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => _presionado = true),
    onPointerUp: (_) => setState(() => _presionado = false),
    onPointerCancel: (_) => setState(() => _presionado = false),
    child: AnimatedScale(
      scale: !MediaQuery.disableAnimationsOf(context) && _presionado
          ? 0.975
          : 1,
      duration: duracionMovimiento(context, _presionado ? 80 : 180),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}

class AdornoVivo extends StatefulWidget {
  const AdornoVivo({super.key, required this.child});
  final Widget child;
  @override
  State<AdornoVivo> createState() => _AdornoVivoState();
}

class _AdornoVivoState extends State<AdornoVivo>
    with SingleTickerProviderStateMixin {
  late final _reloj = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _reloj.stop();
      _reloj.value = 0;
    } else if (!_reloj.isAnimating) {
      _reloj.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _reloj,
      child: widget.child,
      builder: (context, child) {
        final fase = Curves.easeInOutSine.transform(_reloj.value);
        return Transform.rotate(
          angle: math.pi / 180 * (fase * 2.2 - 1.1),
          child: Transform.scale(scale: 1 + fase * 0.025, child: child),
        );
      },
    ),
  );
}

class CambioSuave extends StatelessWidget {
  const CambioSuave({super.key, required this.child, this.duracion = 320});
  final Widget child;
  final int duracion;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: duracionMovimiento(context, duracion),
    reverseDuration: duracionMovimiento(context, 160),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (actual, anteriores) =>
        Stack(alignment: Alignment.topLeft, children: [...anteriores, ?actual]),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0.04, 0.025),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: child,
  );
}

class TamanoSuave extends StatelessWidget {
  const TamanoSuave({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: child,
        );
}

PageRoute<T> rutaSuave<T>(BuildContext context, Widget pantalla) =>
    PageRouteBuilder<T>(
      transitionDuration: duracionMovimiento(context, 380),
      reverseTransitionDuration: duracionMovimiento(context, 260),
      pageBuilder: (_, _, _) => pantalla,
      transitionsBuilder: (_, animacion, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animacion, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(begin: const Offset(0.05, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animacion, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      ),
    );

final observadorPaginas = RouteObserver<PageRoute<dynamic>>();

class AparicionBreve extends StatelessWidget {
  const AparicionBreve({super.key, required this.child, this.demora = 0});
  final Widget child;
  final int demora;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + demora),
      child: child,
      builder: (context, t, child) {
        final p = Curves.easeOutCubic.transform(
          ((t * (240 + demora) - demora) / 240).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - p)),
            child: child,
          ),
        );
      },
    );
  }
}

class CelebracionBreve extends StatelessWidget {
  const CelebracionBreve({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      if (!MediaQuery.disableAnimationsOf(context))
        Positioned(
          top: -30,
          right: 8,
          width: 92,
          height: 80,
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                builder: (context, p, _) =>
                    CustomPaint(painter: _TrazosCelebracion(p)),
              ),
            ),
          ),
        ),
    ],
  );
}

class _TrazosCelebracion extends CustomPainter {
  const _TrazosCelebracion(this.progreso);
  final double progreso;
  @override
  void paint(Canvas canvas, Size size) {
    final opacidad = (progreso < .2 ? progreso / .2 : (1 - progreso) / .8)
        .clamp(0.0, 1.0);
    final pintura = Paint()
      ..color = TemaTriviaAntiguedad.naranja.withValues(alpha: opacidad)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final centro = Offset(size.width / 2, size.height * .75);
    for (var i = 0; i < 5; i++) {
      final angulo = math.pi * (1.10 + i * .20);
      final direccion = Offset(math.cos(angulo), math.sin(angulo));
      canvas.drawLine(
        centro + direccion * (14 + progreso * 12),
        centro + direccion * (22 + progreso * 22),
        pintura,
      );
    }
  }

  @override
  bool shouldRepaint(_TrazosCelebracion oldDelegate) =>
      oldDelegate.progreso != progreso;
}
