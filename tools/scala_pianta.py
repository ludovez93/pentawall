# -*- coding: utf-8 -*-
"""
Ingrandisce la pianta della palestra in pianta (x e z), lasciando le altezze.

Tappa 11, blocco E (06/10/2026): da 66 x 66 a 80 x 80 m, la misura di Amateur del
1999. Le quote (-2, 0, 3,5, 7) e le altezze restano: sono tarate sul salto.

**Si lavora sui bordi, non sui centri.** Ogni scatola diventa i suoi due bordi per
asse, e ogni bordo passa per la stessa funzione (moltiplica e arrotonda a 5 cm):
un muro e il pavimento che ci arriva hanno lo stesso bordo, e lo stesso bordo da'
lo stesso numero, quindi quello che si toccava si tocca ancora. Moltiplicare i
centri staccherebbe i pezzi: il bordo di un muro da 0,8 m si sposterebbe di 8 cm
rispetto a quello del pavimento.

**Le sponde e le insegne restano appoggiate.** Stanno a pochi centimetri da una
faccia di muro (la sponda ci entra di 2 cm, l'insegna ne sta fuori 20): quella
distanza si conserva, e la faccia si sposta come il suo muro.

**Le cose tonde restano tonde.** Un pilone e' tondo se la sua misura e' uguale sui
due lati (`Arena._e_tondo`): per lui si moltiplicano centro e misura, cosi' i due
lati non possono finire diversi di un arrotondamento.

Uso:  python tools/scala_pianta.py <fattore> [pianta.json]
      il fattore e' un numero (1.2121...) oppure una frazione (80/66)
"""
import json
import sys
from fractions import Fraction

GRIGLIA = 0.05          # la pianta sta sui 5 cm (LEARNED.md 63: le sporgenze no)
APPOGGIO = 0.65         # oltre questa distanza da una faccia, non e' appoggiata (le insegne stanno a 0,6)


def leggi_fattore(testo):
    return float(Fraction(testo)) if "/" in testo else float(testo)


class Scala:
    def __init__(self, k):
        self.k = k

    def f(self, v):
        """Il bordo: moltiplicato e riportato sulla griglia."""
        return round(round(round(v, 6) * self.k / GRIGLIA) * GRIGLIA, 2)

    def lungo(self, v):
        """Una lunghezza che non e' fra due bordi (diagonali, raggi)."""
        return self.f(v)

    def estensione(self, centro, misura):
        a = self.f(centro - misura / 2.0)
        b = self.f(centro + misura / 2.0)
        return round((a + b) / 2.0, 3), round(b - a, 2)


def numero(v):
    """Come li scriverebbe una persona: 40 e non 40.0, 12.35 e non 12.350000001."""
    v = round(v, 3)
    return int(v) if v == int(v) else v


def facce_dei_muri(pianta):
    """Le facce dritte su cui si appoggia qualcosa: (asse normale, posizione,
    intervallo lungo l'altro asse, intervallo in altezza)."""
    facce = []
    for gruppo, alto in (("muri", None), ("fasce", None), ("soffitti", 0.6)):
        for m in pianta.get(gruppo, []):
            if m.get("giro", 0) != 0:
                continue
            cx, cz = m["centro"]
            mx, mz = m["misura"]
            y0 = m["quota"]
            y1 = y0 + (alto if alto is not None else m["alto"])
            for s in (-1, 1):
                facce.append(("x", cx + s * mx / 2.0, (cz - mz / 2.0, cz + mz / 2.0), (y0, y1)))
                facce.append(("z", cz + s * mz / 2.0, (cx - mx / 2.0, cx + mx / 2.0), (y0, y1)))
    return facce


def appoggio(facce, asse, normale, lungo, y0, y1):
    """La faccia piu' vicina su quell'asse che ha davanti il pezzo, se c'e'."""
    migliore = None
    for a, pos, (t0, t1), (h0, h1) in facce:
        if a != asse:
            continue
        d = abs(normale - pos)
        if d > APPOGGIO or not (t0 - 1e-6 <= lungo <= t1 + 1e-6):
            continue
        if min(y1, h1) - max(y0, h0) <= 0:
            continue
        if migliore is None or d < abs(normale - migliore):
            migliore = pos
    return migliore


def ingrandisci(pianta, k):
    sc = Scala(k)
    vecchia = json.loads(json.dumps(pianta))   # le facce si cercano sulla pianta di prima
    facce = facce_dei_muri(vecchia)
    punto = lambda p: [numero(sc.f(p[0])), numero(sc.f(p[1]))]
    rapporto = []

    m = pianta["misura"]
    m["larghezza"] = numero(sc.f(m["larghezza"] / 2.0) * 2)
    m["profondita"] = numero(sc.f(m["profondita"] / 2.0) * 2)

    for z in pianta["zone"]:
        z["poligono"] = [punto(p) for p in z["poligono"]]
        if "etichetta" in z:
            z["etichetta"] = punto(z["etichetta"])

    for r in pianta["rampe"]:
        da, a, w = r["da"], r["a"], r["larghezza"]
        if da[0] == a[0]:                    # corre lungo z: i fianchi sono bordi in x
            cx, nw = sc.estensione(da[0], w)
            r["da"] = [numero(cx), numero(sc.f(da[1]))]
            r["a"] = [numero(cx), numero(sc.f(a[1]))]
        elif da[1] == a[1]:                  # corre lungo x: i fianchi sono bordi in z
            cz, nw = sc.estensione(da[1], w)
            r["da"] = [numero(sc.f(da[0])), numero(cz)]
            r["a"] = [numero(sc.f(a[0])), numero(cz)]
        else:                                # in diagonale
            r["da"], r["a"] = punto(da), punto(a)
            nw = sc.lungo(w)
        r["larghezza"] = numero(nw)

    for gruppo in ("muri", "soffitti", "fasce"):
        for x in pianta.get(gruppo, []):
            cx, cz = x["centro"]
            mx, mz = x["misura"]
            if x.get("giro", 0) != 0 or mx == mz:
                x["centro"] = punto(x["centro"])
                x["misura"] = [numero(sc.lungo(mx)), numero(sc.lungo(mz))]
            else:
                ncx, nmx = sc.estensione(cx, mx)
                ncz, nmz = sc.estensione(cz, mz)
                x["centro"] = [numero(ncx), numero(ncz)]
                x["misura"] = [numero(nmx), numero(nmz)]

    for l in pianta["lucernari"]:
        cx, nmx = sc.estensione(l["dove"][0], l["misura"][0])
        cz, nmz = sc.estensione(l["dove"][1], l["misura"][1])
        l["dove"] = [numero(cx), numero(cz)]
        l["misura"] = [numero(nmx), numero(nmz)]

    muri_storti = [x for x in vecchia["muri"] if x.get("giro", 0) != 0]

    for s in pianta["sponde"]:
        cx, cz = s["centro"]
        w, h = s["faccia"]
        if "sdraiata" in s:
            ncx, nw = sc.estensione(cx, w)
            ncz, nh = sc.estensione(cz, h)
            s["centro"] = [numero(ncx), numero(ncz)]
            s["faccia"] = [numero(nw), numero(nh)]
            continue
        giro = s.get("giro", 0)
        if giro in (0, 90, -90, 180):
            asse = "z" if giro in (0, 180) else "x"
            normale, lungo = (cz, cx) if asse == "z" else (cx, cz)
            faccia = appoggio(facce, asse, normale, lungo, s["quota"] - h / 2.0, s["quota"] + h / 2.0)
            if faccia is None:
                rapporto.append("sponda senza appoggio, moltiplicata e basta: " + s["nome"])
                nn = sc.f(normale)
            else:
                nn = sc.f(faccia) + (normale - faccia)
            nl, nw = sc.estensione(lungo, w)
            s["centro"] = [numero(nn), numero(nl)] if asse == "x" else [numero(nl), numero(nn)]
            s["faccia"] = [numero(nw), h]
        else:
            vicino = min(muri_storti, key=lambda m: (m["centro"][0] - cx) ** 2 + (m["centro"][1] - cz) ** 2)
            dx, dz = cx - vicino["centro"][0], cz - vicino["centro"][1]
            if dx * dx + dz * dz > 1.0:
                rapporto.append("sponda storta senza muro vicino: " + s["nome"])
                s["centro"] = punto(s["centro"])
            else:
                c = [sc.f(vicino["centro"][0]), sc.f(vicino["centro"][1])]
                s["centro"] = [numero(c[0] + dx), numero(c[1] + dz)]
            s["faccia"] = [numero(sc.lungo(w)), h]

    # Insegne e bersagli bonus stanno appesi a un muro: come le sponde, conservano la
    # distanza dalla sua faccia.
    for i in pianta.get("insegne", []) + pianta.get("bonus", []):
        x, z = i["dove"]
        asse = "z" if i.get("giro", 0) in (0, 180) else "x"
        normale, lungo = (z, x) if asse == "z" else (x, z)
        faccia = appoggio(facce, asse, normale, lungo, i["quota"] - 0.5, i["quota"] + 0.5)
        if faccia is None:
            rapporto.append("appesa senza appoggio, moltiplicata e basta: " + i.get("testo", i.get("nome", "")))
            nn = sc.f(normale)
        else:
            nn = sc.f(faccia) + (normale - faccia)
        nl = sc.f(lungo)
        i["dove"] = [numero(nn), numero(nl)] if asse == "x" else [numero(nl), numero(nn)]

    for gruppo in ("partenze", "bersagli", "segni_per_dopo", "sfere"):
        for x in pianta.get(gruppo, []):
            x["dove"] = punto(x["dove"])
            if "raggio" in x:
                x["raggio"] = numero(sc.lungo(x["raggio"]))

    return rapporto


def scrivi(pianta, percorso):
    """Un oggetto per riga, come la pianta scritta a mano: si legge e si confronta."""
    righe = ["{"]
    chiavi = list(pianta.keys())
    for n, chiave in enumerate(chiavi):
        v = pianta[chiave]
        fine = "," if n < len(chiavi) - 1 else ""
        if isinstance(v, list) and v and isinstance(v[0], dict):
            righe.append('  "%s": [' % chiave)
            for j, x in enumerate(v):
                virgola = "," if j < len(v) - 1 else ""
                righe.append("    " + json.dumps(x, ensure_ascii=False, separators=(", ", ": "))
                             + virgola)
            righe.append("  ]" + fine)
        else:
            righe.append('  "%s": %s%s' % (chiave, json.dumps(v, ensure_ascii=False,
                                                          separators=(", ", ": ")), fine))
    righe.append("}")
    with open(percorso, "w", encoding="utf-8", newline="\n") as uscita:
        uscita.write("\n".join(righe) + "\n")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    k = leggi_fattore(sys.argv[1])
    percorso = sys.argv[2] if len(sys.argv) > 2 else "arene/palestra.json"
    with open(percorso, encoding="utf-8") as entrata:
        pianta = json.load(entrata)
    rapporto = ingrandisci(pianta, k)
    scrivi(pianta, percorso)
    print("pianta ingrandita di %.4f: %s x %s m" % (k, pianta["misura"]["larghezza"],
                                                  pianta["misura"]["profondita"]))
    for riga in rapporto:
        print("  " + riga)


if __name__ == "__main__":
    main()
