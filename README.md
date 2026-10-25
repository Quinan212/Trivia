# Trivia

Aplicación Flutter de evaluación para tabletas Android, en horizontal y vertical. Funciona sin conexión, sin cuentas, anuncios ni servicios externos. La materia, unidad, docente, ayudante y paleta de colores se pueden configurar.

## Funciones

- Bancos de preguntas por JSON con temas, cuatro alternativas y explicación. Incluye el banco original de 200 preguntas de Unidad IV.
- Carga de estudiantes por JSON, plantilla descargable y restauración de la lista inicial. La pulsación prolongada permite corregir un nombre o eliminar antes de iniciar.
- Hasta 20 estudiantes y 10 preguntas distintas reservadas por cada estudiante registrado. Se verifica la capacidad del banco antes de comenzar.
- Tiempo manual de 60 segundos, respuestas desde A–D, hasta dos robos por pregunta y Deshacer. Un acierto suma 1 punto y un robo correcto 2, con tope de 10. Desde 7 puntos se puede cerrar la evaluación de esa persona o continuar; al alcanzar 10 termina su participación.
- Guardado local, recuperación con tiempo pausado e historial de evaluaciones.
- Informes individuales en PDF y descarga de todos los informes reunidos en un único documento, con portada y numeración propia por estudiante.
- Sonidos, movimiento reducido y cinco paletas. Icono propio de diálogo multicolor.

La interfaz requiere una ventana de tableta con lado menor de al menos 600 dp. No incluye una versión para teléfonos.

## Desarrollo

Entorno usado: Flutter 3.47.2 / Dart 3.13.2, Java 17 y Android SDK con API 36. Android mínimo 24. El paquete es `ar.maillet.triviaantiguedad`; el nombre visible es **Trivia**.

```sh
git clone https://github.com/Quinan212/Trivia.git
cd Trivia
flutter pub get
flutter run
```

Seleccioná una tableta o un emulador desde tu entorno de desarrollo. Cada máquina configura su SDK localmente; `android/local.properties` no se versiona.

```sh
flutter analyze --no-pub lib
flutter test --no-pub test/evaluacion/motor_test.dart test/evaluacion/banco_personalizado_test.dart test/evaluacion/estudiantes_json_test.dart
```

Las pruebas visuales y algunas herramientas de emulador conservan rutas del entorno Windows original; ajustalas antes de usarlas en otra máquina. No ejecutes pruebas y compilaciones simultáneamente sobre el mismo proyecto.

## Compilar una versión de publicación

La firma activa de Trivia y su configuración están incluidas por indicación del propietario:

- `android/firma-google-play/trivia-upload-keystore.jks`: almacén de firma.
- `android/key.properties`: configuración que utiliza Gradle, con ruta relativa al almacén.
- `android/firma-google-play/credenciales.properties`: copia de la configuración de firma.

Las firmas anteriores y sus respaldos permanecen fuera del repositorio. Para usar otra firma, configurá localmente `android/key.properties` a partir de `android/key.properties.example`.

```sh
flutter build apk --release --split-per-abi --target-platform android-arm64,android-x64 --obfuscate --split-debug-info=output/simbolos
```

Las APK se generan en `build/app/outputs/flutter-apk/`. Los símbolos y los resultados de compilación permanecen locales. Para Google Play se puede generar un Android App Bundle con `flutter build appbundle --release` usando la firma de publicación correspondiente.

El [certificado público de carga](docs/certificados/trivia-upload-certificate.pem) está disponible en el repositorio; su [huella SHA-256](docs/certificados/README.md) permite verificarlo.

## Plantillas

- [Preguntas](output/Plantilla-banco-preguntas.json) · [Guía de bancos](output/Guia-bancos-JSON.md)
- [Estudiantes](output/Plantilla-estudiantes.json) · [Guía de estudiantes](output/Guia-estudiantes-JSON.md)

La plantilla de preguntas usa `formato: banco-trivia`, versión 1; la de estudiantes, `formato: estudiantes-trivia`, versión 1. Cancelar una carga o un archivo inválido conserva los datos anteriores. Reemplazar banco o estudiantes durante una evaluación requiere confirmar una nueva evaluación; la anterior queda guardada.

## Estructura

- `lib/funcionalidades/evaluacion/`: modelos, reglas, carga JSON, controlador, almacenamiento, pantallas y PDF.
- `lib/compartido/` y `lib/tema/`: componentes, sonido, movimiento y paletas.
- `assets/`: preguntas, lista inicial, fuentes, identidad gráfica, ilustraciones y sonidos.
- `android/`: aplicación Android y configuración Gradle.
- `test/`, `integration_test/`, `test_driver/`: pruebas.
- `scripts/`: generación de recursos y herramientas de desarrollo.

Las APK históricas, capturas, respaldos, archivos temporales y notas internas de trabajo no se publican. El banco original de preguntas se conserva literalmente; los cambios de contenido se realizan mediante bancos JSON personalizados.
