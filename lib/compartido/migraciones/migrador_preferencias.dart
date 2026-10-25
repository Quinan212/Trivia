import '../almacenamiento/almacen_preferencias.dart';

abstract final class MigradorPreferencias {
  static const claveVersion = 'trivia_antiguedad_esquema_preferencias';
  static const versionActual = 1;
  static Future<void> ejecutar(AlmacenPreferencias almacen) async {
    final anterior = int.tryParse(await almacen.leer(claveVersion) ?? '0') ?? 0;
    if (anterior > versionActual) {
      throw const FormatException('Formato de preferencias más reciente.');
    }
    if (anterior == versionActual) return;
    // Las próximas migraciones se agregan por versión y con claves propias.
    await almacen.escribir(claveVersion, versionActual.toString());
  }
}
