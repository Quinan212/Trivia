import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/almacenamiento/proveedores_almacenamiento.dart';
import 'package:trivia_antiguedad/compartido/componentes/boton_sonido.dart';
import 'package:trivia_antiguedad/compartido/componentes/entrada_inicio.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/bienvenida/componentes/puerta_bienvenida.dart';

import '../apoyo/base_pruebas.dart';

class _Destino extends StatelessWidget {
  const _Destino();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topRight,
    child: Padding(
      padding: const EdgeInsets.only(top: 26, right: 104),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.settings_outlined),
          Opacity(
            opacity: EntradaInicio.of(context)?.ocultarSonido == true ? 0 : 1,
            child: const BotonSonido(),
          ),
        ],
      ),
    ),
  );
}

double _opacidad(WidgetTester tester, Finder finder) => tester
    .widgetList<Opacity>(
      find.ancestor(of: finder, matching: find.byType(Opacity)),
    )
    .fold(1, (valor, widget) => valor * widget.opacity);

void main() {
  testWidgets(
    'Comenzar retira sonido sin moverlo y revela el de cabecera sin salto',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [const Size(1280, 800), const Size(800, 1280)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              almacenProvider.overrideWithValue(AlmacenMemoria()),
              respuestaInterfazProvider.overrideWithValue(
                const RespuestaSilenciosa(),
              ),
            ],
            child: MaterialApp(
              home: const PuertaBienvenida(
                revelarContenidoCompleto: true,
                tutorialAutomatico: false,
                anchoMenu: 1320,
                identidad: Text('Unidad IV'),
                child: _Destino(),
              ),
            ),
          ),
        );
        for (var i = 0; i < 65; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final origen = find.byKey(const ValueKey('sonido'));
        expect(origen, findsOneWidget);
        final rectInicial = tester.getRect(origen);
        await tester.tap(find.text('Comenzar'));
        await tester.pump();
        Rect? destino;
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          final botones = find.byKey(const ValueKey('sonido'));
          final visibles = <Finder>[];
          for (var j = 0; j < botones.evaluate().length; j++) {
            final boton = botones.at(j);
            if (_opacidad(tester, boton) > .001) {
              visibles.add(boton);
            }
          }
          expect(visibles.length, lessThanOrEqualTo(1));
          if (visibles.isNotEmpty) {
            final rect = tester.getRect(visibles.single);
            if (i < 12) {
              expect(rect, rectInicial);
            } else {
              destino ??= rect;
              expect(rect, destino);
            }
          }
        }
        expect(destino, isNotNull);
        expect(
          find.byKey(const ValueKey('sonido')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    },
  );
}
