# Análisis detallado — Retro Flash: Climbing

> Documento de investigación sobre la app **Retro Flash: Climbing** (`com.arcadebouldering.system_wall`).
> Fecha del análisis: **11 de agosto de 2026**.
> Fuentes: fichas de Google Play y App Store, web oficial `arcadebouldering.com.de`, capturas de la store y reseñas públicas.

---

## 1. Resumen ejecutivo

**Retro Flash** es una app móvil (Android + iOS) para **spray walls** y paneles de escalada (bouldering). Su idea central es sencilla y potente:

> Se sube una **fotografía** de un muro de escalada. Sobre esa foto, cualquier usuario puede **marcar presas** para definir un bloque (boulder), asignarle nombre, grado y reglas, publicarlo y que otros lo **encadenen (send)** y lo registren.

Es decir: convierte un muro físico de presas densamente pobladas —donde no hay rutas marcadas con cinta— en una **base de datos social de bloques**, replicando lo que MoonBoard/Kilter hacen con tableros estandarizados, pero **para cualquier muro arbitrario** (rocódromo comercial, muro de casa, panel de entrenamiento).

No es un juego pese a aparecer a veces bajo categorías de ocio: es una herramienta de entrenamiento + red social vertical de escalada.

---

## 2. Ficha técnica

| Campo | Google Play (Android) | App Store (iOS) |
|---|---|---|
| Nombre | Retro Flash: Climbing | Retro Flash: Climbing |
| ID / bundle | `com.arcadebouldering.system_wall` | `id1519582483` |
| Desarrollador | Arcade Bouldering UG (haftungsbeschränkt) — empresa alemana | Ídem |
| Categoría | Health & Fitness | Sports |
| Versión | 2.1.7 (build 268) | 2.1.7 |
| Tamaño | ~112 MB | ~171 MB |
| Última actualización | 25 de julio de 2026 | 26 de julio de 2026 |
| Requisitos | Android 6.0+ / 7.0+ según versión | iOS (4+) |
| Valoración | **4,7 ★** (555 reseñas) | **4,7 ★** (226 valoraciones) |
| Descargas | **10.000+** | n/d |
| Precio | Gratis | Gratis |
| Monetización | Anuncios ("Contains ads") + compras in-app | Compras in-app |
| Clasificación | PEGI 3 — "Users Interact, In-App Purchases" | 4+ |
| App complementaria | **Retro Tablet** (€24,99, de pago, para rocódromos) | — |

**Observación:** la ficha de Android declara anuncios, la de iOS no. La cifra de descargas (10K+) y de reseñas indica un producto **de nicho, pequeño**, no un actor masivo.

### Aviso de datos (Data Safety de Google Play)

- **No comparte datos con terceros.**
- Datos que puede recopilar: **Fotos y vídeos** (las fotos de los muros y los vídeos de beta).
- Datos cifrados en tránsito.
- Existe mecanismo para solicitar el borrado de datos.
- En iOS, además, declara recoger **email e identificadores de usuario** vinculados a la cuenta (funcionalidad de la app).

Es un perfil de privacidad **notablemente limpio** para una app social.

---

## 3. Descripción oficial (texto literal de Google Play)

> Welcome to Retro Flash and the Arcade Bouldering Community!
>
> Retro Flash is the Ultimate Spray Wall App, designed with every member of the climbing community in mind!
>
> We have created a lot of unique tools to ensure that everyone has everything they need to get the most out of their spray walls! For example, we support symmetrical, partly symmetrical, adjustable and private walls!
>
> Set all kinds of problems on your wall, like circuits or even competition boulders!
>
> With our wall upgrades, we upgrade your walls to the next level, opening up a lot of new possibilities! Now, you can even upgrade your walls by yourself!!
>
> Retro Flash supports the Fontainebleau, Dankyu and Hueco grading systems. You can also define your own grading systems or even deactivate grading!
>
> Download Retro Flash now and become a part of our growing community!

---

## 4. Qué hace exactamente la app — funcionalidad por bloques

### 4.1 Gestión de muros (Walls)

El objeto central del modelo de datos es el **muro**, que es esencialmente **una foto**.

- **Crear muro**: se sube una fotografía del panel desde la sección "Home Walls" del perfil, o desde el perfil del rocódromo.
- **Resetear muro**: cuando se cambian las presas, se sube una foto nueva. Esto invalida/archiva los bloques anteriores (equivale a un "reset" de rocódromo).
- **Añadir presas sin perder bloques**: existe un flujo específico para subir una foto nueva **conservando los bloques ya existentes** (útil cuando solo se añaden presas, no se reconstruye el muro).
- **Tipos de muro soportados** (esto es su diferenciador declarado):
  - **Simétricos** — permite espejar bloques automáticamente (marcas un bloque y existe su versión reflejada).
  - **Parcialmente simétricos** — solo una zona del muro es simétrica.
  - **Ajustables** — muros con inclinación variable (el ángulo forma parte del contexto del bloque).
  - **Privados** — visibles solo para un grupo determinado (equipos, casa, entrenadores).
- **Favoritos**: se pueden marcar muros con un corazón y encontrarlos en la página *Projects / Walls / Folders*.
- **Visibilidad**: público, o restringido a un **grupo privado**.

### 4.2 "Wall Upgrade" — el concepto clave del producto

Un muro "normal" es solo una foto: para marcar una presa hay que **tocar sobre el píxel** y la app coloca un marcador aproximado.

Un **muro *upgraded*** tiene **cada presa y cada volumen delimitados por un polígono vectorial**. Esto cambia la experiencia por completo:

- Marcar una presa es **un solo toque** sobre la presa, y queda perfectamente contorneada.
- Los bloques se ven mucho mejor (contornos con grosor y separación estéticamente calibrados).
- Permite funciones avanzadas: **simetría real** (el equipo mapea qué presa corresponde a cuál en el lado espejo), reglas por presa, etc.

Este *upgrade* se ofrece de dos formas:

1. **Servicio manual del equipo de Arcade Bouldering** — se compra un *Wall Upgrade Code* en su tienda (**€99, en oferta a €80**), se introduce en la página de edición del muro, y su equipo dibuja los polígonos manualmente. El plazo depende de la cola de pedidos y del número de presas. El progreso se puede seguir desde la app. Soporte: `support@arcadebouldering.com`.
2. **Auto-upgrade del usuario** — funcionalidad añadida recientemente ("Now, you can even upgrade your walls by yourself!!"), que permite al propio usuario contornear su muro sin pasar por el servicio de pago.

> **Lectura estratégica:** este es a la vez el mayor activo y el mayor cuello de botella del producto. El valor real de la app depende de un trabajo **manual, humano, no escalable** de vectorización de presas. Es exactamente el punto que hoy resolvería una segmentación automática por visión artificial (SAM / detección de instancias).

### 4.3 Creación de bloques (Set Boulder)

Flujo observado en las capturas oficiales:

1. **Pantalla "Set Boulder"** — se muestra la foto del muro con zoom/pan. Se toca cada presa para asignarle un rol.
2. **Roles de presa** (botones inferiores): **Start (S)**, **Middle (M)**, **Top (T)**. Cada rol se representa con un color distinto sobre la presa. En las capturas también aparecen etiquetas **L** (mano izquierda) y **R** (mano derecha) sobre presas concretas.
3. **Botón "+ Rules"** — reglas por presa individual:
   - `no match` (no se pueden juntar las dos manos)
   - `no foot` (no se puede pisar)
   - `Zone` (presa de zona, para competición)
   - `Top`
   - `Right Hand` / `Left Hand` (obligar mano concreta)
   - Modo **Free Feet** (pies libres, todo vale) como alternativa a marcar pies.
4. **Pantalla "Add Boulder"** — metadatos:
   - **Nombre** (máx. ~20 caracteres)
   - **Descripción** (máx. ~250 caracteres, p. ej. *"don't match the blue holds :)"*)
   - **Tags de estilo** con iconos: **Dyno, Power, Slopey, Pump, Crimpy**…
   - **Grado** mediante selector deslizante (p. ej. V0 → V0+)
   - Toggle **"Sent?"** — marcar si ya lo has encadenado al publicarlo
5. **Guardar** → el bloque queda publicado en el muro.

### 4.4 Circuitos y bloques de competición

- **Circuitos**: se numeran las presas *Middle* (azules) tocando el círculo azul al marcar. Sirve para secuencias ordenadas de calentamiento o entrenamiento.
- **Bloques de competición**: combinando reglas por presa (Zone, Top, mano obligada) se replica el formato de competición.
- **Folders (carpetas)**: agrupan bloques de forma privada y se **publican todos a la vez** en un momento dado, o se comparten por **enlace directo o código QR**. Esto habilita:
  - **Simulaciones de competición** para entrenadores
  - **Eventos y competiciones internas** en rocódromos

### 4.5 Sistemas de graduación

Soporta múltiples escalas, algo poco común:

- **Fontainebleau** (6A, 7B+…)
- **Hueco / V-scale** (V0, V5…)
- **Dan-kyū** (escala japonesa)
- **Escalas personalizadas** definidas por el usuario
- **Graduación desactivada** (bloques "open" / sin grado, como se ve en la captura: *"Grade: open"*)

### 4.6 Registro de ascensos y estadísticas

- **Log send**: botón directo en la ficha del bloque para registrar el encadene.
- **Añadir vídeo de beta** al *send* (editable a posteriori).
- Ficha de bloque con pestañas **Details / Proj / Sends**, mostrando: descripción, *Set by* (quién lo puso), grado, nº de sends, nº de likes, valoración por estrellas y el muro al que pertenece.
- **Notas privadas** bajo cada bloque (para entrenamiento propio, no visibles para otros).

> ⚠️ **Punto débil reconocido por los usuarios:** el "logbook" es flojo comparado con Kilter/Tension/Moon. No ofrece un desglose completo por grados y volumen de bloques encadenados, ni permite comentar el propio *send*.

### 4.7 Capa social / comunidad

- **Perfiles de usuario** y **seguir a otros escaladores**.
- **Feed** con los últimos sends y bloques de la gente a la que sigues, más un apartado de *popular sends and boulders*.
- **Fist bumps** (choque de puños) — el "me gusta" sobre un send ajeno.
- **Corazones (hearts)** para bloques y muros favoritos.
- **Valoración por estrellas** de los bloques (calidad de la línea).
- **Proyectos compartidos**: la app te muestra **quién más tiene el mismo bloque como proyecto**, para "proyectar juntos". Hay un botón dedicado para añadir un bloque a proyectos.
- **Grupos privados** para hogares, equipos o clubes.

### 4.8 Funcionalidades para rocódromos comerciales

- **Alta del rocódromo** en el directorio, con ubicación, para que los clientes lo encuentren. La pantalla principal muestra "Favorite Gyms" / "Recent Gyms" con buscador y contadores de muros/bloques.
- **Perfil de rocódromo** con logo, nombre, ubicación y enlaces a redes sociales (Instagram, Facebook, X, YouTube).
- **Subida y reseteo rápido de muros**, sin periodo de espera.
- **Nombre del equipo de equipadores (setters)** visible para los clientes.
- **Eventos y competiciones** vía carpetas + QR.
- **Retro Tablet**: app separada, de pago (**€24,99**, ~1+ descargas, actualizada en 2021 y aparentemente abandonada), pensada para instalar en una tablet fija junto al muro, mostrando **solo los muros de ese rocódromo**, de modo que el cliente no necesita instalar nada ni registrarse.

### 4.9 Funcionalidades para entrenadores

- Bloques de competición con reglas por presa.
- Circuitos numerados compartibles.
- Carpetas para simulaciones de competición.
- **Muros privados** visibles solo para los atletas del grupo.
- Seguimiento de los atletas: sus sends, sus vídeos de beta, su progresión.

---

## 5. Arquitectura funcional (modelo de datos inferido)

```
Usuario
 ├── perfil, seguidores/seguidos, feed
 ├── Home Walls (propios)
 ├── Proyectos / Favoritos / Carpetas
 └── Sends (log)

Gym (rocódromo)
 ├── perfil, ubicación, redes sociales, setter team
 └── Walls[]

Wall (muro)  ← objeto central
 ├── foto (base de todo)
 ├── tipo: normal | upgraded (polígonos por presa)
 ├── geometría: simétrico | parcialmente simétrico | ajustable
 ├── visibilidad: público | privado (grupo)
 ├── sistema de graduación configurable
 └── Boulders[]

Boulder (bloque)
 ├── nombre, descripción, autor (setter)
 ├── holds[]: { presa, rol: start|middle|top, reglas: no-match|no-foot|zone|left|right }
 ├── modo pies: marcados | free feet
 ├── numeración (circuitos)
 ├── grado (o "open"), tags de estilo
 ├── métricas: sends, likes, estrellas
 └── Sends[] → { usuario, fecha, vídeo de beta, notas privadas }

Folder (carpeta)
 └── Boulders[] con publicación diferida + enlace/QR
```

---

## 6. Modelo de negocio

App gratuita con **compras in-app de tipo "pase"**, no suscripción clásica (los usuarios valoran positivamente que sean **pagos únicos / anuales**, no mensuales recurrentes). Precios de la App Store de EE. UU.:

| Producto | Precio | Para qué sirve |
|---|---|---|
| Home Wall Year Pass | 4,99 $ | Mantener activo un muro de casa durante un año |
| Additional Wall | 9,99 $ | Muro adicional |
| Gym Year Pass Tier 1 | 14,99 $ | Rocódromo, escalón 1 |
| Gym Year Pass Tier 2 | 29,99 $ | Rocódromo, escalón 2 |
| Add Gym | 14,99 $ | Dar de alta un rocódromo |
| 1 Month Upgrade Pass | 8,99 $ | Pase de upgrade mensual |
| 6 Months Upgrade Pass | 44,99 $ | Pase de upgrade semestral |
| Unlock Rules for Circles | 4,99 $ | Desbloquear reglas por presa |
| **Wall Upgrade Code** (tienda web) | **€99 → €80** | Vectorización manual de las presas del muro |
| **Retro Tablet** (app aparte) | **€24,99** | App de tablet para rocódromos |

Además: **publicidad** en la versión Android.

**Cambio reciente (v2.1.7, julio 2026):** *"Introduced annual fees for gyms and home walls to help cover the app's ongoing operational and maintenance costs."* — la app ha pasado de un modelo casi totalmente gratuito a **cuotas anuales obligatorias** para muros de casa y rocódromos. Es un giro importante y una fuente probable de fricción con la base de usuarios existente, que en las reseñas alababa precisamente que fuera gratis.

---

## 7. Fortalezas

1. **Funciona sobre cualquier muro**, no requiere hardware estandarizado ni LEDs. Barrera de entrada casi nula: una foto.
2. **Muros simétricos y parcialmente simétricos** — poco frecuente en la competencia; duplica de facto el catálogo de bloques.
3. **Reglas por presa muy granulares** (no match, no foot, zone, top, mano obligada) → cubre entrenamiento y **formato de competición real**, no solo bloques informales.
4. **Multi-escala de graduación** (Font, V, Dan-kyū, personalizada, o sin grado) → viabilidad internacional.
5. **Carpetas + QR con publicación diferida** → funcionalidad de eventos/competiciones que la mayoría de apps del sector no tiene.
6. **Segmentación clara del producto** en cuatro públicos: escaladores, muros de casa, rocódromos, entrenadores.
7. **Perfil de privacidad limpio**: sin compartición con terceros.
8. **Multiplataforma** Android + iOS + tablet.
9. Valoración muy alta y sostenida (**4,7★** en ambas tiendas).

---

## 8. Debilidades y quejas recurrentes

Extraídas de reseñas públicas de Google Play y App Store:

| Problema | Detalle |
|---|---|
| **Precisión táctil al marcar presas** | Al hacer zoom, la app registra el gesto como *tap* y selecciona presas por error. No distingue bien `tap` / `swipe` / `pinch`. Es el fallo más citado y afecta al flujo nuclear del producto. |
| **Logbook pobre** | Sin desglose de grados ni estadísticas de progresión al nivel de Kilter/Moon/Tension. No se pueden comentar los propios sends. |
| **Falta "copiar ruta"** | No hay forma cómoda de duplicar un bloque para crear variantes. |
| **Rendimiento** | Carga lenta y recuperación de datos lenta reportada por usuarios. |
| **Bugs de gestión de muros** | Fallos al resetear/borrar muros y al añadir cuentas; el flujo "add gym" reportado como no funcional. |
| **Soporte al cliente** | Descrito como "pobre o ausente" en varias reseñas. |
| **Onboarding y pricing confusos** | Curva de aprendizaje alta y poca claridad sobre qué es de pago. Agravado por la introducción de cuotas anuales. |
| **Enlaces de beta de Instagram** | Reportados como no funcionales. |
| **Escala del producto** | 10K+ descargas: el efecto red —esencial en un producto social— es débil fuera de sus rocódromos ancla. |
| **Retro Tablet abandonada** | Última actualización en agosto de 2021, 1+ descargas. La pata "rocódromo comercial" está prácticamente muerta. |
| **Dependencia de trabajo manual** | El *Wall Upgrade* premium requiere que un humano dibuje polígonos, con plazos variables. Cuello de botella estructural. |

---

## 9. Posicionamiento competitivo

| | **Retro Flash** | **Kilter / Tension / Grasshopper** | **MoonBoard** |
|---|---|---|---|
| Tipo de muro | **Cualquiera** (foto) | Tablero estandarizado propietario | Tablero estandarizado |
| Hardware | Ninguno | Panel + LEDs (caro) | Panel + LEDs |
| Bloques | Creados por la comunidad sobre tu muro | Catálogo global compartido | Catálogo global compartido |
| Comparabilidad de grados | Baja (cada muro es único) | **Alta** (mismo panel en todo el mundo) | Alta |
| Coste de entrada | ~0 | Elevado (muro + LEDs) | Elevado |
| Feedback visual en el muro | Solo en pantalla | LEDs físicos | LEDs físicos |
| Público | Rocódromos con spray wall, muros de casa, equipos | Entrenamiento estandarizado | Entrenamiento estandarizado |

**Conclusión:** Retro Flash **no compite** con Kilter/Moon; ocupa el hueco complementario. Su ventaja es la **universalidad** (cualquier muro), su desventaja es la **falta de estandarización** (los grados no son comparables entre muros y la comunidad se fragmenta por muro).

---

## 10. Lecciones para un producto propio de spray wall

Si el objetivo es construir algo en este espacio, lo que Retro Flash enseña:

**Lo que hay que copiar**
- El muro es una foto; ese es el modelo de datos correcto y la barrera de entrada mínima.
- Roles de presa (start/middle/top/pies) + reglas por presa: es el vocabulario mínimo viable, y da acceso al caso de uso de competición.
- Simetría de muro: multiplica el contenido gratis.
- Multi-escala de graduación desde el día uno.
- Muros privados / grupos: es lo que permite vender a equipos y entrenadores.
- Carpetas con publicación diferida y QR: funcionalidad de evento infravalorada.

**Dónde hay hueco real para superarlos**
1. **Detección automática de presas por visión artificial.** Su producto premium de €80–99 es un humano dibujando polígonos. Esto hoy se resuelve con segmentación automática de instancias sobre la foto del muro. Es la mayor oportunidad de diferenciación del sector.
2. **Gestos**: separar limpiamente `tap` / `pan` / `pinch` en el canvas de marcado. Es su bug número uno y afecta al flujo central.
3. **Logbook y estadísticas serias**: pirámide de grados, volumen, progresión temporal, comentarios en los sends. Es la queja más repetida.
4. **Duplicar/derivar bloques** (variantes de una misma línea).
5. **Rendimiento**: carga rápida y modo offline; en un rocódromo la cobertura suele ser mala.
6. **Onboarding y pricing transparentes**: su transición a cuotas anuales es un momento de vulnerabilidad para su base de usuarios.
7. **Normalización de grados entre muros** mediante consenso de la comunidad (votación de grado agregada) para mitigar la fragmentación.

---

## 11. Fuentes

- [Retro Flash: Climbing — Google Play](https://play.google.com/store/apps/details?id=com.arcadebouldering.system_wall&hl=en)
- [Data safety — Google Play](https://play.google.com/store/apps/datasafety?id=com.arcadebouldering.system_wall&hl=en)
- [Retro Flash: Climbing — App Store](https://apps.apple.com/us/app/retro-flash-climbing/id1519582483)
- [Retro Tablet — Google Play](https://play.google.com/store/apps/details?id=com.arcadebouldering.retro_tablet&hl=en)
- [Arcade Bouldering — web oficial](https://www.arcadebouldering.com.de/en)
- [Retro Flash — página de producto](https://www.arcadebouldering.com.de/en/i/retro-flash)
- [Retro Flash for Climbers](https://www.arcadebouldering.com.de/en/i/for-climbers)
- [Retro Flash for Home Walls](https://www.arcadebouldering.com.de/en/i/for-home-walls)
- [Retro Flash for Coaches](https://www.arcadebouldering.com.de/en/i/for-coaches)
- [Retro Flash for Climbing Gyms](https://www.arcadebouldering.com.de/en/i/for-climbing-gyms)
- [Wall Upgrade Codes for Retro Flash](https://www.arcadebouldering.com.de/en/p/wall-upgrade-code)
- [APKCombo — datos técnicos y versiones](https://apkcombo.com/retro-flash-climbing/com.arcadebouldering.system_wall/)
- [Spray wall — Wikipedia](https://en.wikipedia.org/wiki/Spray_wall)
