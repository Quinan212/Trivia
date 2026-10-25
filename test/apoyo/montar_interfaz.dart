import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivia_antiguedad/app.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/controladores/controlador_partida.dart';
import 'package:trivia_antiguedad/funcionalidades/partida/dominio/reloj_carta.dart';
import 'package:trivia_antiguedad/funcionalidades/ajustes/datos/repositorio_experiencia.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/compartido/movimiento/movimiento.dart';

import 'base_pruebas.dart';

Future<void> montar(
  WidgetTester tester,
  AlmacenMemoria almacen, {
  bool primeraVez = false,
  bool animaciones = false,
  RespuestaInterfaz respuesta = const RespuestaSilenciosa(),
  RelojCarta? reloj,
  bool completarEntrada = true,
}) async {
  if (!primeraVez) {
    almacen.datos.putIfAbsent(
      RepositorioExperiencia.clave,
      () => '{"version":1,"tutorialVisto":true,"sonidos":true}',
    );
  }
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        almacenProvider.overrideWithValue(almacen),
        preguntasProvider.overrideWithValue(PreguntasFijas(catalogoReal())),
        respuestaInterfazProvider.overrideWithValue(respuesta),
        permitirMovimientoProvider.overrideWithValue(animaciones),
        intervaloRespaldoProvider.overrideWithValue(null),
        if (reloj != null) relojCartaProvider.overrideWithValue(reloj),
      ],
      child: const TriviaAntiguedadApp(modoConversacion: true),
    ),
  );
  if (completarEntrada) {
    await tester.pumpAndSettle();
    await tocar(tester, 'comenzar-bienvenida');
  } else {
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }
}

Future<void> tocar(WidgetTester tester, String clave) async {
  final elemento = find.byKey(ValueKey(clave));
  await tester.ensureVisible(elemento);
  await tester.tap(elemento);
  await tester.pumpAndSettle();
}
