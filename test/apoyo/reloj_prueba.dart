import 'package:trivia_antiguedad/funcionalidades/partida/dominio/reloj_carta.dart';

class RelojPrueba implements RelojCarta {
  bool activo = false;
  int acumulado = 0;
  void pasar(int milisegundos) {
    if (activo) acumulado += milisegundos;
  }

  @override
  void iniciar() => activo = true;
  @override
  void detener() => activo = false;
  @override
  int tomarMilisegundos() {
    final valor = acumulado;
    acumulado = 0;
    return valor;
  }
}
