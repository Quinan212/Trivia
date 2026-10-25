import 'package:shared_preferences/shared_preferences.dart';

/// Permite probar repositorios sin depender de un plugin ni del emulador.
abstract interface class AlmacenPreferencias {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
}

class PreferenciasAndroid implements AlmacenPreferencias {
  PreferenciasAndroid() : _preferencias = SharedPreferencesAsync();
  final SharedPreferencesAsync _preferencias;
  @override
  Future<String?> leer(String clave) => _preferencias.getString(clave);
  @override
  Future<void> escribir(String clave, String valor) =>
      _preferencias.setString(clave, valor);
}
