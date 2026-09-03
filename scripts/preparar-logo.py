"""Genera el juego de iconos de la app a partir del logo del gato.

Entrada:  Imagenes/logo-original.png  (el gato de presas sobre fondo claro)
Salida:   Imagenes/iconos/
            icon-192.png           fondo blanco, para el manifest (purpose "any")
            icon-512.png           idem, 512
            icon-512-maskable.png  fondo blanco y MÁS margen: Android recorta en
                                   círculo, así que el gato va dentro de la zona segura
            favicon.png            96x96, para la pestaña del navegador
            logo.png               512x512 con FONDO TRANSPARENTE, para usar dentro
                                   de la app sobre el tema oscuro

El fondo se recorta con un relleno por inundación desde los bordes, en vez de por
umbral global: así las presas blancas y grises que están DENTRO del gato se conservan
(un umbral global se las comería).

Uso:  python scripts/preparar-logo.py
"""

from collections import deque
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
ORIGEN = RAIZ / "Imagenes" / "logo-original.png"
DESTINO = RAIZ / "Imagenes" / "iconos"

# Un píxel cuenta como fondo si es claro y poco saturado.
BRILLO_MIN = 200
SATURACION_MAX = 28


def es_fondo(px):
    r, g, b = px[:3]
    return max(r, g, b) - min(r, g, b) <= SATURACION_MAX and (r + g + b) / 3 >= BRILLO_MIN


def quitar_fondo(img):
    """Devuelve la imagen en RGBA con el fondo exterior transparente."""
    img = img.convert("RGBA")
    ancho, alto = img.size
    px = img.load()

    fuera = bytearray(ancho * alto)
    cola = deque()

    # Siembra: todos los píxeles del borde que sean fondo.
    for x in range(ancho):
        for y in (0, alto - 1):
            if es_fondo(px[x, y]):
                cola.append((x, y))
                fuera[y * ancho + x] = 1
    for y in range(alto):
        for x in (0, ancho - 1):
            if es_fondo(px[x, y]) and not fuera[y * ancho + x]:
                cola.append((x, y))
                fuera[y * ancho + x] = 1

    while cola:
        x, y = cola.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < ancho and 0 <= ny < alto:
                i = ny * ancho + nx
                if not fuera[i] and es_fondo(px[nx, ny]):
                    fuera[i] = 1
                    cola.append((nx, ny))

    for y in range(alto):
        fila = y * ancho
        for x in range(ancho):
            if fuera[fila + x]:
                px[x, y] = (255, 255, 255, 0)

    return img


def recortar(img):
    """Recorta a la caja del gato, medida solo sobre píxeles de color.

    No sirve usar `getbbox()` del alfa: la sombra del icono original deja píxeles
    grises sueltos en los márgenes que sobreviven al recorte de fondo y ensanchan la
    caja casi 200 px, con lo que el gato saldría pequeño y descentrado. El gato es muy
    saturado y la sombra no, así que la caja se mide sobre la saturación.
    """
    px = img.load()
    ancho, alto = img.size
    minx, miny, maxx, maxy = ancho, alto, -1, -1

    for y in range(alto):
        for x in range(ancho):
            r, g, b, a = px[x, y]
            if a > 128 and max(r, g, b) - min(r, g, b) > 50:
                if x < minx:
                    minx = x
                if x > maxx:
                    maxx = x
                if y < miny:
                    miny = y
                if y > maxy:
                    maxy = y

    if maxx < 0:
        raise SystemExit("No he encontrado contenido de color en la imagen.")

    return img.crop((minx, miny, maxx + 1, maxy + 1))


def componer(gato, lado, ocupacion, fondo):
    """Centra el gato en un lienzo cuadrado ocupando `ocupacion` del lado."""
    lienzo = Image.new("RGBA", (lado, lado), fondo)

    objetivo = int(lado * ocupacion)
    escala = objetivo / max(gato.size)
    nuevo = (max(1, round(gato.width * escala)), max(1, round(gato.height * escala)))
    escalado = gato.resize(nuevo, Image.LANCZOS)

    lienzo.alpha_composite(
        escalado,
        ((lado - nuevo[0]) // 2, (lado - nuevo[1]) // 2),
    )
    return lienzo


def main():
    if not ORIGEN.exists():
        raise SystemExit(f"No encuentro {ORIGEN}")

    DESTINO.mkdir(parents=True, exist_ok=True)

    gato = recortar(quitar_fondo(Image.open(ORIGEN)))
    print(f"gato recortado: {gato.width}x{gato.height}")

    BLANCO = (255, 255, 255, 255)
    salidas = [
        # (nombre, lado, ocupación, fondo)
        ("icon-192.png", 192, 0.86, BLANCO),
        ("icon-512.png", 512, 0.86, BLANCO),
        # Android recorta el maskable en círculo: el contenido debe caber en el 80%
        # central. Con 0.66 de alto y un gato estrecho, la semidiagonal queda dentro.
        ("icon-512-maskable.png", 512, 0.66, BLANCO),
        ("favicon.png", 96, 0.90, BLANCO),
        # Para dentro de la app, sobre el tema oscuro: sin fondo.
        ("logo.png", 512, 0.94, (255, 255, 255, 0)),
    ]

    for nombre, lado, ocupacion, fondo in salidas:
        img = componer(gato, lado, ocupacion, fondo)
        ruta = DESTINO / nombre
        img.save(ruta, "PNG", optimize=True)
        kb = round(ruta.stat().st_size / 1024, 1)
        print(f"  {nombre:24} {lado}x{lado}  ocupacion={ocupacion:.0%}  {kb} KB")

    print(f"\nListo en {DESTINO}")


if __name__ == "__main__":
    main()
