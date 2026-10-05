"""I tappetini a incastro del pavimento dell'arena-giocattolo (tappa 10, blocco D).

Il pavimento di NERF Superblast e' un azzurro-lilla liscio a riquadri: qui sono i
tappetini di gommapiuma a incastro delle palestre per bambini, quadrati da due metri
coi denti sui bordi. L'immagine e' in grigi: il colore lo mette il materiale di ogni
zona (`Giocattolo`), cosi' un'immagine sola veste tutti i pavimenti.

Copre quattro metri per quattro (2 x 2 tappetini): e' il passo delle coordinate che
`Muratura._prisma` da' ai pavimenti, che sono prese dal mondo, quindi i tappetini di
due zone vicine combaciano.

Uso (dalla cartella `gioco/`):  python tools/prepara_tappeti.py
"""

from pathlib import Path

import numpy as np
from PIL import Image

QUI = Path(__file__).resolve().parent.parent
USCITA = QUI / "assets" / "giocattolo" / "tappeto.png"

LATO = 256          # pixel per quattro metri
TAPPETO = LATO // 2  # un tappetino da due metri
DENTI = 5           # denti per lato di un tappetino
PROFONDO = 7        # quanto entra un dente, in pixel
CHIARO = 0.93
SCURO = 0.86
SOLCO = 0.58
ORLO = 0.985


def main() -> None:
    y, x = np.mgrid[0:LATO, 0:LATO].astype(np.float64)
    # Di quale tappetino e' ogni pixel, prima dei denti.
    colonna = (x // TAPPETO).astype(int)
    riga = (y // TAPPETO).astype(int)
    # I denti: lungo ogni bordo verticale il confine si sposta a onde quadre
    # arrotondate, e lo stesso lungo i bordi orizzontali. Un pixel vicino al bordo
    # passa al tappetino accanto se cade dentro un dente.
    passo = TAPPETO / DENTI
    onda_y = np.sin((y % TAPPETO) / passo * np.pi * 2.0)
    onda_x = np.sin((x % TAPPETO) / passo * np.pi * 2.0)
    dente_y = np.clip(onda_y * 3.0, -1.0, 1.0) * PROFONDO * 0.5
    dente_x = np.clip(onda_x * 3.0, -1.0, 1.0) * PROFONDO * 0.5
    sposta_x = x + dente_y
    sposta_y = y + dente_x
    colonna = np.floor(sposta_x / TAPPETO).astype(int)
    riga = np.floor(sposta_y / TAPPETO).astype(int)
    scacco = (colonna + riga) % 2
    tinta = np.where(scacco == 0, CHIARO, SCURO)
    # Il solco fra due tappetini: dove il confine deformato passa vicino.
    dist_x = np.abs(((sposta_x + TAPPETO / 2) % TAPPETO) - TAPPETO / 2)
    dist_y = np.abs(((sposta_y + TAPPETO / 2) % TAPPETO) - TAPPETO / 2)
    vicino = np.minimum(dist_x, dist_y)
    solco = np.clip(1.0 - (vicino - 0.6) / 1.4, 0.0, 1.0)
    orlo = np.clip(1.0 - np.abs(vicino - 2.6) / 1.2, 0.0, 1.0) * 0.5
    valore = tinta * (1.0 - solco) + SOLCO * solco
    valore = valore * (1.0 - orlo) + ORLO * orlo
    # Una grana leggerissima, che a distanza sparisce: la gommapiuma non e' plastica.
    rng = np.random.default_rng(5)
    grana = rng.normal(0.0, 0.012, (LATO, LATO))
    valore = np.clip(valore + grana, 0.0, 1.0)

    USCITA.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((valore * 255.0 + 0.5).astype(np.uint8), mode="L").convert("RGB").save(USCITA)
    print(f"scritto {USCITA} ({USCITA.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
