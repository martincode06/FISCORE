# FISCORE

Marcador Android de básquet, en español y horizontal, desarrollado con Flutter y el SDK Android de esta laptop. Versión 1.5.0.

## Uso

1. Configurar partido: accesos a 4 × 10 y 2 × 10 minutos, cantidad de 1 a 12 tiempos, duración de 1 a 99 minutos y prórroga de 1 a 30. Los valores se cambian con +/−. Guardar actualiza también el reloj conservando el tiempo ya jugado.
2. Jugadores: el lápiz edita nombre y dorsal. Para 88, toca 8 y 8 en el panel de dígitos; incluye 0, 00 y borrar, sin teclado numérico de Android. El nombre se mantiene visible sobre el teclado y se guarda con Guardar o Listo.
3. Los jugadores con más faltas aparecen primero, tanto en Jugadores como en el panel de faltas. En empate se ordenan por dorsal. Se recalcula al sumar, quitar o deshacer; la plantilla guardada y los identificadores de cada jugador se mantienen.
4. INICIAR y PAUSAR controlan el reloj principal. El botón de reloj permite corregir minutos y segundos con +/−. El último minuto muestra décimas.
5. Suma puntos con +1, +2 y +3. Corregir transforma los mismos botones en −1, −2 y −3, de forma independiente por equipo. Las restas que dejarían puntos negativos se deshabilitan. Deshacer revierte el último cambio de puntos o faltas.
6. Faltas + / − pausa el partido. Elige el tipo y usa los controles de cada jugador; se guarda al tocar. El menos retira la última falta de ese tipo de ese jugador. El panel vuelve arriba para mostrar el nuevo orden y resalta al jugador modificado.
7. Los dos accesos principales son Marcador y Jugadores. Se retiraron la pestaña Registro y la franja inferior de estado. El guardado automático continúa; los errores se avisan en pantalla.
8. Los tres puntos permiten probar la chicharra con el reloj pausado, abrir Mis equipos, consultar reglas, finalizar y empezar un partido nuevo. La señal de período utiliza el clip elegido por el usuario, Official NBA Horn SFX; la de posesión usa un fragmento corto distinto.
9. (?) abre los créditos: Martin Villy, consultas, contrataciones y donaciones al 925 449 100, copia del número y la nota «Tu apoyo voluntario ayuda a mejorar FISCORE. ¡Gracias!».

## Mis equipos

Abre el icono de personas de la barra superior o Mis equipos en los tres puntos.

- Guardar LOCAL o Guardar VISITANTE guarda la plantilla de ese lado con el nombre que elijas. Por ejemplo, guarda FIAI con sus doce jugadores y dorsales después de editarlos.
- Si ya existe un equipo con ese nombre, se pide confirmar su actualización. Guardar no añade puntos ni faltas a la plantilla y no modifica el partido actual.
- Toca un equipo guardado para consultar sus jugadores. Usa Usar como local o Usar como visitante para cargarlo en otro encuentro.
- Se recuperan el nombre del equipo, los nombres de los jugadores y sus dorsales. El equipo cargado comienza con cero puntos y cero faltas; el otro equipo y el reloj se conservan.
- Si el lado elegido tiene puntos o faltas, se pide confirmar su reemplazo. Si el partido ya terminó, se ofrece iniciar otro partido en cero antes de cargar la plantilla.
- Los equipos se almacenan por separado del partido y siguen disponibles al empezar otro encuentro o reabrir la app. Los cambios posteriores de un jugador no alteran una plantilla guardada hasta que la actualices.

## Posesión y faltas

24 s y 14 s reinician la posesión manualmente. Sumar puntos o faltas no la cambia automáticamente. INICIAR/PAUSAR coordina ambos relojes; la posesión tiene pausa independiente. Sus tres puntos permiten ajustar segundos y décimas, apagarla o consultar ayuda. Una nueva cuenta más larga que el tiempo restante queda sin cuenta; no se apaga una cuenta ya en marcha por bajar de 14 segundos. Al agotarse, el operador decide si corresponde pausar según la jugada y el árbitro. El fin de período tiene prioridad si ambos relojes vencen a la vez.

Cinco faltas acumuladas excluyen al jugador durante todo el partido. Dos T, dos U, T + U o una D lo descalifican. Las faltas de equipo se reinician por tiempo reglamentario; las prórrogas conservan las del último. Desde la cuarta se indica la penalización y desde la quinta se avisa. Las faltas de sustitutos T/U/D no suman al equipo si se desactiva En cancha. El formato 4 × 10 sigue la base FIBA; los personalizados mantienen el conteo por tiempo y cinco faltas individuales. El árbitro determina las sanciones; no se conceden tiros ni puntos automáticamente. No se incluyen faltas del entrenador ni del resto del banco.

Referencia: [Reglas Oficiales FIBA 2024 v1.0a](https://assets.fiba.basketball/image/upload/documents-corporate-fiba-official-rules-2024-v10a.pdf), artículos 8, 29, 36, 37, 40, 41, 49 y 50.

## Guardado e instalación

El partido se guarda después de cada cambio y cada segundo durante el juego. Al salir se pausa y se recupera pausado. La pantalla permanece encendida. El audio utiliza el volumen de alarmas. Funciona sin cuenta ni internet; guarda un partido y varias plantillas de equipos. Desinstalar borra estos datos.

Envía entrega/FISCORE.apk, versión 1.5.0, por WhatsApp como documento. También está en entrega/fiscore-v1.5.0.apk. Instálala sobre la versión anterior, sin desinstalar, para conservar el partido y las plantillas: se mantienen el paquete y la firma. Es una APK con firma de desarrollo para instalación directa, no una publicación en Google Play.

## Desarrollo

Para trabajar con una copia del repositorio, instala Flutter 3.44.4 o compatible con Dart 3.12.2, Java 17 y el SDK Android 36. Configura Flutter y Android SDK en tu equipo y, desde la carpeta del proyecto, ejecuta:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

La primera descarga de dependencias necesita conexión. Después puedes usar `./build-apk.ps1` con la caché local; el script también copia la APK y calcula su SHA-256. Las rutas locales del SDK, las cachés y las claves de firma no se guardan en Git. Los audios finales ya están incluidos: no hace falta ejecutar el conversor para compilar la app.

- lib/game.dart: reglas, reloj, correcciones, orden de jugadores y serialización.
- lib/main.dart: interfaz y ciclo de vida.
- lib/match_panels.dart, lib/app_widgets.dart y lib/player_editor.dart: controles y paneles adaptables.
- lib/saved_teams.dart y lib/saved_teams_panel.dart: biblioteca de plantillas.
- lib/app_credits.dart: créditos, contacto y atribución del audio.
- android/app/src/main/kotlin/pe/marti/score_basquet/MainActivity.kt: almacenamiento nativo y reproducción de audio.
- tools/prepare_selected_horn.py: conversión y preparación del clip seleccionado, con un conversor de desarrollo en build/audio-tools; no se incluye ese conversor en la APK.
- THIRD_PARTY_NOTICES.md: procedencia del audio y recursos de terceros.

./build-apk.ps1 resuelve paquetes desde la caché, analiza, prueba, compila y entrega ambas APKs y el SHA-256. Acepta -FlutterRoot si Flutter no está en PATH.
