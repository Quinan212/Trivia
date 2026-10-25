import 'package:flutter/material.dart';

import '../../tema/paleta_evaluacion.dart';

/// La evaluación solo se monta en superficies de tableta, en ambas orientaciones.
class AccesoTableta extends StatelessWidget {
  const AccesoTableta({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class PantallaSoloTabletas extends StatelessWidget {
  const PantallaSoloTabletas({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: PaletaEvaluacion.of(context).fondo,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: PaletaEvaluacion.of(context).salviaClara,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: PaletaEvaluacion.of(context).borde),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tablet_android_rounded,
                    size: 64,
                    color: PaletaEvaluacion.of(context).naranjaTexto,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Ups, esta app es para tabletas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: PaletaEvaluacion.of(context).tinta,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No está disponible para teléfonos móviles.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: PaletaEvaluacion.of(context).tenue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
