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
viven las decisiones que sostienen todo lo demás.

**1. Coordenadas normalizadas 0..1.** Las presas se guardan en `boulders.holds` (JSONB) como
`{x, y, tipo}` (más un `tamano` opcional) con `x`/`y` relativos a la imagen. Son independientes de
resolución, zoom y tamaño de pantalla. La capa de dibujo las convierte a **píxeles de la caja**
(`h.x * caja.w`, `h.y * caja.h`) para quedar ancladas a su presa.

**2. Aspecto dinámico.** Las fotos tienen proporciones distintas: las 4 de muro son verticales
(2400x2295, 2400x2263, 1769x2400, 2165x2400) y la panorámica de la sala es apaisada (8000x2595). El lienzo lee
`naturalWidth/naturalHeight` en el `onLoad` y aplica ese aspecto con `object-contain`. Nunca asumir
una proporción fija ni usar `object-fill`: deforma.

**3. Desambiguación de gestos.** Un toque cuenta como "marcar presa" solo si el dedo se movió
< 10 px, en < 300 ms y sin un segundo puntero en pantalla. Es la queja número uno de los usuarios
de Retro Flash (el zoom se confunde con toques) y está resuelta explícitamente. No tocarlo sin
entender por qué está así.

Además: **la zona sensible al toque no depende del tamaño del marcador**. Es un círculo de
`RADIO_TOQUE = RADIO * 2` (`RADIO = 0.0175` del ancho, el radio del círculo *original*) centrado en
la coordenada de la presa, y se mantiene aunque el dibujo encoja, para poder corregir con el dedo.

**3 bis. Las constantes geométricas se escalan con `walls.escala_presa`.** Todas van en fracción del
ancho de la foto, y eso solo vale mientras el encuadre sea un muro: una presa es el 3 % del ancho en
las cuatro fotos verticales, pero el **0,9 %** en la panorámica, que abarca la sala entera. Sin
corregirlo, el claro medía 240 px de foto para presas de 70, y el radio de captura, 280 px, con las
presas separadas ~100: **el segundo toque borraba la presa anterior en vez de añadir una nueva**.

La columna dice cuánto ocupa una presa típica en esa foto (0.03 en los muros verticales, 0.009 en la
panorámica), llega al lienzo por la prop `escalaPresa` y de ahí sale `k = escalaPresa / 0.03`, que
multiplica a `RADIO_TOQUE`, a `RADIO_FOCO` y a la cascada de ventanas de `medidas.ts`. **Con `k = 1`
el resultado es el de siempre**, y eso es lo que hay que preservar en cualquier cambio: el dato es
explícito y no deducido del aspecto de la foto, por lo mismo que `panoramico`.

**4. Las presas se iluminan; el resto del muro se apaga.** No hay marcador *encima* de la presa:
un `<svg>` superpuesto pinta un rectángulo negro al `OSCURIDAD = 0.72` recortado por una `<mask>` con
un claro difuminado por presa (`RADIO_FOCO = 0.030` del ancho, `DIFUMINADO = 0.35` del radio), y en
el borde de cada claro un aro del color del tipo con resplandor. La presa queda entera a la vista.
Antes era un pin de gota con bulbo, y antes de eso un círculo centrado sobre la presa que la tapaba.

**La presa además se aclara de verdad, no solo se libra de la sombra.** Debajo del velo negro,
`CapaClara` pinta una SEGUNDA copia de la foto (`<image href={imagen}>`, la misma URL, la sirve la
caché) recortada a las presas y pasada por `feComponentTransfer` lineal (`slope 1.45`,
`intercept 0.05`) más un `saturate 1.2`. Encaja píxel a píxel porque el `viewBox` va en píxeles de
la caja y la caja tiene el aspecto de la foto. Dos reglas:

- **Las dos máscaras salen de la misma función `FormasPresas`**, con el color y el gradiente como
  parámetros: la del velo lleva las presas en negro sobre blanco y la de la capa clara al revés. Si
  se tocan por separado, el claro y el aclarado dejan de coincidir y se ve un halo.
- **`CapaClara` va memoizada y no puede depender de `escala`.** El filtro es caro; si sus props
  cambiaran en cada `onTransform`, el navegador lo recalcularía en cada fotograma del zoom.

Tres cosas que no se ven a primera vista:

- **El `viewBox` va en píxeles de la caja** (`0 0 caja.w caja.h`), no en porcentajes. Es lo único
  que hace que los claros salgan **redondos**: `x` es fracción del ancho e `y` del alto, y las
  fotos tienen proporciones distintas. En porcentajes saldrían ovalados.
- **Sin presas marcadas no se dibuja la capa.** Si no, el editor arrancaría con la foto a oscuras
  y sería imposible buscar la primera presa.
- Los ids de la `mask` y del `radialGradient` salen de `useId()`, para que dos lienzos en la misma
  página no se pisen.

La etiqueta (`I`/`T`/`IT` o el número de orden) va en un **disco pegado al aro a 45º**, fuera del
claro, con el texto como `<text>` del SVG; su tope es el 60 % del diámetro del disco para que no
desborde. Las presas de mano/pie no llevan disco.

**El claro se ajusta a la presa medida**, tanto en el visor como en el editor: los dos pasan la prop
`medir` de `WallCanvas` (`false` por defecto). El editor dibujó círculos durante un tiempo, para
marcar rápido; se cambió al ver la referencia de Crux, y sale a cuenta porque la caché de medidas va
por presa. El aro de color lleva debajo el mismo trazo en negro al 75 % y **un punto más ancho**
(`grosor + 1`, no el doble: con el doble la línea se ve recargada), que es lo que hace que el color
se lea igual sobre una presa clara que sobre una oscura. El trazo va a `1.5 / escala` y el
resplandor a `3 / escala`; los dos se bajaron juntos, porque con la línea fina un halo de 5 px la
vuelve a engordar y el cambio no se nota.

**`inicio-top` se dibuja bicolor, partiendo el aro por la mitad**: media vuelta en el color de top y
media en el de inicio, con el trazo negro entero por debajo. En el contorno son dos `<polyline>`
sobre las dos mitades de la lista de vértices; en el círculo, dos arcos. El disco de la etiqueta
`IT` va en el color de inicio. Un solo color no se distinguía de una presa de inicio normal.

**El creador puede corregir a mano el tamaño del foco.** La medida automática es una propuesta: cada
presa admite un `tamano` (multiplicador, 1 por defecto) que se aplica a la vez al claro y al aro. Es
el modo **«Ajustar foco»** del editor, entre 0,5 y 2,5 en pasos de 0,1. Dos reglas:

- **El factor se aplica solo en `ejesDe` y `contornoDe`**, las dos únicas fuentes de la forma. Si el
  claro y el aro se escalaran por caminos distintos volvería el halo. En el contorno el escalado es
  respecto a la coordenada de la presa, no al centroide del polígono, para que la forma no se
  desplace al crecer.
- **`limpiarHolds` no escribe `tamano` cuando vale 1**, así los bloques que no lo usan quedan igual
  que antes.

En ese modo, tocar una presa solo la **selecciona** (no borra ni cambia el tipo), y la seleccionada
se marca con un aro blanco discontinuo por fuera del de color, al 118 % — por fuera y no encima,
para no tapar justo lo que se está ajustando.

`src/lib/medidas.ts` mide cada presa **en el navegador** (coordenadas 0..1, nada guardado en la base
de datos) y devuelve una **cascada de recursos**, en este orden:

1. **Contorno**: el borde real de la región (cóncavo incluido), como polígono de 8 a 28 vértices.
2. **Elipse** por momentos de la región (centroide, covarianza, semiejes a 2 sigma y ángulo).
3. **Círculo del área cruda**: no hay forma válida, pero sí una región que creció con tamaño
   creíble; se dibuja un círculo de área equivalente. Se pierde la forma, no el tamaño.
4. **Círculo con la mediana de radios del bloque**, para las presas que no se han podido medir. Este
   retoque es **por bloque y no entra en la caché** (la caché guarda la medida cruda de cada presa).
5. **`null`** —ya casi nunca—, y entonces el lienzo dibuja el círculo de `RADIO_FOCO` con su aro.

**Se mide sobre un recorte de la foto a resolución nativa, no sobre la foto entera reducida.** Antes
se decodificaba toda la imagen a un canvas de 900 px de ancho y todas las presas se medían ahí; en
la panorámica eso dejaba una presa de 70 px de foto en **7,9 px de trabajo**, por debajo de
`MIN_SEMIEJE = 6`, y el contorno que salía tenía 9 vértices: un churro, no una silueta. Ahora se
cachea la **imagen decodificada** por URL y cada presa recorta su ventana con `drawImage(sx, sy, sw,
sh, …)` sobre un lienzo de **lado fijo `LADO = 252`**.

Ese 252 es la pieza que sostiene el cambio, y no es arbitrario: es justo el lado que ocupaba la
ventana mayor dentro del canvas de 900 (`0.14 * 900 * 2`). Manteniéndolo, la relación entre píxeles
de trabajo y píxeles de foto es **idéntica a la de antes en un muro normal**, así que `MAX_SEMIEJE`,
`MIN_SEMIEJE`, `TOL_SIMPLIFICADO` y los topes de vértices siguen valiendo sin recalibrar. Las tres
ventanas de la cascada dejan de recortar la foto y pasan a ser **subventanas del lienzo**
(`RADIOS_REL`, fracción del semilado): sobre un muro de 2400 px dan los mismos 50, 81 y 126 px de
antes. La presa sigue midiendo ~33 px de trabajo en el Spray Wall y pasa de 7,9 a ~26 en la
panorámica. Medido en producción antes y después: «Hori», 11 contornos de 11 en los dos casos;
«Alargadera», que tiene una presa a `x = 0.004` —pegada al borde, donde el recorte se sale de la
foto y lo que falta entra como transparente—, 4 contornos y 3 aros en los dos casos.

**La regla que no se puede romper: ninguna presa se queda sin aro de color, nunca.** Ni cuando falla
la detección ni mientras se calcula. Esa fue la queja real de la sala: la primera versión no dibujaba
aro si no había silueta, y como las presas de mano tampoco llevan disco, se volvían invisibles. Los
niveles 3 y 4 son la segunda vuelta de lo mismo: el círculo de reserva ahora tiene un tamaño medido,
no la constante del lienzo, que sobre una presa grande se veía como un punto en medio.

Lo que costó encontrar: **los contornos se partían por el brillo, no por la tolerancia.** Una presa
tiene la mitad iluminada y la mitad en sombra —mismo tono, luminancia muy distinta—, así que el
crecimiento de región se paraba a medio camino. Por eso hay **ocho pasadas**: cuatro con
`PESO_CROMA = 0.12` (la luminancia casi no cuenta) y tolerancias `40, 28, 20, 14`, y cuatro con
`PESO_CLASICO = 0.5` y tolerancias `45, 32, 22, 15`, que recuperan las presas que en tono se
confunden con la madera pero en brillo no. Medido sobre dos bloques reales del Spray Wall:
**13 contornos buenos de 20 presas**, y con una sola pasada eran 4 de 10.

**No gana la primera pasada que pasa los filtros, sino la más estable.** `elegirEstable` ordena
todos los candidatos por área creciente y acepta mientras el área no dé un salto mayor que
`SALTO_MAX = 1.6`; se queda con el último aceptado. Con la regla antigua decidía el orden de las
pasadas, y media presa iluminada le ganaba a la presa entera: pasa todos los filtros (área válida,
homogeneidad altísima, contiene el punto) y se mide antes. Mientras el crecimiento sea suave, más
área es más presa; el primer salto delata el escape a la vecina y ahí se corta.

**La distancia de color no es la euclídea del principio.** La cara en sombra de una presa conserva
el TONO pero pierde SATURACIÓN, así que el croma se descompone en su parte tangencial (arco de tono,
pesado por el croma menor, porque el tono de un píxel casi gris no es fiable) y su parte radial
(diferencia de saturación), y a esta se le baja el peso de 2 a 0,5. El término dominante mantiene la
escala de siempre: **las tolerancias no hay que recalibrarlas**. Salvaguarda: por debajo de
`CROMA_MINIMO = 12` —presas grises, blancas o negras— el tono es ruido y se vuelve a la fórmula
clásica.

El borde se traza con **Moore-neighbor** sobre la máscara y se simplifica con Douglas-Peucker (8 a
28 vértices). Es el **contorno real, cóncavo incluido**: el casco convexo era el culpable de que dos
presas juntas salieran como una sola mancha, porque rellenaba el hueco de en medio. Hoy el casco
convexo solo se calcula para medir la **solidez** (`MIN_SOLIDEZ = 0.72`, área de la máscara entre
área de su casco): una región con forma de reloj de arena es la que ha cogido dos presas y el puente
entre ellas.

Además, antes de trazar: **cierre morfológico NEUTRO** (dos dilataciones y dos erosiones) y
**`rellenarAgujeros`**, que marca como interior todo lo no alcanzable desde el borde del cuadrado.
Sin lo segundo, el agujero del tornillo partía la región y el contorno acababa rodeando el hueco en
vez de la presa. Y el cierre tiene que ser neutro: con 2+1 quedaba una dilatación neta de 1 px, y
ese píxel de más es justo el que tiende un puente entre dos presas separadas por una línea fina de
sombra. La elipse de reserva sigue con su cierre de 1+1.

**La ventana de búsqueda va en cascada: `RADIOS_MAX = [0.055, 0.09, 0.14]` del ancho** (por `k`, y
hoy aplicadas como fracción del semilado del recorte). Con una sola
ventana de 0.055 —101 px sobre el canvas de 900— una presa grande no cabe: o se sale por los bordes,
o se pasa del `MAX_AREA`, y los dos filtros la tiran. Medido sobre la foto del Spray Wall, con 15
presas grandes reales: **0 contornos con una ventana, 9 con la cascada**, y ninguna pérdida en las
pequeñas (probado aparte con 14). Eso era «en las grandes sale un círculo».

Tres detalles de la cascada, y los tres importan:

- **Solo se agranda la ventana si alguna pasada avisó de que la presa no cabe**, y ese aviso
  (`DESBORDA`) lo dan tanto tocar el borde como pasarse de `MAX_AREA`. Lo segundo es lo que rescata
  a la presa grande, que cabe entera sin tocar el borde y aun así se pasa de área. Si ninguna pasada
  avisó, la región cabía holgada y falló por otra cosa: se corta, porque con más ventana va a fallar
  igual y agrandarla cuesta el triple de tiempo.
- **Mientras queden ventanas, el límite de borde es `MAX_BORDE_ESTRICTO = 0.06`**, no el 0.35 de
  siempre, que se reserva para la última. Así una presa que roza el borde de la ventana pequeña se
  vuelve a medir con sitio de sobra en vez de quedarse con un contorno truncado.
- **El crecimiento de región se corta en cuanto se pasa de `MAX_AREA`.** Un toque sobre la madera
  inundaba la ventana entera, ocho veces por ventana, para acabar descartándose igual: 988 ms → 412 ms
  en esas 15 presas, sin cambiar ni un resultado.
- **Los candidatos de todas las ventanas probadas se acumulan** y compiten juntos en
  `elegirEstable`. Si cada ventana eligiera por su cuenta, una presa grande se quedaría con el
  candidato truncado de la ventana pequeña y nunca llegaría a verse la buena.

Probado y descartado: subir `MAX_AREA` a 0.25 y `MAX_SEMIEJE` a 80 no gana **ni una** presa, y lo
primero ensancha los contornos más allá del borde real de la presa.

Los descartes, todos medidos y no inventados:

- Geométricos, sobre la región: la ventana de la cascada, `MAX_BORDE = 0.35` del perímetro (0.06
  mientras queden ventanas), `MIN_AREA` 0,15 % y `MAX_AREA` 15 % del cuadrado.
- `MIN_HOMOGENEIDAD_CONTORNO = 0.68` y `MIN_HOMOGENEIDAD = 0.55` (elipse): fracción del interior que
  sigue pareciéndose al color de referencia, **con el peso y la tolerancia de la pasada que ganó**;
  compararlo con otros valores da resultados incoherentes. Es el filtro que de verdad discrimina: la
  elipse que se comía tres presas vecinas daba 0,51 y la que rodeaba un agujero 0,38, contra 0,61 a
  0,94 en todas las buenas.
- `MIN_SOLIDEZ = 0.72` sobre el contorno: descarta el reloj de arena, o sea dos presas y el puente.
- **El punto que marcó el usuario tiene que caer dentro** de la forma, y para la elipse además
  semieje mayor ≤ 46 px del lienzo de trabajo, menor ≥ 6 y relación entre ejes ≤ 4.

Dos trampas del dibujo:

- **En la `<mask>`, el negro ilumina y el blanco oscurece.** El `<rect>` de fondo es blanco y cada
  claro se abre pintando negro (el `radialGradient` arranca en `#000`). Un polígono en blanco deja
  la presa *tapada*, que es justo lo contrario, y pasó exactamente eso.
- **Los dos semiejes se normalizan por el ANCHO** y los dos se multiplican por `caja.w`. Como la
  caja tiene el aspecto de la foto, así la elipse no se deforma; normalizando `b` por el alto
  saldrían achatadas. Los puntos del contorno, en cambio, van `x` por ancho e `y` por alto.

Y dos cosas heredadas que siguen valiendo: **la imagen se carga con `crossOrigin="anonymous"`** (si
el bucket no lo permitiera, `getImageData` lanza `SecurityError` y *todas* las presas caen al
círculo —canvas contaminado, no fallo del algoritmo—), y el resultado se **cachea en memoria**, así
que recargar la página lo recalcula.

La caché va **por presa** (`imagen|escala|x|y` — la escala entra en la clave porque cambiarla cambia
la medida), y la **imagen decodificada** de cada foto se guarda aparte para no volver a
descargarla ni decodificarla. Iba por imagen + lista completa de presas, y con el editor midiendo
eso volvía a medirlo todo en cada toque.

Esto es visión artificial sobre fotos de sala: **el resultado depende de la foto**. Con luz uniforme
y presas saturadas acierta casi siempre; contra madera clara, no. Que una presa concreta salga con
aro en vez de contorno es el comportamiento previsto, no una regresión.

**5. La barra de zoom aplica el zoom sin animación, a propósito.** `centerView(escala, 0)`. Con
animación la librería escribe el `transform` en el DOM mientras el `onTransform` provoca un
re-render de React que lo sobrescribe: el indicador subía y la foto no se movía. Por lo mismo, el
indicador y la posición de la barra se leen **solo** de la escala real que llega por `onTransform`,
nunca de un valor optimista. El recorrido es geométrico (`escala = zoomMax^t`).

**El máximo no es el mismo en todos los muros**: `ZOOM_MAX = 8` y `ZOOM_MAX_PANORAMICO = 16`, y el
efectivo (`zoomMax = panoramico ? … : …`) tiene que ir **a la vez** en `maxScale`, en el tope de
`aplicarEscala`, en el clamp del zoom inicial y en `aEscala`/`aPosicion`, que lo reciben por
parámetro. Si la barra calcula con un máximo y el lienzo permite otro, el indicador y la foto dejan
de corresponderse, que es el mismo fallo que provocaba la animación.

**6. El muro panorámico arranca con el zoom puesto.** La prop `panoramico` (que viene de la columna
`walls.panoramico`, no de medir el aspecto de la foto) hace que, una vez conocidos el aspecto real y
la caja, se aplique `alto / caja.h`: la foto llena la altura del móvil y la sala se recorre a lo
ancho, en vez de verse como una tira diminuta en medio de la pantalla. **Solo una vez por imagen**
—si el usuario aleja, no se le vuelve a imponer— y sin animación, por lo mismo que la barra de zoom.

Y por eso su zoom máximo es 16 y no 8: **arranca ya ampliada** (×1,4 en escritorio, ~×3,8 en móvil),
así que con el tope de 8 le quedaban dos ampliaciones escasas por encima de lo que se ve al abrir.
El 16 está emparejado con la foto, no elegido al azar: a ×16 se dibuja a 7168 px de ancho sobre los
8000 reales, o sea justo antes de agotar la resolución. Subir el tope sin subir la foto solo amplía
píxeles borrosos. Medido en producción sobre la matriz del DOM: 1,364 → 16, y la foto crece con él.

Que sea una columna y no el aspecto de la imagen es deliberado: el aspecto no se conoce hasta que la
foto ha cargado, y hay decisiones que se toman antes (la tarjeta del muro ocupa las dos columnas de
la rejilla y no muestra la pastilla del ángulo, y la cabecera del visor y el selector del editor
escriben solo el nombre, sin `· 0º`).

El visor tiene además **pantalla completa** (`/bloque/$boulderId`), con el mismo `WallCanvas` a
`h-dvh`. Empuja una entrada al historial al abrirse, así que el botón «atrás» del móvil cierra la
foto en vez de salirse del bloque; al cerrarla desde el botón, el `useEffect` deshace esa entrada.

### Modelo de datos

```
profiles    id · nombre · rol ('entrenador'|'alumno') · created_at
            user_id → auth.users (unique, anulable) · email (anulable)
user_roles  id · user_id → auth.users · role ('alumno'|'entrenador'|'admin')
            created_at · UNIQUE(user_id, role)
walls       id · nombre · angulo · imagen · orden · panoramico bool  -- 5 filas
            escala_presa real (0.03 por defecto, 0.009 en la panorámica)
boulders    id · wall_id · nombre · grado · creador_id · creador_nombre
            creador_rol · descripcion · holds jsonb · numerar bool · created_at
            imagen · holds_previos jsonb · imagen_previa    -- las 3 anulables
            grado_consenso (anulable) · votos_grado int     -- los calcula un trigger
ascents     id · boulder_id · user_id · user_nombre · created_at · UNIQUE(boulder_id,user_id)
grade_votes id · boulder_id · user_id (→ profiles) · grado · created_at · updated_at
            UNIQUE(boulder_id, user_id)
```

`holds` es `{x, y, tipo, tamano?}` con `tipo` en `inicio | mano | top | inicio-top`. El cuarto es
para las travesías circulares (la misma presa es inicio y top) y **cuenta como inicio y como top** en
todos los recuentos y validaciones. `tamano` es el multiplicador del foco del modo «Ajustar foco», y
solo está presente cuando el creador lo ha cambiado. `numerar` (por defecto `false`) decide si el
marcador muestra el orden o solo `I`/`T`/`IT`: los entrenadores no querían una secuencia impuesta,
el orden lo decide quien escala.

`walls.panoramico` marca la foto apaisada de toda la sala (el quinto muro, `angulo` 0). Es un dato,
no una deducción del aspecto de la imagen: ver el punto 6 de `WallCanvas`. `walls.escala_presa` es
su pareja para el marcado (punto 3 bis): cuánto ocupa una presa en esa foto. **Un muro nuevo con un
encuadre distinto del de un panel necesita su valor**, o el claro y la zona sensible saldrán
descolocados aunque el código esté bien.

`boulders.imagen` **fija la foto de ese bloque**: si es `null` — el caso normal — se usa la del muro.
Solo se rellena cuando un bloque se queda anclado a una foto anterior, y el helper `fotoDeBloque()`
resuelve las dos situaciones; usarlo en cualquier sitio nuevo donde se pinte un bloque.
`holds_previos` e `imagen_previa` guardan el estado anterior al último reajuste, y son lo que hace
posible «Deshacer reajuste».

`walls.imagen` admite un nombre de archivo (`spraywall.jpg` → `/walls/…`, las fotos de `public/`)
o una **URL absoluta** del bucket `walls` de Storage, que es lo que guarda el panel de entrenador.
`imagenUrl()` distingue ambos casos; no romperlo. Hoy los cinco muros apuntan ya a Storage, pero el
camino del nombre de archivo sigue siendo el que se usa al dar de alta un muro por migración.

### Cuentas, roles y el perfil reclamado

**Email y contraseña con Supabase Auth**, con el mismo esquema que `repara.nekoescalada.com`
(proyecto Lovable `neko-fix-it`): sesión de Supabase, `user_roles` + `has_role()` en las RLS, y las
cuentas de entrenador concedidas por un admin. El código de sala ya no existe.

La regla que sostiene todo lo demás: **`profiles.id` sigue siendo la identidad de la app y no cambia
de valor**. La cuenta se *enlaza* con `profiles.user_id` (→ `auth.users`) y `profiles.email`, así que
`boulders.creador_id` y `ascents.user_id` nunca se reescriben. Cualquier cambio futuro que implique
migrar los ids de los perfiles rompe los 15 bloques y los encadenes que ya hay.

`handle_new_user` (trigger sobre `auth.users`) hace tres cosas: reclama el perfil antiguo más antiguo
con ese nombre y `user_id is null` —forzándole `rol = 'alumno'`, para que reclamar el nombre de un
entrenador no dé sus permisos—, o crea uno nuevo si no lo hay; inserta el rol `alumno`; y da `admin`
y `entrenador` **solo al email `diego@nekoescalada.com`**. No se usa la regla de neko-fix-it de que
el primer usuario sea admin: la app ya estaba publicada y se habría registrado antes cualquier alumno.

`perfil_por_nombre()` es lo que alimenta el aviso del formulario de registro («recuperarás sus 6
encadenes y sus 3 bloques») y **tiene que desempatar igual que el trigger**: informar del más antiguo
sin reclamar. Si las dos funciones divergen, la pantalla promete una cosa y el registro hace otra.

`user_roles` es la fuente de verdad del rol. `profiles.rol` es una copia que mantiene al día el
trigger `sync_profile_rol`, y existe solo para que siga funcionando lo que ya pintaba con ese campo
(`creador_rol`, la estrella del creador, los filtros del muro). **Para decidir permisos, usar
`esEntrenador` / `esAdmin` de `useUser()`, nunca `user.rol`.**

Las RLS ya no son permisivas: lectura pública en `walls`, `boulders`, `ascents`, `profiles` y
`grade_votes` —para no romper los enlaces compartidos—, y escritura acotada con `mi_perfil()` y
`has_role()`. `mi_perfil()` es el helper que traduce `auth.uid()` al id del perfil.

### El grado: el del creador y el de la comunidad

`boulders.grado` es **el del creador** y no lo cambia la votación. Se edita después de publicar desde
la propia ficha, con el lapicero pequeño junto a la pastilla «Creador» (creador y entrenadores).

El de la comunidad es la **mediana** de `grade_votes` (`percentile_disc(0.5)`), desnormalizada por
trigger en `boulders.grado_consenso` y `votos_grado`. Mediana y no media por dos razones: devuelve
siempre un grado real de la escala, y un voto exagerado no mueve el resultado. Está desnormalizada
a propósito: en la sala hay mala cobertura y la lista del muro no puede hacer una consulta por bloque.

**Editar un bloque es solo de quien lo creó**, y la política de `UPDATE` de `boulders` es
`creador_id = mi_perfil()` en el `using` y en el `with check` (lo segundo, para que nadie pueda
cambiarle el dueño a un bloque mientras lo edita). **Borrar sigue siendo del creador, los
entrenadores y el admin**: es la única forma de limpiar el bloque de alguien que ya no viene. La
asimetría es deliberada y la pidió la sala; no «arreglarla» igualando las dos.

Vota solo quien tiene el encadene, y **el creador no vota el suyo**; las dos condiciones van en el
`with check` de la RLS, no solo en la interfaz. Al borrar un encadene, un trigger sobre `ascents`
retira también su voto.

Donde haya que elegir un grado solo —filtro y orden del muro, pirámide y grado máximo de progreso—
se usa `gradoEfectivo()`, igual que `fotoDeBloque()` para la foto. Si se añade una pantalla nueva que
pinte un grado, pasa por ahí.

### Rutas

`/` muros · `/muro/$wallId` lista con filtros · `/bloque/$boulderId` visor + "¡Encadenado!" ·
`/crear` y `/crear/$wallId` editor · `/progreso` ticklist · `/instalar` QR ·
`/entrenador` panel de entrenador (cambiar la foto de un muro; y, si eres admin, dar y quitar el rol
de entrenador) · `/reset` poner contraseña nueva · `/ayuda` guía de uso dentro de la app.

`/reset` es la **única ruta que se ve sin sesión**: el `Gate` de `__root.tsx` la deja pasar a
propósito, porque es donde aterriza el enlace del email de recuperación.

`/ayuda` es un acordeón de once secciones, la primera «SprayWall está en beta» y abierta por
defecto (`defaultValue="beta"`). Dos cosas que no se ven en el código a primera vista:
la sección «Soy entrenador» solo se monta si `esEntrenador` (el rol real, no el campo del perfil).
Su leyenda de presas (el componente `Foco`) **reimplementa** el dibujo de `WallCanvas` —máscara, aro
bicolor del `inicio-top` y disco— con los mismos `HOLD_COLORS`, así que un cambio en la presa obliga
a tocar los dos sitios; ahí se quedó atrás, por ejemplo, la opacidad del velo (0.56 en la miniatura
contra `OSCURIDAD = 0.72` en el lienzo). Se llega desde el icono `?` de Muros, otro en la
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
  (va por `spraywall-v4`). Si no, quien tenga la PWA instalada seguirá viendo los iconos
  viejos: el service worker los tiene precacheados. El `sw.js` hace cache-first también con
  `/storage/v1/object/` (las fotos subidas), y funciona porque sus nombres son únicos.
- El nombre de archivo en `Imagenes/web/` debe coincidir con la columna `walls.imagen`; el mapeo
  está en la tabla `$mapa` de `scripts/preparar-imagenes.ps1`.
- El icono maskable va al **66 %** de ocupación (los demás al 86-94 %) porque Android lo recorta
  en círculo y con más ocupación le corta las orejas y la cola al gato.
- **El service worker solo se registra en la URL publicada**, no en la previsualización del editor.
  Para probar la instalación como PWA hay que usar la URL de producción.
- Al cambiar de dominio ya no se pierde la identidad: la sesión es de Supabase Auth y basta con
  entrar con el mismo email. Lo que sí es por origen es la caché del service worker.
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
