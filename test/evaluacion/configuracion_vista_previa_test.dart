import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/almacenamiento/proveedores_almacenamiento.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/configuracion.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/controlador.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/pantalla.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/preferencias_evaluacion.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/repositorio.dart';
import 'package:trivia_antiguedad/tema/paleta_evaluacion.dart';
import 'package:trivia_antiguedad/tema/tema_evaluacion.dart';

import '../apoyo/base_pruebas.dart';
import 'motor_test.dart' show muestra;

class _Repo extends RepositorioEvaluacion {
  _Repo() : super(Directory.systemTemp);
  String? ultimo;
  @override
  Future<void> guardar(String raw) async {
    ultimo = raw;
  }
}

void main() {
  testWidgets(
    'previsualiza pantalla y diálogo sin guardar; cancelar revierte y guardar confirma',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final almacen = AlmacenMemoria();
      final repo = _Repo();
      final c = ControladorEvaluacion(muestra(2), repo, temporizador: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            almacenProvider.overrideWithValue(almacen),
            respuestaInterfazProvider.overrideWithValue(
              const RespuestaSilenciosa(),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final config =
                  ref.watch(configuracionEvaluacionProvider).value ??
                  const ConfiguracionEvaluacion();
              return MaterialApp(
                theme: temaEvaluacion(PaletaEvaluacion(config.color)),
                home: PantallaEvaluacion(controlador: c),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      ColorEvaluacion colorPantalla() =>
          PaletaEvaluacion.of(tester.element(find.byType(PantallaEvaluacion)))
              .tipo;
      Future<void> elegir(String color) async {
        await tester.ensureVisible(find.byTooltip(color));
        await tester.tap(find.byTooltip(color));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const ValueKey('configuracion-evaluacion')));
      await tester.pumpAndSettle();
      await elegir('Amarillo');
      expect(colorPantalla(), ColorEvaluacion.amarillo);
      expect(
        PaletaEvaluacion.of(tester.element(find.byType(Dialog))).tipo,
        ColorEvaluacion.amarillo,
      );
      expect(c.sesion.configuracion.color, ColorEvaluacion.rojo);
      expect(repo.ultimo, isNull);
      expect(almacen.datos[PreferenciasEvaluacion.clave], isNull);
      final estilo = DefaultTextStyle.of(tester.element(find.text('Guardar')))
          .style;
      expect(estilo.color, Colors.black);
      expect(estilo.shadows, isNull);
      final tema = Theme.of(tester.element(find.byType(Dialog)));
      expect(
        tema.switchTheme.trackOutlineColor!.resolve({WidgetState.selected}),
        const PaletaEvaluacion(ColorEvaluacion.amarillo).borde,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(colorPantalla(), ColorEvaluacion.rojo);
      expect(repo.ultimo, isNull);
      await tester.tap(find.byKey(const ValueKey('configuracion-evaluacion')));
      await tester.pumpAndSettle();
      await elegir('Azul');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(colorPantalla(), ColorEvaluacion.azul);
      expect(c.sesion.configuracion.color, ColorEvaluacion.azul);
      expect(
        (jsonDecode(repo.ultimo!) as Map)['configuracion']['color'],
        'azul',
      );
      expect(
        (jsonDecode(almacen.datos[PreferenciasEvaluacion.clave]!)
            as Map)['color'],
        'azul',
      );
      await tester.tap(find.byKey(const ValueKey('configuracion-evaluacion')));
      await tester.pumpAndSettle();
      await elegir('Verde');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(colorPantalla(), ColorEvaluacion.azul);
      expect(c.sesion.configuracion.color, ColorEvaluacion.azul);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.pump();
      await c.guardadoPendiente;
    },
  );
}
