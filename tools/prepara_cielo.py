"""Il cielo di giorno dell'arena-giocattolo (tappa 10, blocco D).

Parte da un cielo vero di Poly Haven (CC0, `kloofendal_48d_partly_cloudy_puresky`,
scaricato in `../materiale-3d/cielo/`) e lo ridipinge come quello di NERF Superblast:
azzurro saturo, piu' chiaro verso l'orizzonte, nuvole bianche piene con l'ombra
azzurrina. Dal cielo vero si prende solo **dove** stanno le nuvole e quanto sono
dense; i colori li decide questo file. Esce un panorama da 2048 x 1024 in JPG, che
il gioco legge con `PanoramaSkyMaterial`.

Uso (dalla cartella `gioco/`):  python tools/prepara_cielo.py
"""

from pathlib import Path

import cv2
import numpy as np

QUI = Path(__file__).resolve().parent.parent
SORGENTE = QUI.parent / "materiale-3d" / "cielo" / "kloofendal_48d_partly_cloudy_puresky_2k.hdr"
USCITA = QUI / "assets" / "cielo" / "cielo_giorno.jpg"

# I colori, in RGB da 0 a 1: lo zenit e l'orizzonte del cielo, la luce e l'ombra
# delle nuvole.
ZENIT = np.array([0.07, 0.50, 0.93])
ORIZZONTE = np.array([0.56, 0.84, 1.00])
NUVOLA_LUCE = np.array([1.00, 1.00, 1.00])
NUVOLA_OMBRA = np.array([0.70, 0.80, 0.95])
# Sotto l'orizzonte non si vede quasi mai (lo coprono i muri e le rocce): una foschia
# chiara, cosi' quello che spunta fra due rocce non e' un buco.
FOSCHIA = np.array([0.80, 0.90, 0.98])


def liscio(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def main() -> None:
    hdr = cv2.imread(str(SORGENTE), cv2.IMREAD_ANYDEPTH | cv2.IMREAD_COLOR)
    if hdr is None:
        raise SystemExit(f"manca il cielo sorgente: {SORGENTE}")
    rgb = hdr[:, :, ::-1].astype(np.float64)
    alto, largo = rgb.shape[:2]
    # Il sole sfonda di migliaia di volte: si taglia, o la nuvola che gli sta
    # davanti diventa un buco bianco.
    rgb = np.minimum(rgb, 4.0)
    rgb = cv2.GaussianBlur(rgb, (0, 0), 1.2)
    luce = rgb @ np.array([0.2126, 0.7152, 0.0722])
    # Quanto e' blu un punto: il cielo sereno ha il blu ben sopra il rosso, la
    # nuvola no.
    blu = (rgb[:, :, 2] - rgb[:, :, 0]) / (rgb[:, :, 2] + 1e-4)
    cielo_sereno = np.percentile(blu[: alto // 3], 85)
    nuvola = liscio(cielo_sereno * 0.78, cielo_sereno * 0.30, blu)
    # E quanto e' chiaro rispetto al cielo della sua riga: separa il bordo della
    # nuvola dal cielo velato.
    riga_cielo = np.percentile(luce, 30, axis=1, keepdims=True)
    nuvola *= liscio(1.02, 1.45, luce / riga_cielo)
    nuvola = cv2.GaussianBlur(nuvola, (0, 0), 1.0)
    # La luce dentro la nuvola: il lato al sole bianco pieno, il ventre azzurrino.
    dentro = liscio(0.25, 0.85, (luce / (riga_cielo * 2.4)))

    # L'altezza sull'orizzonte, da +90 (riga 0) a -90 (ultima riga).
    elevazione = 90.0 - np.arange(alto) / (alto - 1) * 180.0
    sopra = liscio(0.0, 55.0, elevazione)[:, None, None]
    fondo = ORIZZONTE * (1.0 - sopra) + ZENIT * sopra
    sotto = liscio(0.0, -12.0, elevazione)[:, None, None]
    fondo = fondo * (1.0 - sotto) + FOSCHIA * sotto
    fondo = np.broadcast_to(fondo, (alto, largo, 3))

    colore_nuvola = NUVOLA_OMBRA * (1.0 - dentro[:, :, None]) + NUVOLA_LUCE * dentro[:, :, None]
    # Le nuvole stanno sopra l'orizzonte: sotto, il cielo vero di Poly Haven e'
    # un riflesso, e va tolto.
    nuvola *= liscio(-1.0, 2.0, elevazione)[:, None]
    finale = fondo * (1.0 - nuvola[:, :, None]) + colore_nuvola * nuvola[:, :, None]

    USCITA.parent.mkdir(parents=True, exist_ok=True)
    otto = np.clip(finale ** (1.0 / 1.0), 0.0, 1.0)
    cv2.imwrite(str(USCITA), (otto[:, :, ::-1] * 255.0 + 0.5).astype(np.uint8),
                [cv2.IMWRITE_JPEG_QUALITY, 90])
    print(f"scritto {USCITA} ({USCITA.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
