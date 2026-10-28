# Verificación de FISCORE 1.5.0

## Comprobaciones automáticas

- Análisis Flutter/Dart sin problemas.
- 55 pruebas superadas: reglas, relojes, posesión, guardado, correcciones, formatos, nombres, dorsales, orden de faltas y biblioteca de equipos.
- Interfaz y paneles probados en 568 × 280, 640 × 320, 640 × 360, 800 × 360, 1000 × 450 y 1280 × 800; texto ampliado al 130 %.
- Pruebas de nombre visible con teclado de 200 px en 568 × 280, 640 × 320 y 800 × 360. Se mantiene el guardado con Listo y Guardar cuando hay altura suficiente.
- Más faltas primero: cambios al sumar, quitar y deshacer; empate por dorsal, 0 y 00 diferenciados; no se altera la plantilla ni se asignan faltas a otro jugador al mover sus controles. Las pruebas incluyen desplazarse hasta el último jugador.
- Mis equipos: nombres y dorsales sin puntos, faltas ni referencias compartidas; carga en cualquiera de los lados; actualización por nombre sin duplicados; conservación de otro equipo y reloj; confirmación y cancelación de reemplazo; inicio de otro partido al cargar después de finalizar. Recuperación y reintento de errores de almacenamiento sin sobrescribir una biblioteca dañada.
- Acceso 2 × 10 aplicado al reloj y ajustes con +/−. Los formatos personalizados siguen permitiendo otras duraciones.
- Ausencia de la pestaña Registro y del footer de guardado/estado.

## Comprobaciones en Android

- Prueba aislada en Pixel 8, 1600 × 720 y 320 dpi. No se instaló nada en el celular.
- Se editó el primer jugador a dorsal 88 y nombre Ana. Tras registrar una falta al dorsal 5, se guardó una plantilla llamada FIAI.
- Se forzó el cierre y reabrió la app: FIAI y el jugador 88 Ana siguieron en Mis equipos.
- FIAI cargado como visitante: el dorsal 5 mostró Personal: 0 y 0/5. El equipo local conservó sus faltas. Después de añadir dos al dorsal 6, el local mostró 3 de equipo y FIAI 0 de equipo.
- El dorsal 6 con 2/5 apareció encima del dorsal 5 con 1/5 en Android. Los controles se mantuvieron asociados al jugador correcto.
- Configuración 2 × 10 y créditos con consultas, contrataciones y donaciones comprobados en la APK. Capturas actuales: android-marcador.png, android-configuracion.png, android-faltas.png, android-jugadores.png, android-equipos.png y android-creditos.png.
- SoundPool confirmó la carga de los dos recursos del clip Official NBA Horn SFX y la reproducción de la señal de período desde Probar chicharra. La prueba usa un emulador sin salida de audio; la muestra Chicharra-NBA-FISCORE.wav permite escuchar el sonido que se incluyó.
- El audio del período dura 5 s y la posesión 0,6 s, ambos mono PCM 16 bits a 44 100 Hz, con extremos en cero y sin recorte digital de amplitud. Sus contenidos SHA-256 coinciden con los WAV dentro de la APK, aunque Android renombre los recursos. La muestra coincide con el audio de período.

## APK entregada

- Versión 1.5.0, código 6, etiqueta FISCORE, paquete pe.marti.score_basquet.
- Android 7.0/API 24 o posterior; SDK objetivo 36; ARM de 32 y 64 bits y x86_64.
- Tamaño: 50 797 408 bytes. Firma de desarrollo v2 verificada con apksigner; se mantiene la clave de las versiones anteriores.
- FISCORE.apk y fiscore-v1.5.0.apk tienen el mismo SHA-256: 71ED148B059AA37283ADC90A6F533AB5E21E380CB8FFFD01F2E12DFF363D813A.
- No hay permiso de Internet ni permisos de acceso a datos personales. El conversor de audio es una herramienta de desarrollo y no forma parte de la APK.

Esta versión se verificó automáticamente y en el emulador; no se probó en el celular físico. La aplicación lleva conteos y no sustituye un acta oficial ni decide sanciones arbitrales.
