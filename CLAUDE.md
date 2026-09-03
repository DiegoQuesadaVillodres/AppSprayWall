# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Lo primero que hay que entender

**Este repositorio no contiene el código de la app.** Es un repo de *assets y documentación*: fotos
de los muros, scripts para prepararlas, el logo, el QR, las capturas del manual y los documentos de
análisis. No hay `package.json`, ni build, ni tests, ni siquiera git.

El código de la app (React + TanStack Router/Query + Tailwind + shadcn/ui + PostgreSQL) vive en un
proyecto de **Lovable**, y se edita **enviándole mensajes en lenguaje natural** con las herramientas
MCP `mcp__claude_ai_Lovable__*`, no escribiendo archivos.

| | |
|---|---|
| Project ID | `bce99613-a62d-4469-86b7-dc1e73a81037` — usar `list_projects` si hace falta confirmarlo |
| App en producción | https://spraywall.nekoescalada.com |
| URL de Lovable | https://spraywall-neko.lovable.app (redirige al dominio propio) |
| Editor | https://lovable.dev/projects/bce99613-a62d-4469-86b7-dc1e73a81037 |

## Cómo trabajar con Lovable

- **`send_message` y `create_project` tardan mucho y agotan el timeout de 300 s.** Llamarlos con
  `wait: false` y luego sondear con `get_message`. Si `create_project` da timeout, el proyecto
  probablemente *sí* se creó: recuperar el id con `list_projects` antes de reintentar.
- **Un turno tarda de 20 min a 1 h y pico**, y los mensajes se **encolan**: se pueden enviar varios
  seguidos y los procesa en orden. Sondear con `get_diff` (respuesta corta: da `Message has no
  associated edit` mientras no haya commit) en lugar de `get_message`, que devuelve el prompt
  entero. `read_file` refleja el working tree en vivo, antes del commit.
- **A veces un turno se cuelga: se queda en `running` indefinidamente y no toca nada.** Pasó una vez
  con 3 h de espera. Para distinguirlo de un turno lento: `get_project` da `agentFinished` y
  `status`, y `read_file` muestra si hay cambios a medias. Si el agente terminó y el código está
  intacto, reenviar el mensaje — no duplica trabajo.
- **No fiarse de que diga que algo está hecho: verificarlo en el navegador.** La barra de zoom se
  entregó dos veces "terminada" y no movía la foto; se cazó midiendo la matriz de transformación del
  DOM antes y después de pulsar el botón, no mirando la interfaz.
- **Un mensaje = una tanda de cambios completa.** Pedir "el backend" y luego "el frontend" en
  mensajes separados funciona; pedir algo ambiguo produce solo la mitad. Describir el resultado
  esperado con detalle, y las correcciones como una lista numerada de defectos concretos.
- Revisar lo que hizo con `get_diff` / `read_file`, y verificar en el navegador contra la URL
  **publicada** (no la de previsualización).
- Consultar y modificar datos con `query_database` (Supabase vía Lovable Cloud).
- Publicar con `deploy_project`.

## Comandos locales

```powershell
# Fotos de los muros: Imagenes/Recortadas/*.JPG -> Imagenes/web/*.jpg (lado mayor 2400 px, q82)
pwsh -File scripts/preparar-imagenes.ps1

# Iconos y logo: Imagenes/logo-original.png -> Imagenes/iconos/ (5 archivos)
python scripts/preparar-logo.py
```

Ambos scripts solo generan archivos en `Imagenes/`. **Subirlos después al proyecto de Lovable**
(`public/walls/` y `public/icons/` + `public/`) es un paso manual aparte.

## Arquitectura de la app

`src/components/WallCanvas.tsx` es el componente central: lo comparten el visor y el editor, y ahí
viven las tres decisiones que sostienen todo lo demás.

**1. Coordenadas normalizadas 0..1.** Las presas se guardan en `boulders.holds` (JSONB) como
`{x, y, tipo}` con `x`/`y` relativos a la imagen. Son independientes de resolución, zoom y tamaño
de pantalla. La capa de dibujo las convierte a **píxeles de la caja** (`h.x * caja.w`,
`h.y * caja.h`) para quedar ancladas a su presa.

**2. Aspecto dinámico.** Las 4 fotos tienen proporciones distintas (2400x2295, 2400x2263,
1769x2400, 2165x2400). El lienzo lee `naturalWidth/naturalHeight` en el `onLoad` y aplica ese
aspecto con `object-contain`. Nunca asumir una proporción fija ni usar `object-fill`: deforma.

**3. Desambiguación de gestos.** Un toque cuenta como "marcar presa" solo si el dedo se movió
< 10 px, en < 300 ms y sin un segundo puntero en pantalla. Es la queja número uno de los usuarios
de Retro Flash (el zoom se confunde con toques) y está resuelta explícitamente. No tocarlo sin
entender por qué está así.

Además: **la zona sensible al toque no depende del tamaño del marcador**. Es un círculo de
`RADIO_TOQUE = RADIO * 2` (`RADIO = 0.0175` del ancho, el radio del círculo *original*) centrado en
la coordenada de la presa, y se mantiene aunque el dibujo encoja, para poder corregir con el dedo.

**4. Las presas se iluminan; el resto del muro se apaga.** No hay marcador *encima* de la presa:
un `<svg>` superpuesto pinta un rectángulo negro al `OSCURIDAD = 0.56` recortado por una `<mask>` con
un claro difuminado por presa (`RADIO_FOCO = 0.030` del ancho, `DIFUMINADO = 0.35` del radio), y en
el borde de cada claro un aro del color del tipo con resplandor. La presa queda entera a la vista.
Antes era un pin de gota con bulbo, y antes de eso un círculo centrado sobre la presa que la tapaba.

Tres cosas que no se ven a primera vista:

- **El `viewBox` va en píxeles de la caja** (`0 0 caja.w caja.h`), no en porcentajes. Es lo único
  que hace que los claros salgan **redondos**: `x` es fracción del ancho e `y` del alto, y las 4
  fotos tienen proporciones distintas. En porcentajes saldrían ovalados.
- **Sin presas marcadas no se dibuja la capa.** Si no, el editor arrancaría con la foto a oscuras
  y sería imposible buscar la primera presa.
- Los ids de la `mask` y del `radialGradient` salen de `useId()`, para que dos lienzos en la misma
  página no se pisen.

La etiqueta (`I`/`T`/`IT` o el número de orden) va en un **disco pegado al aro a 45º**, fuera del
claro, con el texto como `<text>` del SVG; su tope es el 60 % del diámetro del disco para que no
desborde. Las presas de mano/pie no llevan disco.

**El claro es redondo en el editor y se ajusta a la presa en el visor.** Lo decide la prop `medir`
de `WallCanvas`, `false` por defecto: solo la pasa `/bloque/$boulderId`. El editor se queda con el
círculo a propósito: ahí lo que importa es marcar rápido.

`src/lib/medidas.ts` mide cada presa **en el navegador** (canvas de 900 px, coordenadas 0..1, nada
guardado en la base de datos) y devuelve una **cascada de tres recursos**, en este orden:

1. **Contorno**: el casco convexo de la región, como polígono de 13 a 23 vértices.
2. **Elipse** por momentos de la región (centroide, covarianza, semiejes a 2 sigma y ángulo).
3. **`null`**, y entonces el lienzo dibuja el círculo de `RADIO_FOCO` con su aro.

**La regla que no se puede romper: ninguna presa se queda sin aro de color, nunca.** Ni cuando falla
la detección ni mientras se calcula. Esa fue la queja real de la sala: la primera versión no dibujaba
aro si no había silueta, y como las presas de mano tampoco llevan disco, se volvían invisibles.

Lo que costó encontrar: **los contornos se partían por el brillo, no por la tolerancia.** Una presa
tiene la mitad iluminada y la mitad en sombra —mismo tono, luminancia muy distinta—, así que el
crecimiento de región se paraba a medio camino. Por eso hay **ocho pasadas** y gana la primera que
pasa los filtros: cuatro con `PESO_CROMA = 0.12` (la luminancia casi no cuenta) y tolerancias
`40, 28, 20, 14`, y cuatro con `PESO_CLASICO = 0.5` y tolerancias `45, 32, 22, 15`, que recuperan
las presas que en tono se confunden con la madera pero en brillo no. Medido sobre dos bloques reales
del Spray Wall: **13 contornos buenos de 20 presas**, y con una sola pasada eran 4 de 10.

Además, antes de trazar: **cierre morfológico amplio** (dos dilataciones y una erosión) y
**`rellenarAgujeros`**, que marca como interior todo lo no alcanzable desde el borde del cuadrado.
Sin eso, el agujero del tornillo partía la región y el contorno acababa rodeando el hueco en vez de
la presa.

Los descartes, todos medidos y no inventados:

- Geométricos, sobre la región: `RADIO_MAX = 0.055` del ancho (el cuadrado de búsqueda),
  `MAX_BORDE = 0.35` del perímetro, `MIN_AREA` 0,15 % y `MAX_AREA` 15 % del cuadrado.
- `MIN_HOMOGENEIDAD_CONTORNO = 0.68` y `MIN_HOMOGENEIDAD = 0.55` (elipse): fracción del interior que
  sigue pareciéndose al color de referencia, **con el peso y la tolerancia de la pasada que ganó**;
  compararlo con otros valores da resultados incoherentes. Es el filtro que de verdad discrimina: la
  elipse que se comía tres presas vecinas daba 0,51 y la que rodeaba un agujero 0,38, contra 0,61 a
  0,94 en todas las buenas.
- **El punto que marcó el usuario tiene que caer dentro** de la forma, y para la elipse además
  semieje mayor ≤ 46 px de los 900, menor ≥ 6 y relación entre ejes ≤ 4.

Dos trampas del dibujo:

- **En la `<mask>`, el negro ilumina y el blanco oscurece.** El `<rect>` de fondo es blanco y cada
  claro se abre pintando negro (el `radialGradient` arranca en `#000`). Un polígono en blanco deja
  la presa *tapada*, que es justo lo contrario, y pasó exactamente eso.
- **Los dos semiejes se normalizan por el ANCHO** y los dos se multiplican por `caja.w`. Como la
  caja tiene el aspecto de la foto, así la elipse no se deforma; normalizando `b` por el alto
  saldrían achatadas. Los puntos del contorno, en cambio, van `x` por ancho e `y` por alto.

Y dos cosas heredadas que siguen valiendo: **la imagen se carga con `crossOrigin="anonymous"`** (si
el bucket no lo permitiera, `getImageData` lanza `SecurityError` y *todas* las presas caen al
círculo —canvas contaminado, no fallo del algoritmo—), y el resultado se **cachea en memoria** por
`imagen` + presas, así que recargar la página lo recalcula.

Esto es visión artificial sobre fotos de sala: **el resultado depende de la foto**. Con luz uniforme
y presas saturadas acierta casi siempre; contra madera clara, no. Que una presa concreta salga con
aro en vez de contorno es el comportamiento previsto, no una regresión.

**5. La barra de zoom aplica el zoom sin animación, a propósito.** `centerView(escala, 0)`. Con
animación la librería escribe el `transform` en el DOM mientras el `onTransform` provoca un
re-render de React que lo sobrescribe: el indicador subía y la foto no se movía. Por lo mismo, el
indicador y la posición de la barra se leen **solo** de la escala real que llega por `onTransform`,
nunca de un valor optimista. El recorrido es geométrico (`escala = 8^t`).

### Modelo de datos

```
profiles  id · nombre · rol ('entrenador'|'alumno') · created_at
walls     id · nombre · angulo · imagen · orden                    -- 4 filas
boulders  id · wall_id · nombre · grado · creador_id · creador_nombre
          creador_rol · descripcion · holds jsonb · numerar bool · created_at
          imagen · holds_previos jsonb · imagen_previa      -- las 3 anulables
ascents   id · boulder_id · user_id · user_nombre · created_at · UNIQUE(boulder_id,user_id)
```

`holds` es `{x, y, tipo}` con `tipo` en `inicio | mano | top | inicio-top`. El cuarto es para las
travesías circulares (la misma presa es inicio y top) y **cuenta como inicio y como top** en todos
los recuentos y validaciones. `numerar` (por defecto `false`) decide si el marcador muestra el orden
o solo `I`/`T`/`IT`: los entrenadores no querían una secuencia impuesta, el orden lo decide quien
escala.

`boulders.imagen` **fija la foto de ese bloque**: si es `null` — el caso normal — se usa la del muro.
Solo se rellena cuando un bloque se queda anclado a una foto anterior, y el helper `fotoDeBloque()`
resuelve las dos situaciones; usarlo en cualquier sitio nuevo donde se pinte un bloque.
`holds_previos` e `imagen_previa` guardan el estado anterior al último reajuste, y son lo que hace
posible «Deshacer reajuste».

`walls.imagen` admite un nombre de archivo (`spraywall.jpg` → `/walls/…`, las 4 fotos de `public/`)
o una **URL absoluta** del bucket `walls` de Storage, que es lo que guarda el panel de entrenador.
`imagenUrl()` distingue ambos casos; no romperlo.

Sin contraseñas: el usuario escribe su nombre, elige rol y su id queda en `localStorage`
(`spraywall_user_id`). El rol de entrenador pide un **código de sala** que no se escribe
en este repositorio porque es público: está en la app (`CODIGO` en `src/components/Welcome.tsx`) y
en la guía del equipo, y cambiarlo obliga a tocar los dos sitios a la vez. RLS permisiva a
propósito: es un tablón interno, no un sistema con datos sensibles. El punto de cambio si algún día se quiere auth real es `UserProvider` + Supabase Auth.

### Rutas

`/` muros · `/muro/$wallId` lista con filtros · `/bloque/$boulderId` visor + "¡Encadenado!" ·
`/crear` y `/crear/$wallId` editor · `/progreso` ticklist · `/instalar` QR ·
`/entrenador` panel de entrenador (cambiar la foto de un muro) ·
`/ayuda` guía de uso dentro de la app.

`/ayuda` es un acordeón de diez secciones, la primera «SprayWall está en beta» y abierta por
defecto (`defaultValue="beta"`). Dos cosas que no se ven en el código a primera vista:
la sección «Soy entrenador» solo se monta si `user.rol === "entrenador"`, y **el código de sala no
aparece ahí a propósito** (la pantalla la ve cualquiera; dice que lo dan en recepción). Su leyenda
de presas reproduce el foco de `WallCanvas` (máscara, aro y disco) con los mismos `HOLD_COLORS`,
así que un cambio en el dibujo de la presa obliga a tocar los dos sitios. Se llega desde el icono `?` de Muros, otro en la
cabecera de «Mi progreso» y uno pequeño junto a los pinceles del editor.

El panel de entrenador sube la foto redimensionada en el navegador (2400 px, JPEG 0.82, respetando
la orientación EXIF con `createImageBitmap(..., { imageOrientation: "from-image" })`, porque las
fotos de la cámara vienen tumbadas 90º) al bucket público `walls`, con nombre único. **Solo si la
subida va bien** toca los bloques; ese orden importa. La lógica está en `src/lib/muros.ts`.

### Añadir presas sin perder los bloques

Al elegir la foto, el panel pregunta **qué ha cambiado en el muro**, y de ahí salen dos caminos:

- **«He reequipado el muro»** → `cambiarFotoMuro`, el comportamiento de siempre: avisa del recuento
  real, exige escribir `BORRAR` y borra los bloques y sus encadenes.
- **«Solo he añadido presas»** → `anadirPresasAlMuro`, que **no borra nada**. Abre `AlinearFoto`,
  donde la foto antigua se superpone a la nueva y se arrastra, escala y gira hasta que las presas
  coinciden; de ese ajuste sale la transformación que se aplica a las presas de todos los bloques
  del muro. Si el muro no tiene bloques se salta la alineación y sube directamente.

`src/lib/alineacion.ts` es el núcleo, y su regla es lo único que hay que respetar aquí: el ajuste son
**cuatro números en píxeles de la foto nueva** (`s`, `theta`, `tx`, `ty`), y de ellos salen tanto
`transformarPunto` (los datos) como `estiloAntigua` (el dibujo en pantalla, multiplicado por el
factor pantalla/foto). Calcular el render por otro camino es el fallo clásico: encaja en pantalla y
no encaja en los datos, y no se nota hasta abrir un bloque. Verificado: la equivalencia entre las
dos es exacta salvo coma flotante, y con el ajuste inicial y la misma proporción es la identidad.

Un bloque al que el reajuste le saque **alguna presa fuera del encuadre** no se transforma: se le
pone `imagen` = la foto antigua y se queda dibujado sobre ella. Nunca se pierde.

La foto se redimensiona **una sola vez**, al elegirla, y ese mismo `Blob` es el que se previsualiza,
el que se mide en la alineación y el que se sube. No es un detalle de rendimiento: si se midiera el
archivo original y se subiera el redimensionado, bastaría una foto tumbada por EXIF —lo normal en la
cámara de la sala— para que el ancho y el alto no correspondieran y **todas** las presas de **todos**
los bloques se fueran a otro sitio.

## Trampas conocidas

- **Cambiar la foto de un muro descoloca los bloques ya guardados**, porque sus coordenadas son
  relativas al encuadre anterior. Hay dos salidas, según lo que haya cambiado: reequipar borra los
  bloques (con `BORRAR`), y añadir presas los conserva reajustándolos con `AlinearFoto`. Lo que no
  existe es dejar de borrar *sin* reajustar: conservar las coordenadas viejas sobre un encuadre
  nuevo es peor que perderlas, porque el bloque señala presas equivocadas y nadie lo sabe.
- **«Deshacer reajuste» no toca `walls.imagen`.** La foto nueva se queda y los bloques vuelven a la
  antigua, que sigue en Storage porque los nombres son únicos. Por eso `imagen_previa` guarda
  `b.imagen ?? imagenAntigua` y no `b.imagen ?? null`: con `null` el bloque volvería a la foto del
  muro, que ya es la nueva, y deshacer descolocaría justo lo que venía a salvar.
- **Al cambiar los iconos hay que subir la versión de la caché** en `public/sw.js`
  (va por `spraywall-v3`). Si no, quien tenga la PWA instalada seguirá viendo los iconos
  viejos: el service worker los tiene precacheados. El `sw.js` hace cache-first también con
  `/storage/v1/object/` (las fotos subidas), y funciona porque sus nombres son únicos.
- El nombre de archivo en `Imagenes/web/` debe coincidir con la columna `walls.imagen`; el mapeo
  está en la tabla `$mapa` de `scripts/preparar-imagenes.ps1`.
- El icono maskable va al **66 %** de ocupación (los demás al 86-94 %) porque Android lo recorta
  en círculo y con más ocupación le corta las orejas y la cola al gato.
- **El service worker solo se registra en la URL publicada**, no en la previsualización del editor.
  Para probar la instalación como PWA hay que usar la URL de producción.
- `localStorage` es por origen: al cambiar de dominio cada persona vuelve a escribir su nombre.
  Escribiendo **el mismo nombre** recupera perfil e historial, que viven en la base de datos.
- **`boulders` y `ascents` son datos reales de usuarios de la sala.** Confirmar con el usuario
  antes de borrar nada, aunque parezca de prueba.
- La API de Google Docs rechaza imágenes privadas de Drive ("The provided image should be publicly
  accessible"). El apaño: `link_sharing: reader` temporal → insertar (Google las copia al
  documento) → `link_sharing: off`. Las imágenes siguen viéndose después.
- `create_drive_file` no acepta rutas locales arbitrarias: hay que copiar primero a
  `C:\Users\diego\.workspace-mcp\attachments`.
- **El QR de la app está bien**; si alguien dice que "no le deja escanearlo", casi siempre es que lo
  intenta con el mismo móvil que lo muestra (imposible) o con una cámara sin lector de QR. No hace
  falta contratar un generador externo. La pantalla `/instalar` ya lo advierte y ofrece el PNG
  imprimible.
- El componente `Slider` de shadcn viene cableado **solo para horizontal** (`h-1.5 w-full`); para
  usarlo en vertical hay que darle variantes explícitas.

## Documentos del repo

- `README.md` — documentación del proyecto para el usuario (muros, funcionalidades, instalación,
  logo, dominio). Mantenerlo al día cuando cambie algo visible.
- `analisis-retro-flash.md` — análisis de la app de referencia: qué copiar, qué mejorar y qué se
  dejó fuera a propósito (reglas por presa, circuitos numerados, detección automática de presas).
- `manual/capturas/01..08-*.png` — capturas usadas en la guía del equipo (Google Doc
  `1MSta1NFO8AuKjaiK_rafHAnB0ggeIz4l6qogNZ3Jb2c`, en la carpeta `SpraywallNeko` de Drive).
