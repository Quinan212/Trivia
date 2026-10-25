import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/almacenamiento/proveedores_almacenamiento.dart';
import '../datos/repositorio_experiencia.dart';
import '../modelos/ajustes_experiencia.dart';

final experienciaProvider =
    AsyncNotifierProvider<ControladorExperiencia, AjustesExperiencia>(
      ControladorExperiencia.new,
    );

class ControladorExperiencia extends AsyncNotifier<AjustesExperiencia> {
  Future<void> _cola = Future.value();
  RepositorioExperiencia get _repo =>
      RepositorioExperiencia(ref.read(almacenProvider));
  @override
  Future<AjustesExperiencia> build() => _repo.cargar();

  Future<void> _actualizar(AjustesExperiencia ajustes) {
    state = AsyncData(ajustes.copyWith(limpiarAviso: true));
    _cola = _cola.then((_) async {
      try {
        await _repo.guardar(ajustes);
      } on Object {
        if (!ref.mounted || !state.hasValue) return;
        state = AsyncData(
          state.requireValue.copyWith(
            aviso: 'No pudimos guardar esta preferencia. Probá de nuevo.',
          ),
        );
      }
    });
    return _cola;
  }

  Future<void> marcarTutorialVisto() =>
      _actualizar(state.requireValue.copyWith(tutorialVisto: true));
  Future<void> alternarSonidos() => _actualizar(
    state.requireValue.copyWith(sonidos: !state.requireValue.sonidos),
  );
  Future<void> alternarVibracion() => _actualizar(
    state.requireValue.copyWith(vibracion: !state.requireValue.vibracion),
  );
  void cerrarAviso() =>
      state = AsyncData(state.requireValue.copyWith(limpiarAviso: true));
}
