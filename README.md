# SprayWall — App de bloques para el spray wall de la sala

App móvil (PWA instalable en Android) para crear, buscar y encadenar bloques sobre el spray wall
y los paneles de la sala. Inspirada en Retro Flash, pero reducida a lo esencial y para **una sola sala**.

- **App publicada:** https://spraywall.nekoescalada.com ← esta es la URL para el móvil
- **URL de Lovable:** https://spraywall-neko.lovable.app (redirige al dominio propio)
- **Editor:** https://lovable.dev/projects/bce99613-a62d-4469-86b7-dc1e73a81037
- **Previsualización (desarrollo):** https://id-preview--bce99613-a62d-4469-86b7-dc1e73a81037.lovable.app
- **Stack:** React + TanStack Router/Query + Tailwind + shadcn/ui, backend PostgreSQL (Supabase vía Lovable Cloud)

> **La app está en beta.** Se puede usar con normalidad, pero es una versión en pruebas y lo dice
> en la propia interfaz: una etiqueta `BETA` junto al título en la bienvenida y en la pantalla de
> Muros, un aviso descartable la primera vez que se abre la home
> (`localStorage: spraywall:beta-aviso-descartado`) y la primera sección de `/ayuda`,
> «SprayWall está en beta», abierta por defecto. Los títulos de página llevan `(beta)`.
>
> Los datos **no** son de prueba: los bloques y los encadenes se guardan en la base de datos y no
> se borran por ser beta. Al pasar a versión oficial hay que quitar esas cuatro cosas
> (`src/components/BadgeBeta.tsx`, `src/components/AvisoBeta.tsx`, la sección de `/ayuda` y los
> `(beta)` de los títulos); no hace falta reinstalar la PWA, porque el aviso de beta no toca el
> manifest ni el service worker.

> El service worker solo se registra en la app publicada, no en la previsualización del editor
> (para que el editor nunca sirva una versión antigua). Así que para probar la instalación como
> PWA hay que usar la URL publicada.

---

## Los 4 muros

Las fotos en uso salen de `Imagenes/Recortadas/` (encuadradas a mano para que el muro llene el
cuadro, sin techo ni suelo sobrando). `Imagenes/web/` guarda las versiones optimizadas que se
suben a la app: lado mayor 2400 px, JPEG calidad 82.

`Imagenes/*.JPG` son los originales de cámara, que venían tumbados 90º.

| Archivo en la app | Muro | Ángulo | Resolución |
|---|---|---|---|
| `spraywall.jpg` | Spray Wall (principal, muy denso de presas) | 0º | 2400x2295 |
| `muro-0.jpg` | Panel 0º | 0º | 2400x2263 |
| `muro-5.jpg` | Panel 5º | 5º | 1769x2400 |
| `muro-15.jpg` | Panel 15º | 15º | 2165x2400 |

Cada foto tiene una proporción distinta, así que el lienzo **no** asume ninguna: lee
`naturalWidth/naturalHeight` al cargar la imagen y aplica ese aspecto. Se puede sustituir
cualquier foto por otra de proporción diferente sin tocar código.

Para regenerar las imágenes optimizadas desde las recortadas:

```powershell
pwsh -File scripts/preparar-imagenes.ps1
```

> **Al cambiar la foto de un muro, los bloques existentes quedan descolocados**: sus presas están
> guardadas en coordenadas relativas al encuadre anterior. Si es un reencuadre, hay que borrar los
> bloques de ese muro. Si es un cambio de presas, lo limpio es crear una fila nueva en `walls` y
> conservar la antigua como histórico.

---

## Funcionalidades

### 1. Visor interactivo del muro
Foto fija de alta resolución con **zoom y desplazamiento**, y marcadores sobre las presas del
bloque. Las coordenadas normalizadas se convierten a píxeles de la caja del lienzo, así que los
marcadores quedan anclados a su presa y escalan con el zoom.

El zoom (1x a 8x) se maneja de tres formas: pinza, doble toque y una **barra de zoom vertical** en
el lado derecho del lienzo, con botones + y −. El recorrido de la barra es **geométrico**
(`escala = 8^t`, con `t` de 0 a 1), no lineal: así el punto medio es ×2,8 y los saltos se perciben
iguales en todo el recorrido. Antes solo había pinza y doble toque, y se pasaba de estar demasiado
lejos a demasiado cerca sin nada en medio.

> La barra aplica el zoom con `centerView(escala, 0)`, **sin animación**, y a propósito. Con
> animación la librería escribe el `transform` directamente en el DOM mientras el `onTransform`
> provoca un re-render de React que lo sobrescribe: el indicador subía y la foto no se movía.

### 2. Creador de bloques
Se toca sobre cada presa para marcarla:

| Color | Tipo | Significado |
|---|---|---|
| 🟢 Verde | `inicio` | Presas de inicio |
| 🔵 Azul | `mano` | Manos y pies |
| 🔴 Rojo | `top` | Presa de top |
| 🟡 Ámbar | `inicio-top` | La misma presa es inicio **y** top (travesías circulares) |

Las presas del bloque **se iluminan y el resto del muro se apaga**: una capa negra al 56 % cubre la
foto, con un claro de bordes difuminados sobre cada presa (radio: 3 % del ancho de la imagen) y un
aro de su color, con resplandor, en el borde del claro. La presa queda entera a la vista, sin nada
encima, y la secuencia del bloque se lee de un golpe. El aro de `inicio-top` es bicolor, mitad
verde mitad rojo.

Antes fue un pin con forma de gota, y antes un círculo centrado sobre la presa que la tapaba. La
zona sensible al toque no ha cambiado en ninguno de los dos cambios: sigue siendo el doble del radio
original, para poder corregir con el dedo. Si no hay ninguna presa marcada, la foto se ve limpia.

Al abrir un bloque, la app **reconoce cada presa** sobre la foto y ajusta la marca a su forma, sin
que nadie tenga que dibujar contornos a mano. Va extendiendo una mancha desde el punto guardado
mientras el color se parezca, y compara **el color casi sin mirar el brillo**: si mirara el brillo
se pararía en la sombra de la propia presa y marcaría solo la mitad iluminada. Prueba hasta ocho
combinaciones por presa y se queda con la primera limpia. No se guarda nada en la base de datos.

Según lo que consigue reconocer, la marca es una de tres, siempre del color del tipo de presa:

1. **La línea del contorno**, siguiendo la forma de la presa. Es el caso bueno: unas dos de cada
   tres.
2. **Un aro ovalado** del tamaño y la inclinación de la presa, cuando el contorno no sale limpio.
3. **El aro redondo** de siempre, cuando la foto no da para más.

> **Ninguna presa se queda nunca sin su aro de color.** Es la regla que manda sobre todo lo demás:
> es preferible un círculo honesto a una línea que marque el sitio equivocado. Las que más se
> resisten son las presas de madera, las beige pegadas al panel y los volúmenes muy grandes. En el
> **editor** la marca es siempre redonda, a propósito: ahí lo que importa es marcar rápido.

La **numeración es opcional** y viene desactivada: el orden de las presas lo decide quien escala.
Hay un checkbox «Numerar las presas en orden» en la ficha del bloque (columna `boulders.numerar`).
Sin numerar, el disco pegado al aro muestra `I` en las de inicio, `T` en las de top, `IT` en las
de inicio y top,
y nada en manos/pies. Numerado, muestra el orden, que se recalcula al borrar una presa intermedia.

Tocar una presa con un pincel distinto la convierte a ese tipo; tocarla con su mismo pincel la
borra. Hay cuatro pinceles en rejilla 2×2, deshacer, limpiar y un contador en vivo. Una presa
`inicio-top` cuenta como inicio y como top en los recuentos y en la validación al guardar.

**Detección de gestos:** un toque solo cuenta como "marcar presa" si el dedo se movió
menos de 10 px, en menos de 300 ms y sin un segundo dedo en pantalla. Es la queja número
uno de los usuarios de Retro Flash (el zoom se confunde con toques) y aquí está resuelto
explícitamente.

### 3. Filtros
Por texto (nombre del bloque o creador), por **grado**, por **creador**
(`Todos` / `Entrenadores` / `Alumnos` / `Míos`), por estado (`Pendientes` / `Encadenados`)
y orden (recientes / grado / más encadenados).

### 4. Ticklist (Mi progreso)
Botón **"¡Encadenado!"** en el visor de cada bloque. La pantalla de progreso muestra
encadenes totales, bloques creados, grado máximo, una **pirámide de grados** en barras y el
historial cronológico.

### 5. Panel de entrenador
En `/entrenador`, accesible desde «Mi progreso» y **solo con rol de entrenador**. Lista los 4 muros
con su foto, su ángulo y cuántos bloques y encadenes tiene cada uno, y permite **cambiar la foto de
fondo** de un muro cuando cambia el equipamiento de la sala.

Al elegir la foto, la app pregunta **qué ha cambiado en el muro**, porque la respuesta decide qué
pasa con los bloques que ya existen:

- **«Solo he añadido presas»** — el muro es el mismo, solo hay presas nuevas. **No se borra nada.**
  Se abre una pantalla donde la foto antigua queda superpuesta a la nueva y se arrastra, escala y
  gira con los dedos hasta que las presas coinciden; con ese encaje la app mueve las presas de todos
  los bloques del muro a su sitio en la foto nueva. Hay un deslizador de transparencia, flechas de
  ajuste fino de un píxel y un **modo diferencia**: cuando las dos fotos encajan la imagen se vuelve
  casi negra, que es la forma más rápida de acertar. Si el muro todavía no tiene bloques, la foto se
  sube directamente sin pasar por el ajuste.
- **«He reequipado el muro»** — las presas son otras. Se borran los bloques de ese muro y sus
  encadenes, avisando del recuento real y exigiendo escribir `BORRAR`.

Un bloque al que el reajuste le saque alguna presa fuera del encuadre **no se toca**: se queda
dibujado sobre la foto anterior, que sigue guardada. Y mientras haya algún reajuste reciente, cada
muro ofrece **«Deshacer reajuste»**, que devuelve las presas a donde estaban.

La foto se redimensiona **en el navegador** antes de subirla (lado mayor 2400 px, JPEG 0.82, los
mismos valores que `scripts/preparar-imagenes.ps1`) con `createImageBitmap(file, { imageOrientation:
"from-image" })`, porque las fotos de la cámara vienen tumbadas 90º y sin eso el muro sale girado.
Se sube al bucket público `walls` de Storage con nombre único (`muro-<wall_id>-<timestamp>.jpg`), y
solo **si la subida ha ido bien** se actualiza `walls.imagen` y se borran los bloques.

> **Cambiar la foto borra los bloques de ese muro y sus encadenes**, porque las presas están en
> coordenadas relativas al encuadre anterior. Es irreversible, así que la pantalla enseña el
> recuento real («este muro tiene 3 bloques con 7 encadenes») y exige **escribir `BORRAR`** para
> habilitar el botón. Si el muro no tiene bloques, basta con confirmar.

Es una barrera de conveniencia, no de seguridad: el rol es autodeclarado con el código de sala.

### 6. Ayuda dentro de la app
`/ayuda`: nueve secciones plegables que explican qué es el tablón, cómo buscar y filtrar, qué
significa cada color de presa, cómo montar un bloque, el progreso, la instalación en el móvil, cómo
funcionan el nombre y el historial, y una lista de dudas frecuentes (el QR que no se puede escanear
con el propio móvil, los aros descolocados al cambiar la foto, los encadenes «perdidos»).

La sección **«Soy entrenador»** solo aparece con rol de entrenador, con el aviso de que cambiar la
foto borra los bloques. **El código de sala no se menciona**: la pantalla la ve cualquiera, así que
remite a recepción.

La leyenda de colores no dibuja bolitas de muestra: reproduce el **mismo foco** que `WallCanvas`
—muro oscurecido, claro, aro y disco de etiqueta— con los mismos `HOLD_COLORS`, incluido el aro
bicolor de inicio+top, para que lo que se ve en la ayuda sea idéntico a lo que luego se ve en el
muro. Si cambia el dibujo de la presa, hay que cambiar los dos.

Se llega desde tres sitios: el icono `?` de la cabecera de Muros, otro en la cabecera de Mi
progreso, y uno pequeño junto a los pinceles del editor, que es donde más dudas surgen.

---

## Identificación

Sin contraseñas: el usuario escribe su nombre y elige rol.

- **Alumno** — acceso directo.
- **Entrenador** — requiere el código de sala, que se da en recepción (no se publica aquí).

El perfil se guarda en la tabla `profiles` y su id en `localStorage` (`spraywall_user_id`),
así que la app entra directa en visitas posteriores. Hay un "Cambiar de usuario" en el perfil.

> Es un tablón interno de la sala, no un sistema con datos sensibles: por eso RLS es permisiva
> y no hay auth con contraseña. Si en el futuro se quiere control de acceso real, el punto de
> cambio es `UserProvider` + activar Supabase Auth.

---

## Modelo de datos

```
profiles  id uuid pk · nombre text · rol text ('entrenador'|'alumno') · created_at
walls     id uuid pk · nombre text · angulo int · imagen text · orden int
boulders  id uuid pk · wall_id fk · nombre text · grado text · creador_id fk
          creador_nombre text · creador_rol text · descripcion text null
          holds jsonb · numerar bool (default false) · created_at
          imagen text null · holds_previos jsonb null · imagen_previa text null
ascents   id uuid pk · boulder_id fk · user_id fk · user_nombre text · created_at
          UNIQUE (boulder_id, user_id)
```

`holds` guarda las presas con **coordenadas normalizadas 0..1** relativas a la imagen, de modo
que son independientes de la resolución, del zoom y del tamaño de pantalla:

```json
[
  { "x": 0.42, "y": 0.31, "tipo": "inicio" },
  { "x": 0.50, "y": 0.60, "tipo": "mano" },
  { "x": 0.48, "y": 0.12, "tipo": "top" },
  { "x": 0.31, "y": 0.44, "tipo": "inicio-top" }
]
```

`walls.imagen` admite dos formas: un nombre de archivo (`spraywall.jpg`, que `imagenUrl()` resuelve
a `/walls/…`, para las 4 fotos que viven en `public/`) o una **URL absoluta** del bucket de Storage,
que es lo que guarda el panel de entrenador al subir una foto nueva.

`boulders.imagen` hace lo mismo para un bloque concreto: si está vacía —lo normal— el bloque se
dibuja sobre la foto de su muro, y si tiene valor, sobre esa foto en particular. Es lo que permite
que un bloque sobreviva a un cambio de foto sin descolocarse.

Si se reequipa el muro de arriba abajo y aun así se quiere conservar el histórico, sigue habiendo un
camino manual: crear una **fila nueva en `walls`** y dejar la antigua. Eso no está en la interfaz.

---

## Grados

Escala Font de bloque: `3, 4, 4+, 5, 5+, 6A, 6A+, 6B, 6B+, 6C, 6C+, 7A, 7A+, 7B, 7B+, 7C, 7C+, 8A`.
Colores de badge: azul (3–5+) → verde (6A–6B+) → ámbar (6C–7A) → naranja (7A+–7B+) → rojo (7C–7C+) → morado (8A).

---

## Instalación en Android

Tres caminos, de más fácil a más manual:

1. **Escanear el QR** de [`qr-spraywall.png`](qr-spraywall.png) con la cámara. Se puede imprimir y
   colgar junto al muro. El mismo QR está dentro de la app en la pantalla **Instalar**
   (Mi progreso → botón "Instalar"), con un botón para **descargarlo en PNG de 1024 px** (margen de
   4 módulos y corrección de errores `Q`, para que aguante impreso junto al muro).

   > Un móvil **no puede escanear el QR de su propia pantalla**. Hay que escanearlo desde otro
   > dispositivo o desde el papel impreso; si no, se escribe la dirección a mano. Es la confusión
   > que ya nos ha reportado un entrenador, y la pantalla Instalar lo advierte.
2. **El banner** que sale solo en la pantalla de Muros: "📲 Instala SprayWall en tu móvil" →
   botón *Instalar*. Se puede descartar y no vuelve a aparecer.
3. **A mano**: Chrome → menú ⋮ → *Instalar aplicación*. En iPhone, Safari → Compartir →
   *Añadir a pantalla de inicio*.

Se abre en modo standalone, sin barra del navegador, en vertical.

El service worker cachea las fotos de los muros tras la primera visita (cache-first para `/walls/`),
porque pesan ~750 KB cada una y dentro del rocódromo la cobertura móvil suele ser mala. Las llamadas
a la base de datos nunca se cachean.

---

## Estructura de la app

| Ruta | Pantalla |
|---|---|
| `/` | Muros — rejilla con los 4 muros y su nº de bloques |
| `/muro/$wallId` | Lista de bloques del muro, con todos los filtros |
| `/bloque/$boulderId` | Visor del bloque + botón "¡Encadenado!" |
| `/crear` | Elegir en qué muro montar el bloque |
| `/crear/$wallId` | Editor: marcar presas sobre la foto |
| `/progreso` | Ticklist: métricas, pirámide de grados e historial |
| `/entrenador` | Panel de entrenador: cambiar la foto de fondo de un muro |
| `/instalar` | QR, instalación como PWA y descarga del QR imprimible |
| `/ayuda` | Guía de uso dentro de la app, en secciones plegables |

Componente central: `src/components/WallCanvas.tsx` — lo comparten el visor y el editor.
Ahí vive la detección de gestos y el posicionamiento de los marcadores.

---

## Logo e iconos

El logo es el gato de Neko formado por presas de escalada. Los iconos se generan desde
`Imagenes/logo-original.png` con:

```bash
python scripts/preparar-logo.py
```

Salen a `Imagenes/iconos/` y de ahí se suben a `public/`:

| Archivo | Destino | Ocupación | Por qué |
|---|---|---|---|
| `icon-192.png` | `public/icons/` | 86 % | icono del manifest (`purpose: any`) |
| `icon-512.png` | `public/icons/` | 86 % | idem, tamaño grande |
| `icon-512-maskable.png` | `public/icons/` | **66 %** | Android recorta en círculo: con más ocupación le corta las orejas y la cola |
| `favicon.png` | `public/` | 90 % | pestaña del navegador |
| `logo.png` | `public/` | 94 %, **fondo transparente** | dentro de la app, sobre el tema oscuro |

El script recorta el fondo con un relleno por inundación desde los bordes (no por umbral
global) para no comerse las presas blancas que hay *dentro* del gato, y encuadra midiendo
solo los píxeles de color, porque la sombra del icono original deja píxeles grises sueltos
que si no descentran el resultado.

> **Al cambiar los iconos hay que subir la versión de la caché** en `public/sw.js`
> (va por `spraywall-v3`). Si no, quien tenga la app instalada seguirá viendo los
> iconos viejos: el service worker los tiene precacheados.

---

## Dominio propio

Pendiente de configurar. El DNS de `nekoescalada.com` está en **one.com**.

1. En Lovable: *Settings → Domains → Connect domain* → `spraywall.nekoescalada.com`.
   Copiar el valor TXT de verificación.
2. En el DNS de one.com:
   - **Borrar el registro `AAAA` de `spraywall`** — Lovable exige que no exista ninguno.
   - Cambiar el `A` de `spraywall`: `46.30.215.41` (hosting de one.com) → **`185.158.133.1`** (Lovable).
   - Añadir el `TXT` de verificación con el host y valor que muestre el panel de Lovable.

El QR y el botón de compartir usan `window.location.origin`, así que se adaptan solos al
dominio nuevo. Lo que **no** se traslada es la identificación: `localStorage` es por origen,
así que cada persona tendrá que volver a escribir su nombre en el dominio nuevo — escribiendo
**el mismo nombre** recupera su perfil y su historial, que viven en la base de datos.

---

## Contenido

Ya hay **bloques reales creados por gente de la sala**, no de ejemplo. Confirmar siempre antes de
borrar nada, aunque el nombre parezca de prueba. Se pueden borrar desde el propio visor: cualquier
entrenador tiene el icono de papelera arriba a la derecha.

---

## Qué queda fuera (por si se quiere ampliar)

- **Reglas por presa** (`no match`, `no pie`, zona de competición, mano obligada). Es lo que
  diferencia a Retro Flash y abre el caso de uso de competición; ver el análisis adjunto.
- **Vídeos de beta** en los encadenes.
- **Detección automática de presas** por visión artificial: hoy las presas se marcan a mano
  sobre la foto. Es la mejora con más recorrido del sector.
- **Versionado de muro en la interfaz**: añadir presas ya conserva los bloques, pero reequipar de
  cero sigue borrándolos, y conservar ese histórico exige crear a mano una fila nueva en `walls`.
- **Editar el nombre y el ángulo de un muro** desde el panel de entrenador; hoy solo la foto.

Ya hechos, a partir del feedback de los entrenadores: añadir presas al muro sin perder los bloques,
numeración opcional de presas, presa de
inicio y top a la vez, marcador que no tapa la presa, secuencia iluminada sobre el muro oscurecido
y barra de zoom progresiva.

---

## Documentos relacionados

- [`analisis-retro-flash.md`](analisis-retro-flash.md) — análisis de la app de referencia y de qué
  copiar / qué mejorar.
