# Trivia de la antiguedad · Android

Base independiente de Che Preguntame, copiada el 21 de octubre de 2026. Se conserva el juego actual: cartas, continuaciones, dinámicas, reglas, pantallas, animaciones, imágenes, sonidos y fuentes. La paleta se actualizó a los colores de la portada Historia Antigua proporcionada por Alan: crema, rojo, marrón y rosas. El contenido todavía es el original de conversación; esta copia no incorpora preguntas históricas.

## Identidad

- Nombre de la app: **Trivia de la antiguedad**.
- Paquete Dart: `trivia_antiguedad`.
- Application ID y namespace Android: `ar.maillet.triviaantiguedad`.
- Clase principal: `TriviaAntiguedadApp`.
- Preferencias locales: prefijo `trivia_antiguedad_`.
- Versión heredada de la base: `1.0.0+6`.
- Firma de release propia, distinta de la original; archivos locales ignorados por Git: `android/key.properties` y `android/trivia-antiguedad-upload.jks`. Conservar ambos de forma privada para futuras actualizaciones. No publicar sus contraseñas.

El paquete independiente permite instalar ambas aplicaciones sin reemplazar la original ni compartir sus partidas. Los nombres de las imágenes y recursos Android se adaptaron conservando sus bytes. El logo y el icono siguen mostrando el diseño original por pedido de conservar los gráficos. Solo se actualizó el nombre de la aplicación en los títulos, etiquetas y política de privacidad; las cartas no se modificaron.

## Desarrollo

Abrir `Trivia de la antiguedad.code-workspace` y ejecutar la configuración Android de VS Code, o usar:

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release
```

`scripts/depurar.ps1` permite iniciar la depuración con el emulador local. La app sigue siendo gratuita y sin conexión, con todos sus datos locales.

Para trabajar en tableta se preparó `Trivia_Antiguedad_Tablet_API_36`, un AVD Pixel Tablet de 2560×1600, 320 dpi y Android 16. `scripts/tableta.ps1` abre ese emulador y la app instalada; con `-Depurar` ejecuta Flutter sobre él. También está disponible la configuración **Tableta · Trivia de la antiguedad** en VS Code. En esta etapa solo se preparó el entorno: la distribución sigue siendo la de la base para adaptarla en el siguiente trabajo. Paleta y alcance: `docs/paleta-portada/GUIA.md`; verificación actual: `qa/paleta-tableta/`.

Compilar release con la resolución normal de dependencias regenera el registro nativo sin los plugins exclusivos de pruebas. No ejecutar pruebas y compilación simultáneamente, porque comparten archivos generados de Flutter.

## Archivos heredados y verificación

`heredado-original/` conserva íntegros la documentación, los scripts y las evidencias QA del proyecto original, con sus nombres y referencias históricas. Sus APK y resultados corresponden a Che Preguntame y no acreditan esta copia. No ejecutar esos scripts contra la copia: algunos instalan binarios o limpian datos del paquete original. La documentación histórica puede contener decisiones ya superadas.

Las cachés, compilaciones anteriores, estado del IDE y credenciales de firma originales se excluyeron; Flutter regenera los archivos de trabajo. Las dependencias y su lockfile se conservaron.

Las verificaciones de esta app se guardan exclusivamente en `qa/clonacion/`. `assets.json` registra las huellas SHA-256 del original y la copia: todos los recursos son idénticos salvo la sustitución del nombre en la política de privacidad. `identidad.json` registra los identificadores adaptados y el origen.
