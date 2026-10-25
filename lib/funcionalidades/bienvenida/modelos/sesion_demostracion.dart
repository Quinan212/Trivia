import 'package:flutter/foundation.dart';

import '../../../compartido/movimiento/coordinador_carta.dart';
import '../../partida/modelos/catalogo_preguntas.dart';
import '../../partida/modelos/estado_partida.dart';
import '../../partida/modelos/pregunta.dart';

/// Datos de práctica en memoria, sin repositorio ni acceso al progreso real.
class SesionDemostracion extends ChangeNotifier {
  SesionDemostracion({bool tutorial = false}) {
    if (tutorial) {
      // Ejemplos breves para leer ambas caras completas al practicar.
      // Las cartas largas y la consigna sin reverso quedan en el laboratorio.
      cartas = const [
        Pregunta(
          id: 'ejemplo-1',
          nivel: 1,
          tema: 'Cotidiano',
          texto: 'Decí una maña tuya.',
          repregunta: '¿Cuándo aparece?',
        ),
        Pregunta(
          id: 'ejemplo-2',
          nivel: 1,
          tema: 'Vínculos',
          texto: '¿Qué comida defendés?',
          repregunta: '¿Quién te hace segunda?',
        ),
        Pregunta(
          id: 'ejemplo-3',
          nivel: 1,
          tema: 'Cotidiano',
          texto: 'Completá: «Ya voy significa…».',
          repregunta: '¿Cuánto tardás de verdad?',
        ),
      ];
    }
  }
  int nivel = 1;
  int indice = 0;
  int pasadas = 0;
  final Set<String> _pasadas = {};
  List<Pregunta> cartas = const [
    Pregunta(
      id: 'ejemplo-1',
      nivel: 1,
      tema: 'Cotidiano',
      texto: 'Decí una canción que te sabés entera. Los demás adivinan cómo la aprendiste.',
      repregunta: 'Contá la historia real.',
    ),
    Pregunta(
      id: 'ejemplo-2',
      nivel: 1,
      tema: 'Vínculos',
      texto: 'Están terminando de comer y alguien propone dividir la cuenta por igual. Vos pediste algo mucho más barato que el resto. Decí qué harías en esa mesa, aunque te dé vergüenza tener que explicar por qué preferís pagar tu parte.',
      repregunta: '¿Cambia tu respuesta según quién esté?',
    ),
    Pregunta(
      id: 'ejemplo-3',
      nivel: 1,
      tema: 'Consigna',
      texto: 'Cada uno dice una comida que le encanta y otra que no soporta. Los demás adivinan cuál es cuál.',
    ),
  ];
  bool get terminada => indice >= cartas.length;
  void seleccionar(int valor) {
    nivel = valor;
    notifyListeners();
  }

  void confirmar(AccionCarta accion) {
    if (accion == AccionCarta.girar || terminada) return;
    if (accion == AccionCarta.pasar) {
      pasadas++;
      _pasadas.add(cartas[indice].id);
    }
    indice++;
    notifyListeners();
  }

  void reiniciar() {
    indice = 0;
    pasadas = 0;
    _pasadas.clear();
    notifyListeners();
  }

  CatalogoPreguntas get catalogo => CatalogoPreguntas(
    version: 'ejemplo',
    cartas: [
      ...cartas,
      for (final nivel in [0, 2, 3])
        Pregunta(
          id: 'solo-catalogo-$nivel',
          nivel: nivel,
          tema: 'Ejemplo',
          texto: 'Ejemplo',
        ),
    ],
  );
  EstadoPartida get cierreEjemplo => EstadoPartida(
    nivel: nivel,
    cartas: cartas.map((c) => c.id).toList(),
    versionContenido: 'ejemplo',
    ronda: 0,
    inicio: DateTime(2026),
    indice: cartas.length,
    pasadas: pasadas,
    cartasPasadas: Set.of(_pasadas),
    tiemposMs: {cartas[0].id: 64000, cartas[1].id: 48000, cartas[2].id: 26000},
  );
}
