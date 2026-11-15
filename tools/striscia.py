"""Strisce di fotogrammi numerati, per guardare il movimento in movimento.

Un effetto che dura tre decimi non si giudica in uno scatto: si mettono in fila i
fotogrammi, ognuno col suo numero, e si guarda dove comincia, dov'e' al colmo e dove
finisce (`LEARNED.md` § 75 e § 79). Questo attrezzo prende dei fotogrammi, ne ritaglia lo
stesso pezzo, lo ingrandisce senza sfumarlo e li mette in griglia; con piu' gruppi
(«PRIMA», «DOPO») fa un foglio di confronto, una striscia sotto l'altra.

Uso (dalla cartella `gioco/`):
  python tools/striscia.py USCITA [--ritaglio X,Y,L,A] [--volte N] [--colonne N]
        [--titolo TESTO] [--gruppo NOME] IMMAGINI... [--gruppo NOME IMMAGINI...]

  --ritaglio X,Y,L,A   il pezzo di ogni fotogramma, in pixel dell'originale (senza: tutto)
  --volte N            quante volte ingrandire il ritaglio (1; anche 0.5 per rimpicciolire)
  --colonne N          quanti per riga (senza: tutti su una riga, al piu' dieci)
  --titolo TESTO       una riga in cima al foglio
  --gruppo NOME        da qui in poi i fotogrammi sono di questo gruppo, con la sua fascia

Il numero su ogni riquadro e' quello in fondo al nome del file (`...-07.png` -> 07), o
il suo posto nella fila. Esempio, il lampo alla canna prima e dopo:
  python tools/striscia.py foglio.jpg --ritaglio 300,120,260,170 --volte 3 \
      --gruppo PRIMA scatti/S14-prima-colpo-0*.png --gruppo DOPO scatti/S14-dopo-colpo-0*.png
"""

import glob
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

QUI = Path(__file__).resolve().parent.parent
TITOLI = QUI / "assets" / "font" / "BebasNeue-Regular.ttf"
NAVY = (15, 27, 61)
ORO = (255, 196, 46)
CHIARO = (240, 242, 250)
MARGINE = 10


def _carattere(misura):
    return ImageFont.truetype(str(TITOLI), misura)


def _leggi(argomenti):
    """Le opzioni e i gruppi: [(nome, [file, ...]), ...]."""
    opzioni = {"ritaglio": None, "volte": 1.0, "colonne": 0, "titolo": ""}
    gruppi = [("", [])]
    i = 0
    while i < len(argomenti):
        voce = argomenti[i]
        if voce == "--ritaglio":
            opzioni["ritaglio"] = tuple(int(n) for n in argomenti[i + 1].split(","))
            i += 2
        elif voce == "--volte":
            opzioni["volte"] = float(argomenti[i + 1])
            i += 2
        elif voce == "--colonne":
            opzioni["colonne"] = int(argomenti[i + 1])
            i += 2
        elif voce == "--titolo":
            opzioni["titolo"] = argomenti[i + 1]
            i += 2
        elif voce == "--gruppo":
            gruppi.append((argomenti[i + 1], []))
            i += 2
        else:
            # La shell di Windows non apre gli asterischi: lo si fa qui.
            trovati = sorted(glob.glob(voce)) if any(c in voce for c in "*?[") else [voce]
            gruppi[-1][1].extend(trovati)
            i += 1
    return opzioni, [g for g in gruppi if g[1]]


def _numero(percorso, posto):
    trovato = re.search(r"(\d+)\.[A-Za-z]+$", Path(percorso).name)
    return trovato.group(1) if trovato else "%02d" % posto


def _riquadro(percorso, posto, opzioni):
    immagine = Image.open(percorso).convert("RGB")
    if opzioni["ritaglio"]:
        x, y, largo, alto = opzioni["ritaglio"]
        immagine = immagine.crop((x, y, x + largo, y + alto))
    volte = opzioni["volte"]
    if volte != 1.0:
        misura = (max(1, round(immagine.width * volte)), max(1, round(immagine.height * volte)))
        # Ingrandendo, i pixel restano pixel: e' quello che si vuole guardare.
        immagine = immagine.resize(misura, Image.NEAREST if volte > 1.0 else Image.LANCZOS)
    # Il numero in alto a sinistra, oro su una linguetta navy.
    alto_numero = max(18, min(34, immagine.height // 7))
    carattere = _carattere(alto_numero)
    testo = _numero(percorso, posto)
    disegno = ImageDraw.Draw(immagine)
    largo_testo = disegno.textlength(testo, font=carattere)
    disegno.rectangle((0, 0, largo_testo + 12, alto_numero + 6), fill=NAVY)
    disegno.text((6, 2), testo, font=carattere, fill=ORO)
    return immagine


def _striscia(nome, file, opzioni):
    riquadri = [_riquadro(percorso, i, opzioni) for i, percorso in enumerate(file)]
    colonne = opzioni["colonne"] or min(len(riquadri), 10)
    righe = (len(riquadri) + colonne - 1) // colonne
    largo = max(r.width for r in riquadri)
    alto = max(r.height for r in riquadri)
    fascia = 40 if nome else 0
    foglio = Image.new("RGB", (MARGINE + colonne * (largo + MARGINE),
                               fascia + MARGINE + righe * (alto + MARGINE)), NAVY)
    if nome:
        ImageDraw.Draw(foglio).text((MARGINE, 4), nome, font=_carattere(32), fill=CHIARO)
    for i, riquadro in enumerate(riquadri):
        foglio.paste(riquadro, (MARGINE + (i % colonne) * (largo + MARGINE),
                                fascia + MARGINE + (i // colonne) * (alto + MARGINE)))
    return foglio


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    uscita = Path(sys.argv[1])
    opzioni, gruppi = _leggi(sys.argv[2:])
    if not gruppi:
        print("nessun fotogramma trovato")
        return 1
    strisce = [_striscia(nome, file, opzioni) for nome, file in gruppi]
    testa = 54 if opzioni["titolo"] else 0
    foglio = Image.new("RGB", (max(s.width for s in strisce), testa + sum(s.height for s in strisce)), NAVY)
    if opzioni["titolo"]:
        ImageDraw.Draw(foglio).text((MARGINE, 6), opzioni["titolo"], font=_carattere(42), fill=ORO)
    y = testa
    for striscia in strisce:
        foglio.paste(striscia, (0, y))
        y += striscia.height
    uscita.parent.mkdir(parents=True, exist_ok=True)
    if uscita.suffix.lower() in (".jpg", ".jpeg"):
        foglio.save(uscita, quality=92)
    else:
        foglio.save(uscita)
    print("%s: %d x %d, %d fotogrammi" % (uscita, foglio.width, foglio.height,
                                          sum(len(file) for _, file in gruppi)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
