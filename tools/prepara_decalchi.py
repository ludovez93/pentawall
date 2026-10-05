"""Le decalcomanie dell'arena-giocattolo (tappa 10, blocco D).

In NERF Superblast i muri portano grafiche grandi (il marchio, numeri, frecce). Qui
stanno tutte in un foglio solo, e il gioco le incolla sui pannelli dei muri come
quadrati con le coordinate del foglio: tutte insieme sono una chiamata di disegno.

Il foglio non ha colori, ha due maschere: nel rosso la parte bianca della grafica,
nel verde la grafica col suo contorno. Il colore del contorno lo mette il muro (e' il
colore dei suoi bordi), lo shader `assets/giocattolo/decalco.gdshader` li compone.

Le caselle (in pixel, sul foglio da 1024):
  PENTAWALL       0,   0 - 1024, 256
  OCRA            0, 256 -  512, 384      TURBO    512, 256 - 1024, 384
  TRIBUNA         0, 384 -  512, 512      PORTICO  512, 384 - 1024, 512
  stella          0, 512 -  256, 768      cinque   256, 512 -  512, 768
  frecce        512, 512 -  768, 768      fulmine  768, 512 - 1024, 768

Uso (dalla cartella `gioco/`):  python tools/prepara_decalchi.py
"""

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

QUI = Path(__file__).resolve().parent.parent
CARATTERE = QUI / "assets" / "font" / "RussoOne-Regular.ttf"
USCITA = QUI / "assets" / "giocattolo" / "decalchi.png"

LATO = 1024
BORDO = 13  # spessore del contorno, in pixel


def maschera_testo(testo: str, casella: tuple[int, int, int, int]) -> tuple[Image.Image, Image.Image]:
    x0, y0, x1, y1 = casella
    largo, alto = x1 - x0, y1 - y0
    # La misura piu' grande che ci sta col contorno e un margine.
    misura = alto
    while misura > 8:
        carattere = ImageFont.truetype(str(CARATTERE), misura)
        sx0, sy0, sx1, sy1 = carattere.getbbox(testo)
        if sx1 - sx0 <= largo - 2 * BORDO - 24 and sy1 - sy0 <= alto - 2 * BORDO - 20:
            break
        misura -= 2
    pieno = Image.new("L", (largo, alto), 0)
    disegno = ImageDraw.Draw(pieno)
    sx0, sy0, sx1, sy1 = carattere.getbbox(testo)
    dove = ((largo - (sx1 - sx0)) / 2 - sx0, (alto - (sy1 - sy0)) / 2 - sy0)
    disegno.text(dove, testo, font=carattere, fill=255)
    contorno = Image.new("L", (largo, alto), 0)
    ImageDraw.Draw(contorno).text(dove, testo, font=carattere, fill=255,
                                  stroke_width=BORDO, stroke_fill=255)
    return pieno, contorno


def con_contorno(pieno: Image.Image) -> Image.Image:
    return pieno.filter(ImageFilter.MaxFilter(2 * BORDO + 1))


def stella(lato: int) -> Image.Image:
    im = Image.new("L", (lato, lato), 0)
    c = lato / 2
    fuori, dentro = lato * 0.36, lato * 0.16
    punti = []
    for k in range(10):
        r = fuori if k % 2 == 0 else dentro
        a = -math.pi / 2 + k * math.pi / 5
        punti.append((c + r * math.cos(a), c + r * math.sin(a)))
    ImageDraw.Draw(im).polygon(punti, fill=255)
    return im


def cinque(lato: int) -> tuple[Image.Image, Image.Image]:
    """Il cinque dentro l'anello: il segno del gioco (cinque muri)."""
    pieno = Image.new("L", (lato, lato), 0)
    d = ImageDraw.Draw(pieno)
    c = lato / 2
    r_fuori, r_dentro = lato * 0.36, lato * 0.28
    d.ellipse((c - r_fuori, c - r_fuori, c + r_fuori, c + r_fuori), fill=255)
    d.ellipse((c - r_dentro, c - r_dentro, c + r_dentro, c + r_dentro), fill=0)
    carattere = ImageFont.truetype(str(CARATTERE), int(lato * 0.42))
    sx0, sy0, sx1, sy1 = carattere.getbbox("5")
    d.text((c - (sx1 - sx0) / 2 - sx0, c - (sy1 - sy0) / 2 - sy0), "5", font=carattere, fill=255)
    # Il contorno: l'esterno dell'anello allargato, e il buco fra anello e cinque
    # pieno del colore del contorno (si legge come un gettone).
    contorno = Image.new("L", (lato, lato), 0)
    r = r_fuori + BORDO
    ImageDraw.Draw(contorno).ellipse((c - r, c - r, c + r, c + r), fill=255)
    return pieno, contorno


def frecce(lato: int) -> Image.Image:
    im = Image.new("L", (lato, lato), 0)
    d = ImageDraw.Draw(im)
    for k in range(2):
        x = lato * (0.22 + 0.30 * k)
        s = lato * 0.24
        punta = lato * 0.5
        d.polygon([(x, punta - s), (x + s * 0.55, punta - s), (x + s * 0.55 + s, punta),
                   (x + s * 0.55, punta + s), (x, punta + s), (x + s, punta)], fill=255)
    return im


def fulmine(lato: int) -> Image.Image:
    im = Image.new("L", (lato, lato), 0)
    s = lato / 100.0
    punti = [(58, 10), (28, 54), (47, 54), (38, 90), (74, 42), (54, 42), (64, 10)]
    ImageDraw.Draw(im).polygon([(x * s, y * s) for x, y in punti], fill=255)
    return im


def incolla(foglio_r: Image.Image, foglio_g: Image.Image, pieno: Image.Image,
            contorno: Image.Image, dove: tuple[int, int]) -> None:
    foglio_r.paste(pieno, dove)
    foglio_g.paste(contorno, dove)


def main() -> None:
    rosso = Image.new("L", (LATO, LATO), 0)
    verde = Image.new("L", (LATO, LATO), 0)
    for testo, casella in [("PENTAWALL", (0, 0, 1024, 256)), ("OCRA", (0, 256, 512, 384)),
                           ("TURBO", (512, 256, 1024, 384)), ("TRIBUNA", (0, 384, 512, 512)),
                           ("PORTICO", (512, 384, 1024, 512))]:
        pieno, contorno = maschera_testo(testo, casella)
        incolla(rosso, verde, pieno, contorno, casella[:2])
    s = stella(256)
    incolla(rosso, verde, s, con_contorno(s), (0, 512))
    pieno, contorno = cinque(256)
    incolla(rosso, verde, pieno, contorno, (256, 512))
    f = frecce(256)
    incolla(rosso, verde, f, con_contorno(f), (512, 512))
    z = fulmine(256)
    incolla(rosso, verde, z, con_contorno(z), (768, 512))

    blu = Image.new("L", (LATO, LATO), 0)
    foglio = Image.merge("RGB", (rosso, verde, blu))
    USCITA.parent.mkdir(parents=True, exist_ok=True)
    foglio.save(USCITA)
    print(f"scritto {USCITA} ({USCITA.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
