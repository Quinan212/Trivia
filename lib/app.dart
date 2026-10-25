import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'funcionalidades/inicio/pantallas/pantalla_inicio.dart';
import 'funcionalidades/bienvenida/componentes/puerta_bienvenida.dart';
import 'compartido/movimiento/movimiento.dart';
import 'tema/tema_trivia_antiguedad.dart';
import 'funcionalidades/evaluacion/pantalla.dart';
import 'funcionalidades/evaluacion/acceso_tableta.dart';
import 'funcionalidades/evaluacion/configuracion.dart';
import 'funcionalidades/evaluacion/preferencias_evaluacion.dart';
import 'tema/paleta_evaluacion.dart';
import 'tema/tema_evaluacion.dart';

class TriviaAntiguedadApp extends ConsumerWidget {
  const TriviaAntiguedadApp({super.key, this.modoConversacion = false});
  final bool modoConversacion;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configuracion =
        ref.watch(configuracionEvaluacionProvider).value ??
        const ConfiguracionEvaluacion();
    final animar =
        ref.watch(permitirMovimientoProvider) &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    return MaterialApp(
      title: configuracion.titulo,
      debugShowCheckedModeBanner: false,
      theme: modoConversacion
          ? TemaTriviaAntiguedad.claro
          : temaEvaluacion(PaletaEvaluacion(configuracion.color)),
      themeAnimationDuration: animar ? duracionCambioPaleta : Duration.zero,
      themeAnimationCurve: curvaCambioPaleta,
      locale: const Locale('es', 'AR'),
      supportedLocales: const [Locale('es', 'AR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      navigatorObservers: [observadorPaginas],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              MediaQuery.disableAnimationsOf(context) ||
              !ref.watch(permitirMovimientoProvider),
        ),
        child: modoConversacion ? child! : AccesoTableta(child: child!),
      ),
      home: modoConversacion
          ? const PuertaBienvenida(child: PantallaInicio())
          : PuertaBienvenida(
              tutorialAutomatico: false,
              revelarContenidoCompleto: true,
              anchoMenu: 1320,
              lema: 'Evaluación individual',
              identidad: const MarcaEvaluacion(),
              child: const PantallaEvaluacion(),
            ),
    );
  }
}
