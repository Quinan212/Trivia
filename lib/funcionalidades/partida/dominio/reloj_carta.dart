import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class RelojCarta {
  void iniciar();
  int tomarMilisegundos();
  void detener();
}

class RelojMonotono implements RelojCarta {
  final _reloj = Stopwatch();
  @override
  void iniciar() => _reloj.start();
  @override
  int tomarMilisegundos() {
    final tiempo = _reloj.elapsedMilliseconds;
    _reloj.reset();
    return tiempo;
  }

  @override
  void detener() => _reloj.stop();
}

final relojCartaProvider = Provider<RelojCarta>((ref) => RelojMonotono());
final intervaloRespaldoProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: 10),
);
