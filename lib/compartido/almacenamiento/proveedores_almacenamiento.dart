import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'almacen_preferencias.dart';

final almacenProvider = Provider<AlmacenPreferencias>(
  (ref) => PreferenciasAndroid(),
);
