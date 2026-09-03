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
desborde. Las presas de mano/pie no llevan disco. Cuando hay silueta el disco se pega a la esquina
superior derecha de su rectángulo envolvente, no a los 45º del punto.

**El claro es redondo en el editor y sigue la silueta en el visor.** Lo decide la prop `siluetas`
de `WallCanvas`, `false` por defecto: solo la pasa `/bloque/$boulderId`. Con ella,
`src/lib/siluetas.ts` calcula el contorno de cada presa **en el navegador** y devuelve un polígono
en coordenadas 0..1, que abre el claro en la `<mask>` (relleno, engrosado y desenfocado) y lleva
encima el resplandor del color. El editor se queda con el círculo a propósito: ahí lo que importa
es marcar rápido, no que quede bonito.

Cómo detecta: reescala la foto a 900 px de ancho en un canvas fuera de pantalla y hace crecimiento
de región (BFS 4-conexo) desde el punto guardado, comparando color en YCbCr **con el croma pesando
cuatro veces más que la luminancia** — si no, las sombras del panel se cuelan por el degradado. Tres
límites duros evitan que la mancha se coma medio muro: no salir de un cuadrado de `RADIO_MAX = 0.055`
del ancho, descartar si toca el borde de ese cuadrado en más del 35 % de su perímetro, y descartar
si el área es menor que el 0,15 % del cuadrado. Luego cierre morfológico, seguimiento de borde de
Moore y Douglas-Peucker hasta 56 puntos.

Cuatro cosas de las siluetas que conviene saber:

- **La presa que falla no desaparece**: se dibuja con el claro redondo de siempre, pero sin aro.
  Espéralo en las presas de madera y en las grises sobre panel gris.
- **No se guarda nada.** Ni en `holds` ni en columnas nuevas: se calcula al abrir el bloque y se
  cachea en memoria por `imagen` + presas. Recargar la página lo recalcula.
- **La imagen se carga con `crossOrigin="anonymous"`.** Si el bucket no lo permitiera,
  `getImageData` lanza `SecurityError`, y entonces *todas* las presas caen al claro redondo. No es
  un fallo del algoritmo: es el canvas contaminado.
- **`TOLERANCIA` (45) es el número que hay que calibrar** contra las fotos reales de la sala. Es el
  único mando de verdad: subirlo se come el panel, bajarlo deja la silueta en un pegote.

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
ascents   id · boulder_id · user_id · user_nombre · created_at · UNIQUE(boulder_id,user_id)
```

`holds` es `{x, y, tipo}` con `tipo` en `inicio | mano | top | inicio-top`. El cuarto es para las
travesías circulares (la misma presa es inicio y top) y **cuenta como inicio y como top** en todos
los recuentos y validaciones. `numerar` (por defecto `false`) decide si el marcador muestra el orden
o solo `I`/`T`/`IT`: los entrenadores no querían una secuencia impuesta, el orden lo decide quien
escala.

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
subida va bien** actualiza `walls.imagen` y borra los bloques del muro; ese orden importa. La lógica
está en `src/lib/muros.ts`.

## Trampas conocidas

- **Cambiar la foto de un muro descoloca los bloques ya guardados**, porque sus coordenadas son
  relativas al encuadre anterior. El panel de entrenador lo resuelve borrándolos, avisando con el
  recuento real y exigiendo escribir `BORRAR`. Para conservar el histórico hay que crear a mano una
  **fila nueva en `walls`** y dejar la antigua.
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
