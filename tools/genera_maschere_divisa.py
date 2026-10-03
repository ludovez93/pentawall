"""Le maschere della divisa dei corpi umani (tappa 8, blocco D).

Il corpo base di Quaternius è nudo, e la tuta gliela mette `assets/materials/tuta.gdshader`.
Fino al 03/10/2026 la tuta era una tinta sola dal collo ai piedi, piedi e mani compresi: da
vicino un manichino in calzamaglia, scalzo. Qui si ricava **dove stanno le scarpe, i guanti e
gli inserti** leggendo il modello stesso — a quale osso è legato ogni vertice — e lo si
disegna nello spazio delle UV, così lo shader sa cosa colorare come cosa.

Canali dell'immagine:
  R  scarpe: 1,0 la tomaia, 0,5 la suola (gli ultimi centimetri da terra)
  G  guanti: le mani, dal polso in giù
  B  inserti: avambracci e stinchi, nel secondo colore della divisa

Uso:  python tools/genera_maschere_divisa.py
"""
import json
import os
import struct

from PIL import Image, ImageDraw, ImageFilter

QUI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(QUI, "..", "assets", "models", "quaternius", "base")
LATO = 1024

SCARPE = {"foot_l", "foot_r", "ball_l", "ball_r", "ball_leaf_l", "ball_leaf_r"}
INSERTI = {"lowerarm_l", "lowerarm_r", "calf_l", "calf_r"}
ALTEZZA_SUOLA = 0.035  # metri da terra, nella posa di riposo

TIPI = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
COMPONENTI = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def leggi(gltf, binario, indice):
    acc = gltf["accessors"][indice]
    vista = gltf["bufferViews"][acc["bufferView"]]
    n = COMPONENTI[acc["type"]]
    tipo = TIPI[acc["componentType"]]
    passo_elem = struct.calcsize("<" + tipo) * n
    passo = vista.get("byteStride", passo_elem)
    inizio = vista.get("byteOffset", 0) + acc.get("byteOffset", 0)
    fuori = []
    for i in range(acc["count"]):
        valori = struct.unpack_from("<" + tipo * n, binario, inizio + i * passo)
        fuori.append(valori if n > 1 else valori[0])
    if acc.get("normalized") and tipo in "BH":
        massimo = 255.0 if tipo == "B" else 65535.0
        fuori = [tuple(v / massimo for v in x) if n > 1 else x / massimo for x in fuori]
    return fuori


def regione(nome_osso, altezza):
    if nome_osso in SCARPE:
        return (255 if altezza > ALTEZZA_SUOLA else 128, 0, 0)
    if nome_osso.startswith("hand_") or any(
            nome_osso.startswith(d) for d in ("index_", "middle_", "pinky_", "ring_", "thumb_")):
        return (0, 255, 0)
    if nome_osso in INSERTI:
        return (0, 0, 255)
    return (0, 0, 0)


def maschera(sesso):
    percorso = os.path.join(BASE, f"Superhero_{sesso}_FullBody.gltf")
    with open(percorso, encoding="utf-8") as f:
        gltf = json.load(f)
    with open(os.path.join(BASE, gltf["buffers"][0]["uri"]), "rb") as f:
        binario = f.read()
    nodi = gltf["nodes"]
    ossa = [nodi[j]["name"] for j in gltf["skins"][0]["joints"]]

    # La mesh del corpo è quella con più triangoli (le altre sono occhi e sopracciglia).
    corpo = max(gltf["meshes"],
                key=lambda m: gltf["accessors"][m["primitives"][0]["indices"]]["count"])
    primitiva = corpo["primitives"][0]
    att = primitiva["attributes"]
    posizioni = leggi(gltf, binario, att["POSITION"])
    uv = leggi(gltf, binario, att["TEXCOORD_0"])
    giunti = leggi(gltf, binario, att["JOINTS_0"])
    pesi = leggi(gltf, binario, att["WEIGHTS_0"])
    indici = leggi(gltf, binario, primitiva["indices"])
    terra = min(p[1] for p in posizioni)

    colori = []
    for i in range(len(posizioni)):
        migliore = max(range(4), key=lambda k: pesi[i][k])
        colori.append(regione(ossa[giunti[i][migliore]], posizioni[i][1] - terra))

    immagine = Image.new("RGB", (LATO, LATO), (0, 0, 0))
    disegno = ImageDraw.Draw(immagine)
    for t in range(0, len(indici), 3):
        a, b, c = indici[t], indici[t + 1], indici[t + 2]
        # Il triangolo prende la regione della maggioranza dei suoi vertici: un
        # bordo fra due regioni resta netto invece di sfumare in un terzo colore.
        voti = {}
        for v in (a, b, c):
            voti[colori[v]] = voti.get(colori[v], 0) + 1
        colore = max(voti, key=voti.get)
        if colore == (0, 0, 0):
            continue
        punti = [(uv[v][0] * LATO, uv[v][1] * LATO) for v in (a, b, c)]
        disegno.polygon(punti, fill=colore)
    # Un paio di pixel di margine sulle cuciture delle UV, o al filo si vede la tuta.
    immagine = immagine.filter(ImageFilter.MaxFilter(5))
    uscita = os.path.join(BASE, f"Maschera_Divisa_{sesso}.png")
    immagine.save(uscita)
    conta = {}
    for c in colori:
        conta[c] = conta.get(c, 0) + 1
    print(sesso, "vertici", len(posizioni), "regioni", conta, "->", os.path.basename(uscita))


if __name__ == "__main__":
    for s in ("Male", "Female"):
        maschera(s)
